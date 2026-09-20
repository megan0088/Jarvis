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
    /// `nil` bila kalimat Apl tidak menjawab apa pun — sapaan proaktif yang
    /// diklik pengguna (spec C2 §5). Menampilkan pertanyaan lama di atasnya
    /// akan membuat sapaan itu tampak seperti jawaban atas hal lain.
    let question: String?
    /// `nil` selama jawaban belum ada (baru dikirim, atau sedang mengalir).
    let answer: ChatMessage?

    static func latest(in messages: [ChatMessage]) -> QuickAskTurn? {
        guard let last = messages.last else { return nil }

        guard let asked = messages.lastIndex(where: { $0.role == .user }) else {
            // Belum pernah ada pertanyaan: yang ada hanya kalimat Apl sendiri.
            return last.role == .assistant ? QuickAskTurn(question: nil, answer: last) : nil
        }

        let reply = messages.index(after: asked)
        let lastIndex = messages.index(before: messages.endIndex)
        // Kalimat Apl yang datang setelah jawaban bukan jawaban atas apa pun.
        if last.role == .assistant, lastIndex > reply {
            return QuickAskTurn(question: nil, answer: last)
        }

        let answer = messages.indices.contains(reply) && messages[reply].role == .assistant
            ? messages[reply]
            : nil
        return QuickAskTurn(question: messages[asked].text, answer: answer)
    }
}
