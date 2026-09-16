//
//  AccountStore.swift
//  AplMac
//
//  Status akun Sign in with Apple.
//
//  Tidak ada server. Identifier opaque dari Apple disimpan lokal di Keychain dan
//  tidak pernah dikirim ke mana pun — app ini memang tidak punya backend.
//

import Foundation
import AuthenticationServices

@MainActor
@Observable
final class AccountStore {

    private enum Keys {
        static let userID = "appleUserID"                       // Keychain
        static let displayName = "account.displayName"          // UserDefaults
        static let onboardingDone = "onboarding.completed"      // UserDefaults
    }

    private(set) var userID: String?
    private(set) var displayName: String?

    /// Onboarding dianggap tuntas hanya bila layar-layarnya sudah dilalui.
    /// Disimpan terpisah dari status login supaya sign-out tidak memaksa user
    /// mengulang layar izin notifikasi dan perkenalan.
    private(set) var hasCompletedOnboarding: Bool

    var isSignedIn: Bool { userID != nil }

    /// Nama depan untuk sapaan dashboard.
    ///
    /// Fungsi murni yang dipisah, bukan hanya properti, supaya bisa diuji tanpa
    /// menyentuh Keychain atau UserDefaults — dan supaya tidak ada jalan masuk
    /// khusus-test yang perlu ditambahkan ke kelas ini.
    nonisolated static func firstName(from displayName: String?) -> String? {
        guard let first = displayName?
            .split(separator: " ", omittingEmptySubsequences: true)
            .first else { return nil }
        return String(first)
    }

    var firstName: String? { Self.firstName(from: displayName) }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.userID = KeychainStore.string(for: Keys.userID)
        self.displayName = defaults.string(forKey: Keys.displayName)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingDone)
    }

    // MARK: - Sign in

    private static let nameFormatter: PersonNameComponentsFormatter = {
        let f = PersonNameComponentsFormatter()
        return f
    }()

    func signIn(with credential: ASAuthorizationAppleIDCredential) {
        let id = credential.user

        // Jika Keychain gagal, kita tidak memperbarui in-memory state —
        // dibiarkan tidak login daripada menampilkan state yang berbohong
        // (isSignedIn = true padahal kredensial tidak tersimpan).
        do {
            try KeychainStore.set(id, for: Keys.userID)
        } catch {
            // Gagal simpan Keychain: jangan update userID supaya state konsisten.
            return
        }
        userID = id

        // fullName hanya dikirim Apple pada otorisasi PERTAMA. Login berikutnya
        // mengembalikan nil, jadi nama yang sudah tersimpan tidak boleh ditimpa.
        if let name = credential.fullName,
           let formatted = Self.nameFormatter.string(for: name).flatMap({
               $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0
           }) {
            displayName = formatted
            defaults.set(formatted, forKey: Keys.displayName)
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    #if DEBUG
    /// Hanya untuk build Debug, yang tidak membawa entitlement Sign in with Apple
    /// sehingga tombol aslinya tidak bisa berfungsi. Dikompilasi keluar dari rilis.
    func debugBypassSignIn() {
        userID = "debug-local-user"
        displayName = "Debug User"
    }
    #endif

    // MARK: - Sign out & deletion

    func signOut() {
        KeychainStore.remove(Keys.userID)
        userID = nil
    }

    /// Penghapusan akun, diwajibkan App Store Guideline 5.1.1(v):
    /// "If your app supports account creation, you must also offer account
    /// deletion within the app."
    ///
    /// Tanpa server, "menghapus akun" berarti memusnahkan seluruh jejak lokal:
    /// kredensial, nama, dan data wellness/chat. Kredensial Sign in with Apple
    /// di sisi Apple dicabut user lewat System Settings — di luar kuasa app,
    /// jadi UI harus menyebutkannya, bukan berpura-pura sudah menanganinya.
    ///
    /// Store ini HANYA membersihkan miliknya sendiri: nama dan status onboarding.
    /// Pembersihan kredensial (signOut) dilakukan SETELAH eraseAllStoredData()
    /// oleh DeleteAccountUseCase, bukan di sini — supaya signOut() tidak
    /// dipanggil dua kali (sekali dari sini, sekali dari closure signOut: UseCase).
    func eraseAllStoredData() {
        displayName = nil
        defaults.removeObject(forKey: Keys.displayName)
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: Keys.onboardingDone)
    }

    // MARK: - Credential state

    /// Apple ID bisa dicabut user dari System Settings sewaktu-waktu. Tanpa
    /// pemeriksaan ini, app akan terus menganggap dirinya login selamanya.
    func refreshCredentialState() async {
        guard let userID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: userID)
        switch state {
        case .revoked, .notFound:
            signOut()
        default:
            break
        }
    }
}

extension AccountStore: LocallyErasable {}
