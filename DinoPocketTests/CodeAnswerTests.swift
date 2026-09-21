import Testing
@testable import Apl

struct CodeAnswerTests {

    private func block(_ body: String) -> String { "```swift\n\(body)\n```" }

    @Test func oneBlockOfReasonableSizeIsAccepted() {
        let body = String(repeating: "let x = 1\n", count: 10)
        let answer = "Here you go:\n\n" + block(body)
        guard case .success = CodeAnswer.fileContents(from: answer, originalCharacters: body.count) else {
            Issue.record("blok tunggal berukuran wajar seharusnya diterima")
            return
        }
    }

    @Test func answerWithoutACodeBlockWritesNothing() {
        #expect(CodeAnswer.fileContents(from: "I would change the name.", originalCharacters: 100)
                == .failure(.noCodeBlock))
    }

    /// Dua blok berarti model memberi potongan, bukan berkas utuh — dan menulis
    /// salah satunya berarti membuang sisanya.
    @Test func twoBlocksWriteNothing() {
        let answer = block("a") + "\n\n" + block("b")
        #expect(CodeAnswer.fileContents(from: answer, originalCharacters: 100)
                == .failure(.manyCodeBlocks))
    }

    @Test func emptyBlockWritesNothing() {
        #expect(CodeAnswer.fileContents(from: block(""), originalCharacters: 100)
                == .failure(.empty))
    }

    /// Model kecil kadang berhenti di tengah. Berkas yang tiba-tiba tinggal
    /// seperlima bukan suntingan — itu kehilangan.
    @Test func suspiciouslyShortAnswerWritesNothing() {
        #expect(CodeAnswer.fileContents(from: block("let x = 1"), originalCharacters: 1_000)
                == .failure(.sizeOutOfBand))
    }

    @Test func suspiciouslyLongAnswerWritesNothing() {
        let long = String(repeating: "x", count: 1_000)
        #expect(CodeAnswer.fileContents(from: block(long), originalCharacters: 100)
                == .failure(.sizeOutOfBand))
    }

    @Test func returnedContentsAreTheBlockWithoutTheFence() {
        let body = String(repeating: "let x = 1\n", count: 10)
        let contents = try? CodeAnswer.fileContents(from: block(body), originalCharacters: body.count).get()
        #expect(contents?.contains("```") == false)
        #expect(contents?.hasPrefix("let x = 1") == true)
    }
}
