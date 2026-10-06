import Testing
@testable import Apl

struct MarkdownBlocksTests {

    @Test func plainTextIsASingleBlock() {
        #expect(MarkdownBlocks.split("Hello **there**") == [.text("Hello **there**")])
    }

    @Test func fencedCodeIsSeparatedFromText() {
        let source = "Here you go:\n```swift\nlet a = 1\nprint(a)\n```\nThat's it."

        #expect(MarkdownBlocks.split(source) == [
            .text("Here you go:"),
            .code(language: "swift", code: "let a = 1\nprint(a)", isClosed: true),
            .text("That's it."),
        ])
    }

    /// Saat streaming, pagar penutup belum datang. Sisa teks tetap tampil
    /// sebagai kode, bukan hilang atau dirender sebagai Markdown rusak.
    @Test func unclosedFenceWhileStreamingStaysCode() {
        #expect(MarkdownBlocks.split("Try:\n```\nprint(1)") == [
            .text("Try:"),
            .code(language: nil, code: "print(1)", isClosed: false),
        ])
    }

    /// List dan paragraf tetap satu blok teks; baris kosong di dalamnya dipertahankan.
    @Test func blankLinesInsideTextAreKept() {
        #expect(MarkdownBlocks.split("First\n\n- one\n- two\n") == [.text("First\n\n- one\n- two")])
    }

    @Test func emptyInputHasNoBlocks() {
        #expect(MarkdownBlocks.split("").isEmpty)
        #expect(MarkdownBlocks.split("\n\n").isEmpty)
    }
}
