//
//  QuickAskTurn.swift
//  Apl
//
//  Satu giliran: pertanyaan terakhir dan jawabannya (spec C1 §2 #2).
//
//  Bubble tidak menyimpan apa pun sendiri — ia memotong `ChatStore.messages`
//  setiap kali digambar. Karena itu isi bubble tidak pernah bisa berbeda dari
//  isi jendela utama.
//

struct QuickAskTurn: Equatable {
    let question: String
    /// `nil` selama jawaban belum ada (baru dikirim, atau sedang mengalir).
    let answer: ChatMessage?

    static func latest(in messages: [ChatMessage]) -> QuickAskTurn? {
        guard let asked = messages.lastIndex(where: { $0.role == .user }) else { return nil }
        let next = messages.index(after: asked)
        let answer = messages.indices.contains(next) && messages[next].role == .assistant
            ? messages[next]
            : nil
        return QuickAskTurn(question: messages[asked].text, answer: answer)
    }
}
