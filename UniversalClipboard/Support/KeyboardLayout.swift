import Carbon.HIToolbox
import CoreGraphics

@MainActor
enum KeyboardLayout {
    /// The key that types `character` while ⌘ is held in the current keyboard layout,
    /// so ⌘V still means paste on layouts like Dvorak. Returns nil for layouts that can't type it
    /// (e.g. Persian), where macOS maps ⌘ shortcuts to the QWERTY positions anyway.
    static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        let target = String(character).lowercased()
        let commandModifier = UInt32((cmdKey >> 8) & 0xFF)

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for keyCode in UInt16(0)..<128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, keyCode, UInt16(kUCKeyActionDisplay), commandModifier, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters
                )
                if status == noErr, length > 0,
                   String(utf16CodeUnits: characters, count: length).lowercased() == target {
                    return CGKeyCode(keyCode)
                }
            }
            return nil
        }
    }
}
