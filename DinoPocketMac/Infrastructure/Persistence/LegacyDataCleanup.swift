//
//  LegacyDataCleanup.swift
//  AplMac
//
//  Membersihkan jejak data dari era wellness dan Sign in with Apple.
//
//  App belum pernah rilis, jadi data lama tidak dimigrasikan (spec A §2 #4) —
//  tetapi ia tetap harus hilang dari disk. Tanpa ini, Erase All Data
//  meninggalkan riwayat wellness di suite app group dan identifier Apple ID
//  di Keychain, karena tidak ada lagi store yang mengaku memilikinya.
//

import Foundation
import Security
import UserNotifications

@MainActor
struct LegacyDataCleanup {

    nonisolated static let doneKey = "apl.legacyCleanupDone"
    nonisolated static let appGroupSuite = "group.com.ega.apl"

    /// Kunci `WellnessStore` yang dihapus di sub-project A. Ditulis literal
    /// karena store-nya sudah tidak ada untuk ditanya.
    nonisolated static let appGroupKeys = [
        "pet.mood", "pet.hunger", "pet.energy", "pet.lastFed", "pet.affection",
        "wellness.screenTimeHistory", "wellness.reminderHistory", "wellness.reminderEventsSeen",
        "wellness.remindersEnabled", "wellness.goalProgress", "wellness.snoozedReminders",
        "pet.customSchedules",
    ]

    nonisolated static let activeBrainKey = "jarvis.activeBrain"
    nonisolated static let chatRecentKey = "jarvis.chat.recent"

    /// Identifier notifikasi jadwal wellness bawaan ("wellness.") dan reminder
    /// chat versi lama ("custom.").
    nonisolated static let notificationPrefixes = ["wellness.", "custom."]

    private let standard: UserDefaults
    private let appGroup: UserDefaults?
    private let transcripts: (any LocallyErasable)?
    private let removeKeychainItem: () -> Void
    private let removePendingNotifications: ([String]) -> Void

    init(standard: UserDefaults = .standard,
         appGroup: UserDefaults? = UserDefaults(suiteName: LegacyDataCleanup.appGroupSuite),
         transcripts: (any LocallyErasable)?,
         removeKeychainItem: @escaping () -> Void = LegacyDataCleanup.removeAppleUserID,
         removePendingNotifications: @escaping ([String]) -> Void = LegacyDataCleanup.removePending(withPrefixes:)) {
        self.standard = standard
        self.appGroup = appGroup
        self.transcripts = transcripts
        self.removeKeychainItem = removeKeychainItem
        self.removePendingNotifications = removePendingNotifications
    }

    /// - Parameter force: `false` saat app dibuka (sekali per instalasi);
    ///   `true` dari Erase All Data (selalu).
    func run(force: Bool = false) {
        let isFirstRun = !standard.bool(forKey: Self.doneKey)
        guard force || isFirstRun else { return }

        for key in Self.appGroupKeys {
            appGroup?.removeObject(forKey: key)
        }
        standard.removeObject(forKey: Self.activeBrainKey)

        // Percakapan lama dibuat dengan instructions persona lama, dan transcript
        // yang dilanjutkan terus membawa instructions itu. Hanya pada jalan
        // pertama: setelahnya percakapan milik pengguna, dan hanya Erase All Data
        // (lewat ChatStore) yang boleh menghapusnya.
        if isFirstRun {
            standard.removeObject(forKey: Self.chatRecentKey)
            transcripts?.eraseAllStoredData()
        }

        removeKeychainItem()
        removePendingNotifications(Self.notificationPrefixes)
        standard.set(true, forKey: Self.doneKey)
    }

    /// Item Keychain milik AccountStore/KeychainStore yang sudah dihapus.
    nonisolated static func removeAppleUserID() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ega.apl.account",
            kSecAttrAccount as String: "appleUserID",
        ]
        SecItemDelete(query as CFDictionary)
    }

    nonisolated static func removePending(withPrefixes prefixes: [String]) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter { identifier in
                prefixes.contains { identifier.hasPrefix($0) }
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}

extension LegacyDataCleanup: LocallyErasable {
    func eraseAllStoredData() {
        run(force: true)
    }
}
