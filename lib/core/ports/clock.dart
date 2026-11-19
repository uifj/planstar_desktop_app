/// 时钟端口。
library;

/// 时钟端口：让「今天」「提前量」可测，避免聚合直接读 `DateTime.now()`。
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
