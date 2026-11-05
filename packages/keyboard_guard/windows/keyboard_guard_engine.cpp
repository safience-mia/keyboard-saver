#include "keyboard_guard_engine.h"
#include <utility>

namespace keyboard_guard {
thread_local KeyboardGuardEngine* KeyboardGuardEngine::current_ = nullptr;

KeyboardGuardEngine::KeyboardGuardEngine(std::function<void(GuardState)> on_change)
    : on_change_(std::move(on_change)) {
  std::promise<void> ready;
  auto started = ready.get_future();
  thread_ = std::thread(&KeyboardGuardEngine::Run, this, std::move(ready));
  started.get();
}
KeyboardGuardEngine::~KeyboardGuardEngine() {
  PostThreadMessage(thread_id_, WM_QUIT, 0, 0);
  if (thread_.joinable()) thread_.join();
}
GuardReply KeyboardGuardEngine::Execute(const std::string& method) {
  auto command = std::make_unique<Command>();
  command->method = method;
  auto reply = command->reply.get_future();
  if (!PostThreadMessage(thread_id_, kCommand, 0,
                         reinterpret_cast<LPARAM>(command.get()))) {
    return {GuardState{}, "worker_unavailable"};
  }
  command.release();
  return reply.get();
}
void KeyboardGuardEngine::Run(std::promise<void> ready) {
  current_ = this;
  thread_id_ = GetCurrentThreadId();
  MSG message;
  PeekMessage(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  ready.set_value();
  while (GetMessage(&message, nullptr, 0, 0) > 0) {
    if (message.message == kCommand) {
      std::unique_ptr<Command> command(reinterpret_cast<Command*>(message.lParam));
      std::string error;
      if (command->method == "start") {
        error = Start();
      }
      if (command->method == "stop") Stop();
      if (command->method == "cancel" && hook_ != nullptr) {
        RemoveHook();
        state_.phase = "fault";
        state_.reason = "session_interrupted";
        Publish();
      }
      command->reply.set_value({state_, error});
    } else {
      TranslateMessage(&message);
      DispatchMessage(&message);
    }
  }
  RemoveHook();
  current_ = nullptr;
}
std::string KeyboardGuardEngine::Start() {
  if (hook_) return "already_locked";
  // Exclude mouse buttons. Do not start halfway through a keyboard stroke.
  for (int key = VK_BACK; key < 255; ++key) {
    if ((GetAsyncKeyState(key) & 0x8000) != 0) return "keys_held";
  }
  HMODULE module = nullptr;
  if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(&KeyboardProc), &module)) {
    return "hook_failed";
  }
  hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardProc, module, 0);
  if (!hook_) return "hook_failed";
  state_.phase = "locked";
  state_.reason.clear();
  Publish();
  return "";
}
LRESULT CALLBACK KeyboardGuardEngine::KeyboardProc(int code, WPARAM message,
                                                  LPARAM data) {
  auto* engine = current_;
  if (code < 0 || !engine || !engine->hook_) {
    return CallNextHookEx(nullptr, code, message, data);
  }
  // Suppress both edges and repeats, including synthesized and media-key input.
  // OEM brightness controls delivered directly through HID/ACPI bypass this hook.
  return 1;
}
void KeyboardGuardEngine::RemoveHook() {
  if (hook_) UnhookWindowsHookEx(hook_);
  hook_ = nullptr;
}
void KeyboardGuardEngine::Stop() {
  RemoveHook();
  state_.phase = "idle";
  state_.reason.clear();
  Publish();
}
void KeyboardGuardEngine::Publish() {
  ++state_.revision;
  on_change_(state_);
}
}  // namespace keyboard_guard
