import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_guard/keyboard_guard.dart';

class CleaningController extends ChangeNotifier {
  CleaningController(this._guard);

  final KeyboardGuard _guard;
  StreamSubscription<GuardSnapshot>? _subscription;
  bool _disposed = false;
  bool _refreshRequested = false;
  bool initialized = false;
  bool busy = false;
  bool statusReliable = true;
  String? error;
  GuardSnapshot snapshot = const GuardSnapshot(
    phase: GuardPhase.idle,
    permissionGranted: false,
    revision: -1,
  );

  Future<void> initialize() async {
    if (_subscription != null) return;
    _subscription = _guard.changes.listen(
      _apply,
      onError: (Object exception) {
        statusReliable = false;
        error = '잠금 상태를 확인할 수 없어요. 앱을 닫고 다시 실행해 주세요.';
        _notify();
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (busy) {
      // Returning from System Settings may race with requestPermission's reply.
      // Coalesce these reads, but never discard the latest permission check.
      _refreshRequested = true;
      return;
    }
    await _run(_guard.getStatus);
  }

  Future<void> requestPermission() => _run(_guard.requestPermission);

  Future<void> revealPermissionApp() async {
    if (_disposed || snapshot.permissionApp == null) return;
    try {
      await _guard.revealPermissionApp();
    } catch (_) {
      error = 'Finder를 열지 못했어요. 안내에 표시된 위치에서 앱을 찾아 주세요.';
      _notify();
    }
  }

  Future<void> start() async {
    if (busy ||
        !initialized ||
        !statusReliable ||
        snapshot.isBlocking ||
        !snapshot.permissionGranted) {
      return;
    }
    await _run(_guard.start);
  }

  // The only exit must remain available even while another reply is pending.
  Future<void> stop() async {
    if (_disposed) return;
    try {
      _apply(await _guard.stop());
    } catch (_) {
      statusReliable = false;
      error = '앱에서 해제하지 못했어요. 마우스로 앱을 강제 종료해 주세요.';
      _notify();
    }
  }

  Future<void> _run(Future<GuardSnapshot> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      _apply(await action());
    } on PlatformException catch (exception) {
      error = switch (exception.code) {
        'permission_denied' => '손쉬운 사용 권한을 허용한 뒤 다시 확인해 주세요.',
        'keys_held' => '키보드에서 손을 떼고 다시 시작해 주세요.',
        'already_locked' => '이미 청소 모드가 실행 중이에요.',
        _ => '입력 차단을 시작하지 못했어요. 앱을 다시 실행해 주세요.',
      };
    } catch (_) {
      statusReliable = false;
      error = '입력 차단 모듈에 연결할 수 없어요. 앱을 다시 실행해 주세요.';
    } finally {
      busy = false;
      _notify();
      if (_refreshRequested && !_disposed) {
        _refreshRequested = false;
        await refresh();
      }
    }
  }

  void _apply(GuardSnapshot value) {
    // A delayed method response must not overwrite a newer native event.
    if (_disposed || value.revision < snapshot.revision) return;
    initialized = true;
    statusReliable = true;
    snapshot = value;
    if (value.phase == GuardPhase.idle) {
      error = null;
    }
    if (value.phase == GuardPhase.fault) {
      error = '입력 차단이 중단됐어요. 청소를 멈추고 다시 시작해 주세요.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
