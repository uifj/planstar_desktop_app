/// `ValueObject`：**没有身份**、只由属性定义相等的不可变值。
///
/// DDD 里区分"实体"和"值对象"的唯一判据是身份：
/// `Money(100, 'CNY')` 和另一个 `Money(100, 'CNY')` 是同一个东西（相等），
/// 而两张同价的订单不是同一张订单（[Entity] 靠 id 相等）。
///
/// 用法：`final class` + 全 `final` 字段 + 构造函数里校验 + 实现 [props]。
///
/// ```dart
/// final class OrderNumber extends ValueObject {
///   OrderNumber(String value) : value = _validate(value);
///   final String value;
///   @override
///   List<Object?> get props => [value];
/// }
/// ```
library;

/// 值对象的公共父类：只提供"按属性相等"和 `hashCode`。
///
/// ⚠ 不要用它来做"带 id 的对象"——那属于 [Entity]。
abstract class ValueObject {
  const ValueObject();

  /// 参与相等比较的属性（顺序即语义，`[a, b]` 与 `[b, a]` 不相等）。
  ///
  /// 返回的元素里如果又套了集合，用 [List] / [Map] 即可——本类做了深比较。
  List<Object?> get props;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return _deepEquals((other as ValueObject).props, props);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        runtimeType,
        ...props.map(_deepHashCode),
      ]);
}

/// 值对象内部的深比较。
///
/// 手写 `equals()` 比较很容易漏字段（`Coupon` 之类）；
/// 这里统一成一份实现，子类只需要报 [ValueObject.props]。
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

/// 与 [_deepEquals] 对齐的深哈希：List 按序、Map 按排序后的 key，
/// 保证「相等的对象哈希必然相等」这一 Dart 契约（原先集合用 identity hash，
/// 两个内容相同的 AppSettings/RecurrenceRule 在 Set/Map 里会重复）。
int _deepHashCode(Object? value) {
  if (value == null) return 0;
  if (value is List) return Object.hashAll(value.map(_deepHashCode));
  if (value is Map) {
    final keys = value.keys.toList()
      ..sort((Object? a, Object? b) => a.toString().compareTo(b.toString()));
    return Object.hashAll(<Object?>[
      for (final key in keys) _deepHashCode(key),
      for (final key in keys) _deepHashCode(value[key]),
    ]);
  }
  return value.hashCode;
}
