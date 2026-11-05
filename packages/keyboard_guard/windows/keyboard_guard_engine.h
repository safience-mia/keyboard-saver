#ifndef KEYBOARD_GUARD_ENGINE_H_
#define KEYBOARD_GUARD_ENGINE_H_

#include <windows.h>
#include <cstdint>
#include <functional>
#include <future>
#include <memory>
#include <string>
#include <thread>

namespace keyboard_guard {
struct GuardState {
  std::string phase = "idle";
  int64_t revision = 0;
  std::string reason;
};
struct GuardReply {
  GuardState state;
  std::string error;
};

// Input filtering never waits for Dart or the UI thread.
class KeyboardGuardEngine {
 public:
  explicit KeyboardGuardEngine(std::function<void(GuardState)> on_change);
  ~KeyboardGuardEngine();
  KeyboardGuardEngine(const KeyboardGuardEngine&) = delete;
  KeyboardGuardEngine& operator=(const KeyboardGuardEngine&) = delete;
  GuardReply Execute(const std::string& method);

 private:
  struct Command {
    std::string method;
    std::promise<GuardReply> reply;
  };
  static constexpr UINT kCommand = WM_APP + 101;
  static thread_local KeyboardGuardEngine* current_;
  static LRESULT CALLBACK KeyboardProc(int code, WPARAM message, LPARAM data);
  void Run(std::promise<void> ready);
  std::string Start();
  void Stop();
  void RemoveHook();
  void Publish();

  DWORD thread_id_ = 0;
  std::thread thread_;
  HHOOK hook_ = nullptr;
  GuardState state_;
  std::function<void(GuardState)> on_change_;
};
}  // namespace keyboard_guard
#endif
