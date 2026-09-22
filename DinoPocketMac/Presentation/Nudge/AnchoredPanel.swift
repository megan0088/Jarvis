//
//  AnchoredPanel.swift
//  Apl
//
//  Balon kecil yang ditambatkan ke robot — dipakai sapaan proaktif (C2) dan
//  permainan (F).
//
//  Satu parameter membedakan keduanya, dan itu bukan soal rasa: balon sapaan
//  datang TANPA DIMINTA, jadi ia tidak boleh mencuri ketikan siapa pun —
//  kelasnya sengaja tidak meng-override `canBecomeKey`. Balon permainan dimulai
//  pengguna sendiri dengan mengetik, jadi ia boleh.
//

import AppKit
import SwiftUI

private final class PassivePanel: NSPanel {}

private final class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AnchoredPanel {

    /// Lebar maksimum balon. Isi yang lebih lebar dari ini dipersempit oleh
    /// view-nya sendiri; angka di sini jaring pengaman terakhir.
    static let maxWidth: CGFloat = 320

    private let canBecomeKey: Bool
    private let buddy: AplBuddyWindowController
    private var panel: NSPanel?
    private var host: NSView?

    init(canBecomeKey: Bool, buddy: AplBuddyWindowController = .shared) {
        self.canBecomeKey = canBecomeKey
        self.buddy = buddy
    }

    var isShowing: Bool { panel?.isVisible == true }

    /// Apakah ada robot untuk dijangkari — pemanggil yang memutuskan apa
    /// gantinya bila tidak ada.
    var canAnchor: Bool { buddy.characterScreenFrame != nil }

    /// `false` berarti tidak ada robot untuk dijangkari.
    @discardableResult
    func show<Content: View>(_ content: Content) -> Bool {
        guard canAnchor else { return false }
        let panel = self.panel ?? makePanel()
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        host = hosting

        reposition()
        buddy.pauseStrolling()
        panel.orderFrontRegardless()
        if canBecomeKey {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func reposition() {
        guard let panel, let host, let anchor = buddy.characterScreenFrame else { return }
        // Diukur SETELAH tata letak dijalankan. `fittingSize` yang dibaca
        // sebelum SwiftUI sempat menata isinya mengembalikan ukuran kerdil, dan
        // panelnya menyusut jadi kotak 70×90 dengan teks terpotong.
        host.layoutSubtreeIfNeeded()
        let size = CGSize(width: min(host.fittingSize.width, Self.maxWidth),
                          height: host.fittingSize.height)
        panel.setFrame(BubblePlacement.frame(robot: anchor.rect,
                                             screen: anchor.screen.visibleFrame,
                                             size: size),
                       display: true)
    }

    /// Untuk pemanggil yang berada DI DALAM evaluasi `body` SwiftUI: di sana
    /// isinya belum ditata, jadi pengukuran ditunda sampai siklus tampilan
    /// berikutnya.
    func repositionAfterLayout() {
        DispatchQueue.main.async { [weak self] in self?.reposition() }
    }

    func dismiss() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        buddy.resumeStrolling()
    }

    private func makePanel() -> NSPanel {
        let panel: NSPanel = canBecomeKey
            ? FocusablePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
            : PassivePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
        return panel
    }
}
