/// 窗口与多窗口端口。
library;

import 'dart:async';

/// 与平台无关的窗口矩形，避免端口依赖 `dart:ui`。
final class WindowRect {
  const WindowRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory WindowRect.fromJson(Map<String, Object?> json) => WindowRect(
    (json['x'] as num?)?.toDouble() ?? 100,
    (json['y'] as num?)?.toDouble() ?? 100,
    (json['width'] as num?)?.toDouble() ?? 360,
    (json['height'] as num?)?.toDouble() ?? 420,
  );

  WindowRect copyWith({double? x, double? y, double? width, double? height}) =>
      WindowRect(
        x ?? this.x,
        y ?? this.y,
        width ?? this.width,
        height ?? this.height,
      );
}

abstract interface class WindowGateway {
  Future<void> initializeMainWindow();

  Future<void> initializeSubWindow(String title, WindowRect rect);

  Future<void> setAlwaysOnTop(bool value);

  Future<void> setOpacity(double value);

  /// 自定义标题栏拖动窗口。
  Future<void> startDragging();

  Future<void> show();

  Future<void> hide();

  Future<void> minimize();

  Future<void> toggleMaximize();

  /// 原生关闭按钮 / Alt+F4 触发的隐藏通知（由实现方回调），
  /// 用于让应用层状态与真实窗口可见态保持一致。
  void Function()? onCloseIntercepted;

  /// 请求关闭窗口。主窗口已开启「关闭拦截」，实际行为是隐藏到托盘；
  /// 真正结束进程请用 [destroy]。
  Future<void> close();

  /// 托盘「退出」专用：绕过关闭拦截强制结束应用。
  Future<void> destroy();

  Future<WindowRect> bounds();

  Future<void> setBounds(WindowRect rect);
}

/// 多窗口消息（主窗口 → 子窗口 / 反向）。
final class MultiWindowCommand {
  const MultiWindowCommand(this.method, this.arguments);

  final String method;
  final Map<String, Object?> arguments;
}

abstract interface class MultiWindowGateway {
  /// 打开独立便签窗口（旧版「便签置顶」「桌面便签」）。
  Future<String> openNoteWindow(String noteId, {WindowRect? rect});

  /// 打开倒数日桌面卡片窗口。
  Future<String> openCountdownWindow({WindowRect? rect});

  /// 打开「贴在桌面上的可编辑月历小组件」窗口（Vectra 式 overlay）。
  Future<String> openDesktopWidget();

  /// 隐藏当前 engine 所属的窗口（桌面小组件的「收起」）。
  Future<void> hideCurrentWindow();

  Future<List<String>> openWindowIds();

  /// 隐藏指定窗口（不销毁 engine，复用时再 [showWindow]）。
  Future<void> closeWindow(String windowId);

  /// 重新显示已隐藏的窗口，避免反复开关累积多个 engine。
  Future<void> showWindow(String windowId);

  Future<void> sendTo(String windowId, MultiWindowCommand command);

  /// 子窗口收到的指令。
  Stream<MultiWindowCommand> get incoming;
}
