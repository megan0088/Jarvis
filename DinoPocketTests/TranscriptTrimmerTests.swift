import Foundation
import Testing
import FoundationModels
@testable import Apl

// Deployment target sudah macOS 26.2, jadi tidak perlu anotasi @available —
// dan Swift Testing memang menolak @Test pada fungsi yang punya anotasi itu.
struct TranscriptTrimmerTests {

    private func prompt(_ text: String) -> Transcript.Entry {
        .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: text))]))
    }

    private func instructions(_ text: String) -> Transcript.Entry {
        .instructions(Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: text))],
            toolDefinitions: []
        ))
    }

    /// Invarian terpenting. Membuang `instructions` menghapus persona: model
    /// tetap menjawab, tapi berhenti menjadi karakter yang sama — kegagalan
    /// yang tidak pernah muncul sebagai error.
    @Test func instructionsSurviveTrimming() {
        let entries = [instructions("You are Jarvis.")] + (1...20).map { prompt("pesan \($0)") }
        let trimmed = TranscriptTrimmer.trimmed(Transcript(entries: entries), keepingLast: 4)

        let keptInstructions = trimmed.filter { if case .instructions = $0 { return true } else { return false } }
        #expect(keptInstructions.count == 1)
    }

    @Test func keepsOnlyTheNewestEntries() {
        let entries = [instructions("persona")] + (1...10).map { prompt("pesan \($0)") }
        let trimmed = TranscriptTrimmer.trimmed(Transcript(entries: entries), keepingLast: 3)

        // 1 instructions + 3 terbaru
        #expect(trimmed.count == 4)
    }

    @Test func shortTranscriptSurvivesUntouched() {
        let entries = [instructions("persona"), prompt("halo")]
        let trimmed = TranscriptTrimmer.trimmed(Transcript(entries: entries), keepingLast: 6)
        #expect(trimmed.count == 2)
    }

    @Test func emptyTranscriptStaysEmpty() {
        #expect(TranscriptTrimmer.trimmed(Transcript(entries: [])).isEmpty)
    }
}
