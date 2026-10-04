import Foundation
import Testing
@testable import Apl

@MainActor
struct PictureWithoutBrainTests {

    private func store() -> ChatStore {
        ChatStore(brain: nil, defaults: UserDefaults(suiteName: "test.picture.\(UUID())")!)
    }

    /// Janji spec G §2 #1: jalur menggambar tidak pernah menyentuh model.
    /// `brain: nil` membuat jalur model gagal keras.
    @Test func drawingNeverReachesTheModel() async {
        let chat = store()
        var asked: PictureRequest?
        chat.pictureRequested = { asked = $0 }

        await chat.send("gambarkan kucing oranye")

        #expect(asked?.concept == "kucing oranye")
        #expect(asked?.sourceImage == nil)
        #expect(chat.noticeMessage == nil)
        #expect(chat.isStreaming == false)
    }

    /// Spec G §2 #5: tidak ada kalimat jawaban saat sheet dibuka. Yang ada di
    /// percakapan hanyalah kalimat pengguna sendiri.
    @Test func aplSaysNothingUntilThereIsAnImage() async {
        let chat = store()
        chat.pictureRequested = { _ in }

        await chat.send("gambarkan kucing oranye")

        #expect(chat.messages.count == 1)
        #expect(chat.messages.first?.role == .user)
    }

    @Test func appendingAPictureAttachesIt() async {
        let chat = store()
        chat.pictureRequested = { _ in }
        await chat.send("gambarkan kucing oranye")

        chat.appendPicture(name: "a.png", concept: "kucing oranye")

        #expect(chat.messages.last?.role == .assistant)
        #expect(chat.messages.last?.text.isEmpty == true)
        #expect(chat.messages.last?.attachment == .picture(name: "a.png", concept: "kucing oranye"))
        #expect(chat.pictureNames == ["a.png"])
    }

    /// Tanpa pemasangan, kalimatnya bukan urusan siapa-siapa dan harus
    /// diteruskan seperti pesan biasa.
    @Test func withoutAHandlerTheSentenceGoesOnAsUsual() async {
        let chat = store()
        await chat.send("gambarkan kucing oranye")
        #expect(chat.noticeMessage == ChatStore.unavailableNotice)
    }

    /// Spec G §2 #3: bubble ⌥Space memakai ChatStore yang sama, tetapi sheet
    /// hanya punya jendela utama untuk ditempeli. Dari sana kalimatnya tetap
    /// pesan biasa, walau pemasangnya ada.
    @Test func quickAskNeverOpensTheSheet() async {
        let chat = store()
        var asked: PictureRequest?
        chat.pictureRequested = { asked = $0 }

        await chat.send("gambarkan kucing oranye", allowsPictures: false)

        #expect(asked == nil)
        #expect(chat.noticeMessage == ChatStore.unavailableNotice)
    }
}
