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

    static func live() -> AppDependencies {
        #if DEBUG
        let brains: [BrainKind: Brain] = [.apple: AppleBrain(), .ollama: OllamaBrain()]
        #else
        let brains: [BrainKind: Brain] = [.apple: AppleBrain()]
        #endif

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            account: AccountStore(),
            brains: brains
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
