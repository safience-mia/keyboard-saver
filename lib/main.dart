import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:keyboard_guard/keyboard_guard.dart';

import 'cleaning_controller.dart';

void main() => runApp(const KeyboardSaverApp());

class KeyboardSaverApp extends StatelessWidget {
  const KeyboardSaverApp({super.key, this.guard});
  final KeyboardGuard? guard;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Keyboard Saver',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F5F1),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25624B)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: CleaningScreen(guard: guard ?? MethodChannelKeyboardGuard()),
  );
}

class CleaningScreen extends StatefulWidget {
  const CleaningScreen({super.key, required this.guard});
  final KeyboardGuard guard;

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen>
    with WidgetsBindingObserver {
  late final CleaningController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = CleaningController(widget.guard);
    unawaited(controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> _showPermissionHelp(PermissionApp app) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('허용했는데도 인식되지 않나요?'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '앱을 업데이트하거나 다른 위치의 복사본을 실행하면 이전 권한과 연결되지 않을 수 있어요. '
                '켜져 있는 스위치만으로는 현재 앱의 권한을 확인할 수 없어요.',
              ),
              const SizedBox(height: 16),
              Text(
                '1. 손쉬운 사용 목록에서 기존 ${app.name} 항목을 선택하고 − 버튼으로 삭제해 주세요.\n\n'
                '2. 아래 버튼으로 찾은 앱을 손쉬운 사용 목록에 드래그하거나 + 버튼으로 추가하고 허용해 주세요.\n\n'
                '3. 이 앱으로 돌아와 ‘권한과 상태 다시 확인’을 눌러 주세요. '
                '계속 인식되지 않으면 앱을 종료하고 아래 위치의 앱을 다시 실행해 주세요.',
              ),
              const SizedBox(height: 20),
              Text(
                '현재 실행 중: ${app.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SelectableText(app.path, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton.icon(
          onPressed: controller.revealPermissionApp,
          icon: const Icon(Icons.folder_open),
          label: const Text('현재 앱을 Finder에서 보기'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.snapshot.isBlocking) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '청소가 끝나면 키보드에서 손을 떼고 눌러 주세요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: controller.stop,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('청소 끝내기'),
                ),
              ],
            ),
          ),
        );
      },
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final status = controller.snapshot;
          final locked = status.isBlocking;
          final permitted = status.permissionGranted;
          final appName = status.permissionApp?.name ?? 'Keyboard Saver';
          final label = !controller.statusReliable
              ? '상태 확인 필요'
              : !controller.initialized
              ? '상태 확인 중'
              : locked
              ? '청소 모드'
              : permitted
              ? '시작할 준비 완료'
              : '권한 설정 필요';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _AppBrand(label: appName)),
                        const SizedBox(width: 16),
                        Chip(
                          avatar: Icon(
                            Icons.circle,
                            size: 9,
                            color: locked
                                ? const Color(0xFF25624B)
                                : Colors.grey,
                          ),
                          label: Text(label),
                          side: BorderSide.none,
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            locked
                                ? 'CLEANING TIME'
                                : 'A LITTLE CARE, A FRESH START',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF25624B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            !controller.statusReliable
                                ? '청소를 잠시 멈춰 주세요.'
                                : locked
                                ? '편하게 닦으세요.'
                                : '키보드에게 잠깐의 휴식을.',
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F3029),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            !controller.statusReliable
                                ? '입력 차단 상태를 확인할 수 없어요. 청소를 끝내거나 앱을 닫아 주세요.'
                                : locked
                                ? '키보드 입력을 차단하고 있어요. 마우스는 그대로 사용할 수 있어요.'
                                : '청소 시작을 누르면 키보드 입력을 차단해요.\n청소가 끝나면 마우스로 ‘청소 끝내기’를 눌러 주세요.',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.7,
                              color: Color(0xFF65736C),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _KeyboardIllustration(active: locked),
                          const SizedBox(height: 28),
                          if (!permitted && controller.initialized) ...[
                            Text(
                              '시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서\n$appName를 허용해 주세요.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.7),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (controller.error != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                controller.error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (!locked)
                            FilledButton.icon(
                              onPressed:
                                  controller.busy ||
                                      !controller.initialized ||
                                      !controller.statusReliable
                                  ? null
                                  : permitted
                                  ? controller.start
                                  : controller.requestPermission,
                              icon: Icon(
                                permitted
                                    ? Icons.cleaning_services_outlined
                                    : Icons.settings_outlined,
                              ),
                              label: Text(permitted ? '청소 시작' : '권한 설정 열기'),
                            ),
                          if (!locked &&
                              (!permitted || controller.error != null))
                            TextButton(
                              onPressed: controller.busy
                                  ? null
                                  : controller.refresh,
                              child: const Text('권한과 상태 다시 확인'),
                            ),
                          if (!locked &&
                              !permitted &&
                              status.permissionApp != null)
                            TextButton(
                              onPressed: () =>
                                  _showPermissionHelp(status.permissionApp!),
                              child: const Text('허용했는데도 안 되나요?'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      defaultTargetPlatform == TargetPlatform.macOS
                          ? '앱이 멈추면: 다른 앱을 마우스로 선택 →  메뉴 → 강제 종료 → $appName'
                          : '앱이 멈추면: 시작 버튼 우클릭 → 작업 관리자 → Keyboard Saver → 작업 끝내기',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Color(0xFF65736C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      defaultTargetPlatform == TargetPlatform.macOS
                          ? '청소 중 밝기·음량·미디어 키도 차단해요.\n전원·Touch ID와 기기 자체에서 처리하는 키는 차단되지 않을 수 있어요.'
                          : '청소 중 음량·미디어 키도 차단해요.\n전원·일부 밝기 키는 차단되지 않을 수 있어요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Color(0xFF65736C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _AppBrand extends StatelessWidget {
  const _AppBrand({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: ExcludeSemantics(
      child: Row(
        children: [
          Image.asset(
            'assets/images/foam-keycap/k-keycap-fill.png',
            width: 44,
            height: 44,
          ),
          Flexible(
            child: ClipRect(
              // Trim transparent vertical padding without stretching the title.
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                heightFactor: 0.5,
                child: Image.asset(
                  'assets/images/wordmark/keyboard-saver-title-bold.png',
                  width: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _KeyboardIllustration extends StatelessWidget {
  const _KeyboardIllustration({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 420,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE2EDE5) : const Color(0xFFF0F2EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final row in ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final key in row.split(''))
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      width: 30,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        key,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF708076),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 160,
            height: 23,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    ),
  );
}
