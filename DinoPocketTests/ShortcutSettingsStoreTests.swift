import Foundation
import Testing
@testable import Apl

@MainActor
struct ShortcutSettingsStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.shortcut.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func freshInstallStartsAtTheDefaultPreset() {
        let store = ShortcutSettingsStore(defaults: isolatedDefaults(#function))
        #expect(store.preset == .optionSpace)
    }

    @Test func choiceSurvivesRelaunch() {
        let defaults = isolatedDefaults(#function)
        ShortcutSettingsStore(defaults: defaults).preset = .optionCommandA
        #expect(ShortcutSettingsStore(defaults: defaults).preset == .optionCommandA)
    }

    @Test func offSurvivesRelaunchInsteadOfFallingBackToDefault() {
        let defaults = isolatedDefaults(#function)
        ShortcutSettingsStore(defaults: defaults).preset = .off
        #expect(ShortcutSettingsStore(defaults: defaults).preset == .off)
    }

    @Test func unknownStoredValueFallsBackToDefault() {
        let defaults = isolatedDefaults(#function)
        defaults.set("commandShiftBanana", forKey: ShortcutSettingsStore.presetKey)
        #expect(ShortcutSettingsStore(defaults: defaults).preset == .optionSpace)
    }

    @Test func changingThePresetNotifiesOnce() {
        let store = ShortcutSettingsStore(defaults: isolatedDefaults(#function))
        var seen: [ShortcutPreset] = []
        store.onChange = { seen.append($0) }
        store.preset = .optionCommandA
        store.preset = .optionCommandA      // nilai sama: tidak diberitahukan lagi
        #expect(seen == [.optionCommandA])
    }

    @Test func eraseReturnsToDefaultAndLeavesNoKeyBehind() {
        let defaults = isolatedDefaults(#function)
        let store = ShortcutSettingsStore(defaults: defaults)
        store.preset = .off
        store.eraseAllStoredData()
        #expect(store.preset == .optionSpace)
        #expect(defaults.string(forKey: ShortcutSettingsStore.presetKey) == nil)
    }
}
