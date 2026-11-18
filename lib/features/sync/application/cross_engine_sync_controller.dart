/// 跨 engine 数据同步：收到原生 DataHub 的 EventChannel 广播后，按 key
/// 精准重载对应读模型，并补齐本 engine 的本地副作用。
///
/// 与旧实现的差异：
/// - 不再依赖「磁盘标记 + 700ms 轮询 + SharedPreferences.reload()」；
///   Windows 的 legacy reload() 实际不会重读磁盘，旧链路从设计上就不生效。
/// - 不再无条件 `load()` 全部 7 个 controller，避免快速输入时的中间态与重复 IO。
/// - 用单调 revision 丢弃乱序/重复事件，串行化处理避免并发 load 互相覆盖。
library;

import 'package:core/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../calendar/application/calendar_controllers.dart';
import '../../countdown/application/countdown_controller.dart';
import '../../history/application/history_controller.dart';
import '../../notes/application/notes_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../subscription/application/subscription_controller.dart';
import '../../timetable/application/timetable_controller.dart';

final crossEngineSyncControllerProvider =
    NotifierProvider<CrossEngineSyncController, int>(
  CrossEngineSyncController.new,
);

final class CrossEngineSyncController extends Notifier<int> {
  bool _applying = false;
  int _lastAppliedRevision = 0;
  // reload 期间到达的变更不能丢弃：按 key 保留最新的一条，当前批次
  // 结束后再串行处理一轮，否则旧读模型会一直留在界面上。
  final Map<String, DataChange> _pending = <String, DataChange>{};

  @override
  int build() {
    // 只在入口 initState 里被 ref.read，没有 widget watch 它；Riverpod 3
    // 会在无人监听时 dispose 此 controller 并取消订阅，必须显式保活。
    ref.keepAlive();
    final subscription = ref.watch(crossEngineSyncProvider).changes.listen(
          (DataChange change) => _apply(change),
        );
    ref.onDispose(subscription.cancel);
    return 0;
  }

  Future<void> _apply(DataChange change) async {
    if (_applying) {
      _enqueue(change);
      return;
    }
    if (change.revision > 0 && change.revision <= _lastAppliedRevision) return;
    _applying = true;
    try {
      DataChange current = change;
      while (true) {
        await _applyOne(current);
        // 同一 key 若期间来了更新版本，取最新的一条继续处理。
        final nextKey = _pending.keys.firstOrNull;
        if (nextKey == null) break;
        final next = _pending.remove(nextKey)!;
        if (next.revision <= _lastAppliedRevision) continue;
        current = next;
      }
    } finally {
      _applying = false;
    }
  }

  void _enqueue(DataChange change) {
    if (change.revision > 0 && change.revision <= _lastAppliedRevision) return;
    final key = change.isFullReload ? '' : change.key;
    final existing = _pending[key];
    if (existing == null || change.revision >= existing.revision) {
      _pending[key] = change;
    }
  }

  Future<void> _applyOne(DataChange change) async {
    if (change.isFullReload) {
      await ref.read(storageReloaderProvider).reload();
      await _reloadAll();
    } else {
      await _reloadFor(change.key);
    }
    if (change.revision > _lastAppliedRevision) {
      _lastAppliedRevision = change.revision;
    }
    // 本 engine 的数据已刷新，补齐无落盘副作用的联动（提醒重排 / 脏计数）。
    // 历史留痕不在这里做：写入方的 DayCellChanged 已单次落盘，避免广播回环。
    await ref.read(domainEventBusProvider).dispatch(<DomainEvent>[
      CrossEngineDataChanged(
        aggregateId: change.key,
        occurredAt: ref.read(clockProvider).now(),
        key: change.key,
        revision: change.revision,
      ),
    ]);
    state++;
  }

  Future<void> _reloadFor(String key) async {
    switch (reloadTargetFor(key)) {
      case 'calendar':
        await ref.read(calendarControllerProvider.notifier).load();
      case 'settings':
        await ref.read(settingsControllerProvider.notifier).load();
      case 'notes':
        await ref.read(notesControllerProvider.notifier).load();
      case 'countdown':
        await ref.read(countdownControllerProvider.notifier).load();
      case 'subscription':
        await ref.read(subscriptionControllerProvider.notifier).load();
      case 'timetable':
        await ref.read(timetableControllerProvider.notifier).load();
      case 'history':
        await ref.read(historyControllerProvider.notifier).load();
      case 'position':
        // 桌面卡片位置只有 overlay engine 自己使用，不需要重载读模型。
        break;
      default:
        await _reloadAll();
    }
  }

  Future<void> _reloadAll() => Future.wait(<Future<void>>[
        ref.read(calendarControllerProvider.notifier).load(),
        ref.read(settingsControllerProvider.notifier).load(),
        ref.read(notesControllerProvider.notifier).load(),
        ref.read(countdownControllerProvider.notifier).load(),
        ref.read(subscriptionControllerProvider.notifier).load(),
        ref.read(timetableControllerProvider.notifier).load(),
        ref.read(historyControllerProvider.notifier).load(),
      ]);
}
