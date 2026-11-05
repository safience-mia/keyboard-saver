import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_guard/keyboard_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('keyboard_saver/guard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('start takes no arguments and decodes the native status', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'start');
      expect(call.arguments, isNull);
      return {'phase': 'locked', 'permissionGranted': true, 'revision': 2};
    });
    final state = await MethodChannelKeyboardGuard().start();
    expect(state.phase, GuardPhase.locked);
    expect(state.revision, 2);
    expect(state.permissionApp, isNull); // Windows / older native responses.
  });

  test(
    'permission details identify the running bundle; reveal takes no path',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments, isNull);
        if (call.method == 'revealPermissionApp') return null;
        expect(call.method, 'getStatus');
        return {
          'phase': 'idle',
          'permissionGranted': false,
          'revision': 0,
          'permissionApp': {
            'name': 'Keyboard Saver Debug',
            'path': '/test/Keyboard Saver Debug.app',
            'bundleIdentifier': 'dev.keyboardsaver.keyboardSaver.debug',
          },
        };
      });
      final guard = MethodChannelKeyboardGuard();
      final state = await guard.getStatus();
      expect(state.permissionApp!.name, 'Keyboard Saver Debug');
      expect(state.permissionApp!.path, '/test/Keyboard Saver Debug.app');
      expect(
        state.permissionApp!.bundleIdentifier,
        'dev.keyboardsaver.keyboardSaver.debug',
      );
      await guard.revealPermissionApp();
    },
  );

  test('native errors propagate rather than synthesizing a success', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'permission_denied');
    });
    await expectLater(
      MethodChannelKeyboardGuard().start(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('stop uses the sole exit command and restores idle', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'stop');
      expect(call.arguments, isNull);
      return {'phase': 'idle', 'permissionGranted': true, 'revision': 3};
    });
    final state = await MethodChannelKeyboardGuard().stop();
    expect(state.isBlocking, false);
  });
}
