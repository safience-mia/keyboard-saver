import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_guard/keyboard_guard.dart';
import 'package:keyboard_saver/main.dart';

import 'fake_keyboard_guard.dart';

void main() {
  testWidgets(
    'permission recovery reveals the running bundle without locking',
    (tester) async {
      final guard = FakeKeyboardGuard();
      guard.state = const GuardSnapshot(
        phase: GuardPhase.idle,
        permissionGranted: false,
        revision: 0,
        permissionApp: PermissionApp(
          name: 'Keyboard Saver Debug',
          path: '/test/Debug/Keyboard Saver Debug.app',
          bundleIdentifier: 'dev.keyboardsaver.keyboardSaver.debug',
        ),
      );
      await tester.pumpWidget(KeyboardSaverApp(guard: guard));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('허용했는데도 안 되나요?'));
      await tester.tap(find.text('허용했는데도 안 되나요?'));
      await tester.pumpAndSettle();
      expect(find.text('현재 실행 중: Keyboard Saver Debug'), findsOneWidget);
      expect(find.text('/test/Debug/Keyboard Saver Debug.app'), findsOneWidget);
      await tester.tap(find.text('현재 앱을 Finder에서 보기'));
      await tester.pumpAndSettle();
      expect(guard.appReveals, 1);
      expect(guard.startCalls, 0);
      expect(guard.permissionRequests, 0);
      await tester.pumpWidget(const SizedBox());
      await guard.events.close();
    },
  );

  testWidgets('permission guidance and start button do not imply a lock', (
    tester,
  ) async {
    final guard = FakeKeyboardGuard();
    guard.state = const GuardSnapshot(
      phase: GuardPhase.idle,
      permissionGranted: false,
      revision: 0,
    );
    await tester.pumpWidget(KeyboardSaverApp(guard: guard));
    await tester.pumpAndSettle();
    expect(find.text('권한 설정 열기'), findsOneWidget);
    expect(find.text('편하게 닦으세요.'), findsNothing);
    expect(guard.startCalls, 0);
    await tester.pumpWidget(const SizedBox());
    await guard.events.close();
  });

  testWidgets('cleaning has one mouse exit and returns to idle immediately', (
    tester,
  ) async {
    final guard = FakeKeyboardGuard();
    await tester.pumpWidget(KeyboardSaverApp(guard: guard));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '청소 시작'), findsOneWidget);
    await tester.ensureVisible(find.text('청소 시작'));
    await tester.tap(find.text('청소 시작'));
    await tester.pumpAndSettle();
    expect(find.text('편하게 닦으세요.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '청소 끝내기'), findsOneWidget);
    expect(find.text('즉시 해제'), findsNothing);
    expect(find.text('아래 숫자를 차례로 입력하면 해제돼요.'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    await tester.ensureVisible(find.text('청소 끝내기'));
    await tester.tap(find.text('청소 끝내기'));
    await tester.pumpAndSettle();
    expect(guard.stopCalls, 1);
    expect(find.text('청소 끝내기'), findsNothing);
    expect(find.text('키보드에게 잠깐의 휴식을.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await guard.events.close();
  });

  testWidgets(
    'the only exit stays visible in a short window while start is pending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final guard = FakeKeyboardGuard();
      final response = Completer<GuardSnapshot>();
      guard.onStart = () {
        guard.emit(GuardPhase.locked);
        return response.future;
      };
      await tester.pumpWidget(KeyboardSaverApp(guard: guard));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('청소 시작'));
      await tester.tap(find.text('청소 시작'));
      await tester.pumpAndSettle();
      final old = guard.state;
      // No scroll is needed, and the pending start must not disable the exit.
      expect(find.text('청소 끝내기').hitTestable(), findsOneWidget);
      await tester.tap(find.text('청소 끝내기'));
      await tester.pumpAndSettle();
      expect(guard.state.isBlocking, false);
      expect(guard.stopCalls, 1);
      response.complete(old);
      await tester.pumpAndSettle();
      expect(find.text('청소 끝내기'), findsNothing);
      expect(find.text('청소 시작'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await guard.events.close();
    },
  );
}
