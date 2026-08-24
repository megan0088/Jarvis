//
//  CreateReminderFromTextUseCase.swift
//  SharedCore
//
//  Bahasa alami → jadwal tersimpan → notifikasi terdaftar.
//
//  Sebelumnya ketiga langkah ini tersebar: ChatStore memanggil parser, meneruskan
//  hasilnya lewat closure `onCreateReminder`, dan penjadwalan notifikasi terjadi
//  di tempat lain lagi. Closure itu membuat siapa yang bertanggung jawab
//  menjadwalkan bergantung pada siapa yang kebetulan memasangnya.
//

import Foundation

@MainActor
struct CreateReminderFromTextUseCase {

    private let parser: ReminderParsing
    private let store: any WellnessStoring
    private let notifications: NotificationScheduling

    init(parser: ReminderParsing,
         store: any WellnessStoring,
         notifications: NotificationScheduling) {
        self.parser = parser
        self.store = store
        self.notifications = notifications
    }

    struct Output: Equatable {
        let schedule: ReminderSchedule
        /// Kalimat konfirmasi siap tampil, dibangun dari jadwal yang BENAR-BENAR
        /// tersimpan — bukan dari teks permintaan user.
        var confirmation: String {
            "Done — I set a reminder: \(schedule.title) at \(schedule.timeLabel)."
        }
    }

    /// Mengembalikan nil bila teks bukan permintaan pengingat; pemanggil lalu
    /// meneruskannya ke otak AI seperti pesan biasa.
    func execute(text: String) async -> Output? {
        guard let schedule = parser.parse(text) else { return nil }

        store.addCustomSchedule(schedule)
        await notifications.schedule(store.reminderSchedules)

        return Output(schedule: schedule)
    }
}
