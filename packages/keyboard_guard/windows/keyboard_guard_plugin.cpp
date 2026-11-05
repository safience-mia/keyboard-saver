#include "keyboard_guard_plugin.h"
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <wtsapi32.h>
#include <utility>

namespace keyboard_guard {
using Value = flutter::EncodableValue;

void KeyboardGuardPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<KeyboardGuardPlugin>(registrar));
}
KeyboardGuardPlugin::KeyboardGuardPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      window_(GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT)),
      state_message_(RegisterWindowMessageW(L"dev.keyboardsaver.guard.state")) {
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND, UINT message, WPARAM wparam, LPARAM) -> std::optional<LRESULT> {
        if (message == state_message_) {
          std::optional<GuardState> state;
          { std::lock_guard<std::mutex> lock(mutex_); state.swap(pending_); }
          if (state && sink_) sink_->Success(Encode(*state));
          return 0;
        }
        if ((message == WM_WTSSESSION_CHANGE && wparam == WTS_SESSION_LOCK) ||
            (message == WM_POWERBROADCAST && wparam == PBT_APMSUSPEND)) {
          engine_->Execute("cancel");
        }
        return std::nullopt;
      });
  WTSRegisterSessionNotification(window_, NOTIFY_FOR_THIS_SESSION);
  engine_ = std::make_unique<KeyboardGuardEngine>(
      [this](GuardState state) { QueueState(std::move(state)); });
  methods_ = std::make_unique<flutter::MethodChannel<Value>>(
      registrar->messenger(), "keyboard_saver/guard", &flutter::StandardMethodCodec::GetInstance());
  methods_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
  events_ = std::make_unique<flutter::EventChannel<Value>>(
      registrar->messenger(), "keyboard_saver/guard/events", &flutter::StandardMethodCodec::GetInstance());
  events_->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<Value>>(
      [this](const Value*, std::unique_ptr<flutter::EventSink<Value>>&& sink)
          -> std::unique_ptr<flutter::StreamHandlerError<Value>> {
        sink_ = std::move(sink);
        sink_->Success(Encode(engine_->Execute("getStatus").state));
        return nullptr;
      },
      [this](const Value*) -> std::unique_ptr<flutter::StreamHandlerError<Value>> {
        sink_.reset();
        engine_->Execute("cancel");
        return nullptr;
      }));
}
KeyboardGuardPlugin::~KeyboardGuardPlugin() {
  engine_.reset();
  WTSUnRegisterSessionNotification(window_);
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  events_->SetStreamHandler(nullptr);
  methods_->SetMethodCallHandler(nullptr);
}
Value KeyboardGuardPlugin::Encode(const GuardState& state) {
  flutter::EncodableMap map{
      {Value("phase"), Value(state.phase)},
      {Value("permissionGranted"), Value(true)},
      {Value("revision"), Value(state.revision)},
  };
  if (!state.reason.empty()) map[Value("reason")] = Value(state.reason);
  return Value(map);
}
void KeyboardGuardPlugin::QueueState(GuardState state) {
  { std::lock_guard<std::mutex> lock(mutex_); pending_ = std::move(state); }
  PostMessage(window_, state_message_, 0, 0);
}
void KeyboardGuardPlugin::HandleMethodCall(const flutter::MethodCall<Value>& call,
    std::unique_ptr<flutter::MethodResult<Value>> result) {
  const auto& method = call.method_name();
  if (method != "getStatus" && method != "requestPermission" && method != "start" &&
      method != "stop") {
    result->NotImplemented();
    return;
  }
  auto reply = engine_->Execute(method);
  if (!reply.error.empty()) result->Error(reply.error, "Keyboard guard could not complete the request.");
  else result->Success(Encode(reply.state));
}
}  // namespace keyboard_guard
