/// [CrossEngineSync] 的文件标记实现。
///
/// `desktop_multi_window` 的每个窗口是独立 engine，`shared_preferences` 各自
/// 缓存一份数据。任何一次写入都会更新一个共享的 revision 文件；其它 engine
/// 轮询到变化后调用 `SharedPreferences.reload()` 并从磁盘重读聚合。
/// 该文件只存微秒时间戳，不承载业务数据，因此不会与插件的 JSON 文件冲突。
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/ports.dart';

final class FileCrossEngineSync implements CrossEngineSync {
  FileCrossEngineSync();

  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  Timer? _timer;
  File? _marker;
  String _lastValue = '';
  bool _polling = false;

  Future<void> initialize() async {
    final root = await getApplicationSupportDirectory();
    _marker = File('${root.path}/planstar_revision.txt');
    try {
      _lastValue = (await _marker!.readAsString()).trim();
    } on Object {
      _lastValue = '';
    }
    _timer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _poll(),
    );
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> signalChange() async {
    final file = _marker;
    if (file == null) return;
    try {
      await file.writeAsString(
        DateTime.now().microsecondsSinceEpoch.toString(),
        flush: true,
      );
    } on Object {
      // 标记文件写失败时退化为「仅本 engine 可见」，不阻断业务流程。
    }
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final file = _marker;
      if (file == null || !await file.exists()) return;
      final value = (await file.readAsString()).trim();
      if (value != _lastValue) {
        _lastValue = value;
        _changes.add(null);
      }
    } on Object {
      // ignore transient IO errors
    } finally {
      _polling = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _changes.close();
  }
}
