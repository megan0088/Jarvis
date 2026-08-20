import Foundation

enum OllamaWire {
    private struct Chunk: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message?
        let done: Bool
    }

    /// Delta konten dari satu baris NDJSON, atau nil kalau baris kontrol/rusak.
    static func delta(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(Chunk.self, from: data),
              let content = chunk.message?.content, !content.isEmpty
        else { return nil }
        return content
    }

    /// Peta baris-baris NDJSON menjadi daftar teks KUMULATIF.
    static func cumulative(from lines: [String]) -> [String] {
        var acc = ""
        var out: [String] = []
        for line in lines {
            guard let d = delta(from: line) else { continue }
            acc += d
            out.append(acc)
        }
        return out
    }

    /// Ekstrak pesan error dari body JSON Ollama {"error":"..."} — nil kalau bukan error.
    static func errorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? String, !err.isEmpty else { return nil }
        return err
    }
}

struct OllamaBrain: Brain {
    var kind: BrainKind { .ollama }
    var host = URL(string: "http://localhost:11434")!
    var model = "llama3.1:8b"

    func availability() async -> BrainAvailability {
        var req = URLRequest(url: host.appendingPathComponent("api/tags"))
        req.timeoutInterval = 2
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 { return .ready }
            return .needsSetup("Ollama isn't responding at \(host.host ?? "localhost").")
        } catch {
            return .needsSetup("Ollama isn't running. Run `ollama serve` and try again.")
        }
    }

    func reply(to history: [ChatMessage], persona: Persona) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages: [[String: String]] = [["role": "system", "content": persona.systemPrompt]]
                    messages += history.map { ["role": $0.role.rawValue, "content": $0.text] }
                    let body: [String: Any] = ["model": model, "messages": messages, "stream": true]

                    var req = URLRequest(url: host.appendingPathComponent("api/chat"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        let message = OllamaWire.errorMessage(from: body)
                            ?? "Ollama responded with status \(http.statusCode)."
                        throw NSError(domain: "OllamaBrain", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: message])
                    }
                    var acc = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let d = OllamaWire.delta(from: line) {
                            acc += d
                            continuation.yield(acc)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
