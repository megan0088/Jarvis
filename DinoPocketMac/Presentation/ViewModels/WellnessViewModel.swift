//
//  WellnessViewModel.swift
//  DinoPocketMac
//
//  Satu-satunya jalan view membaca data wellness.
//
//  Kriteria hijau Wave 1: nol View menyentuh `WellnessStore` langsung. Sebelum
//  ini enam kartu memegang store persistensi apa adanya, sehingga setiap
//  perubahan bentuk penyimpanan merembet ke lapisan tampilan.
//
//  Store konkret sengaja dipegang, bukan `any WellnessStoring`: pelacakan
//  `@Observable` bekerja lewat pemanggilan getter, dan menahannya sebagai tipe
//  konkret membuat propagasi perubahan ke SwiftUI tidak perlu diperdebatkan.
//  UseCase tetap menerima protokolnya, di situlah nilai abstraksi itu berada.
//

import Foundation
import Observation

@MainActor
@Observable
final class WellnessViewModel {

    private let store: WellnessStore
    private let notifications: NotificationScheduling

    init(store: WellnessStore, notifications: NotificationScheduling) {
        self.store = store
        self.notifications = notifications
    }

    // MARK: - Bacaan untuk kartu

    var goalProgress: WellnessGoalProgress { store.goalProgress }
    var energy: Int { store.energy }
    var statusMessage: String { store.statusMessage }
    var todayScreenTime: TimeInterval { store.todayScreenTime }
    var screenTimeHistory: [ScreenTimeEntry] { store.screenTimeHistory }
    var recentScreenTimeHistory: [ScreenTimeEntry] { store.recentScreenTimeHistory }
    var recentReminderHistory: [ReminderEvent] { store.recentReminderHistory }
    var reminderSchedules: [ReminderSchedule] { store.reminderSchedules }

    var isHistoryEmpty: Bool {
        recentReminderHistory.isEmpty && recentScreenTimeHistory.isEmpty
    }

    // MARK: - UseCase

    var summary: FetchWellnessSummaryUseCase.Output {
        FetchWellnessSummaryUseCase(store: store).execute()
    }

    /// Prompt ringkasan harian, dibangun dari angka NYATA.
    ///
    /// Instruksi penutupnya bukan basa-basi: uji langsung terhadap Foundation
    /// Models menunjukkan model on-device mengarang fakta dunia dengan percaya
    /// diri, tetapi patuh merangkai data yang diberikan. Mengikatnya ke angka
    /// yang sudah ada menghapus ruang halusinasi.
    var summaryPrompt: String {
        let s = summary
        return """
        Summarize my day so far in two or three warm sentences. \
        Here is what I actually did: \(s.deskTimeText) at my desk, \(s.water) glasses of water, \
        \(s.stretch) stretch breaks, \(s.meals) meals. \
        Only use these numbers; do not invent anything else.
        """
    }

    // MARK: - Siklus hidup

    func prepare() async {
        await store.prepareWellness()
    }

    func resumeSession() {
        store.resumeScreenTime()
    }

    func pauseSession() {
        store.pauseScreenTime()
    }

    func tick() {
        store.tick()
    }

    func syncReminderHistory() async {
        await store.syncReminderHistory()
    }

    /// Dipakai `ChatStore` saat pengingat lahir dari percakapan.
    func makeCreateReminderUseCase() -> CreateReminderFromTextUseCase {
        CreateReminderFromTextUseCase(parser: ReminderIntentParser(),
                                      store: store,
                                      notifications: notifications)
    }

    /// Diperlukan `DeleteAccountUseCase`; view tidak pernah memanggilnya.
    var erasableStore: any LocallyErasable { store }
}

#if DEBUG
extension WellnessViewModel {
    /// Untuk #Preview saja. Memakai store sungguhan karena WellnessStore
    /// membaca UserDefaults dan tidak menyentuh jaringan atau perangkat keras.
    static var preview: WellnessViewModel {
        WellnessViewModel(store: WellnessStore(),
                          notifications: WellnessNotificationCenter.shared)
    }
}
#endif
