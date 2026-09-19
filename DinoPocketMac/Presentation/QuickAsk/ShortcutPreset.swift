//
//  ShortcutPreset.swift
//  Apl
//
//  Pilihan shortcut siap pakai (spec C1 §5).
//
//  Bukan perekam tombol: daftar tertutup berarti tidak ada kombinasi sembarang
//  yang harus divalidasi, disimpan, dan diterjemahkan kembali ke Carbon.
//
//  ⌃Space tidak ditawarkan — macOS memakainya untuk berpindah sumber input.
//  ⌥Space sendiri adalah bawaan Raycast dan Alfred, jadi Off dan dua alternatif
//  wajib ada, bukan pelengkap.
//

import Carbon.HIToolbox
import Foundation

enum ShortcutPreset: String, CaseIterable, Sendable {
    case off
    case optionSpace
    case optionCommandA
    case controlOptionSpace

    static let `default` = ShortcutPreset.optionSpace

    /// `nil` berarti tidak ada yang didaftarkan ke sistem.
    var keyCode: UInt32? {
        switch self {
        case .off: nil
        case .optionSpace, .controlOptionSpace: UInt32(kVK_Space)
        case .optionCommandA: UInt32(kVK_ANSI_A)
        }
    }

    /// Bendera modifier Carbon, bukan `NSEvent.ModifierFlags`.
    var modifiers: UInt32 {
        switch self {
        case .off: 0
        case .optionSpace: UInt32(optionKey)
        case .optionCommandA: UInt32(optionKey | cmdKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        }
    }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .optionSpace: "⌥Space"
        case .optionCommandA: "⌥⌘A"
        case .controlOptionSpace: "⌃⌥Space"
        }
    }
}
