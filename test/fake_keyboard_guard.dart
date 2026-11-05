import 'dart:async';

import 'package:keyboard_guard/keyboard_guard.dart';

class FakeKeyboardGuard implements KeyboardGuard {
  final events = StreamController<GuardSnapshot>.broadcast(sync: true);
  GuardSnapshot state = const GuardSnapshot(
    phase: GuardPhase.idle,
    permissionGranted: true,
    revision: 0,
  );
  Object? startError;
  Future<GuardSnapshot> Function()? onStart;
  Future<GuardSnapshot> Function()? onStop;
  Future<GuardSnapshot> Function()? onRequestPermission;
  int statusReads = 0;
  int appReveals = 0;
  int startCalls = 0;
  int permissionRequests = 0;
  int stopCalls = 0;

  @override
  Stream<GuardSnapshot> get changes => events.stream;
  @override
  Future<GuardSnapshot> getStatus() async {
    statusReads++;
    return state;
  }

  @override
  Future<GuardSnapshot> requestPermission() async {
    permissionRequests++;
    if (onRequestPermission != null) return onRequestPermission!();
    return state;
  }

  @override
  Future<void> revealPermissionApp() async {
    appReveals++;
  }

  @override
  Future<GuardSnapshot> start() async {
    startCalls++;
    if (startError != null) throw startError!;
    if (onStart != null) return onStart!();
    emit(GuardPhase.locked);
    return state;
  }

  @override
  Future<GuardSnapshot> stop() async {
    stopCalls++;
    if (onStop != null) return onStop!();
    emit(GuardPhase.idle);
    return state;
  }

  void emit(GuardPhase phase, {String? reason}) {
    state = GuardSnapshot(
      phase: phase,
      permissionGranted: state.permissionGranted,
      revision: state.revision + 1,
      reason: reason,
      permissionApp: state.permissionApp,
    );
    events.add(state);
  }
}
