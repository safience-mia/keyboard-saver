# Keyboard Saver

Mac과 Windows에서 작업을 종료하지 않고 키보드를 청소하기 위한 Flutter 데스크톱 앱입니다. 현재는 **초기 프로토타입**으로, 공통 화면과 두 운영체제의 입력 차단 구현을 연결했습니다.

프로젝트 할 일은 [TODO.md](TODO.md)에서 관리합니다.

## 구성

```text
lib/                       공통 화면, 청소 상태 관리
assets/images/foam-keycap/  키캡 이미지 리소스 (fill, outline)
macos/                     macOS 앱 실행 및 빌드 설정
windows/                   Windows 앱 실행 및 빌드 설정
packages/keyboard_guard/
  lib/                     MethodChannel / EventChannel API
  macos/keyboard_guard/    Swift Package, 전용 run loop의 CGEventTap
  windows/                 C++ 전용 메시지 스레드의 WH_KEYBOARD_LL
  test/                    채널 계약 및 macOS 시스템 키 판정 테스트
test/                      화면 및 비동기 상태 전환 테스트
tool/                      로컬 검증 스크립트
.github/workflows/ci.yml    macOS / Windows 분석, 테스트, 빌드
```

`assets/images/foam-keycap/`의 두 PNG는 Flutter 에셋으로 등록되어 있습니다. `k-keycap-fill.png`를 macOS의 `AppIcon.appiconset`과 Windows의 `app_icon.ico`에 사용합니다. 이미지 원본은 `output/imagegen/foam-keycap/`에 있습니다.

## 개발 환경

- Flutter **3.47.7 stable**, Dart **3.13.5**. `.fvmrc`에 버전을 고정했습니다. FVM 사용은 선택입니다.
- Mac: macOS 12 이상을 대상으로 하는 Xcode 개발 환경. 플러그인은 Swift Package Manager를 사용합니다.
- Windows: Windows 10/11 및 Visual Studio의 **Desktop development with C++** 워크로드와 Windows SDK.
- 각 플랫폼의 앱은 해당 OS에서 빌드합니다.

Flutter를 설치해 PATH에 추가한 후:

```sh
flutter doctor
flutter pub get
bash tool/dev_macos.sh
```

Windows에서는 `flutter run -d windows`를 사용합니다.

설치한 Flutter SDK의 `bin` 경로를 셸의 PATH에 추가하세요. macOS에서 `~/.zprofile`을 수정했다면 새 터미널을 열거나 `source ~/.zprofile`로 설정을 적용하세요.

Mac에서는 실행 중인 Debug 앱을 종료한 뒤 `bash tool/dev_macos.sh`를 사용합니다. 스크립트는 Debug 빌드를 한 번 수행하고 macOS의 일반 앱 실행 방식으로 연 다음 `flutter attach`로 디버거를 연결합니다. 기존 Debug 빌드를 그대로 사용하려면 `bash tool/dev_macos.sh --no-build`를 실행하세요.

이후 Dart 파일을 수정·저장하고, 연결된 터미널에서 `r`을 눌러 **핫 리로드**합니다. 화면 상태를 유지하면서 문구·색상·배치 등의 변경을 반영할 수 있습니다. `main()`·`initState()` 등 초기화 코드의 변경은 `R`로 **핫 리스타트**하고, Swift·C++ 네이티브 코드의 변경은 앱을 종료한 뒤 `bash tool/dev_macos.sh`로 다시 빌드·실행하세요. 앱의 출력 로그 경로는 스크립트가 터미널에 표시합니다.

## 동작

1. 앱을 실행해도 입력 차단이나 권한 요청은 자동으로 시작하지 않습니다.
2. Mac에서 **권한 설정 열기**를 누르고 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Keyboard Saver를 허용합니다. 앱으로 돌아와 상태를 다시 확인합니다. 재빌드로 서명이 바뀌면 권한을 다시 등록해야 할 수 있습니다.
3. **청소 시작**을 클릭합니다. 네이티브 필터 설치가 성공한 뒤에만 청소 모드로 표시합니다. 청소 모드에는 자동 종료 시간이 없습니다.
4. 청소가 끝나면 키보드에서 손을 떼고 화면 하단의 **청소 끝내기**를 마우스로 클릭합니다. 버튼은 스크롤 위치와 관계없이 보이며, 다른 요청이 처리 중이어도 사용할 수 있습니다.
5. 버튼을 누르면 네이티브 필터를 바로 제거하고 대기 화면으로 돌아갑니다. 키 해제 이벤트를 기다리지 않으며, 키보드 입력으로 청소 모드가 끝나지 않습니다.

앱이 반응하지 않으면 마우스로 다른 앱을 선택한 뒤 ** → 강제 종료 → Keyboard Saver → 강제 종료**로 프로세스를 종료할 수 있습니다. Windows에서는 시작 버튼을 우클릭해 작업 관리자를 열고 Keyboard Saver의 작업을 끝냅니다. 마우스는 차단하지 않습니다.

입력 차단은 네이티브 전용 스레드에서 수행합니다. 숫자 입력, 키 반복, 여러 키를 동시에 누르는 동작으로는 해제되지 않습니다. 마우스와 트랙패드는 차단하지 않습니다.

입력 내용을 파일이나 네트워크에 저장하지 않으며, 코드 인식을 위한 입력 이력도 수집하지 않습니다. 앱 종료, Dart 이벤트 구독 해제, 시스템 잠자기 또는 사용자 세션 중단 시 필터를 정리합니다.

## 검증

```sh
flutter analyze
flutter test
flutter test packages/keyboard_guard/test
bash tool/test_native.sh
flutter build macos --release
```

`tool/test_native.sh`는 Mac에서 메모리에 만든 시스템 키 이벤트로 차단 판정·반복·modifier 조합·다른 시스템 이벤트 통과를 검증합니다. 실제 전역 키보드 차단을 켜거나 이벤트를 OS로 보내지는 않습니다. Flutter 테스트는 단일 종료 버튼과 비동기 응답 중 해제, 늦은 응답 무시, 실패 후 재시도를 확인합니다. Windows 네이티브 빌드 검증은 Windows 환경 또는 CI에서 수행해야 합니다. CI는 두 운영체제의 검증·빌드가 끝나면 다운로드용 파일을 artifact로 보관합니다.

수동 검증 절차와 아직 보장하지 않는 동작은 [docs/manual-testing.md](docs/manual-testing.md)에 있습니다.

## 다운로드용 파일 만들기

Python 3와 해당 운영체제의 빌드 환경이 필요합니다. 먼저 Release를 빌드한 뒤 포장합니다.

Mac:

```sh
flutter build macos --release
python3 tool/package_desktop.py
```

Windows (PowerShell):

```powershell
flutter build windows --release
python tool/package_desktop.py
```

`dist/`에 버전·운영체제·CPU 종류가 표시된 ZIP과 SHA-256 체크섬 파일을 만듭니다. ZIP에는 앱, 운영체제별 설치 안내, 서드파티 라이선스를 넣습니다. Mac은 실제 앱과 프레임워크에 포함된 CPU 아키텍처를 확인하고, 압축 해제 후 서명 무결성을 검증합니다. Windows는 Release 폴더 전체와 Visual Studio의 x64 재배포용 런타임 DLL을 포함하고, 압축 해제한 앱이 입력 차단 없이 대기 상태로 실행되는지 확인합니다.

GitHub Actions의 **Desktop checks** 실행 결과에서 `keyboard-saver-macOS`, `keyboard-saver-Windows` artifact를 받을 수 있습니다. artifact 압축 안에 들어 있는 ZIP과 `.sha256` 파일을 GitHub Release에 첨부하세요. Actions artifact는 30일 동안 보관하며, 일반 사용자에게 제공할 영구 다운로드 링크는 Release에서 만듭니다.

### GitHub Release 자동화

`pubspec.yaml`의 앱 버전에 맞는 `v*` 태그를 푸시하면 **Desktop release**가 실행됩니다. 예를 들어 `version: 0.1.0+1`이면:

```sh
git tag v0.1.0
git push origin v0.1.0
```

태그와 앱 버전이 일치하는지 검사한 뒤, 기존 CI를 재사용해 Mac·Windows 테스트, Release 빌드, ZIP 포장과 체크섬 검증을 수행합니다. 성공하면 두 ZIP과 각각의 체크섬을 첨부한 **Draft Release**를 만듭니다. GitHub Releases에서 설치 파일과 안내를 확인한 뒤 Publish release로 공개하세요. `v0.1.0-beta.1`처럼 버전에 하이픈이 있으면 Pre-release로 표시합니다.

같은 태그의 초안은 Actions의 **Desktop release → Run workflow**에 기존 태그를 입력해 다시 만들 수 있습니다. 이미 공개한 Release는 수정하지 않고 실패하며, 새 버전을 사용해야 합니다. 수동 실행 메뉴는 이 workflow가 기본 브랜치에 반영된 뒤 표시됩니다. 개인 토큰이나 배포용 인증서 없이 저장소의 `GITHUB_TOKEN`으로 Release 초안을 만들며, 쓰기 권한은 Release 첨부 작업에만 부여합니다.

현재 파일은 Mac의 Developer ID 서명·공증과 Windows 배포 서명이 없는 테스트 버전입니다. Mac은 ad hoc 서명으로 앱 무결성만 확인하며, 다운로드 후 보안 경고나 추가 허용 절차가 나타날 수 있습니다. 무료 테스트 배포와 일반 사용자용 서명·공증 준비를 구분합니다.

## Mac에서 허용해도 권한이 인식되지 않을 때

Cursor 등의 내장 터미널에서 `flutter run -d macos`로 직접 실행하면 macOS가 권한 검사 대상을 개발 도구로 판단할 수 있습니다. 이 경우 Debug 앱의 권한을 허용해도 `AXIsProcessTrusted()`는 계속 `false`를 반환할 수 있습니다. 실제로 Cursor를 검사 대상으로 삼아 요청이 거부되는 로그를 확인했습니다. 앱을 종료한 뒤 `bash tool/dev_macos.sh --no-build`로 실행하면 같은 빌드와 기존 권한을 사용하면서 앱 자체를 검사 대상으로 실행하고, 핫 리로드도 사용할 수 있습니다.

현재 빌드는 개발용 ad hoc 서명을 사용합니다. 바이너리가 바뀌면 macOS가 이전에 허용한 앱과 같은 앱으로 인정하지 않을 수 있으며, 앱 재시작이나 스위치 토글만으로 복구되지 않을 수 있습니다. [Apple의 코드 서명 요구사항 설명](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)을 참고하세요.

1. 앱에서 **허용했는데도 안 되나요? → 현재 앱을 Finder에서 보기**를 누릅니다.
2. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 해당 앱의 기존 항목을 `−`로 삭제합니다.
3. Finder에서 선택된 **현재 실행 파일**을 목록에 드래그하거나 `+`로 추가하고 허용합니다.
4. 앱의 **권한과 상태 다시 확인**을 누릅니다. 계속 인식되지 않으면 앱을 종료한 뒤 방금 선택한 파일로 다시 실행합니다.

Debug는 `Keyboard Saver Debug` / `dev.keyboardsaver.keyboardSaver.debug`, Release는 `Keyboard Saver` / `dev.keyboardsaver.keyboardSaver`로 분리했습니다. 권한도 각각 허용해야 합니다. 예전 빌드의 `build/macos/Build/Products/Debug/Keyboard Saver.app`는 사용하지 마세요. Release 앱은 `build/macos/Build/Products/Release/Keyboard Saver.app`에 있습니다. Dock의 예전 바로가기 대신 Finder에서 원하는 빌드를 직접 실행하면 혼동을 줄일 수 있습니다.

반복 빌드에서도 권한을 유지하려면 Xcode의 Runner → Signing & Capabilities에서 본인의 Team과 **Apple Development** 서명을 설정하세요. 일반 사용자에게 원활하게 배포하려면 **Developer ID Application** 서명과 공증을 준비하세요. 인증서가 없는 환경에서 ad hoc 서명만으로 권한 유지를 보장할 수는 없습니다. 앱은 시스템 권한을 자동으로 초기화하거나 허용하지 않습니다.

## 현재 범위와 배포

- 일반 키와 modifier 입력 차단, 마우스 해제, 권한 안내, 비동기 상태 처리까지 구현했습니다.
- macOS는 `NX_SYSDEFINED`의 보조 제어 키 이벤트를 추가로 차단합니다. 화면·키보드 밝기, 음량·음소거, 재생/일시정지, 이전/다음 곡 및 탐색 키가 대상입니다. 누름·뗌·반복을 모두 차단합니다. 전원·잠자기 알림과 보조 마우스 버튼 등 다른 시스템 이벤트는 그대로 통과시킵니다.
- Windows의 표준 `VK_VOLUME_*`·`VK_MEDIA_*` 키는 기존 키보드 훅으로 차단합니다. [HID Consumer Control로 처리되는 밝기 키](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/display-brightness-control)나 제조사 ACPI 경로는 이 훅을 거치지 않을 수 있으며, Windows 밝기 차단은 아직 지원 범위로 보장하지 않습니다.
- 전원/Touch ID, 기기 자체에서 처리되는 키, macOS 보안 입력, Windows 보안 데스크톱/UAC 및 Ctrl+Alt+Delete까지 차단한다고 보장하지 않습니다. 실제 밝기·음량·재생 상태가 변하지 않는지는 기기별 수동 검증이 필요합니다.
- macOS는 기본 App Sandbox를 해제한 직접 배포용 프로토타입입니다. 배포 시 Developer ID 서명과 공증을 별도로 구성해야 하며, 현재 설정은 Mac App Store 제출용이 아닙니다.
- Windows의 훅은 시간 초과 시 OS가 조용히 제거할 수 있습니다. 전용 스레드로 지연을 줄였지만 실제 기기에서 장시간·부하 테스트가 필요합니다.
- 메뉴 막대/트레이 상주, 자동 시작, 설치 프로그램, 자동 업데이트, 배포 서명은 다음 단계입니다.
- 로그인, 서버, 계정, 원격 저장 기능은 포함하지 않습니다.

## 네이티브 API

- 메서드 채널: `keyboard_saver/guard`
- 이벤트 채널: `keyboard_saver/guard/events`

`getStatus`, `requestPermission`, `start`, `stop`이 동일한 상태를 반환합니다.

```text
phase: idle | locked | fault
permissionGranted: bool
revision: 증가하는 상태 번호
reason: 선택적인 중단 원인 (session_interrupted, permission_revoked 등)
permissionApp: macOS에서만 제공하는 현재 앱의 name, path, bundleIdentifier
```

Dart는 revision으로 늦게 도착한 응답을 무시합니다. `stop`은 누른 키의 상태에 관계없이 필터를 제거하고 `idle`을 반환합니다. 반복 호출해도 대기 상태를 유지합니다.

macOS 전용 `revealPermissionApp`은 인수 없이 현재 앱을 Finder에서 선택하고 반환합니다. 입력 차단이나 권한 변경을 수행하지 않습니다.
