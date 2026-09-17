import Foundation

/// Otak percakapan. Satu-satunya implementasi adalah `AppleBrain`
/// (spec A §2 #7); protokol ini ada supaya `ChatStore` bisa diuji dengan
/// otak palsu.
protocol Brain {
    func availability() async -> BrainAvailability
    /// Streaming balasan. Tiap nilai yang di-yield adalah teks balasan KUMULATIF.
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error>
    /// Melupakan percakapan yang dipegang model: sesi di memori dan yang
    /// tersimpan. Dipanggil Clear Conversation dan Erase All Data.
    func resetConversation() async
}

extension Brain {
    /// Otak tanpa ingatan sendiri tidak punya apa-apa untuk dilupakan.
    func resetConversation() async {}
}
