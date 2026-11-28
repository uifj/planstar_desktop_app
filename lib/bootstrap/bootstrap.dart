/// 应用装配：创建所有适配器、注入 Provider 覆盖、选择主窗口 / 子窗口入口。
library;

import 'dart:async';
import 'dart:convert';

import 'package:core/config.dart';
import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../app/planstar_app.dart';
import '../core/ports.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/network/planstar_network_interceptor.dart';
import '../features/auth/network/planstar_request_context.dart';
import '../features/reminder/infrastructure/local_notification_gateway.dart';
import '../features/settings/infrastructure/settings_repository.dart';
import '../infrastructure/app_updater_gateway.dart';
import '../infrastructure/data_hub.dart';
import '../infrastructure/desktop_adapters.dart';
import '../infrastructure/desktop_platform_config.dart';
import '../infrastructure/desktop_wallpaper_gateway.dart';
import '../infrastructure/file_gateway.dart';
import '../infrastructure/storage_adapters.dart';
import '../infrastructure/wallpaper_image_gateway.dart';
import '../l10n/l10n.dart';
import '../features/settings/domain/app_settings.dart';
import '../windows/sub_window_app.dart';
import 'core_providers.dart';

final class AppBootstrap {
  const AppBootstrap._();

  /// 统一入口。`desktop_multi_window` 的子窗口会以
  /// `['multi_window', windowId, argumentsJson]` 调用同一个 `main`。
  static Future<void> initializeRuntime() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
  }

  static Future<void> run(List<String> args) async {
    await initializeRuntime();

    final logger = AppLogger(
      sinks: <LogSink>[ConsoleLogSink()],
      level: AppLogger.defaultLevelFor(isReleaseMode: kReleaseMode),
    );
    const clock = SystemClock();
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final isSubWindow = args.length >= 3 && args.first == 'multi_window';
    final forceDesktopEmbedding = args.contains('--planstar-embed-desktop');

    // 单一真相源：所有 engine 通过原生 DataHub 串行读写，类型化回调广播。
    // 不再使用 SharedPreferences —— 它的 Windows 实现每个 isolate 各缓存一份，
    // 且 legacy reload() 并不会重读磁盘。
    //
    // DataHub 建库与配置读取互不依赖，并行启动可减少首帧前的串行等待。
    final dataHubFuture = DataHubStore.create();
    final configLoader = ConfigLoader(
      JsonConfigSource(
        () => rootBundle.loadString('assets/config/default_config.json'),
        label: 'assets/config/default_config.json',
      ),
    );
    final configFuture = configLoader.load();
    final dataHub = await dataHubFuture;
    await configFuture;
    final config = configLoader.cached ?? AppConfig.empty;
    final secureStore = FlutterSecureStorageAdapter(
      const FlutterSecureStorage(),
    );

    final dio = buildDio(
      baseUrl:
          config.getString('apiBaseUrl') ?? 'https://api.planstar.local/v1/',
      enableLogging: false,
    );
    dio.interceptors.add(
      RetryInterceptor(dio: dio, maxRetries: 2, logger: logger.child('net')),
    );
    final apiClient = ApiClient(dio);
    final planstarConfig = config.section('planstar');
    final planstarContext = PlanstarRequestContext();
    final planstarVersion = planstarConfig.getString('appVersion') ?? '1.0.0';
    final planstarChannel = planstarConfig.getString('channel') ?? 'desktop';
    final planstarDio = buildDio(
      baseUrl:
          planstarConfig.getString('baseUrl') ?? 'https://api.planstar.top/',
      enableLogging: false,
    );
    planstarDio.interceptors.add(
      PlanstarNetworkInterceptor(
        context: planstarContext,
        userAgent: 'PlanstarDesktop/$planstarVersion ($planstarChannel)',
      ),
    );
    final planstarApiClient = ApiClient(planstarDio);
    final eventBus = DomainEventBus(
      onHandlerError: (Object error, StackTrace stack, DomainEvent event) {
        logger.error('领域事件处理失败：$event', error: error, stackTrace: stack);
      },
    );

    final localizationScope = AppLocalizationScope();
    try {
      final rawSettings = await dataHub.read(LocalSettingsRepository.key);
      if (rawSettings != null) {
        final storedSettings = jsonDecode(rawSettings) as Map<String, Object?>;
        localizationScope.setLanguage(
          AppSettings.fromJson(storedSettings).language,
        );
      }
    } catch (error) {
      logger.warn('读取已保存的语言设置失败', error: error);
    }
    final notificationGateway = FlutterLocalNotificationsGateway(
      logger: logger.child('notify'),
      clock: clock,
      localizationScope: localizationScope,
      locationName:
          config.section('calendar').getString('timezone') ?? 'Asia/Shanghai',
    );
    // 仅主窗口需要通知。子窗口（便签 / 倒数日 / 桌面小组件）跳过插件初始化，
    // 省掉每个 engine 重复注册通知回调的启动开销；与窗口、托盘初始化并行。
    final notificationReady = isSubWindow
        ? Future<void>.value()
        : notificationGateway.initialize();

    final windowGateway = WindowManagerGateway(
      logger: logger.child('window'),
      localizationScope: localizationScope,
    );
    final trayGateway = TrayManagerGateway(
      logger: logger.child('tray'),
      localizationScope: localizationScope,
    );
    final multiWindowGateway = DesktopMultiWindowGateway(
      logger: logger.child('multiwindow'),
    );
    final autoStartGateway = LaunchAtStartupGateway();
    final appUpdaterGateway = AutoUpdaterGateway();
    final soundGateway = AudioPlayersSoundGateway(
      logger: logger.child('sound'),
    );
    final fileGateway = DesktopFileGateway(
      localizationScope: localizationScope,
    );
    final desktopWallpaperGateway = PigeonDesktopWallpaperGateway(
      logger: logger.child('wallpaper'),
    );
    final wallpaperImageGateway = LocalWallpaperImageGateway();
    final screenGateway = ScreenRetrieverGateway(
      logger: logger.child('screen'),
    );
    final hotkeyGateway = HotkeyManagerGateway(logger: logger.child('hotkey'));
    final trayActions = StreamController<TrayAction>.broadcast();
    final hotkeyActions = StreamController<HotkeyAction>.broadcast();

    Map<String, Object?> subWindowArguments = const <String, Object?>{};
    if (isDesktop) {
      if (isSubWindow) {
        try {
          subWindowArguments = Map<String, Object?>.from(
            jsonDecode(args[2]) as Map,
          );
        } catch (_) {
          subWindowArguments = const <String, Object?>{};
        }
        // 桌面小组件的窗口由原生 overlay 自己接管（全虚拟屏 / 透明 / 最底），
        // 不能再让 window_manager 去设标题栏与固定尺寸。
        if (subWindowArguments['kind'] == 'desktop') {
          if (defaultTargetPlatform == TargetPlatform.macOS) {
            await desktopWallpaperGateway.configureOverlay(enable: true);
          }
        } else {
          final rect = WindowRect.fromJson(
            Map<String, Object?>.from(
              (subWindowArguments['rect'] as Map?) ?? const <String, Object?>{},
            ),
          );
          await windowGateway.initializeSubWindow(
            subWindowArguments['kind'] == 'note'
                ? localizationScope.localizations.noteTitle
                : localizationScope.localizations.countdownWindowTitle,
            rect,
            titleBuilder: (AppLocalizations l10n) =>
                subWindowArguments['kind'] == 'note'
                ? l10n.noteTitle
                : l10n.countdownWindowTitle,
          );
        }
      } else {
        await windowGateway.initializeMainWindow();
        await trayGateway.initialize(trayActions.add);
        await hotkeyGateway.initialize(hotkeyActions.add);
      }
      await multiWindowGateway.bindCurrentWindow();
    }
    await notificationReady;

    // 仅主窗口配置自更新（子窗口是便签/倒数日/小组件 overlay，无需更新检查）。
    if (!isSubWindow) {
      await appUpdaterGateway.configure(
        '${config.getString('apiBaseUrl') ?? 'https://api.planstar.local/v1/'}'
        'update/appcast.xml?platform=${desktopUpdatePlatform(defaultTargetPlatform)}&channel=stable',
      );
    }

    final overrides = [
      appLocalizationScopeProvider.overrideWithValue(localizationScope),
      clockProvider.overrideWithValue(clock),
      keyValueStoreProvider.overrideWithValue(dataHub),
      storageReloaderProvider.overrideWithValue(dataHub),
      crossEngineSyncProvider.overrideWithValue(dataHub),
      secureStoreProvider.overrideWithValue(secureStore),
      loggerProvider.overrideWithValue(logger),
      configLoaderProvider.overrideWithValue(configLoader),
      apiClientProvider.overrideWithValue(apiClient),
      planstarApiClientProvider.overrideWithValue(planstarApiClient),
      planstarRequestContextProvider.overrideWithValue(planstarContext),
      domainEventBusProvider.overrideWithValue(eventBus),
      notificationGatewayProvider.overrideWithValue(notificationGateway),
      windowGatewayProvider.overrideWithValue(windowGateway),
      trayGatewayProvider.overrideWithValue(trayGateway),
      multiWindowGatewayProvider.overrideWithValue(multiWindowGateway),
      autoStartGatewayProvider.overrideWithValue(autoStartGateway),
      appUpdaterGatewayProvider.overrideWithValue(appUpdaterGateway),
      soundGatewayProvider.overrideWithValue(soundGateway),
      fileGatewayProvider.overrideWithValue(fileGateway),
      desktopWallpaperGatewayProvider.overrideWithValue(
        desktopWallpaperGateway,
      ),
      screenGatewayProvider.overrideWithValue(screenGateway),
      wallpaperImageGatewayProvider.overrideWithValue(wallpaperImageGateway),
      desktopEmbeddedOverrideProvider.overrideWithValue(forceDesktopEmbedding),
      trayActionsProvider.overrideWithValue(trayActions.stream),
      hotkeyGatewayProvider.overrideWithValue(hotkeyGateway),
      hotkeyActionsProvider.overrideWithValue(hotkeyActions.stream),
    ];

    runApp(
      ProviderScope(
        overrides: overrides,
        child: isSubWindow
            ? SubWindowApp(arguments: subWindowArguments)
            : const PlanstarApp(),
      ),
    );
    // 启动后非阻塞后台检查一次（有更新时原生更新器才弹窗）。
    unawaited(appUpdaterGateway.checkForUpdates(inBackground: true));
  }
}
