import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/infrastructure/desktop_adapters.dart';
import 'package:planstar_desktop_app/infrastructure/desktop_platform_config.dart';
import 'package:planstar_desktop_app/infrastructure/pigeon/planstar_api.g.dart';

void main() {
  test('更新源按平台选择且保持 Windows 地址不变', () {
    expect(desktopUpdatePlatform(TargetPlatform.windows), 'windows');
    expect(desktopUpdatePlatform(TargetPlatform.macOS), 'macos');
  });

  test('托盘图标按平台选择且保持 Windows ico 不变', () {
    expect(
      desktopTrayIconAsset(TargetPlatform.windows),
      'assets/app_icons/tray_icon.ico',
    );
    expect(
      desktopTrayIconAsset(TargetPlatform.macOS),
      'assets/app_icons/planstar_icon_1024_transparent.png',
    );
  });

  test('仅 macOS 桌面组件由原生 overlay 自行显示', () {
    expect(desktopWindowShownAfterCreate(TargetPlatform.windows), isTrue);
    expect(desktopWindowShownAfterCreate(TargetPlatform.macOS), isFalse);
  });

  test('Windows 与 macOS 均使用原生 DataHub', () {
    expect(desktopUsesNativeDataHub(TargetPlatform.windows), isTrue);
    expect(desktopUsesNativeDataHub(TargetPlatform.macOS), isTrue);
    expect(desktopUsesNativeDataHub(TargetPlatform.linux), isFalse);
  });

  group('LaunchAtStartupGateway macOS Pigeon 桥', () {
    const hostPrefix =
        'dev.flutter.pigeon.planstar_desktop_app.LaunchAtStartupHostApi';
    const legacyChannel = 'launch_at_startup';
    final codec = LaunchAtStartupHostApi.pigeonChannelCodec;
    late TestDefaultBinaryMessenger messenger;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    });

    tearDown(() {
      for (final channel in [
        '$hostPrefix.isEnabled',
        '$hostPrefix.setEnabled',
        legacyChannel,
      ]) {
        messenger.setMockMessageHandler(channel, null);
      }
    });

    test('读取状态使用类型化通道且不调用旧 MethodChannel', () async {
      var legacyCalled = false;
      messenger.setMockMessageHandler(legacyChannel, (_) async {
        legacyCalled = true;
        return const StandardMethodCodec().encodeSuccessEnvelope(false);
      });
      messenger.setMockMessageHandler(
        '$hostPrefix.isEnabled',
        (_) async => codec.encodeMessage([true]),
      );

      final gateway = LaunchAtStartupGateway(binaryMessenger: messenger);
      expect(await gateway.isEnabled(), isTrue);
      expect(legacyCalled, isFalse);
    }, skip: !Platform.isMacOS);

    test('写入状态发送布尔参数并接收空结果', () async {
      Object? sentArgument;
      messenger.setMockMessageHandler('$hostPrefix.setEnabled', (
        message,
      ) async {
        sentArgument = (codec.decodeMessage(message) as List<Object?>).single;
        return codec.encodeMessage([null]);
      });

      final gateway = LaunchAtStartupGateway(binaryMessenger: messenger);
      await gateway.setEnabled(false);
      expect(sentArgument, isFalse);
    }, skip: !Platform.isMacOS);

    test('原生错误沿用端口降级语义', () async {
      messenger.setMockMessageHandler(
        '$hostPrefix.isEnabled',
        (_) async => codec.encodeMessage(['loginItemFailed', 'denied', null]),
      );
      messenger.setMockMessageHandler(
        '$hostPrefix.setEnabled',
        (_) async => codec.encodeMessage(['loginItemFailed', 'denied', null]),
      );

      final gateway = LaunchAtStartupGateway(binaryMessenger: messenger);
      expect(await gateway.isEnabled(), isFalse);
      await expectLater(gateway.setEnabled(true), completes);
    }, skip: !Platform.isMacOS);
  });
}
