//
//  QuickAskRouter.swift
//  Apl
//
//  Satu tombol, tiga arti (spec C1 §3).
//

enum QuickAskAction: Equatable {
    /// Jendela utama sudah di depan: cukup pindahkan fokus ke composer.
    case focusComposer
    /// Robot ada di desktop: buka atau tutup bubble di sampingnya.
    case toggleBubble
    /// Tidak ada robot: bawa jendela utama ke depan.
    case openMainWindow
}

enum QuickAskRouter {

    /// Jendela utama menang atas Buddy. Keduanya bisa hidup bersamaan, dan
    /// menaruh bubble di atas jendela yang sedang dipakai hanya menutupi
    /// percakapan yang sudah terbuka di sana.
    static func action(mainWindowIsFrontmost: Bool, buddyIsRunning: Bool) -> QuickAskAction {
        if mainWindowIsFrontmost { return .focusComposer }
        return buddyIsRunning ? .toggleBubble : .openMainWindow
    }
}
