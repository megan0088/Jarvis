import Foundation
import Testing
@testable import Apl

struct OllamaBrainTests {
    @Test func deltaExtractsContentFromChunk() {
        let line = #"{"model":"llama3.1:8b","message":{"role":"assistant","content":"Hal"},"done":false}"#
        #expect(OllamaWire.delta(from: line) == "Hal")
    }

    @Test func deltaReturnsNilForDoneOrGarbage() {
        #expect(OllamaWire.delta(from: #"{"done":true}"#) == nil)
        #expect(OllamaWire.delta(from: "bukan json") == nil)
        #expect(OllamaWire.delta(from: "") == nil)
    }

    @Test func cumulativeAccumulatesDeltas() {
        let lines = [
            #"{"message":{"content":"Hal"},"done":false}"#,
            #"{"message":{"content":"o "},"done":false}"#,
            #"{"message":{"content":"Ega"},"done":false}"#,
            #"{"done":true}"#
        ]
        #expect(OllamaWire.cumulative(from: lines) == ["Hal", "Halo ", "Halo Ega"])
    }

    @Test func kindIsOllama() {
        #expect(OllamaBrain().kind == .ollama)
    }

    @Test func errorMessageParsesOllamaError() {
        #expect(OllamaWire.errorMessage(from: #"{"error":"model 'x' not found"}"#) == "model 'x' not found")
    }

    @Test func errorMessageNilForNonError() {
        #expect(OllamaWire.errorMessage(from: #"{"message":{"content":"hi"},"done":false}"#) == nil)
        #expect(OllamaWire.errorMessage(from: "garbage") == nil)
    }
}
