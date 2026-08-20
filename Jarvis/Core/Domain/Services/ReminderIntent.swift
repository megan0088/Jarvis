import Foundation

enum ReminderIntent {
    /// Parse an English "remind me…" request into a custom ReminderSchedule, or nil.
    /// Requires: a reminder keyword ("remind"/"reminder") + a recognizable kind + a clock time.
    static func parse(_ text: String) -> PetStore.ReminderSchedule? {
        let t = text.lowercased()
        guard t.contains("remind") else { return nil }

        let kind: PetStore.ReminderKind
        if t.contains("water") || t.contains("drink") || t.contains("hydrat") { kind = .water }
        else if t.contains("stretch") || t.contains("move") { kind = .stretch }
        else if t.contains("meal") || t.contains("eat") || t.contains("lunch") || t.contains("breakfast") || t.contains("dinner") || t.contains("food") { kind = .meal }
        else { return nil }

        guard let (hour, minute) = clock(in: t) else { return nil }

        let (title, body): (String, String) = {
            switch kind {
            case .water: ("Drink water", "Take a short break and drink a glass of water.")
            case .stretch: ("Stretch break", "Stand up and stretch for a couple of minutes.")
            case .meal: ("Meal time", "Time to eat — don't skip it.")
            }
        }()
        return PetStore.ReminderSchedule(
            id: "custom.\(kind.rawValue).\(hour).\(minute)",
            kind: kind, hour: hour, minute: minute, title: title, body: body
        )
    }

    /// Extract a clock time. Accepts "3pm", "3:30 pm", "9am", "15:00", "09:30".
    /// A bare number with neither am/pm nor a colon is NOT treated as a time (avoids false positives).
    private static func clock(in t: String) -> (Int, Int)? {
        let pattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = t as NSString
        for m in re.matches(in: t, range: NSRange(location: 0, length: ns.length)) {
            let hasColon = m.range(at: 2).location != NSNotFound
            let hasMeridiem = m.range(at: 3).location != NSNotFound
            guard hasColon || hasMeridiem else { continue }   // require a real time token
            var hour = Int(ns.substring(with: m.range(at: 1))) ?? -1
            let minute = hasColon ? (Int(ns.substring(with: m.range(at: 2))) ?? 0) : 0
            if hasMeridiem {
                let mer = ns.substring(with: m.range(at: 3))
                if mer == "pm" && hour < 12 { hour += 12 }
                if mer == "am" && hour == 12 { hour = 0 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
            return (hour, minute)
        }
        return nil
    }
}
