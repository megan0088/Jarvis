//
//  QuietSignals.swift
//  Apl
//
//  Jawaban atas satu pertanyaan: boleh bicara sekarang? (spec C2 §4)
//
//  Nilai polos, tanpa cara membacanya sendiri — supaya seluruh aturan bisa
//  diuji tanpa layar, tanpa jendela, dan tanpa Mac yang sedang panas.
//

struct QuietSignals: Equatable {
    var otherAppIsFullScreen = false
    var screenIsAsleepOrLocked = false
    /// Pengguna sudah bersama Apl; tidak perlu disapa.
    var aplIsFrontmost = false
    var quickAskIsOpen = false
    var buddyIsRunning = true
    var aNudgeIsOnScreen = false
    /// Ronde suit sedang tampil. Tanpa ini Apl menyela permainannya sendiri
    /// (spec F §8 #4).
    var aGameIsOnScreen = false

    var allowsSpeaking: Bool {
        buddyIsRunning
            && !otherAppIsFullScreen
            && !screenIsAsleepOrLocked
            && !aplIsFrontmost
            && !quickAskIsOpen
            && !aNudgeIsOnScreen
            && !aGameIsOnScreen
    }
}
