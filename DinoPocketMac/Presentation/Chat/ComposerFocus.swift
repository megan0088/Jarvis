//
//  ComposerFocus.swift
//  Apl
//
//  Permintaan fokus dari luar view (spec C1 §3, cabang `.focusComposer`).
//
//  Berupa penghitung, bukan Bool: menekan shortcut dua kali saat composer sudah
//  fokus harus tetap terbaca sebagai dua permintaan, dan Bool yang sudah `true`
//  tidak memicu `onChange` yang kedua.
//

import Observation

@MainActor
@Observable
final class ComposerFocus {
    private(set) var token = 0

    func request() {
        token += 1
    }
}
