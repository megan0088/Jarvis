import Testing
@testable import Apl

@MainActor
struct PlayExpressionTests {

    /// Aset `RobotSad` sudah ada dan dipakai `.sleepy`. Yang dipisahkan di sini
    /// artinya, bukan gambarnya: robot yang tampak MENGANTUK setiap kali
    /// pengguna menang adalah salah pesan.
    @Test func sadHasItsOwnBehaviourButReusesTheExistingFace() {
        #expect(CharacterBehavior.allCases.contains(.sad))
        #expect(CharacterAsset.robot.resourceName(for: .sad) == "RobotSad")
        #expect(CharacterAsset.robot.resourceName(for: .sleepy) == "RobotSad")
    }

    /// Override hanya berlaku selama ronde; begitu nil, mood mesin kembali
    /// memegang kendali (spec F §8 #2).
    @Test func overrideWinsOverMoodWhileItLasts() {
        #expect(BuddyCharacterHost.behavior(mood: .hot, override: nil) == .sleepy)
        #expect(BuddyCharacterHost.behavior(mood: .hot, override: .celebrate) == .celebrate)
        #expect(BuddyCharacterHost.behavior(mood: .normal, override: nil) == .idle)
    }

    /// Wajah robot yang menyampaikan hasil, bukan teksnya.
    @Test func faceFollowsTheRound() {
        #expect(PlayPanelController.expression(for: nil) == nil)
        var round = SuitGame.Round(aplThrow: .rock)
        #expect(PlayPanelController.expression(for: round) == .greet)
        round.isThinking = true
        #expect(PlayPanelController.expression(for: round) == .thinking)
        round.isThinking = false
        round.yours = .paper
        round.outcome = .youWin
        #expect(PlayPanelController.expression(for: round) == .sad)
        round.outcome = .aplWins
        #expect(PlayPanelController.expression(for: round) == .celebrate)
        round.outcome = .draw
        #expect(PlayPanelController.expression(for: round) == .idle)
    }
}
