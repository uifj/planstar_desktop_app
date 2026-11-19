/// 基于任意 [KeyValueStore] 的 JSON 列表存储（搜索历史 / 浏览记录 / 草稿）。
library;

import 'dart:convert';

import 'stores.dart';

/// 把一组对象以 JSON 数组形式存在单个键下。
///
/// 解码结果按「原始串标签」缓存：readAll 仍读一次底层存储（DataHub 是
/// 内存查表），原始串不变就跳过 jsonDecode/fromJson。外部写入（跨 engine
/// 广播先更新底层值再通知）必然改变原始串，缓存自动失效，无需手动接线。
///
/// 调用方约定：readAll 返回的列表是防御性副本，但**元素视为只读**——
/// 元素实例在缓存命中时被共享，原地改元素会污染后续读取。
final class JsonListStore<T> {
  /// 创建列表存储。
  JsonListStore({
    required this._store,
    required this.key,
    required this.fromJson,
    required this.toJson,
    this.maxItems,
  });

  final KeyValueStore _store;

  /// 存储键。
  final String key;

  /// 单条反序列化。
  final T Function(Map<String, Object?> json) fromJson;

  /// 单条序列化。
  final Map<String, Object?> Function(T value) toJson;

  /// 最多保留条数（超出时保留**最新的**）。`null` 表示不限。
  final int? maxItems;

  String? _cachedRaw;
  List<T>? _cachedItems;

  /// 读全部。
  ///
  /// 单条解析失败会**跳过该条**而不是整体失败：一条坏数据不该让用户的
  /// 全部历史消失。
  Future<List<T>> readAll() async {
    final raw = await _store.read(key);
    if (raw == null) {
      _cachedRaw = null;
      _cachedItems = null;
      return <T>[];
    }
    if (raw == _cachedRaw) {
      return List<T>.of(_cachedItems!);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      decoded = null;
    }
    final result = <T>[];
    if (decoded is List<Object?>) {
      for (final item in decoded) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }
        try {
          result.add(
            fromJson(
              item.map(
                (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
              ),
            ),
          );
        } catch (_) {
          // 单条坏了就跳过。
        }
      }
    }
    _cachedRaw = raw;
    _cachedItems = result;
    return List<T>.of(result);
  }

  /// 覆盖写入全部。
  Future<void> writeAll(List<T> items) async {
    final limit = maxItems;
    final kept = (limit != null && items.length > limit)
        ? items.sublist(items.length - limit)
        : items;
    final raw = jsonEncode(kept.map(toJson).toList());
    await _store.write(key, raw);
    _cachedRaw = raw;
    _cachedItems = List<T>.of(kept);
  }

  /// 追加一条到末尾（并按 [maxItems] 裁剪）。
  Future<void> append(T item) async {
    final items = await readAll();
    items.add(item);
    await writeAll(items);
  }

  /// 清空。
  Future<void> clear() async {
    await _store.delete(key);
    _cachedRaw = null;
    _cachedItems = null;
  }
}
