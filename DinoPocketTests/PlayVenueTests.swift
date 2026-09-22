import Testing
@testable import Apl

struct PlayVenueTests {
    @Test func balloonWhenTheRobotIsThere() {
        #expect(PlayVenue.decide(buddyIsRunning: true) == .balloon)
    }

    /// Permainan tidak menuntut robot; robot yang membuatnya menyenangkan.
    @Test func chatWhenItIsNot() {
        #expect(PlayVenue.decide(buddyIsRunning: false) == .chat)
    }
}
