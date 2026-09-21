import Testing
@testable import Apl

struct ContextBudgetTests {

    private func file(_ bytes: Int) -> WorkspaceFile {
        WorkspaceFile(relativePath: "F\(bytes).swift", byteCount: bytes)
    }

    /// Perkiraan sengaja konservatif: 3,5 karakter per token, dibulatkan ke atas.
    @Test func estimateRoundsUp() {
        #expect(ContextBudget.tokens(forCharacters: 0) == 0)
        #expect(ContextBudget.tokens(forCharacters: 7) == 2)
        #expect(ContextBudget.tokens(forCharacters: 8) == 3)
    }

    @Test func usedIsTheSumOfAttachments() {
        let attached = [file(3_500), file(3_500)]
        #expect(ContextBudget.used(attached) == 2_000)
        #expect(ContextBudget.remaining(after: attached) == 0)
    }

    @Test func fileThatFitsIsAccepted() {
        #expect(ContextBudget.canAdd(file(3_500), to: []))
    }

    @Test func fileThatOverflowsIsRefused() {
        let attached = [file(5_000)]
        #expect(ContextBudget.canAdd(file(3_000), to: attached) == false)
    }

    /// Berkas tunggal yang lebih besar dari seluruh anggaran tidak pernah bisa
    /// dilampirkan — versi ini tidak memotong berkas jadi sebagian (spec E §4).
    @Test func fileLargerThanTheWholeBudgetIsRefusedEvenWhenEmpty() {
        #expect(ContextBudget.canAdd(file(100_000), to: []) == false)
    }

    @Test func remainingNeverGoesNegative() {
        #expect(ContextBudget.remaining(after: [file(100_000)]) == 0)
    }
}
