/// 组合根（Composition Root）的 Provider 声明。
///
/// 所有外部能力都以**端口**形式暴露，具体适配器由 `AppBootstrap` 在
/// `main()` 里 `overrideWithValue` 注入。这样领域层 / 应用层 / 表现层
/// 没有任何插件 import，测试可以整层替换为内存实现。
library;

import 'package:core/config.dart';
import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ports.dart';

/// 时钟。
final clockProvider = Provider<Clock>((Ref ref) => const SystemClock());

/// 全局唯一 id（`core` 的 UUIDv7 形态生成器，字典序 = 时间序）。
final idGeneratorProvider = Provider<IdGenerator>(
  (Ref ref) => TimestampIdGenerator(),
);

/// 普通 KV 存储（由 SharedPreferences 适配）。
final keyValueStoreProvider = Provider<KeyValueStore>(
  (Ref ref) => throw UnimplementedError('keyValueStoreProvider 未注入'),
);

final storageReloaderProvider = Provider<StorageReloader>(
  (Ref ref) => throw UnimplementedError('storageReloaderProvider 未注入'),
);

final crossEngineSyncProvider = Provider<CrossEngineSync>(
  (Ref ref) => throw UnimplementedError('crossEngineSyncProvider 未注入'),
);

/// 安全存储（由 flutter_secure_storage 适配）。
final secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => throw UnimplementedError('secureStoreProvider 未注入'),
);

/// 存储门面：按用户隔离、登出时只清安全存储。
final appStoreProvider = Provider<AppStore>(
  (Ref ref) => AppStore(
    preferences: ref.watch(keyValueStoreProvider),
    secure: ref.watch(secureStoreProvider),
  ),
);

/// 日志器：级别由构建模式决定，sink 可插拔。
final loggerProvider = Provider<AppLogger>(
  (Ref ref) => throw UnimplementedError('loggerProvider 未注入'),
);

/// 幂等配置加载器。
final configLoaderProvider = Provider<ConfigLoader>(
  (Ref ref) => throw UnimplementedError('configLoaderProvider 未注入'),
);

/// 已加载的引导配置（未成功加载时回退到空配置，不让 UI 崩）。
final appConfigProvider = Provider<AppConfig>(
  (Ref ref) => ref.watch(configLoaderProvider).cached ?? AppConfig.empty,
);

/// 永不抛异常的 API 客户端（来自 `packages/infras/core`）。
final apiClientProvider = Provider<ApiClient>(
  (Ref ref) => throw UnimplementedError('apiClientProvider 未注入'),
);

/// 进程内领域事件总线。
final domainEventBusProvider = Provider<DomainEventBus>(
  (Ref ref) => throw UnimplementedError('domainEventBusProvider 未注入'),
);

// ── 桌面能力端口 ────────────────────────────────────────────────────────────

final notificationGatewayProvider = Provider<NotificationGateway>(
  (Ref ref) => throw UnimplementedError('notificationGatewayProvider 未注入'),
);

final windowGatewayProvider = Provider<WindowGateway>(
  (Ref ref) => throw UnimplementedError('windowGatewayProvider 未注入'),
);

final trayGatewayProvider = Provider<TrayGateway>(
  (Ref ref) => throw UnimplementedError('trayGatewayProvider 未注入'),
);

/// 托盘菜单点击事件（组合根把原生回调桥接成流，供 DesktopController 消费）。
final trayActionsProvider = Provider<Stream<TrayAction>>(
  (Ref ref) => const Stream<TrayAction>.empty(),
);

final hotkeyGatewayProvider = Provider<HotkeyGateway>(
  (Ref ref) => throw UnimplementedError('hotkeyGatewayProvider 未注入'),
);

/// 全局热键触发事件（组合根把原生回调桥接成流，供 DesktopController 消费）。
final hotkeyActionsProvider = Provider<Stream<HotkeyAction>>(
  (Ref ref) => const Stream<HotkeyAction>.empty(),
);

final multiWindowGatewayProvider = Provider<MultiWindowGateway>(
  (Ref ref) => throw UnimplementedError('multiWindowGatewayProvider 未注入'),
);

final autoStartGatewayProvider = Provider<AutoStartGateway>(
  (Ref ref) => throw UnimplementedError('autoStartGatewayProvider 未注入'),
);

final soundGatewayProvider = Provider<SoundGateway>(
  (Ref ref) => throw UnimplementedError('soundGatewayProvider 未注入'),
);

final fileGatewayProvider = Provider<FileGateway>(
  (Ref ref) => throw UnimplementedError('fileGatewayProvider 未注入'),
);

/// Windows 桌面层（WorkerW 嵌入 / SPI 壁纸设置）。
final desktopWallpaperGatewayProvider = Provider<DesktopWallpaperGateway>(
  (Ref ref) => throw UnimplementedError(
    'desktopWallpaperGatewayProvider 未注入',
  ),
);

/// 屏幕 / 显示器信息（screen_retriever）。
final screenGatewayProvider = Provider<ScreenGateway>(
  (Ref ref) => throw UnimplementedError('screenGatewayProvider 未注入'),
);

/// 壁纸 PNG 的落盘 / 底图读取。
final wallpaperImageGatewayProvider = Provider<WallpaperImageGateway>(
  (Ref ref) => throw UnimplementedError(
    'wallpaperImageGatewayProvider 未注入',
  ),
);

/// 启动参数 `--planstar-embed-desktop` 的单次覆盖（不写入用户设置）。
final desktopEmbeddedOverrideProvider = Provider<bool>((Ref ref) => false);
