import Testing
@testable import Apl

struct CodeInstructionsTests {

    /// Instructions punya jatah ~300 token dari ~4.096 (spec E §4). Melewatinya
    /// berarti memakan ruang berkas tanpa ada yang memberi tahu.
    @Test func fitsItsShareOfTheContext() {
        #expect(ContextBudget.tokens(forCharacters: CodeInstructions.text.count) <= 300)
    }

    @Test func demandsWholeFilesInOneBlock() {
        let text = CodeInstructions.text.lowercased()
        #expect(text.contains("entire file"))
        #expect(text.contains("one code block"))
    }

    /// Persona Apl tetap, tapi sisi Code tidak boleh berbasa-basi: setiap kata
    /// basa-basi memakan token yang seharusnya jadi kode.
    @Test func asksForTerseAnswers() {
        #expect(CodeInstructions.text.lowercased().contains("brief"))
    }
}
