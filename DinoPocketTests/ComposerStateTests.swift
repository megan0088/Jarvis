import Testing
@testable import Apl

struct ComposerStateTests {

    @Test func streamingWinsOverAvailability() {
        #expect(ComposerState.current(availability: .ready, isStreaming: true) == .streaming)
        #expect(ComposerState.current(availability: nil, isStreaming: true) == .streaming)
    }

    @Test func availabilityDecidesTheRest() {
        #expect(ComposerState.current(availability: .ready, isStreaming: false) == .ready)
        #expect(ComposerState.current(availability: .needsSetup("x"), isStreaming: false) == .preparing)
        #expect(ComposerState.current(availability: nil, isStreaming: false) == .preparing)
        #expect(ComposerState.current(availability: .unavailable("off"), isStreaming: false) == .unavailable("off"))
    }

    /// Apple Intelligence mati tidak mengunci composer: reminder lewat chat
    /// tetap harus bisa dibuat (deviasi 9). Hanya model yang sedang
    /// disiapkan yang mengunci (spec B §9).
    @Test func onlyAModelBeingPreparedLocksTheComposer() {
        #expect(ComposerState.ready.acceptsInput)
        #expect(ComposerState.streaming.acceptsInput)
        #expect(ComposerState.unavailable("off").acceptsInput)
        #expect(!ComposerState.preparing.acceptsInput)
    }
}
