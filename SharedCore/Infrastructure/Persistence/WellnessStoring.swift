//
//  WellnessStoring.swift
//  SharedCore
//
//  Kontrak penyimpanan wellness yang dipakai lapisan UseCase.
//
//  Sengaja dibentuk dari apa yang benar-benar dipanggil, bukan dari seluruh
//  permukaan `WellnessStore`. Survei kode menunjukkan setiap kartu dashboard
//  hanya MEMBACA — nol mutasi — jadi mutasi di bawah hanyalah yang dipakai
//  UseCase dan siklus hidup app.
//

import Foundation

@MainActor
protocol WellnessStoring: AnyObject {

    // MARK: Baca

    var goalProgress: WellnessGoalProgress { get }
    var energy: Int { get }
    var statusMessage: String { get }
    var todayScreenTime: TimeInterval { get }
    var screenTimeHistory: [ScreenTimeEntry] { get }
    var recentScreenTimeHistory: [ScreenTimeEntry] { get }
    var recentReminderHistory: [ReminderEvent] { get }
    var reminderSchedules: [ReminderSchedule] { get }

    // MARK: Tulis

    func addCustomSchedule(_ schedule: ReminderSchedule)
    /// Tanggal diambil sebagai parameter, bukan `Date()` di dalam, supaya
    /// akuntansi sesi bisa diuji tanpa menunggu waktu nyata berjalan.
    func resumeScreenTime(at date: Date)
    func pauseScreenTime(at date: Date)
    func tick()
    func prepareWellness() async
    func syncReminderHistory() async
}

extension WellnessStoring {
    func resumeScreenTime() { resumeScreenTime(at: .now) }
    func pauseScreenTime() { pauseScreenTime(at: .now) }
}

extension WellnessStore: WellnessStoring {}
