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
import 'package:shared_preferences/shared_preferences.dart';

import '../app/planstar_app.dart';
import '../core/ports.dart';
import '../features/reminder/infrastructure/local_notification_gateway.dart';
import '../infrastructure/cross_engine_sync.dart';
import '../infrastructure/desktop_adapters.dart';
import '../infrastructure/desktop_wallpaper_gateway.dart';
import '../infrastructure/file_gateway.dart';
import '../infrastructure/storage_adapters.dart';
import '../infrastructure/wallpaper_image_gateway.dart';
import '../windows/sub_window_app.dart';
import 'core_providers.dart';

final class AppBootstrap {
  const AppBootstrap._();

  /// 统一入口。`desktop_multi_window` 的子窗口会以
  /// `['multi_window', windowId, argumentsJson]` 调用同一个 `main`。
  static Future<void> run(List<String> args) async {
    WidgetsFlutterBinding.ensureInitialized();

    final logger = AppLogger(
      sinks: <LogSink>[ConsoleLogSink()],
      level: AppLogger.defaultLevelFor(isReleaseMode: kReleaseMode),
    );
    const clock = SystemClock();
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final isSubWindow = args.length >= 3 && args.first == 'multi_window';
    final forceDesktopEmbedding =
        args.contains('--planstar-embed-desktop');

    final prefs = await SharedPreferences.getInstance();
    final crossEngineSync = FileCrossEngineSync();
    await crossEngineSync.initialize();
    final keyValueStore = SharedPreferencesStore(
      prefs,
      onWrite: crossEngineSync.signalChange,
    );
    final secureStore = FlutterSecureStorageAdapter(
      const FlutterSecureStorage(),
    );

    final configLoader = ConfigLoader(
      JsonConfigSource(
        () => rootBundle.loadString('assets/config/default_config.json'),
        label: 'assets/config/default_config.json',
      ),
    );
    await configLoader.load();
    final config = configLoader.cached ?? AppConfig.empty;

    final dio = buildDio(
      baseUrl: config.getString('apiBaseUrl') ??
          'https://api.planstar.local/v1/',
      enableLogging: false,
    );
    dio.interceptors.add(
      RetryInterceptor(dio: dio, maxRetries: 2, logger: logger.child('net')),
    );
    final apiClient = ApiClient(dio);
    final eventBus = DomainEventBus(
      onHandlerError: (Object error, StackTrace stack, DomainEvent event) {
        logger.error('领域事件处理失败：$event', error: error, stackTrace: stack);
      },
    );

    final notificationGateway = FlutterLocalNotificationsGateway(
      logger: logger.child('notify'),
      clock: clock,
      locationName: config.section('calendar').getString('timezone') ??
          'Asia/Shanghai',
    );
    await notificationGateway.initialize();

    final windowGateway = WindowManagerGateway(logger: logger.child('window'));
    final trayGateway = TrayManagerGateway();
    final multiWindowGateway =
        DesktopMultiWindowGateway(logger: logger.child('multiwindow'));
    final autoStartGateway = LaunchAtStartupGateway();
    final soundGateway =
        AudioPlayersSoundGateway(logger: logger.child('sound'));
    final fileGateway = DesktopFileGateway();
    final desktopWallpaperGateway = MethodChannelDesktopWallpaperGateway(
      logger: logger.child('wallpaper'),
    );
    final wallpaperImageGateway = LocalWallpaperImageGateway();
    final trayActions = StreamController<TrayAction>.broadcast();

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
        if (subWindowArguments['kind'] != 'desktop') {
          final rect = WindowRect.fromJson(
            Map<String, Object?>.from(
              (subWindowArguments['rect'] as Map?) ??
                  const <String, Object?>{},
            ),
          );
          await windowGateway.initializeSubWindow(
            subWindowArguments['kind'] == 'note' ? '便签' : '倒数日',
            rect,
          );
        }
      } else {
        await windowGateway.initializeMainWindow();
        await trayGateway.initialize(trayActions.add);
      }
      await multiWindowGateway.bindCurrentWindow();
    }

    final overrides = [
      clockProvider.overrideWithValue(clock),
      keyValueStoreProvider.overrideWithValue(keyValueStore),
      storageReloaderProvider.overrideWithValue(keyValueStore),
      crossEngineSyncProvider.overrideWithValue(crossEngineSync),
      secureStoreProvider.overrideWithValue(secureStore),
      loggerProvider.overrideWithValue(logger),
      configLoaderProvider.overrideWithValue(configLoader),
      apiClientProvider.overrideWithValue(apiClient),
      domainEventBusProvider.overrideWithValue(eventBus),
      notificationGatewayProvider.overrideWithValue(notificationGateway),
      windowGatewayProvider.overrideWithValue(windowGateway),
      trayGatewayProvider.overrideWithValue(trayGateway),
      multiWindowGatewayProvider.overrideWithValue(multiWindowGateway),
      autoStartGatewayProvider.overrideWithValue(autoStartGateway),
      soundGatewayProvider.overrideWithValue(soundGateway),
      fileGatewayProvider.overrideWithValue(fileGateway),
      desktopWallpaperGatewayProvider.overrideWithValue(
        desktopWallpaperGateway,
      ),
      wallpaperImageGatewayProvider.overrideWithValue(
        wallpaperImageGateway,
      ),
      desktopEmbeddedOverrideProvider.overrideWithValue(
        forceDesktopEmbedding,
      ),
      trayActionsProvider.overrideWithValue(trayActions.stream),
    ];

    runApp(
      ProviderScope(
        overrides: overrides,
        child: isSubWindow
            ? SubWindowApp(arguments: subWindowArguments)
            : const PlanstarApp(),
      ),
    );
  }
}
