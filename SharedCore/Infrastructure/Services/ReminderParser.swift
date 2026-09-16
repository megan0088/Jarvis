//
//  ReminderParser.swift
//  SharedCore
//
//  Mengurai permintaan reminder berbahasa Inggris, tanpa AI.
//
//  SENGAJA bukan tool call ke model. Parser ini punya dua sifat yang tidak
//  dimiliki model: hasilnya sama untuk input yang sama, dan ia tetap bekerja
//  saat Apple Intelligence mati. Reminder adalah janji ke pengguna; ia tidak
//  boleh ikut padam bersama AI.
//
//  Tata bahasa (spec A §4):
//    pemicu : "remind me" · "set a reminder"
//    waktu  : at 3pm · at 3:30 pm · at 15:00 · today at … · tomorrow at …
//             in 20 minutes · in an hour · every day at … · daily at …
//             at … every day
//    judul  : frasa setelah "to"/"about", tanpa bagian waktu
//
//  Angka polos tanpa am/pm dan tanpa titik dua hanya dianggap jam tepat
//  setelah "at", dan dibaca sebagai jam 24 ("at 9" = 09.00). Di luar itu
//  angka polos bukan waktu — "buy 2 apples" tidak boleh jadi reminder jam 2.
//

import Foundation

enum ReminderParseResult: Equatable, Sendable {
    case reminder(title: String, rule: Reminder.Rule)
    /// Ada niat reminder, tetapi waktunya tidak terbaca.
    case missingTime(title: String?)
    case notAReminder
}

enum ReminderParser {

    /// Judul bila pengguna tidak menyebut apa yang diingatkan.
    static let defaultTitle = "Reminder"

    static func parse(_ text: String, now: Date, calendar: Calendar = .current) -> ReminderParseResult {
        let patterns = Patterns()
        guard let trigger = patterns.trigger.firstMatch(in: text, range: fullRange(of: text)) else {
            return .notAReminder
        }

        let time = findTime(in: text, now: now, calendar: calendar, patterns: patterns)
        let title = extractTitle(from: text, trigger: trigger.range, time: time?.range, patterns: patterns)

        guard let time else { return .missingTime(title: title) }
        return .reminder(title: title ?? defaultTitle, rule: time.rule)
    }

    /// Untuk giliran lanjutan setelah Apl menanyakan jam: nil kecuali seluruh
    /// pesan hanyalah ungkapan waktu ("5pm", "at 5pm", "in 10 minutes").
    static func parseTimeOnly(_ text: String, now: Date, calendar: Calendar = .current) -> Reminder.Rule? {
        guard let time = findTime(in: text, now: now, calendar: calendar, patterns: Patterns()) else {
            return nil
        }
        let rest = NSMutableString(string: text)
        rest.replaceCharacters(in: time.range, with: "")
        let leftover = (rest as String).trimmingCharacters(in: edgeTrim).lowercased()
        return leftover.isEmpty || leftover == "at" ? time.rule : nil
    }

    // MARK: - Pola

    /// Dibangun per panggilan, bukan `static let`: `NSRegularExpression` tidak
    /// dijamin `Sendable`, dan properti statis bertipe non-Sendable ditolak
    /// Swift 6 — kesalahan yang persis pernah menggagalkan build proyek ini.
    /// Pesan chat jarang, jadi biayanya tidak terasa.
    private struct Patterns {
        /// Grup 1 jam, 2 menit, 3 am/pm — sama di setiap pola jam.
        static let clock = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#

        let trigger = Patterns.make(#"\b(?:remind\s+me|set\s+(?:a\s+)?reminder)\b"#)
        let dailyLeading = Patterns.make(#"\b(?:every\s?day|daily)\s+at\s+"# + Patterns.clock)
        let dailyTrailing = Patterns.make(#"\bat\s+"# + Patterns.clock + #"\s+(?:every\s?day|daily)\b"#)
        let tomorrow = Patterns.make(#"\btomorrow\s+at\s+"# + Patterns.clock)
        let relative = Patterns.make(#"\bin\s+(\d{1,3}|an?|one)\s+(minutes?|mins?|hours?|hrs?)\b"#)
        let todayAt = Patterns.make(#"\btoday\s+at\s+"# + Patterns.clock)
        let at = Patterns.make(#"\bat\s+"# + Patterns.clock)
        let bare = Patterns.make(#"\b"# + Patterns.clock)
        let titleLead = Patterns.make(#"\b(?:to|about)\s+"#)

        private static func make(_ pattern: String) -> NSRegularExpression {
            // Pola literal yang dijaga test; kegagalan di sini adalah bug pengembang.
            try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }

    // MARK: - Waktu

    private struct TimeMatch {
        let range: NSRange
        let rule: Reminder.Rule
    }

    private struct Clock {
        let hour: Int
        let minute: Int
    }

    /// Urutan pola adalah prioritas: yang lebih spesifik ("every day at 9")
    /// harus menang atas yang lebih umum ("at 9") pada teks yang sama.
    private static func findTime(in text: String, now: Date, calendar: Calendar,
                                 patterns: Patterns) -> TimeMatch? {
        let range = fullRange(of: text)

        for pattern in [patterns.dailyLeading, patterns.dailyTrailing] {
            for match in pattern.matches(in: text, range: range) {
                if let clock = clock(from: match, in: text) {
                    return TimeMatch(range: match.range, rule: .daily(hour: clock.hour, minute: clock.minute))
                }
            }
        }

        for match in patterns.tomorrow.matches(in: text, range: range) {
            if let clock = clock(from: match, in: text),
               let date = tomorrow(at: clock, now: now, calendar: calendar) {
                return TimeMatch(range: match.range, rule: .once(date))
            }
        }

        for match in patterns.relative.matches(in: text, range: range) {
            if let seconds = seconds(from: match, in: text) {
                return TimeMatch(range: match.range, rule: .once(now.addingTimeInterval(seconds)))
            }
        }

        let clockPatterns: [(NSRegularExpression, requireMinuteOrMeridiem: Bool)] = [
            (patterns.todayAt, false),
            (patterns.at, false),
            (patterns.bare, true),
        ]
        for (pattern, strict) in clockPatterns {
            for match in pattern.matches(in: text, range: range) {
                if let clock = clock(from: match, in: text, requireMinuteOrMeridiem: strict),
                   let date = upcoming(clock, now: now, calendar: calendar) {
                    return TimeMatch(range: match.range, rule: .once(date))
                }
            }
        }

        return nil
    }

    private static func clock(from match: NSTextCheckingResult, in text: String,
                              requireMinuteOrMeridiem: Bool = false) -> Clock? {
        let ns = text as NSString
        let hourRange = match.range(at: 1)
        let minuteRange = match.range(at: 2)
        let meridiemRange = match.range(at: 3)
        guard hourRange.location != NSNotFound,
              var hour = Int(ns.substring(with: hourRange)) else { return nil }

        let hasMinute = minuteRange.location != NSNotFound
        let hasMeridiem = meridiemRange.location != NSNotFound
        if requireMinuteOrMeridiem && !hasMinute && !hasMeridiem { return nil }

        let minute = hasMinute ? (Int(ns.substring(with: minuteRange)) ?? -1) : 0
        if hasMeridiem {
            guard (1...12).contains(hour) else { return nil }
            let meridiem = ns.substring(with: meridiemRange).lowercased()
            if meridiem == "pm", hour < 12 { hour += 12 }
            if meridiem == "am", hour == 12 { hour = 0 }
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return Clock(hour: hour, minute: minute)
    }

    private static func seconds(from match: NSTextCheckingResult, in text: String) -> TimeInterval? {
        let ns = text as NSString
        let amountText = ns.substring(with: match.range(at: 1)).lowercased()
        let amount: Int
        switch amountText {
        case "a", "an", "one":
            amount = 1
        default:
            guard let parsed = Int(amountText), parsed > 0 else { return nil }
            amount = parsed
        }
        let unit = ns.substring(with: match.range(at: 2)).lowercased()
        return TimeInterval(amount) * (unit.hasPrefix("h") ? 3600 : 60)
    }

    /// Hari ini bila jamnya belum lewat, selain itu besok — termasuk untuk
    /// "today at …": jam yang sudah lewat tidak mungkin diingatkan hari ini.
    private static func upcoming(_ clock: Clock, now: Date, calendar: Calendar) -> Date? {
        guard let today = calendar.date(bySettingHour: clock.hour, minute: clock.minute,
                                        second: 0, of: now) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }

    private static func tomorrow(at clock: Clock, now: Date, calendar: Calendar) -> Date? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        return calendar.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: nextDay)
    }

    // MARK: - Judul

    /// Judul dicari SETELAH pemicu: pada "I want you to remind me to call mom",
    /// "to" pertama milik kalimat pembuka, bukan awal judul.
    private static func extractTitle(from text: String, trigger: NSRange, time: NSRange?,
                                     patterns: Patterns) -> String? {
        let remaining = NSMutableString(string: text)
        var searchStart = trigger.location
        let ranges = [trigger] + (time.map { [$0] } ?? [])
        // Dari belakang ke depan, supaya lokasi rentang yang lebih awal tetap valid.
        // Setiap rentang diganti SATU spasi, jadi rentang yang terletak sebelum
        // pemicu menggeser posisi pemicu sebanyak panjangnya dikurangi satu.
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            remaining.replaceCharacters(in: range, with: " ")
            if range.location < trigger.location {
                searchStart -= range.length - 1
            }
        }
        let stripped = remaining as String
        let length = (stripped as NSString).length
        let searchRange = NSRange(location: searchStart, length: length - searchStart)
        guard let lead = patterns.titleLead.firstMatch(in: stripped, range: searchRange) else {
            return nil
        }
        let afterLead = (stripped as NSString).substring(from: NSMaxRange(lead.range))
        let words = afterLead.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let title = words.trimmingCharacters(in: edgeTrim)
        guard let first = title.first else { return nil }
        return first.uppercased() + String(title.dropFirst())
    }

    private static let edgeTrim = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

    private static func fullRange(of text: String) -> NSRange {
        NSRange(location: 0, length: (text as NSString).length)
    }
}
