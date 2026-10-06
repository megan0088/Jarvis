import Testing
@testable import Apl

struct DrawCommandTests {

    /// Konsepnya diuji sebagai string PERSIS. "Cocok/tidak" saja tidak cukup:
    /// yang dikirim ke Image Playground adalah potongan ini.
    @Test func cutsTheConceptOut() {
        #expect(DrawCommand.concept(in: "gambarkan kucing pakai topi") == "kucing pakai topi")
        #expect(DrawCommand.concept(in: "gambar rumah di tepi danau") == "rumah di tepi danau")
        #expect(DrawCommand.concept(in: "buatkan gambar robot kecil") == "robot kecil")
        #expect(DrawCommand.concept(in: "draw a small friendly robot") == "a small friendly robot")
        #expect(DrawCommand.concept(in: "Draw an orange cat") == "an orange cat")
    }

    /// Kalimat yang meminta pengingat tetap pengingat — alasan yang sama
    /// dengan PlayCommand di F.
    @Test func doesNotHijackReminders() {
        #expect(DrawCommand.concept(in: "remind me to draw the logo at 4pm") == nil)
        #expect(DrawCommand.concept(in: "remind me to gambar poster besok") == nil)
    }

    /// Jebakan sebenarnya: "draw" adalah kata biasa di percakapan tentang
    /// koding, dan pertanyaan seperti ini harus sampai ke model.
    @Test func doesNotFireOnQuestions() {
        #expect(DrawCommand.concept(in: "how do I draw a circle in SwiftUI?") == nil)
        #expect(DrawCommand.concept(in: "what does Canvas draw first?") == nil)
        #expect(DrawCommand.concept(in: "apa bedanya draw dan render?") == nil)
    }

    /// Ajakan tanpa konsep bukan ajakan: tidak ada yang bisa dikirim.
    @Test func needsSomethingToDraw() {
        #expect(DrawCommand.concept(in: "gambarkan") == nil)
        #expect(DrawCommand.concept(in: "draw") == nil)
        #expect(DrawCommand.concept(in: "draw a") == nil)
    }

    /// Awalan harus berupa KATA utuh. Tanpa batas kata, "drawing" terpotong
    /// jadi konsep "ing ..." dan kalimat biasa membuka sheet.
    @Test func prefixMustBeAWholeWord() {
        #expect(DrawCommand.concept(in: "drawing a UI in SwiftUI is hard") == nil)
        #expect(DrawCommand.concept(in: "gambarnya bagus sekali") == nil)
        #expect(DrawCommand.concept(in: "drawers keep jamming today") == nil)
    }
}
