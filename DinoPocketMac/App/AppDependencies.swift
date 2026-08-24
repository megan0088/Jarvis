//
//  AppDependencies.swift
//  DinoPocketMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//
//  Nilainya bukan kerapian semata — ia yang membuat "Ollama tidak ikut rilis"
//  jadi fakta struktural di satu berkas, bukan disiplin yang harus diingat di
//  setiap tempat `ChatStore` dibuat.
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let account: AccountStore

    /// Otak yang boleh dipilih. Rilis hanya memuat Apple Intelligence: Ollama
    /// butuh localhost, sementara build ini menyetel
    /// ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO, dan app yang bergantung pada
    /// software eksternal berisiko ditolak App Review.
    let brains: [BrainKind: Brain]

    /// Didaftarkan eksplisit supaya penghapusan akun tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let apple: Brain
        var erasable: [any LocallyErasable] = []
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            apple = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
        } else {
            apple = AppleBrain()
        }

        #if DEBUG
        let brains: [BrainKind: Brain] = [.apple: apple, .ollama: OllamaBrain()]
        #else
        let brains: [BrainKind: Brain] = [.apple: apple]
        #endif

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            account: AccountStore(),
            brains: brains,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brains: brains)
    }

    func makeWellnessStore() -> WellnessStore {
        WellnessStore()
    }

    /// View model dibuat dari store yang sama supaya tidak ada dua sumber
    /// kebenaran wellness di dalam satu app.
    func makeWellnessViewModel(store: WellnessStore? = nil) -> WellnessViewModel {
        WellnessViewModel(store: store ?? WellnessStore(),
                          notifications: WellnessNotificationCenter.shared)
    }
}
