import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyboard_guard/keyboard_guard.dart';
import 'package:keyboard_saver/cleaning_controller.dart';

import 'fake_keyboard_guard.dart';

void main() {
  late FakeKeyboardGuard guard;
  late CleaningController controller;
  setUp(() {
    guard = FakeKeyboardGuard();
    controller = CleaningController(guard);
  });
  tearDown(() async {
    controller.dispose();
    await guard.events.close();
  });

  test(
    'startup only reads status; it never locks or requests permissions',
    () async {
      await controller.initialize();
      expect(guard.startCalls, 0);
      expect(guard.permissionRequests, 0);
      expect(controller.snapshot.isBlocking, false);
    },
  );

  test('denied permission prevents a start attempt', () async {
    guard.state = const GuardSnapshot(
      phase: GuardPhase.idle,
      permissionGranted: false,
      revision: 0,
    );
    await controller.initialize();
    await controller.start();
    expect(guard.startCalls, 0);
  });

  test(
    'returning from settings queues a permission read during a request',
    () async {
      guard.state = const GuardSnapshot(
        phase: GuardPhase.idle,
        permissionGranted: false,
        revision: 0,
      );
      await controller.initialize();
      final denied = guard.state;
      final response = Completer<GuardSnapshot>();
      guard.onRequestPermission = () => response.future;
      final pending = controller.requestPermission();
      // Settings activates the app before the native request finishes.
      await controller.refresh();
      await controller.refresh();
      guard.state = const GuardSnapshot(
        phase: GuardPhase.idle,
        permissionGranted: true,
        revision: 1,
      );
      response.complete(denied);
      await pending;
      expect(controller.snapshot.permissionGranted, true);
      expect(guard.statusReads, 2); // Initial read + one coalesced refresh.
      expect(guard.startCalls, 0);
      expect(controller.busy, false);
    },
  );

  test('failed native installation never displays a lock', () async {
    guard.startError = PlatformException(code: 'tap_failed');
    await controller.initialize();
    await controller.start();
    expect(controller.snapshot.isBlocking, false);
    expect(controller.error, isNotNull);
  });

  test('ending restores idle without a subsequent key-release event', () async {
    await controller.initialize();
    await controller.start();
    expect(controller.snapshot.isBlocking, true);
    await controller.stop();
    expect(controller.snapshot.phase, GuardPhase.idle);
    expect(guard.stopCalls, 1);
  });

  test(
    'late locked reply cannot overwrite a newer interruption event',
    () async {
      final response = Completer<GuardSnapshot>();
      guard.onStart = () => response.future;
      await controller.initialize();
      final pending = controller.start();
      guard.emit(GuardPhase.locked);
      final old = guard.state;
      guard.emit(GuardPhase.fault);
      response.complete(old);
      await pending;
      expect(controller.snapshot.phase, GuardPhase.fault);
      expect(controller.error, isNotNull);
    },
  );

  test(
    'a disconnected event stream is not represented as confirmed protection',
    () async {
      await controller.initialize();
      await controller.start();
      guard.events.addError(StateError('disconnected'));
      expect(controller.statusReliable, false);
      expect(controller.error, isNotNull);
    },
  );

  test('double start does not install multiple hooks', () async {
    final response = Completer<GuardSnapshot>();
    guard.onStart = () => response.future;
    await controller.initialize();
    final first = controller.start();
    await controller.start();
    guard.emit(GuardPhase.locked);
    response.complete(guard.state);
    await first;
    expect(guard.startCalls, 1);
  });

  test(
    'stop can run while start is pending and ignores its late locked reply',
    () async {
      final response = Completer<GuardSnapshot>();
      guard.onStart = () => response.future;
      await controller.initialize();
      final pending = controller.start();
      guard.emit(GuardPhase.locked);
      final old = guard.state;
      expect(controller.busy, true);
      await controller.stop();
      response.complete(old);
      await pending;
      expect(controller.snapshot.isBlocking, false);
      expect(guard.stopCalls, 1);
    },
  );
  test('stop remains available after a stream failure', () async {
    await controller.initialize();
    await controller.start();
    guard.events.addError(StateError('disconnected'));
    await controller.stop();
    expect(controller.snapshot.isBlocking, false);
    expect(controller.statusReliable, true);
    expect(controller.error, isNull);
  });

  test('failed stop keeps the exit available for a successful retry', () async {
    await controller.initialize();
    await controller.start();
    guard.onStop = () async =>
        throw PlatformException(code: 'worker_unavailable');
    await controller.stop();
    expect(controller.snapshot.isBlocking, true);
    expect(controller.statusReliable, false);
    expect(controller.error, isNotNull);
    guard.onStop = null;
    await controller.stop();
    expect(guard.stopCalls, 2);
    expect(controller.snapshot.isBlocking, false);
    expect(controller.error, isNull);
  });
}
