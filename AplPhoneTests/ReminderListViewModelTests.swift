import Foundation
import Testing
@testable import Apl

@MainActor
struct ReminderListViewModelTests {

    private func makeViewModel(_ reminders: [Reminder] = [])
        -> (ReminderListViewModel, InMemoryReminderStore, SpyReminderScheduler) {
        let store = InMemoryReminderStore()
        for reminder in reminders { store.add(reminder) }
        let scheduler = SpyReminderScheduler()
        let viewModel = ReminderListViewModel(store: store, notifications: scheduler,
                                              now: { TestTime.now },
                                              calendar: TestTime.calendar, locale: TestTime.locale)
        return (viewModel, store, scheduler)
    }

    private func once(_ title: String, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Reminder {
        Reminder(title: title, rule: .once(TestTime.date(2026, 9, day, hour, minute)), createdAt: TestTime.now)
    }

    /// Format jam diambil dari ReminderPhrasing (en_US memakai spasi sempit sebelum AM/PM).
    private func clock(_ hour: Int, _ minute: Int) -> String {
        ReminderPhrasing.time(TestTime.date(2026, 9, 16, hour, minute),
                              calendar: TestTime.calendar, locale: TestTime.locale)
    }

    @Test func rowsAreOrderedByNextOccurrence() {
        let noon = Reminder(title: "Noon", rule: .daily(hour: 12, minute: 0), createdAt: TestTime.now)
        let (viewModel, _, _) = makeViewModel([once("Tomorrow", 17, 9), noon, once("Afternoon", 16, 15)])

        #expect(viewModel.rows(at: TestTime.now).map(\.reminder.title) == ["Noon", "Afternoon", "Tomorrow"])
    }

    @Test func passedOnceRemindersAreHidden() {
        let (viewModel, _, _) = makeViewModel([once("Passed", 16, 9)])

        #expect(viewModel.rows(at: TestTime.now).isEmpty)
    }

    @Test func upNextShowsTheNearestThree() {
        let reminders = (1...5).map { hour in
            Reminder(title: "R\(hour)", rule: .once(TestTime.now.addingTimeInterval(TimeInterval(hour * 3600))),
                     createdAt: TestTime.now)
        }
        let (viewModel, _, _) = makeViewModel(reminders.reversed())

        #expect(viewModel.upNext(at: TestTime.now).map(\.reminder.title) == ["R1", "R2", "R3"])
    }

    @Test func whenTextNamesTheDay() {
        func when(_ rule: Reminder.Rule) -> String? {
            let reminder = Reminder(title: "x", rule: rule, createdAt: TestTime.now)
            guard let next = reminder.nextOccurrence(after: TestTime.now, calendar: TestTime.calendar) else {
                return nil
            }
            return ReminderListViewModel.whenText(for: rule, next: next, now: TestTime.now,
                                                  calendar: TestTime.calendar, locale: TestTime.locale)
        }

        #expect(when(.once(TestTime.date(2026, 9, 16, 15, 0))) == "Today, \(clock(15, 0))")
        #expect(when(.once(TestTime.date(2026, 9, 17, 9, 0))) == "Tomorrow, \(clock(9, 0))")
        #expect(when(.daily(hour: 9, minute: 0)) == "Every day, \(clock(9, 0))")
        #expect(when(.once(TestTime.date(2026, 9, 19, 9, 0))) == "Sep 19, \(clock(9, 0))")
    }

    @Test func cancelRemovesTheReminderAndReschedules() async {
        let stretch = once("Stretch", 16, 15)
        let (viewModel, store, scheduler) = makeViewModel([stretch])

        await viewModel.cancel(stretch.id)

        #expect(store.reminders.isEmpty)
        #expect(scheduler.syncCallCount == 1)
        #expect(viewModel.lastCancelled == stretch)
    }

    /// Undo mengembalikan reminder yang SAMA — id tetap, jadi chip di chat
    /// kembali menunjuknya.
    @Test func undoBringsBackTheSameReminder() async {
        let stretch = once("Stretch", 16, 15)
        let (viewModel, store, scheduler) = makeViewModel([stretch])

        await viewModel.cancel(stretch.id)
        await viewModel.undo()

        #expect(store.reminders == [stretch])
        #expect(scheduler.syncCallCount == 2)
        #expect(scheduler.lastSynced == [stretch])
        #expect(viewModel.lastCancelled == nil)
    }

    @Test func updateSavesAndReschedules() async {
        var stretch = once("Stretch", 16, 15)
        let (viewModel, store, scheduler) = makeViewModel([stretch])

        stretch.title = "Stretch longer"
        stretch.rule = .daily(hour: 16, minute: 30)
        await viewModel.update(stretch)

        #expect(store.reminders == [stretch])
        #expect(scheduler.syncCallCount == 1)
    }

    @Test func chipFollowsTheReminderItBelongsTo() async {
        let upcoming = once("Stretch", 16, 15)
        let passed = once("Water", 16, 9)
        let (viewModel, _, _) = makeViewModel([upcoming, passed])

        #expect(viewModel.chipState(for: upcoming.id, at: TestTime.now)
                == .scheduled(title: "Stretch", whenText: "Today, \(clock(15, 0))"))
        #expect(viewModel.chipState(for: passed.id, at: TestTime.now) == .past)
        // Sudah dibuang ReminderStore karena lewat lebih dari sehari.
        #expect(viewModel.chipState(for: UUID(), at: TestTime.now) == .past)

        await viewModel.cancel(upcoming.id)

        #expect(viewModel.chipState(for: upcoming.id, at: TestTime.now) == .removed)
    }

    @Test func permissionIsReadFromTheScheduler() async {
        let (viewModel, _, scheduler) = makeViewModel()
        scheduler.notificationsAllowedAnswer = false

        await viewModel.refreshPermission()

        #expect(viewModel.notificationsAllowed == false)
    }
}
