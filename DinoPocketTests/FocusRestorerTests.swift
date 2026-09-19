import Testing
@testable import Apl

final class FakeApp: ActivatableApp {
    var isCurrent: Bool
    var isTerminated = false
    private(set) var activations = 0

    init(isCurrent: Bool = false) { self.isCurrent = isCurrent }

    @discardableResult
    func activateNow() -> Bool {
        activations += 1
        return true
    }
}

@MainActor
struct FocusRestorerTests {

    @Test func returnsFocusToTheAppThatHadIt() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.remember()
        restorer.restore()
        #expect(other.activations == 1)
    }

    /// Kalau Apl sendiri sudah di depan, tidak ada yang perlu dikembalikan —
    /// mengaktifkan diri sendiri akan merebut fokus dari jendela utama.
    @Test func doesNothingWhenAplWasAlreadyFrontmost() {
        let apl = FakeApp(isCurrent: true)
        let restorer = FocusRestorer(frontmostApp: { apl })
        restorer.remember()
        restorer.restore()
        #expect(apl.activations == 0)
    }

    @Test func doesNotResurrectAnAppThatQuit() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.remember()
        other.isTerminated = true
        restorer.restore()
        #expect(other.activations == 0)
    }

    /// Bubble bisa ditutup dua kali (Esc lalu app lain aktif); yang kedua diam.
    @Test func restoringTwiceActivatesOnce() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.remember()
        restorer.restore()
        restorer.restore()
        #expect(other.activations == 1)
    }

    @Test func restoringWithoutRememberingIsHarmless() {
        let other = FakeApp()
        let restorer = FocusRestorer(frontmostApp: { other })
        restorer.restore()
        #expect(other.activations == 0)
    }
}
