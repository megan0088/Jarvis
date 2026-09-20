//
//  NudgeText.swift
//  Apl
//
//  Kalimat balon (spec C2 §5). Pasti, bukan acak — sapaan acak dihapus di C1
//  justru karena tidak punya aturan.
//

import Foundation

enum NudgeText {

    static func reminderSoon(title: String, at date: Date,
                             locale: Locale = .current,
                             timeZone: TimeZone = .current) -> String {
        let format = Date.FormatStyle(date: .omitted, time: .shortened,
                                      locale: locale, timeZone: timeZone)
        return "\(title) · \(date.formatted(format))"
    }

    /// `nil` berarti tidak ada yang perlu dikatakan tentang keadaan mesin.
    static func machine(_ mood: SystemMood) -> String? {
        switch mood {
        case .hot: "This Mac is running hot."
        case .lowBattery: "Battery is getting low."
        case .normal, .busy: nil
        }
    }
}
