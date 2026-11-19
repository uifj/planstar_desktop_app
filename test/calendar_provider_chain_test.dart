/// ADR-0004 回归：装配后的完整 Provider 链必须可构建。
///
/// 聚合上移 + 读模型拆层后，monthDataProvider 依赖 bootstrap 装配的
/// TimelineContribution 与多个控制器；此用例以空存储 + 全量端口覆盖
/// 走一遍真实依赖图，确保没有循环依赖或未注入端口，且各控制器
/// build 期的 microtask load 完成后不进入 error 态。
library;

import 'package:core/config.dart';
import 'package:core/domain.dart';
import 'package:core/logger.dart';
import 'package:core/network.dart';
import 'package:core/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/bootstrap/core_providers.dart';
import 'package:planstar_desktop_app/core/ports.dart';
import 'package:planstar_desktop_app/features/calendar/presentation/calendar_providers.dart';

final class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 11, 18, 9);
}

final class _Sound implements SoundGateway {
  @override
  Future<void> play(SoundTone tone) async {}
}

void main() {
  test('monthDataProvider 全链路构建且 microtask load 后无错误态', () async {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        domainEventBusProvider.overrideWithValue(DomainEventBus()),
        clockProvider.overrideWithValue(_Clock()),
        soundGatewayProvider.overrideWithValue(_Sound()),
        appConfigProvider.overrideWithValue(AppConfig.empty),
        apiClientProvider.overrideWithValue(
          ApiClient(buildDio(baseUrl: 'https://unit.test/')),
        ),
        loggerProvider.overrideWithValue(
          AppLogger(sinks: <LogSink>[SilentLogSink()], level: LogLevel.debug),
        ),
      ],
    );
    addTearDown(container.dispose);
    final month = container.read(monthDataProvider);
    expect(month.columns, isNotEmpty);
    // 各控制器 build 里的 Future.microtask(load) 完成后不得进入 error 态。
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final after = container.read(monthDataProvider);
    expect(after.columns, isNotEmpty);
  });
}
