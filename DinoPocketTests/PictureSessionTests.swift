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

    /// Sheet Apple boleh menutup dirinya SEBELUM memanggil onCompletion. Kalau
    /// konsepnya ikut hilang bersama permintaan, gambarnya masuk percakapan
    /// tanpa keterangan dan VoiceOver hanya berkata "Image".
    @Test func conceptOutlivesTheRequest() {
        let session = PictureSession()
        session.start(PictureRequest(concept: "an orange cat", sourceImage: nil))
        session.finish()
        #expect(session.request == nil)
        #expect(session.lastConcept == "an orange cat")
    }

    /// Permintaan yang ditolak tidak boleh menimpa konsep yang sedang berjalan.
    @Test func ignoredRequestDoesNotReplaceTheConcept() {
        let session = PictureSession()
        session.start(PictureRequest(concept: "an orange cat", sourceImage: nil))
        session.start(PictureRequest(concept: "a dog", sourceImage: nil))
        #expect(session.lastConcept == "an orange cat")
    }
}
