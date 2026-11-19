/// 完成提示音反应器（ADR-0005）：命令副作用统一走领域事件。
///
/// 订阅 [TaskCompleted]，按当前设置的 taskCompleteTone 经 SoundGateway
/// 播放。命令方法不再接触音频网关，时序统一为「落盘成功 → 分发事件 →
/// 反应器发声」。
///
/// 跨 engine 不变量：领域事件不跨 engine。TaskCompleted 只在操作发起
/// engine 的本地总线分发；其他 engine 经 CrossEngineDataChanged 重载数据
/// 但不会重建 TaskCompleted，因此提示音只在操作端响。
library;

import 'package:core/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../../../core/app_events.dart';
import '../../../core/ports.dart';
import '../../settings/application/settings_controller.dart';

final class SoundReaction {
  SoundReaction({
    required this._bus,
    required this._sound,
    required this._toneOf,
  });

  final DomainEventBus _bus;
  final SoundGateway _sound;
  final SoundTone Function() _toneOf;
  void Function()? _cancel;

  void start() {
    _cancel ??= _bus.on<TaskCompleted>(_onTaskCompleted);
  }

  void stop() {
    _cancel?.call();
    _cancel = null;
  }

  Future<void> _onTaskCompleted(TaskCompleted event) async {
    final tone = _toneOf();
    if (tone == SoundTone.none) return;
    await _sound.play(tone);
  }
}

/// 应用根 ref.read 初始化（主窗口 PlanstarApp / 子窗口 SubWindowApp），
/// 与提醒/历史控制器同一保活模式。
final soundReactionProvider = Provider<SoundReaction>((Ref ref) {
  ref.keepAlive();
  final reaction = SoundReaction(
    bus: ref.watch(domainEventBusProvider),
    sound: ref.watch(soundGatewayProvider),
    toneOf: () => ref.read(settingsControllerProvider).taskCompleteTone,
  );
  reaction.start();
  ref.onDispose(reaction.stop);
  return reaction;
});
