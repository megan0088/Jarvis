//
//  RemindersWiringTests.swift
//  AplTests
//
//  Pengingat adalah fitur inti produk, tetapi sampai wave ini satu-satunya jalan
//  menyalakannya ada di `ContentView.swift` yang DIKECUALIKAN dari target macOS.
//  Akibatnya `remindersEnabled` selamanya false, `scheduleReminders()` selalu
//  return lebih awal, dan nol notifikasi pernah terdaftar — tanpa satu pun error.
//  Test di berkas ini mengikat alur itu ke lapisan yang benar-benar ikut build.
//

import Foundation
import Testing
@testable import Apl

@MainActor
private func freshStore() -> WellnessStore {
    let store = WellnessStore()
    store.goalProgress = WellnessGoalProgress(date: .now, water: 0, stretch: 0, meal: 0)
    store.snoozedReminders = []
    store.reminderHistory = []
    store.seenReminderEventIDs = []
    return store
}

@Suite("Pengingat terhubung ke dashboard")
struct RemindersWiringTests {

    @MainActor
    @Test func completingScheduledReminderAdvancesTodaysGoal() {
        let store = freshStore()
        let vm = WellnessViewModel(store: store, notifications: FakeNotificationScheduler())
        let water = store.reminderSchedules.first { $0.kind == .water }!

        vm.complete(water)

        #expect(vm.goalProgress.water == 1)
    }

    @MainActor
    @Test func completedReminderIsMarkedDoneForToday() {
        let store = freshStore()
        let vm = WellnessViewModel(store: store, notifications: FakeNotificationScheduler())
        let stretch = store.reminderSchedules.first { $0.kind == .stretch }!

        #expect(vm.isCompletedToday(stretch) == false)
        vm.complete(stretch)
        #expect(vm.isCompletedToday(stretch))
    }

    @MainActor
    @Test func snoozingReminderDefersItWithoutTouchingGoals() {
        let store = freshStore()
        let vm = WellnessViewModel(store: store, notifications: FakeNotificationScheduler())
        let meal = store.reminderSchedules.first { $0.kind == .meal }!

        vm.snooze(meal)

        #expect(store.snoozedReminders.count == 1)
        #expect(store.snoozedReminders.first?.kind == .meal)
        #expect(vm.goalProgress.meal == 0)
    }

    @MainActor
    @Test func enablingRemindersRequestsAuthorizationThenSchedulesEveryReminder() async {
        let store = freshStore()
        let notifications = FakeNotificationScheduler()
        let vm = WellnessViewModel(store: store, notifications: notifications)

        await vm.setRemindersEnabled(true)

        #expect(vm.remindersEnabled)
        #expect(notifications.scheduleCallCount == 1)
        #expect(notifications.lastScheduled.count == store.reminderSchedules.count)
    }

    @MainActor
    @Test func deniedAuthorizationLeavesRemindersOffAndSchedulesNothing() async {
        let store = freshStore()
        let notifications = FakeNotificationScheduler()
        notifications.authorizationAnswer = false
        let vm = WellnessViewModel(store: store, notifications: notifications)

        await vm.setRemindersEnabled(true)

        #expect(vm.remindersEnabled == false)
        #expect(notifications.scheduleCallCount == 0)
        #expect(vm.authorizationWasDenied)
    }

    @MainActor
    @Test func turningRemindersOffClearsWhatWasScheduled() async {
        let store = freshStore()
        let notifications = FakeNotificationScheduler()
        let vm = WellnessViewModel(store: store, notifications: notifications)
        await vm.setRemindersEnabled(true)

        await vm.setRemindersEnabled(false)

        #expect(vm.remindersEnabled == false)
        #expect(notifications.clearCallCount == 1)
    }

    @MainActor
    @Test func enabledRemindersSurviveRelaunch() async {
        let store = freshStore()
        let vm = WellnessViewModel(store: store, notifications: FakeNotificationScheduler())
        await vm.setRemindersEnabled(true)

        #expect(WellnessStore().remindersEnabled)
        await vm.setRemindersEnabled(false)
        #expect(WellnessStore().remindersEnabled == false)
    }
}

@Suite("Prompt ringkasan")
struct SummaryPromptTests {

    @MainActor
    @Test func oneGlassIsSingularNotOneGlasses() {
        let store = freshStore()
        store.goalProgress = WellnessGoalProgress(date: .now, water: 1, stretch: 1, meal: 1)
        let vm = WellnessViewModel(store: store, notifications: FakeNotificationScheduler())

        let prompt = vm.summaryPrompt

        #expect(prompt.contains("1 glass of water"))
        #expect(prompt.contains("1 stretch break,"))
        #expect(prompt.contains("1 meal."))
    }

    @MainActor
    @Test func pluralStaysPlural() {
        let store = freshStore()
        store.goalProgress = WellnessGoalProgress(date: .now, water: 2, stretch: 0, meal: 3)
        let vm = WellnessViewModel(store: store, notifications: FakeNotificationScheduler())

        let prompt = vm.summaryPrompt

        #expect(prompt.contains("2 glasses of water"))
        #expect(prompt.contains("0 stretch breaks,"))
        #expect(prompt.contains("3 meals."))
    }
}

@Suite("Ketersediaan otak untuk layar chat")
struct ChatAvailabilityTests {

    @MainActor
    @Test func chatIsUsableWhenAppleIsDownButAnotherBrainIsReady() async {
        let chat = ChatStore(brains: [
            .apple: StubBrain(kind: .apple, availability: .unavailable("Enable Apple Intelligence in System Settings.")),
            .ollama: StubBrain(kind: .ollama, availability: .ready)
        ])

        #expect(await chat.bestAvailability() == .ready)
    }

    @MainActor
    @Test func chatReportsAppleReasonWhenNoBrainIsReady() async {
        let chat = ChatStore(brains: [
            .apple: StubBrain(kind: .apple, availability: .unavailable("Enable Apple Intelligence in System Settings.")),
            .ollama: StubBrain(kind: .ollama, availability: .needsSetup("Ollama isn't running."))
        ])

        #expect(await chat.bestAvailability() == .unavailable("Enable Apple Intelligence in System Settings."))
    }
}

private struct StubBrain: Brain {
    let kind: BrainKind
    let stubbed: BrainAvailability

    init(kind: BrainKind, availability: BrainAvailability) {
        self.kind = kind
        self.stubbed = availability
    }

    func availability() async -> BrainAvailability { stubbed }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

@Suite("Sapaan dashboard")
struct GreetingNameTests {

    @Test func firstNameIsJustTheFirstWordOfTheAppleIDName() {
        #expect(AccountStore.firstName(from: "Muhamad Ega Nugraha") == "Muhamad")
    }

    @Test func firstNameIsNilWhenAppleIDNameWasHidden() {
        #expect(AccountStore.firstName(from: nil) == nil)
    }

    @Test func blankNameGreetsWithoutOne() {
        #expect(AccountStore.firstName(from: "   ") == nil)
    }
}
