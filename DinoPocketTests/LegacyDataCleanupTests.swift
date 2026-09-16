import Foundation
import Testing
@testable import Apl

@MainActor
private final class CleanupSpy: LocallyErasable {
    private(set) var transcriptErasures = 0
    private(set) var keychainRemovals = 0
    private(set) var notificationPrefixes: [[String]] = []

    func eraseAllStoredData() { transcriptErasures += 1 }
    func removeKeychainItem() { keychainRemovals += 1 }
    func removeNotifications(_ prefixes: [String]) { notificationPrefixes.append(prefixes) }
}

/// Suite "app group" di sini SENGAJA palsu: test tidak boleh menghapus data
/// di suite sungguhan milik mesin pengembang.
@MainActor
struct LegacyDataCleanupTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.legacy.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeCleanup(standard: UserDefaults, appGroup: UserDefaults,
                             spy: CleanupSpy) -> LegacyDataCleanup {
        LegacyDataCleanup(standard: standard, appGroup: appGroup, transcripts: spy,
                          removeKeychainItem: { spy.removeKeychainItem() },
                          removePendingNotifications: { spy.removeNotifications($0) })
    }

    @Test func firstRunRemovesEveryLegacyTrace() {
        let standard = isolatedDefaults("first.standard")
        let appGroup = isolatedDefaults("first.group")
        for key in LegacyDataCleanup.appGroupKeys {
            appGroup.set(Data([1]), forKey: key)
        }
        standard.set("ollama", forKey: LegacyDataCleanup.activeBrainKey)
        standard.set(Data([1]), forKey: LegacyDataCleanup.chatRecentKey)
        let spy = CleanupSpy()

        makeCleanup(standard: standard, appGroup: appGroup, spy: spy).run()

        for key in LegacyDataCleanup.appGroupKeys {
            #expect(appGroup.object(forKey: key) == nil, "kunci \(key) tertinggal")
        }
        #expect(standard.object(forKey: LegacyDataCleanup.activeBrainKey) == nil)
        #expect(standard.object(forKey: LegacyDataCleanup.chatRecentKey) == nil)
        #expect(spy.transcriptErasures == 1)
        #expect(spy.keychainRemovals == 1)
        #expect(spy.notificationPrefixes == [["wellness.", "custom."]])
        #expect(standard.bool(forKey: LegacyDataCleanup.doneKey))
    }

    @Test func laterLaunchesDoNothing() {
        let standard = isolatedDefaults("later.standard")
        let appGroup = isolatedDefaults("later.group")
        let spy = CleanupSpy()
        let cleanup = makeCleanup(standard: standard, appGroup: appGroup, spy: spy)
        cleanup.run()
        appGroup.set(Data([1]), forKey: "pet.mood")

        cleanup.run()

        #expect(appGroup.object(forKey: "pet.mood") != nil)
        #expect(spy.keychainRemovals == 1)
    }

    /// Erase All Data membersihkan lagi, tetapi percakapan milik pengguna
    /// bukan urusan cleanup — `ChatStore` sendiri yang menghapusnya.
    @Test func forcedRunCleansAgainButLeavesTheConversationToChatStore() {
        let standard = isolatedDefaults("forced.standard")
        let appGroup = isolatedDefaults("forced.group")
        let spy = CleanupSpy()
        let cleanup = makeCleanup(standard: standard, appGroup: appGroup, spy: spy)
        cleanup.run()
        appGroup.set(Data([1]), forKey: "pet.mood")
        standard.set(Data([1]), forKey: LegacyDataCleanup.chatRecentKey)

        cleanup.run(force: true)

        #expect(appGroup.object(forKey: "pet.mood") == nil)
        #expect(standard.object(forKey: LegacyDataCleanup.chatRecentKey) != nil)
        #expect(spy.transcriptErasures == 1)
        #expect(spy.keychainRemovals == 2)
    }

    @Test func erasingAllDataForcesTheCleanup() {
        let standard = isolatedDefaults("erase.standard")
        let appGroup = isolatedDefaults("erase.group")
        let spy = CleanupSpy()
        let cleanup = makeCleanup(standard: standard, appGroup: appGroup, spy: spy)
        cleanup.run()
        appGroup.set(Data([1]), forKey: "wellness.goalProgress")

        cleanup.eraseAllStoredData()

        #expect(appGroup.object(forKey: "wellness.goalProgress") == nil)
    }
}
