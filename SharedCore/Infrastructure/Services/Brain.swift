import Foundation

/// Otak percakapan. Satu-satunya implementasi adalah `AppleBrain`
/// (spec A §2 #7); protokol ini ada supaya `ChatStore` bisa diuji dengan
/// otak palsu.
protocol Brain {
    func availability() async -> BrainAvailability
    /// Streaming balasan. Tiap nilai yang di-yield adalah teks balasan KUMULATIF.
    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}
