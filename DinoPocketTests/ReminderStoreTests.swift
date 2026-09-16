import Foundation
import Testing
@testable import Apl

@MainActor
struct ReminderStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "test.reminders.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func reminder(_ title: String, _ rule: Reminder.Rule) -> Reminder {
        Reminder(title: title, rule: rule, createdAt: TestTime.now)
    }

    @Test func addedRemindersSurviveRelaunch() {
        let defaults = isolatedDefaults(#function)
        let stretch = reminder("Stretch", .daily(hour: 9, minute: 0))

        ReminderStore(defaults: defaults, now: TestTime.now).add(stretch)

        #expect(ReminderStore(defaults: defaults, now: TestTime.now).reminders == [stretch])
    }

    @Test func updateReplacesTheReminderWithTheSameID() {
        let defaults = isolatedDefaults(#function)
        let store = ReminderStore(defaults: defaults, now: TestTime.now)
        var call = reminder("Call mom", .once(TestTime.date(2026, 9, 16, 15, 0)))
        store.add(call)

        call.title = "Call dad"
        store.update(call)

        #expect(store.reminders == [call])
        #expect(ReminderStore(defaults: defaults, now: TestTime.now).reminders == [call])
    }

    @Test func removeDeletesOnlyThatReminder() {
        let defaults = isolatedDefaults(#function)
        let store = ReminderStore(defaults: defaults, now: TestTime.now)
        let keep = reminder("Stretch", .daily(hour: 9, minute: 0))
        let drop = reminder("Call mom", .once(TestTime.date(2026, 9, 16, 15, 0)))
        store.add(keep)
        store.add(drop)

        store.remove(id: drop.id)

        #expect(store.reminders == [keep])
        #expect(ReminderStore(defaults: defaults, now: TestTime.now).reminders == [keep])
    }

    /// Reminder sekali jalan yang lewat lebih dari sehari hanya mengotori
    /// daftar; yang baru lewat dipertahankan, dan pemangkasan ikut tersimpan.
    @Test func onceRemindersPastForMoreThanADayArePrunedOnLoad() {
        let defaults = isolatedDefaults(#function)
        let stale = reminder("Old", .once(TestTime.now.addingTimeInterval(-25 * 3600)))
        let recent = reminder("Recent", .once(TestTime.now.addingTimeInterval(-3600)))
        let daily = reminder("Daily", .daily(hour: 9, minute: 0))
        let earlier = TestTime.now.addingTimeInterval(-30 * 3600)
        let seeding = ReminderStore(defaults: defaults, now: earlier)
        for item in [stale, recent, daily] {
            seeding.add(item)
        }

        let reloaded = ReminderStore(defaults: defaults, now: TestTime.now)

        #expect(reloaded.reminders == [recent, daily])
        // Dimuat lagi dengan "sekarang" yang lebih awal: stale tetap hilang,
        // artinya hasil pemangkasan benar-benar ditulis ke disk.
        #expect(ReminderStore(defaults: defaults, now: earlier).reminders == [recent, daily])
    }

    @Test func eraseClearsMemoryAndDisk() {
        let defaults = isolatedDefaults(#function)
        let store = ReminderStore(defaults: defaults, now: TestTime.now)
        store.add(reminder("Stretch", .daily(hour: 9, minute: 0)))

        store.eraseAllStoredData()

        #expect(store.reminders.isEmpty)
        #expect(defaults.object(forKey: ReminderStore.storageKey) == nil)
    }
}
