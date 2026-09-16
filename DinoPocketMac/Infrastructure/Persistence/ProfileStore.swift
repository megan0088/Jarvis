//
//  ProfileStore.swift
//  AplMac
//
//  Nama panggilan dan status onboarding.
//
//  Menggantikan AccountStore. App ini on-device tanpa server, jadi tidak ada
//  akun untuk dibuat — login wajib hanya menambah risiko Guideline 5.1.1(v).
//  Kunci UserDefaults sengaja dipertahankan dari AccountStore supaya status
//  onboarding yang sudah ada tidak hilang tanpa alasan.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {

    private enum Keys {
        static let nickname = "account.displayName"
        static let onboardingDone = "onboarding.completed"
    }

    private(set) var nickname: String?
    private(set) var hasCompletedOnboarding: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.nickname = Self.normalizedNickname(defaults.string(forKey: Keys.nickname))
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingDone)
    }

    /// Nama kosong atau hanya spasi berarti "tanpa nama", supaya sapaan tidak
    /// berbunyi "Hello, " dengan koma menggantung.
    nonisolated static func normalizedNickname(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    func setNickname(_ raw: String?) {
        nickname = Self.normalizedNickname(raw)
        if let nickname {
            defaults.set(nickname, forKey: Keys.nickname)
        } else {
            defaults.removeObject(forKey: Keys.nickname)
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    func eraseAllStoredData() {
        nickname = nil
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: Keys.nickname)
        defaults.removeObject(forKey: Keys.onboardingDone)
    }
}

extension ProfileStore: LocallyErasable {}
