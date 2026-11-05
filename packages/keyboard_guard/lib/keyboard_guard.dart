import 'package:flutter/services.dart';

enum GuardPhase { idle, locked, fault }

/// The actual macOS bundle that needs Accessibility permission.
/// Absent on platforms without this permission flow.
class PermissionApp {
  const PermissionApp({
    required this.name,
    required this.path,
    required this.bundleIdentifier,
  });

  factory PermissionApp.fromMap(Object value) {
    final map = Map<Object?, Object?>.from(value as Map);
    return PermissionApp(
      name: map['name']! as String,
      path: map['path']! as String,
      bundleIdentifier: map['bundleIdentifier']! as String,
    );
  }

  final String name;
  final String path;
  final String bundleIdentifier;
}

class GuardSnapshot {
  const GuardSnapshot({
    required this.phase,
    required this.permissionGranted,
    required this.revision,
    this.reason,
    this.permissionApp,
  });

  factory GuardSnapshot.fromMap(Object? value) {
    final map = Map<Object?, Object?>.from(value! as Map);
    return GuardSnapshot(
      phase: GuardPhase.values.byName(map['phase']! as String),
      permissionGranted: map['permissionGranted']! as bool,
      revision: (map['revision']! as num).toInt(),
      reason: map['reason'] as String?,
      permissionApp: map['permissionApp'] == null
          ? null
          : PermissionApp.fromMap(map['permissionApp']!),
    );
  }

  final GuardPhase phase;
  final bool permissionGranted;
  final int revision;
  final String? reason;
  final PermissionApp? permissionApp;

  bool get isBlocking => phase == GuardPhase.locked;
}

/// The shared contract. Native code owns the actual input filter.
abstract interface class KeyboardGuard {
  Stream<GuardSnapshot> get changes;
  Future<GuardSnapshot> getStatus();
  Future<GuardSnapshot> requestPermission();

  /// Reveals the running bundle in Finder. Only call when permissionApp exists.
  Future<void> revealPermissionApp();
  Future<GuardSnapshot> start();
  Future<GuardSnapshot> stop();
}

class MethodChannelKeyboardGuard implements KeyboardGuard {
  MethodChannelKeyboardGuard({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('keyboard_saver/guard'),
      _events = events ?? const EventChannel('keyboard_saver/guard/events');

  final MethodChannel _methods;
  final EventChannel _events;
  late final Stream<GuardSnapshot> _changes = _events
      .receiveBroadcastStream()
      .map(GuardSnapshot.fromMap);

  @override
  Stream<GuardSnapshot> get changes => _changes;

  Future<GuardSnapshot> _call(String method, [Object? arguments]) async =>
      GuardSnapshot.fromMap(
        await _methods.invokeMethod<Object?>(method, arguments),
      );

  @override
  Future<GuardSnapshot> getStatus() => _call('getStatus');

  @override
  Future<GuardSnapshot> requestPermission() => _call('requestPermission');

  @override
  Future<void> revealPermissionApp() =>
      _methods.invokeMethod<void>('revealPermissionApp');

  @override
  Future<GuardSnapshot> start() => _call('start');

  @override
  Future<GuardSnapshot> stop() => _call('stop');
}
