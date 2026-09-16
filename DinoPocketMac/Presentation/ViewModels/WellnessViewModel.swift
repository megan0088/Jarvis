//
//  WellnessViewModel.swift
//  AplMac
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
    private let focus: TrackFocusSessionUseCase
    private var idleCheckTimer: Timer?

    /// Ditolaknya izin notifikasi bukan error yang bisa dibuang: tanpa ini
    /// saklar pengingat berbalik sendiri tanpa penjelasan, dan user menyimpulkan
    /// app-nya rusak alih-alih izinnya yang mati.
    private(set) var authorizationWasDenied = false

    init(store: WellnessStore,
         notifications: NotificationScheduling,
         idle: IdleTimeProviding = IdleTimeService()) {
        self.store = store
        self.notifications = notifications
        self.focus = TrackFocusSessionUseCase(store: store, idle: idle)
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
    var remindersEnabled: Bool { store.remindersEnabled }

    /// Jadwal yang masih akan datang hari ini dan belum ditandai selesai.
    func upcomingReminders(limit: Int = 3, at date: Date = .now) -> [ReminderSchedule] {
        let now = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutesNow = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return reminderSchedules
            .filter { ($0.hour * 60 + $0.minute) >= minutesNow }
            .filter { !store.isCompleted($0, on: date) }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
            .prefix(limit)
            .map { $0 }
    }

    func isCompletedToday(_ schedule: ReminderSchedule) -> Bool {
        store.isCompleted(schedule)
    }

    // MARK: - Aksi pengingat

    /// Ditandai selesai dari kartu dashboard. Sebelum ini tombolnya ada tapi
    /// closure-nya kosong, jadi progres goal tidak pernah bisa naik dari UI.
    func complete(_ schedule: ReminderSchedule) {
        store.completeReminder(store.reminder(for: schedule))
    }

    func snooze(_ schedule: ReminderSchedule, minutes: Int = 10) {
        store.snoozeReminder(store.reminder(for: schedule),
                             until: Date.now.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    /// Menyalakan/mematikan pengingat harian.
    ///
    /// Hidup di sini, bukan di store, supaya izin dan penjadwalan lewat
    /// `NotificationScheduling` yang disuntikkan — satu-satunya bentuk yang bisa
    /// diuji, dan satu-satunya yang benar-benar ikut ke dalam build macOS.
    func setRemindersEnabled(_ enabled: Bool) async {
        guard enabled else {
            store.setRemindersEnabled(false)
            authorizationWasDenied = false
            await notifications.clearScheduledReminders()
            return
        }

        guard await notifications.requestAuthorization() else {
            store.setRemindersEnabled(false)
            authorizationWasDenied = true
            return
        }

        authorizationWasDenied = false
        store.setRemindersEnabled(true)
        await notifications.schedule(store.reminderSchedules)
    }

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
        Here is what I actually did: \(s.deskTimeText) at my desk, \
        \(count(s.water, "glass", "glasses")) of water, \
        \(count(s.stretch, "stretch break", "stretch breaks")), \
        \(count(s.meals, "meal", "meals")). \
        Only use these numbers; do not invent anything else.
        """
    }

    /// "1 glasses of water" membuat model on-device ikut menulis kalimat cacat —
    /// ia merangkai data yang diberikan, termasuk kesalahan tata bahasanya.
    private func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    // MARK: - Siklus hidup

    func prepare() async {
        await store.prepareWellness()
    }

    func resumeSession() {
        focus.handle(.becameActive)
        startIdleWatch()
    }

    func pauseSession() {
        focus.handle(.becameInactive)
        stopIdleWatch()
    }

    /// Ambang idle di `TrackFocusSessionUseCase` hanya berarti kalau ada yang
    /// memeriksanya. `scenePhase` tidak cukup: app yang dibiarkan terbuka
    /// semalaman tetap `.active` dan tidak pernah memicu apa pun.
    private func startIdleWatch() {
        stopIdleWatch()
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.focus.handle(.periodicCheck) }
        }
    }

    private func stopIdleWatch() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
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

extension WellnessViewModel {
    /// Untuk `#Preview`. SENGAJA tidak dibungkus `#if DEBUG`: blok `#Preview`
    /// ikut dikompilasi pada konfigurasi Release, sehingga menyembunyikannya di
    /// balik DEBUG membuat build Debug hijau sementara archive Release patah —
    /// kegagalan yang baru muncul di langkah paling akhir sebelum submit.
    static var preview: WellnessViewModel {
        WellnessViewModel(store: WellnessStore(),
                          notifications: WellnessNotificationCenter.shared)
    }
}
