//
//  PhoneDependencies.swift
//  Apl (iPhone)
//
//  Composition root (spec H §3.2, §5): satu-satunya tempat yang tahu
//  implementasi konkret mana yang dipakai. View dan view model menerima
//  miliknya dari sini lewat properti, bukan `@Environment`.
//

import Foundation

@MainActor
struct PhoneDependencies {

    let profile: ProfileStore
    let chat: ChatStore
    /// Satu-satunya instance: chat dan sheet reminder membaca daftar yang sama.
    let reminderStore: ReminderStore
    let reminders: ReminderListViewModel
    let scheduler: any ReminderScheduling
    let characterCache: CharacterExpressionCache

    /// Didaftarkan eksplisit supaya penghapusan tidak melewatkan satu pun.
    private let erasableStores: [any LocallyErasable]

    /// - Parameters:
    ///   - brain: `nil` hanya di test dan preview.
    ///   - transcripts: ingatan model di disk; harus ikut musnah.
    init(brain: Brain?, defaults: UserDefaults, scheduler: any ReminderScheduling,
         transcripts: (any LocallyErasable)? = nil) {
        let profile = ProfileStore(defaults: defaults)
        let reminderStore = ReminderStore(defaults: defaults)
        let chat = ChatStore(brain: brain, defaults: defaults)
        chat.createReminder = CreateReminderFromTextUseCase(store: reminderStore, notifications: scheduler)

        self.profile = profile
        self.chat = chat
        self.reminderStore = reminderStore
        self.reminders = ReminderListViewModel(store: reminderStore, notifications: scheduler)
        self.scheduler = scheduler
        self.characterCache = CharacterExpressionCache()
        self.erasableStores = [profile, chat, reminderStore] + (transcripts.map { [$0] } ?? [])
    }

    static func live() -> PhoneDependencies {
        // Transcript dipersist supaya percakapan bertahan lintas peluncuran.
        let sessionStore = FileChatSessionStore()
        let appleBrain = AppleBrain(sessionStore: sessionStore)

        #if DEBUG
        // Settings › Debug bisa memaksa status Apple Intelligence, untuk
        // menguji banner tanpa menyentuh pengaturan sistem (spec H §4.4).
        let brain: Brain = DebugAvailabilityBrain(base: appleBrain, defaults: .standard)
        #else
        let brain: Brain = appleBrain
        #endif

        return PhoneDependencies(brain: brain, defaults: .standard,
                                 scheduler: ReminderNotificationCenter.shared,
                                 transcripts: sessionStore)
    }

    /// Erase All Data (spec H §4.4). Tiap penyimpanan memusnahkan miliknya
    /// sendiri; notifikasi dibatalkan dan ditunggu sampai selesai.
    func eraseAllData() async {
        let scheduler = self.scheduler
        await EraseAllDataUseCase(stores: erasableStores,
                                  clearNotifications: { await scheduler.cancelAll() })
            .execute()
    }

    /// Meminta izin, lalu menjadwalkan reminder yang sudah ada.
    func requestNotifications() async -> Bool {
        let granted = await scheduler.requestAuthorization()
        if granted {
            await scheduler.sync(reminderStore.reminders, now: .now)
        }
        await reminders.refreshPermission()
        return granted
    }
}
