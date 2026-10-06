import Foundation
import Testing
@testable import Apl

/// `SharedCore` belum pernah dikompilasi untuk iOS (spec H §3.3). Test ini
/// ada supaya "terkompilasi dan berperilaku sama" punya bukti, bukan harapan.
@MainActor
struct SharedCoreOnPhoneTests {

    @Test func messagesKeepTheirDefaults() {
        let message = ChatMessage(role: .user, text: "hi")
        #expect(message.status == .complete)
        #expect(message.attachment == nil)
    }

    @Test func remindersPersistInTheGivenDefaults() {
        let defaults = UserDefaults(suiteName: "test.phone.core.\(UUID())")!
        let store = ReminderStore(defaults: defaults)
        store.add(Reminder(title: "Stretch", rule: .daily(hour: 9, minute: 0)))

        #expect(ReminderStore(defaults: defaults).reminders.map(\.title) == ["Stretch"])
    }
}
