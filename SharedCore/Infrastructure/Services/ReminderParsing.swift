//
//  ReminderParsing.swift
//  SharedCore
//

import Foundation

protocol ReminderParsing: Sendable {
    /// Mengembalikan nil bila teks bukan permintaan pengingat.
    func parse(_ text: String) -> ReminderSchedule?
}

/// Parser deterministik berbasis kata kunci.
///
/// SENGAJA bukan tool call ke model. Foundation Models menyediakan tool calling,
/// tetapi parser ini punya dua sifat yang tidak dimiliki model: hasilnya sama
/// untuk input yang sama, dan ia tetap bekerja saat Apple Intelligence mati.
/// Pengingat adalah janji ke pengguna; ia tidak boleh ikut padam bersama AI.
struct ReminderIntentParser: ReminderParsing {
    func parse(_ text: String) -> ReminderSchedule? {
        ReminderIntent.parse(text)
    }
}
