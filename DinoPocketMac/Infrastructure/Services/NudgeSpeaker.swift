//
//  NudgeSpeaker.swift
//  Apl
//
//  Membacakan sapaan yang tidak diminta (spec C2 §5). Mati secara bawaan.
//
//  Hanya balon proaktif yang dibacakan: jumlahnya sudah dibatasi kuota.
//  Jawaban atas pertanyaan pengguna tidak pernah bersuara — panjangnya tidak
//  terbatas, dan tidak ada yang meminta dibacakan.
//

import AVFoundation

@MainActor
final class NudgeSpeaker {

    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    /// Selalu menghentikan yang sedang berbunyi: dua kalimat sekaligus tidak
    /// terbaca sebagai apa pun.
    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }
}
