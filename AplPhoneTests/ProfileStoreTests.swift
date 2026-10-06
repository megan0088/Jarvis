import Foundation
import Testing
@testable import Apl

@MainActor
struct ProfileStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.profile.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func blankNicknameCountsAsNone() {
        #expect(ProfileStore.normalizedNickname(nil) == nil)
        #expect(ProfileStore.normalizedNickname("") == nil)
        #expect(ProfileStore.normalizedNickname("   ") == nil)
    }

    @Test func nicknameIsTrimmed() {
        #expect(ProfileStore.normalizedNickname("  Ega \n") == "Ega")
    }

    @Test func nicknameAndOnboardingSurviveRelaunch() {
        let defaults = isolatedDefaults(#function)
        let first = ProfileStore(defaults: defaults)
        first.setNickname("Ega")
        first.completeOnboarding()

        let second = ProfileStore(defaults: defaults)
        #expect(second.nickname == "Ega")
        #expect(second.hasCompletedOnboarding)
    }

    @Test func clearingNicknameRemovesTheStoredValue() {
        let defaults = isolatedDefaults(#function)
        let store = ProfileStore(defaults: defaults)
        store.setNickname("Ega")

        store.setNickname("  ")

        #expect(store.nickname == nil)
        #expect(defaults.object(forKey: "account.displayName") == nil)
    }

    @Test func eraseResetsNicknameAndOnboarding() {
        let defaults = isolatedDefaults(#function)
        let store = ProfileStore(defaults: defaults)
        store.setNickname("Ega")
        store.completeOnboarding()

        store.eraseAllStoredData()

        #expect(store.nickname == nil)
        #expect(store.hasCompletedOnboarding == false)
        #expect(ProfileStore(defaults: defaults).hasCompletedOnboarding == false)
    }
}
