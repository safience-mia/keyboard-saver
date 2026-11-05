import AppKit
import ApplicationServices

struct GuardFailure: Error {
  let code: String
  let message: String
}

/// All event-tap state lives on this dedicated run loop, independently of Dart.
final class KeyboardGuardEngine {
  typealias Reply = (Result<[String: Any], GuardFailure>) -> Void
  private var worker: Thread!
  private var loop: CFRunLoop!
  private let ready = DispatchSemaphore(value: 0)
  private var tap: CFMachPort?
  private var source: CFRunLoopSource?
  private var phase = "idle"
  private var reason: String?
  private var revision = 0
  private var permissionGranted = false
  private let onChange: ([String: Any]) -> Void

  init(onChange: @escaping ([String: Any]) -> Void) {
    self.onChange = onChange
    worker = Thread { [weak self] in
      guard let self else { return }
      self.loop = CFRunLoopGetCurrent()
      let keepAlive = Port()
      RunLoop.current.add(keepAlive, forMode: .default)
      self.permissionGranted = AXIsProcessTrusted()
      self.ready.signal()
      CFRunLoopRun()
      keepAlive.invalidate()
    }
    worker.name = "dev.keyboardsaver.keyboard-guard"
    worker.qualityOfService = .userInteractive
    worker.start()
    ready.wait()
  }

  func perform(_ method: String, reply: @escaping Reply) {
    enqueue { engine in
      do {
        if method == "start" {
          try engine.start()
        }
        if method == "stop" { engine.stop() }
        engine.refreshPermission()
        let value = engine.snapshot()
        DispatchQueue.main.async { reply(.success(value)) }
      } catch let error as GuardFailure {
        DispatchQueue.main.async { reply(.failure(error)) }
      } catch {
        DispatchQueue.main.async {
          reply(.failure(GuardFailure(code: "native_error", message: "Input guard failed.")))
        }
      }
    }
  }

  func cancel(reason: String) {
    enqueue { engine in
      guard engine.tap != nil else { return }
      engine.removeTap()
      engine.phase = "fault"
      engine.reason = reason
      engine.publish()
    }
  }

  func shutdown() {
    enqueue { engine in
      engine.removeTap()
      CFRunLoopStop(engine.loop)
    }
  }

  private func enqueue(_ action: @escaping (KeyboardGuardEngine) -> Void) {
    CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue) { [weak self] in
      if let self { action(self) }
    }
    CFRunLoopWakeUp(loop)
  }

  private func snapshot() -> [String: Any] {
    var value: [String: Any] = [
      "phase": phase, "permissionGranted": permissionGranted, "revision": revision,
      "permissionApp": [
        "name": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Keyboard Saver",
        "path": Bundle.main.bundleURL.path,
        "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
      ],
    ]
    if let reason { value["reason"] = reason }
    return value
  }

  private func publish() {
    revision += 1
    let value = snapshot()
    DispatchQueue.main.async { [onChange] in onChange(value) }
  }

  private func refreshPermission() {
    let granted = AXIsProcessTrusted()
    if permissionGranted != granted {
      permissionGranted = granted
      if !granted && tap != nil {
        removeTap()
        phase = "fault"
        reason = "permission_revoked"
      }
      publish()
    }
  }

  private func start() throws {
    guard tap == nil else {
      throw GuardFailure(code: "already_locked", message: "Already cleaning.")
    }
    refreshPermission()
    guard permissionGranted else {
      throw GuardFailure(code: "permission_denied", message: "Accessibility permission is required.")
    }
    guard !(0..<128).contains(where: {
      CGEventSource.keyState(.hidSystemState, key: CGKeyCode($0))
    }) else {
      throw GuardFailure(code: "keys_held", message: "Release every key before starting.")
    }
    let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(SystemKeyEvent.mask) {
      $0 | (CGEventMask(1) << $1.rawValue)
    }
    guard let newTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, info in
        guard let info else { return Unmanaged.passUnretained(event) }
        let engine = Unmanaged<KeyboardGuardEngine>.fromOpaque(info).takeUnretainedValue()
        // NSEvent bridging must not retain autoreleased objects for a long session.
        return autoreleasepool { engine.filter(type: type, event: event) }
      }, userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else {
      throw GuardFailure(code: "tap_failed", message: "Could not install the keyboard filter.")
    }
    guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
      CFMachPortInvalidate(newTap)
      throw GuardFailure(code: "tap_failed", message: "Could not create the input run loop source.")
    }
    tap = newTap
    source = newSource
    CFRunLoopAddSource(loop, newSource, .defaultMode)
    CGEvent.tapEnable(tap: newTap, enable: true)
    guard CGEvent.tapIsEnabled(tap: newTap) else {
      removeTap()
      throw GuardFailure(code: "tap_failed", message: "The keyboard filter is not enabled.")
    }
    phase = "locked"
    reason = nil
    publish()
  }

  private func stop() {
    removeTap()
    phase = "idle"
    reason = nil
    publish()
  }

  private func filter(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      // A disabled tap means protection was interrupted; never keep showing locked.
      removeTap()
      phase = "fault"
      reason = "tap_disabled"
      publish()
      return Unmanaged.passUnretained(event)
    }
    guard tap != nil else { return Unmanaged.passUnretained(event) }
    if type.rawValue == SystemKeyEvent.type {
      guard SystemKeyEvent.shouldBlock(event) else {
        return Unmanaged.passUnretained(event)
      }
      return nil
    }
    guard type == .keyDown || type == .keyUp || type == .flagsChanged else {
      return Unmanaged.passUnretained(event)
    }
    return nil
  }

  private func removeTap() {
    if let tap { CFMachPortInvalidate(tap) }
    if let source { CFRunLoopRemoveSource(loop, source, .defaultMode) }
    source = nil
    tap = nil
  }
}
