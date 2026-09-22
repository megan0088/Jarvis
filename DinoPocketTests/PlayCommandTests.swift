import Testing
@testable import Apl

struct PlayCommandTests {

    @Test func recognisesTheUsualWays() {
        for text in ["main suit", "Main Suit", "ayo suit", "suit yuk",
                     "rock paper scissors", "let's play rock paper scissors",
                     "play rps"] {
            #expect(PlayCommand.matches(text), "seharusnya dikenali: \(text)")
        }
    }

    /// Yang paling berbahaya bukan yang tidak dikenali, melainkan yang
    /// dikenali padahal bukan — reminder yang berubah jadi permainan.
    @Test func doesNotHijackReminders() {
        for text in ["remind me to play football at 3pm",
                     "remind me to buy rock salt",
                     "remind me to play with the kids"] {
            #expect(PlayCommand.matches(text) == false, "seharusnya TIDAK dikenali: \(text)")
        }
    }

    @Test func doesNotFireOnOrdinaryTalk() {
        for text in ["what is a good way to end the workday?",
                     "explain this suite of tests",
                     "how do I play audio in swift?"] {
            #expect(PlayCommand.matches(text) == false, "seharusnya TIDAK dikenali: \(text)")
        }
    }
}
