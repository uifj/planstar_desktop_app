/// 应用层端口（六边形架构的「驱动侧」契约）按能力域拆分后的汇总门面。
///
/// 这里只有抽象接口与端口自带的小 DTO，具体实现放在 `lib/infrastructure/`。
/// 领域层与表现层都不 import 任何插件，插件只在组合根被注入。
/// 新代码请按域 import `ports/<domain>.dart`。
library;

export 'ports/clock.dart';
export 'ports/desktop.dart';
export 'ports/file.dart';
export 'ports/notification.dart';
export 'ports/sound.dart';
export 'ports/storage.dart';
export 'ports/timeline.dart';
export 'ports/tray.dart';
export 'ports/window.dart';
