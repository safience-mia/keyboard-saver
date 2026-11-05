import AppKit
import IOKit.hidsystem

@main
struct SystemKeyEventTests {
  // Construct events in memory only: never install a tap or post to the OS.
  static func event(_ key: Int32, state: Int32 = NX_KEYDOWN, repeatKey: Bool = false,
                    subtype: Int32 = NX_SUBTYPE_AUX_CONTROL_BUTTONS,
                    modifiers: NSEvent.ModifierFlags = []) -> CGEvent {
    let data = (Int(key) << 16) | (Int(state) << 8) | (repeatKey ? 1 : 0)
    return NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: modifiers,
                             timestamp: 0, windowNumber: 0, context: nil,
                             subtype: Int16(subtype), data1: data, data2: -1)!.cgEvent!
  }

  static func main() {
    let keys: [Int32] = [
      NX_KEYTYPE_BRIGHTNESS_UP, NX_KEYTYPE_BRIGHTNESS_DOWN,
      NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_SOUND_DOWN, NX_KEYTYPE_MUTE,
      NX_KEYTYPE_PLAY, NX_KEYTYPE_NEXT, NX_KEYTYPE_PREVIOUS,
      NX_KEYTYPE_FAST, NX_KEYTYPE_REWIND,
      NX_KEYTYPE_ILLUMINATION_UP, NX_KEYTYPE_ILLUMINATION_DOWN, NX_KEYTYPE_ILLUMINATION_TOGGLE,
    ]
    precondition(SystemKeyEvent.mask & (1 << NSEvent.EventType.systemDefined.rawValue) != 0)
    for key in keys {
      precondition(SystemKeyEvent.shouldBlock(event(key)))
      precondition(SystemKeyEvent.shouldBlock(event(key, repeatKey: true, modifiers: [.option, .shift])))
      precondition(SystemKeyEvent.shouldBlock(event(key, state: NX_KEYUP)))
      precondition(SystemKeyEvent.shouldBlock(event(key, state: 0)))
    }

    // Unknown system notifications, mouse buttons, power and sleep must pass.
    for subtype in [NX_SUBTYPE_AUX_MOUSE_BUTTONS, NX_SUBTYPE_POWER_KEY, NX_SUBTYPE_SLEEP_EVENT] {
      precondition(!SystemKeyEvent.shouldBlock(event(NX_KEYTYPE_SOUND_UP, subtype: subtype)))
    }
    for key: Int32 in [NX_POWER_KEY, NX_KEYTYPE_EJECT, 0xFFFF] {
      precondition(!SystemKeyEvent.shouldBlock(event(key)))
    }
    let ordinary = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    precondition(!SystemKeyEvent.shouldBlock(ordinary))
    precondition(SystemKeyEvent.shouldBlock(event(NX_KEYTYPE_PLAY, state: 0)))
    // An unmatched key-up is also suppressed, with no state that could delay stop.
    precondition(SystemKeyEvent.shouldBlock(event(NX_KEYTYPE_PLAY, state: NX_KEYUP)))
    print("Swift system keys: suppression, repeats, modifiers and pass-through checks passed")
  }
}
