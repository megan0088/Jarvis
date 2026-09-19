import Carbon.HIToolbox
import Foundation
import Testing
@testable import Apl

struct ShortcutPresetTests {

    @Test func offRegistersNothing() {
        #expect(ShortcutPreset.off.keyCode == nil)
        #expect(ShortcutPreset.off.modifiers == 0)
    }

    @Test func spacePresetsShareTheSpaceKey() {
        #expect(ShortcutPreset.optionSpace.keyCode == UInt32(kVK_Space))
        #expect(ShortcutPreset.controlOptionSpace.keyCode == UInt32(kVK_Space))
    }

    @Test func modifiersMatchTheirNames() {
        #expect(ShortcutPreset.optionSpace.modifiers == UInt32(optionKey))
        #expect(ShortcutPreset.optionCommandA.modifiers == UInt32(optionKey | cmdKey))
        #expect(ShortcutPreset.controlOptionSpace.modifiers == UInt32(controlKey | optionKey))
        #expect(ShortcutPreset.optionCommandA.keyCode == UInt32(kVK_ANSI_A))
    }

    /// Teksnya muncul di Settings dan di onboarding; kalau berubah, dua tempat
    /// itu ikut berbohong.
    @Test func displayNamesAreTheSymbolsPeopleSee() {
        #expect(ShortcutPreset.off.displayName == "Off")
        #expect(ShortcutPreset.optionSpace.displayName == "⌥Space")
        #expect(ShortcutPreset.optionCommandA.displayName == "⌥⌘A")
        #expect(ShortcutPreset.controlOptionSpace.displayName == "⌃⌥Space")
    }

    /// ⌃Space sengaja tidak ada: macOS memakainya untuk berpindah sumber input.
    @Test func controlSpaceAloneIsNotOffered() {
        #expect(ShortcutPreset.allCases.count == 4)
        #expect(ShortcutPreset.default == .optionSpace)
    }
}
