#ifndef FLUTTER_PLUGIN_KEYBOARD_GUARD_PLUGIN_H_
#define FLUTTER_PLUGIN_KEYBOARD_GUARD_PLUGIN_H_
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>
#include <mutex>
#include <optional>
#include "keyboard_guard_engine.h"

namespace keyboard_guard {
class KeyboardGuardPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);
  explicit KeyboardGuardPlugin(flutter::PluginRegistrarWindows* registrar);
  ~KeyboardGuardPlugin() override;
  KeyboardGuardPlugin(const KeyboardGuardPlugin&) = delete;
  KeyboardGuardPlugin& operator=(const KeyboardGuardPlugin&) = delete;
 private:
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  static flutter::EncodableValue Encode(const GuardState& state);
  void QueueState(GuardState state);
  flutter::PluginRegistrarWindows* registrar_;
  HWND window_;
  UINT state_message_;
  int window_proc_id_;
  std::mutex mutex_;
  std::optional<GuardState> pending_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<KeyboardGuardEngine> engine_;
};
}  // namespace keyboard_guard
#endif
