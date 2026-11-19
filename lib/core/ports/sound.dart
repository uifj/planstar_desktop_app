/// 提示音端口：只有语义，asset 路径属基础设施细节，由适配器映射。
library;

/// 提示音：对齐旧版 `taskcomplete/ding*.mp3` 与 `reminder/alarm_littlestar.mp3`。
enum SoundTone {
  none('无'),
  ding('滴答'),
  ding2('叮当'),
  ding3('叮咚'),
  dong('咚'),
  littleStar('小星星');

  const SoundTone(this.label);

  final String label;

  static SoundTone fromName(String? name) => SoundTone.values.firstWhere(
    (SoundTone t) => t.name == name,
    orElse: () => SoundTone.none,
  );
}

abstract interface class SoundGateway {
  Future<void> play(SoundTone tone);
}
