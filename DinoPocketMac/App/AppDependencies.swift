//
//  AppDependencies.swift
//  AplMac
//
//  Composition root, mengikuti pola Taggo: satu tempat yang tahu implementasi
//  konkret mana yang dipakai, dan pabrik untuk ViewModel.
//
//

import Foundation

@MainActor
struct AppDependencies {

    let systemStatus: SystemStatusProviding
    let appLauncher: AppLaunching
    let launchAtLogin: LaunchAtLoginManaging
    let buddySettings: BuddySettingsStore
    let shortcutSettings: ShortcutSettingsStore
    let nudgeHistory: NudgeHistory
    let codeWorkspace: CodeWorkspace
    let fileWriter: FileWriter
    let profile: ProfileStore

    /// Apple Intelligence — satu-satunya otak (spec A §2 #7).
    let brain: Brain

    /// Satu-satunya instance ReminderStore: chat dan daftar reminder harus
    /// membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminderScheduler: any ReminderScheduling

    /// Didaftarkan eksplisit supaya penghapusan akun tidak melewatkannya.
    let erasableStores: [any LocallyErasable]

    static func live() -> AppDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran —
        // inti dari "asisten yang ingat kemarin".
        let appleBrain: Brain
        var erasable: [any LocallyErasable] = []
        var transcripts: (any LocallyErasable)?
        if #available(macOS 26.0, *) {
            let sessionStore = FileChatSessionStore()
            appleBrain = AppleBrain(sessionStore: sessionStore)
            erasable.append(sessionStore)
            transcripts = sessionStore
        } else {
            appleBrain = AppleBrain()
        }

        #if DEBUG
        // Tab Debug di Settings bisa memaksa status Apple Intelligence untuk
        // menguji state AI mati tanpa menyentuh pengaturan sistem (spec B §8).
        let brain: Brain = DebugAvailabilityBrain(base: appleBrain, defaults: .standard)
        #else
        let brain = appleBrain
        #endif

        // Sebelum store apa pun membaca data: ChatStore memuat percakapan
        // tersimpan saat dibuat, jadi pembersihan harus mendahuluinya.
        let cleanup = LegacyDataCleanup(transcripts: transcripts)
        cleanup.run()

        let reminderStore = ReminderStore()
        erasable.append(reminderStore)
        erasable.append(cleanup)

        let nudgeHistory = NudgeHistory()
        erasable.append(nudgeHistory)

        return AppDependencies(
            systemStatus: SystemStatusService(),
            appLauncher: AppLauncherService(),
            launchAtLogin: LaunchAtLoginService(),
            buddySettings: BuddySettingsStore(),
            shortcutSettings: ShortcutSettingsStore(),
            nudgeHistory: nudgeHistory,
            codeWorkspace: CodeWorkspace(),
            fileWriter: FileWriter(backups: AppDependencies.backupsFolder()),
            profile: ProfileStore(),
            brain: brain,
            reminderStore: reminderStore,
            reminderScheduler: ReminderNotificationCenter.shared,
            erasableStores: erasable
        )
    }

    // MARK: - Factories

    func makeChatStore() -> ChatStore {
        ChatStore(brain: brain)
    }

    /// Percakapan sisi Code: otak, transcript, dan kunci penyimpanan sendiri —
    /// satu sesi yang dipakai bergantian akan membawa obrolan pagi ke jawaban
    /// koding, dan konteks sekecil ini tidak punya ruang untuk itu (spec E §2 #3).
    func makeCodeChatStore() -> ChatStore {
        let codeBrain: Brain
        if #available(macOS 26.0, *) {
            codeBrain = AppleBrain(instructions: CodeInstructions.text,
                                   sessionStore: FileChatSessionStore(fileName: "code-transcript.json"))
        } else {
            codeBrain = AppleBrain(instructions: CodeInstructions.text)
        }
        return ChatStore(brain: codeBrain, recentKey: "code.chat.recent")
    }

    /// Cadangan tinggal di container app, bukan di folder pengguna (spec E §6 #4).
    static func backupsFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Apl/CodeBackups", isDirectory: true)
    }

    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(store: reminderStore, notifications: reminderScheduler)
    }

    /// Membaca ReminderStore yang sama dengan chat, supaya reminder dari chat
    /// langsung muncul di Up next.
    func makeReminderListViewModel() -> ReminderListViewModel {
        ReminderListViewModel(store: reminderStore, notifications: reminderScheduler)
    }
}
