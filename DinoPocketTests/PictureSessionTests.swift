import Foundation
import Testing
@testable import Apl

@MainActor
struct PictureSessionTests {

    @Test func availabilityIsADecisionNotAnIf() {
        #expect(PictureAvailability.decide(isAvailable: true) == .ready)
        #expect(PictureAvailability.decide(isAvailable: false) == .unavailable)
        #expect(PictureAvailability.unavailableNotice.isEmpty == false)
    }

    @Test func startsOneRequest() {
        let session = PictureSession()
        #expect(session.request == nil)
        #expect(session.start(PictureRequest(concept: "a cat", sourceImage: nil)))
        #expect(session.request?.concept == "a cat")
    }

    /// Sheet kedua di atas sheet pertama bukan jawaban atas apa pun
    /// (spec G §5).
    @Test func refusesASecondRequestWhileOneIsOpen() {
        let session = PictureSession()
        #expect(session.start(PictureRequest(concept: "a cat", sourceImage: nil)))
        #expect(session.start(PictureRequest(concept: "a dog", sourceImage: nil)) == false)
        #expect(session.request?.concept == "a cat")
    }

    @Test func finishClearsIt() {
        let session = PictureSession()
        _ = session.start(PictureRequest(concept: "a cat", sourceImage: nil))
        session.finish()
        #expect(session.request == nil)
        #expect(session.start(PictureRequest(concept: "a dog", sourceImage: nil)))
    }
}
