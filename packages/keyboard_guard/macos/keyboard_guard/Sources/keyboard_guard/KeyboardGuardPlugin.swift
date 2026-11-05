import Cocoa
import FlutterMacOS
import ApplicationServices

public class KeyboardGuardPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []
  private var shutDown = false
  private lazy var engine = KeyboardGuardEngine { [weak self] value in self?.sink?(value) }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = KeyboardGuardPlugin()
    let methods = FlutterMethodChannel(name: "keyboard_saver/guard", binaryMessenger: registrar.messenger)
    let events = FlutterEventChannel(name: "keyboard_saver/guard/events", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    instance.observeLifecycle()
  }

  private func observeLifecycle() {
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
      let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.engine.cancel(reason: "session_interrupted")
      }
      observers.append((workspace, token))
    }
    let center = NotificationCenter.default
    let token = center.addObserver(forName: NSApplication.willTerminateNotification,
                                  object: nil, queue: .main) { [weak self] _ in
      self?.shutdown()
    }
    observers.append((center, token))
  }

  deinit {
    for (center, token) in observers { center.removeObserver(token) }
    shutdown()
  }

  private func shutdown() {
    guard !shutDown else { return }
    shutDown = true
    engine.shutdown()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "revealPermissionApp" {
      // Resolve locally, never accept an arbitrary path from the Dart client.
      NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
      result(nil)
      return
    }
    guard ["getStatus", "requestPermission", "start", "stop"].contains(call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }
    if call.method == "requestPermission" {
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      _ = AXIsProcessTrustedWithOptions(options)
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
      }
    }
    engine.perform(call.method) { response in
      switch response {
      case .success(let value): result(value)
      case .failure(let error):
        result(FlutterError(code: error.code, message: error.message, details: nil))
      }
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    engine.perform("getStatus") { [weak self] response in
      if case .success(let value) = response { self?.sink?(value) }
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    engine.cancel(reason: "client_disconnected")
    return nil
  }
}
