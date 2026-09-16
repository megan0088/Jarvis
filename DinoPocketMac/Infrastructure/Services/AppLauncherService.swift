//
//  AppLauncherService.swift
//  AplMac
//
//  Membuka pane System Settings dan URL scheme umum.
//
//  BUKAN peluncur aplikasi sembarangan. App Sandbox tidak mengizinkannya, dan
//  spec Fase A §7 menerima batasan itu secara sadar: keluar dari sandbox demi
//  fitur ini berarti kehilangan jalur Mac App Store.
//

import Foundation
import AppKit

protocol AppLaunching: Sendable {
    @discardableResult
    func open(_ target: SystemSettingsPane) -> Bool
    @discardableResult
    func open(url: URL) -> Bool
}

/// Pane System Settings yang boleh dibuka. Enum tertutup, bukan string bebas —
/// URL yang salah ketik gagal diam-diam dan menghasilkan tombol yang tak
/// berbuat apa-apa, kegagalan yang sulit terlihat saat pengujian.
enum SystemSettingsPane: String, CaseIterable {
    case appleIntelligence
    case notifications
    case loginItems
    case root

    /// Identifier pane bisa berubah antar versi macOS, jadi setiap kasus
    /// menyediakan fallback ke System Settings umum — lebih baik membuka
    /// jendela yang salah daripada tidak terjadi apa-apa saat tombol ditekan.
    var candidateURLStrings: [String] {
        switch self {
        case .appleIntelligence:
            ["x-apple.systempreferences:com.apple.preference.AppleIntelligence",
             "x-apple.systempreferences:"]
        case .notifications:
            ["x-apple.systempreferences:com.apple.preference.notifications",
             "x-apple.systempreferences:"]
        case .loginItems:
            ["x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
             "x-apple.systempreferences:"]
        case .root:
            ["x-apple.systempreferences:"]
        }
    }

    /// Fungsi murni, dipisah agar bisa diuji tanpa membuka jendela apa pun.
    var candidateURLs: [URL] {
        candidateURLStrings.compactMap(URL.init(string:))
    }
}

struct AppLauncherService: AppLaunching {

    @discardableResult
    func open(_ target: SystemSettingsPane) -> Bool {
        for url in target.candidateURLs where NSWorkspace.shared.open(url) {
            return true
        }
        return false
    }

    @discardableResult
    func open(url: URL) -> Bool {
        // Hanya skema yang tidak berbahaya. `file:` sengaja tidak termasuk:
        // membuka path sembarangan bukan wewenang app ber-sandbox.
        let allowed: Set<String> = ["https", "mailto", "x-apple.systempreferences"]
        guard let scheme = url.scheme?.lowercased(), allowed.contains(scheme) else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
