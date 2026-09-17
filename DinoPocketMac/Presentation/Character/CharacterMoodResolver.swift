//
//  CharacterMoodResolver.swift
//  Apl
//
//  Memilih ekspresi robot dari keadaan chat (spec B §6).
//
//  Fungsi murni, tanpa timer: pemanggil menjadwalkan evaluasi ulang pada
//  `Resolution.reevaluateAt`. Dengan begitu setiap cabang dan batas waktunya
//  bisa dites dengan `now` yang disuntikkan.
//

import Foundation

struct CharacterMoodInput: Equatable {
    var intelligenceAvailable: Bool
    var isStreaming: Bool
    var lastEvent: ChatEvent?
    /// Kapan jendela terakhir menjadi aktif.
    var windowActivatedAt: Date?
}

enum CharacterMoodResolver {

    /// Lama sebuah momen — gagal, reminder dibuat, jendela dibuka — memengaruhi wajah.
    static let momentDuration: TimeInterval = 3

    struct Resolution: Equatable {
        let behavior: CharacterBehavior
        /// Kapan hasil ini berubah tanpa ada input yang berubah; nil bila tidak akan.
        let reevaluateAt: Date?
    }

    /// Dievaluasi berurutan; cabang pertama yang cocok menang.
    static func resolve(_ input: CharacterMoodInput, now: Date) -> Resolution {
        if !input.intelligenceAvailable {
            return Resolution(behavior: .sleepy, reevaluateAt: nil)
        }
        if let event = input.lastEvent, event.kind == .failed,
           let end = momentEnd(startedAt: event.at, now: now) {
            return Resolution(behavior: .sleepy, reevaluateAt: end)
        }
        if input.isStreaming {
            return Resolution(behavior: .thinking, reevaluateAt: nil)
        }
        if let event = input.lastEvent, case .reminderCreated = event.kind,
           let end = momentEnd(startedAt: event.at, now: now) {
            return Resolution(behavior: .celebrate, reevaluateAt: end)
        }
        if let activated = input.windowActivatedAt,
           let end = momentEnd(startedAt: activated, now: now) {
            return Resolution(behavior: .greet, reevaluateAt: end)
        }
        return Resolution(behavior: .idle, reevaluateAt: nil)
    }

    /// Akhir momen bila `now` masih berada di dalamnya.
    ///
    /// Setengah terbuka, [mulai, mulai + 3): tepat di detik ke-3 momen sudah
    /// selesai. Dengan batas inklusif, evaluasi ulang yang dijadwalkan tepat
    /// di detik itu menghasilkan jadwal yang sama, dan wajah tidak pernah
    /// kembali. Momen "di masa depan" (jam mundur) diabaikan.
    private static func momentEnd(startedAt start: Date, now: Date) -> Date? {
        let elapsed = now.timeIntervalSince(start)
        guard elapsed >= 0, elapsed < momentDuration else { return nil }
        return start.addingTimeInterval(momentDuration)
    }
}
