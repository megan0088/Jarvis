import Foundation
import Testing
@testable import Apl

@MainActor
struct PhoneDependenciesTests {

    private func make(_ scheduler: SpyReminderScheduler = SpyReminderScheduler()) -> PhoneDependencies {
        PhoneDependencies(brain: nil,
                          defaults: UserDefaults(suiteName: "test.phone.deps.\(UUID())")!,
                          scheduler: scheduler)
    }

    /// Chat dan daftar reminder harus membaca store yang SAMA; dua instance
    /// berarti reminder dari chat tidak pernah muncul di sheet.
    @Test func chatCreatesRemindersTheListCanSee() async {
        let deps = make()

        await deps.chat.send("remind me to stretch in 45 minutes")

        #expect(deps.reminderStore.reminders.count == 1)
        #expect(deps.reminders.rows(at: .now).count == 1)
        #expect(deps.chat.messages.last?.attachment != nil)
    }

    /// Erase All Data di tengah percakapan (Review Focus #5): setiap store
    /// kosong, notifikasi dibatalkan, dan onboarding kembali.
    @Test func eraseAllDataEmptiesEveryStore() async {
        let scheduler = SpyReminderScheduler()
        let deps = make(scheduler)
        deps.profile.setNickname("Ega")
        deps.profile.completeOnboarding()
        await deps.chat.send("remind me to stretch in 45 minutes")
        await deps.chat.send("hello")

        await deps.eraseAllData()

        #expect(deps.profile.nickname == nil)
        #expect(deps.profile.hasCompletedOnboarding == false)
        #expect(deps.reminderStore.reminders.isEmpty)
        #expect(deps.reminders.rows(at: .now).isEmpty)
        #expect(deps.chat.messages.isEmpty)
        #expect(deps.chat.isStreaming == false)
        #expect(deps.chat.noticeMessage == nil)
        #expect(scheduler.cancelAllCallCount == 1)
    }

    /// Penyimpanan yang lupa didaftarkan tidak ikut terhapus — celah yang
    /// sudah tiga kali muncul di Mac.
    @Test func transcriptsAreErasedToo() async {
        final class Flag: LocallyErasable { var erased = false; func eraseAllStoredData() { erased = true } }
        let flag = Flag()
        let deps = PhoneDependencies(brain: nil,
                                     defaults: UserDefaults(suiteName: "test.phone.deps.\(UUID())")!,
                                     scheduler: SpyReminderScheduler(), transcripts: flag)

        await deps.eraseAllData()

        #expect(flag.erased)
    }

    /// Reminder yang dibuat sebelum izin diberikan baru dijadwalkan begitu
    /// izinnya ada (spec H §6).
    @Test func grantingNotificationsSchedulesWhatAlreadyExists() async {
        let scheduler = SpyReminderScheduler()
        let deps = make(scheduler)
        deps.reminderStore.add(Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0)))
        let before = scheduler.syncCallCount

        let granted = await deps.requestNotifications()

        #expect(granted)
        #expect(scheduler.syncCallCount == before + 1)
        #expect(scheduler.lastSynced.map(\.title) == ["Stretch"])
    }
}
