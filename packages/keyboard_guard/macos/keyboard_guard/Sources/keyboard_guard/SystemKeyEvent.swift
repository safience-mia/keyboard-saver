import AppKit
import IOKit.hidsystem

/// Brightness and media keys arrive as NX_SYSDEFINED auxiliary-control events,
/// not CGEventType.keyDown/keyUp. Keep other system-defined events untouched.
enum SystemKeyEvent {
  static let type = UInt32(NX_SYSDEFINED)
  static let mask = CGEventMask(1) << type

  private static let blockedKeys: Set<Int> = [
    Int(NX_KEYTYPE_SOUND_UP), Int(NX_KEYTYPE_SOUND_DOWN), Int(NX_KEYTYPE_MUTE),
    Int(NX_KEYTYPE_BRIGHTNESS_UP), Int(NX_KEYTYPE_BRIGHTNESS_DOWN),
    Int(NX_KEYTYPE_ILLUMINATION_UP), Int(NX_KEYTYPE_ILLUMINATION_DOWN), Int(NX_KEYTYPE_ILLUMINATION_TOGGLE),
    Int(NX_KEYTYPE_PLAY), Int(NX_KEYTYPE_NEXT), Int(NX_KEYTYPE_PREVIOUS),
    Int(NX_KEYTYPE_FAST), Int(NX_KEYTYPE_REWIND),
  ]

  /// Returns true when the caller must swallow this event. No input is posted.
  static func shouldBlock(_ event: CGEvent) -> Bool {
    guard event.type.rawValue == type,
          let systemEvent = NSEvent(cgEvent: event),
          systemEvent.subtype.rawValue == Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS) else { return false }

    let data = UInt32(truncatingIfNeeded: systemEvent.data1)
    let key = Int((data >> 16) & 0xFFFF)
    // Swallow both edges, repeats, modifiers and unknown transitions of these keys.
    return blockedKeys.contains(key)
  }
}
