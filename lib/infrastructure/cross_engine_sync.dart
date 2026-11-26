/// [CrossEngineSync] 的旧文件标记实现，当前未接入。
///
/// Windows / macOS 已由 DataHubStore 提供跨 engine 同步；本类仅保留为旧降级方案参考。
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/ports.dart';

final class FileCrossEngineSync implements CrossEngineSync {
  FileCrossEngineSync();

  final StreamController<DataChange> _changes =
      StreamController<DataChange>.broadcast();
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
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
  }

  @override
  Stream<DataChange> get changes => _changes.stream;

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
        _changes.add(
          DataChange(key: '', revision: int.tryParse(value) ?? 0, origin: ''),
        );
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
