/// 列表页统一状态壳：加载中 / 数据 / 失败文案。
library;

final class AsyncListState<T extends Object> {
  AsyncListState({
    List<T>? items,
    this.loading = true,
    this.error,
  }) : items = items ?? <T>[];

  final List<T> items;
  final bool loading;
  final String? error;

  AsyncListState<T> copyWith({
    List<T>? items,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      AsyncListState<T>(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );

  static AsyncListState<T> initial<T extends Object>() =>
      AsyncListState<T>(items: <T>[]);
}
