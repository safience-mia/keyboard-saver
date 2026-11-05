# keyboard_guard

Keyboard Saver 저장소 내부용 Flutter 플러그인입니다. 공통 Dart 인터페이스를 Swift/macOS와 C++/Win32 구현에 연결합니다. 공개 패키지 배포를 전제로 하지 않습니다.

- MethodChannel: `keyboard_saver/guard`
- EventChannel: `keyboard_saver/guard/events`
- 메서드: `getStatus`, `requestPermission`, `start`, `stop`
- 네이티브 입력 처리에서 Dart 응답을 기다리지 않습니다.
- macOS에서는 일반 키에 더해 `NX_SYSDEFINED` / `NX_SUBTYPE_AUX_CONTROL_BUTTONS`의 밝기·음량·재생 등 미디어 키를 차단합니다. `SystemKeyEvent`가 차단 대상을 판별합니다. 그 외 시스템 이벤트는 통과시킵니다.
- Windows 표준 음량·미디어 virtual key는 일반 키와 동일한 훅으로 처리합니다. 키보드 훅을 거치지 않는 HID/ACPI 밝기 입력은 별도 지원이 필요합니다.
- `stop`은 키 해제 이벤트를 기다리지 않고 필터를 제거해 `idle`을 반환합니다. 키보드 입력은 상태를 바꾸지 않습니다.
- macOS는 `permissionApp`에 실제 실행 중인 앱의 이름·경로·식별자를 전달합니다.
- macOS 전용 `revealPermissionApp`은 인수 없이 현재 번들을 Finder에서 선택합니다. 권한 설정이나 입력 차단은 변경하지 않습니다.
- 모든 후크와 run loop는 플러그인 수명에 맞춰 해제합니다.

테스트: 저장소 루트에서 `flutter test packages/keyboard_guard/test`, `bash tool/test_native.sh`.

macOS는 Swift Package Manager를 사용합니다. Windows는 Flutter가 생성한 CMake 빌드에 연결됩니다. 테스트 및 지원 범위는 루트 README를 참고하세요.
