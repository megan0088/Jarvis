//
//  Nudge.swift
//  Apl
//
//  Apa yang hendak dikatakan Apl tanpa diminta (spec C2 §3).
//

import Foundation

struct Nudge: Equatable {

    enum Kind: Equatable {
        /// Reminder yang sebentar lagi berbunyi, beserta waktu kemunculannya.
        case reminderSoon(Reminder.ID, at: Date)
        case machine(SystemMood)
    }

    let kind: Kind
    let text: String

    /// Kunci kuota: satu kejadian hanya boleh disapa sekali.
    ///
    /// Waktu kemunculan ikut masuk kunci — tanpa itu, reminder harian hanya
    /// akan disapa sekali seumur hidupnya.
    var key: String {
        switch kind {
        case .reminderSoon(let id, let at):
            "reminder.\(id.uuidString).\(Int(at.timeIntervalSince1970))"
        case .machine(let mood):
            "machine.\(mood.rawValue)"
        }
    }

    var isMachine: Bool {
        if case .machine = kind { return true }
        return false
    }

    /// Waktu kemunculan untuk balon reminder; dipakai memangkas catatan lama.
    var occurrence: Date? {
        if case .reminderSoon(_, let at) = kind { return at }
        return nil
    }
}
