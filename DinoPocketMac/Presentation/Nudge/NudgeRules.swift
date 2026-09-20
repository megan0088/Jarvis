//
//  NudgeRules.swift
//  Apl
//
//  Seluruh keputusan C2, dalam satu fungsi murni (spec C2 §4).
//
//  Tidak menyentuh jam sistem, penyimpanan, maupun AppKit: semuanya masuk lewat
//  parameter. Itu sebabnya kuota empat jam bisa dibuktikan dalam milidetik
//  alih-alih menunggu empat jam.
//

import Foundation

enum NudgeRules {

    static let reminderLead: TimeInterval = 5 * 60
    static let moodMustPersist: TimeInterval = 10 * 60
    static let machineCooldown: TimeInterval = 4 * 3600
    static let machinePerDay = 2
    static let ignoredBackoff: TimeInterval = 3600

    static func next(now: Date,
                     reminders: [Reminder],
                     mood: SystemMood,
                     moodSince: Date?,
                     history: NudgeHistory.Snapshot,
                     signals: QuietSignals,
                     calendar: Calendar = .current) -> Nudge? {
        guard signals.allowsSpeaking else { return nil }
        // Reminder didahulukan: ia punya waktu yang tidak bisa ditunda, dan ia
        // diminta pengguna. Keadaan mesin bisa menunggu detak berikutnya.
        return reminderNudge(now: now, reminders: reminders, history: history, calendar: calendar)
            ?? machineNudge(now: now, mood: mood, moodSince: moodSince,
                            history: history, calendar: calendar)
    }

    private static func reminderNudge(now: Date, reminders: [Reminder],
                                      history: NudgeHistory.Snapshot,
                                      calendar: Calendar) -> Nudge? {
        let upcoming = reminders
            .compactMap { reminder -> (Reminder, Date)? in
                guard let next = reminder.nextOccurrence(after: now, calendar: calendar) else { return nil }
                let delta = next.timeIntervalSince(now)
                guard delta > 0, delta <= reminderLead else { return nil }
                return (reminder, next)
            }
            .sorted { $0.1 < $1.1 }

        for (reminder, at) in upcoming {
            let nudge = Nudge(kind: .reminderSoon(reminder.id, at: at),
                              text: NudgeText.reminderSoon(title: reminder.title, at: at))
            if history.shownReminderKeys[nudge.key] == nil { return nudge }
        }
        return nil
    }

    private static func machineNudge(now: Date, mood: SystemMood, moodSince: Date?,
                                     history: NudgeHistory.Snapshot,
                                     calendar: Calendar) -> Nudge? {
        guard let text = NudgeText.machine(mood) else { return nil }
        // Lonjakan sesaat bukan kabar; yang bertahan barulah kabar.
        guard let moodSince, now.timeIntervalSince(moodSince) >= moodMustPersist else { return nil }

        if let ignored = history.lastIgnoredAt, now.timeIntervalSince(ignored) < ignoredBackoff {
            return nil
        }
        if let last = history.lastMachineAt, now.timeIntervalSince(last) < machineCooldown {
            return nil
        }
        let today = calendar.startOfDay(for: now)
        let countToday = history.machineDay == today ? history.machineCountToday : 0
        guard countToday < machinePerDay else { return nil }

        return Nudge(kind: .machine(mood), text: text)
    }
}
