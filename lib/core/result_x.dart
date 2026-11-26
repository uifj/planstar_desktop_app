/// `packages/infras/core` 的 `Result` 在应用层的少量辅助。
library;

import 'package:core/result.dart';

/// 把可能抛异常的异步边界（文件 IO / 插件通道）收敛成 [Result]。
///
/// 业务内部不要用它吞掉逻辑错误——只有适配层才用。
Future<Result<T>> guardAsync<T>(Future<T> Function() body) async {
  try {
    return Success<T>(await body());
  } catch (error) {
    return Fail<T>(
      Failure(
        code: 'LOCAL_IO_ERROR',
        message: 'LOCAL_IO_ERROR',
        type: FailureType.data,
        cause: error,
      ),
    );
  }
}
