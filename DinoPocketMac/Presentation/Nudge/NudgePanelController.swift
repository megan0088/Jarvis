//
//  NudgePanelController.swift
//  Apl
//
//  Panel pasif untuk sapaan yang tidak diminta (spec C2 §3, §5).
//
//  Jendela, penempatan, dan jangkarnya milik `AnchoredPanel` — dipakai bersama
//  balon permainan (F). Yang tinggal di sini hanya aturan SAPAAN: umur 8 detik,
//  kursor yang menahannya, dan pengumuman VoiceOver berprioritas rendah.
//
//  `canBecomeKey: false` adalah seluruh jaminannya: balon yang datang tanpa
//  diminta tidak punya jalan untuk mencuri ketikan siapa pun — bukan karena ada
//  bendera yang menahannya, tetapi karena kemampuannya memang tidak ada.
//

import AppKit
import SwiftUI

@MainActor
final class NudgePanelController {

    static let shared = NudgePanelController()
    static let maxWidth: CGFloat = 300
    /// Umur balon bila tidak disentuh.
    static let lifetime: TimeInterval = 8

    private let panel: AnchoredPanel
    private var dismissTimer: Timer?
    private var current: Nudge?
    private var onEngage: ((Nudge) -> Void)?
    private var onIgnore: ((Nudge) -> Void)?
    private var isHovered = false

    init(buddy: AplBuddyWindowController = .shared) {
        panel = AnchoredPanel(canBecomeKey: false, buddy: buddy)
    }

    var isShowing: Bool { panel.isShowing }

    func show(_ nudge: Nudge,
              onEngage: @escaping (Nudge) -> Void,
              onIgnore: @escaping (Nudge) -> Void) {
        guard panel.canAnchor else { return }
        dismiss(engaged: false, notify: false)

        current = nudge
        self.onEngage = onEngage
        self.onIgnore = onIgnore

        let balloon = NudgeBalloon(
            text: nudge.text,
            onTap: { [weak self] in self?.engage() },
            onHoverChange: { [weak self] hovering in self?.hoverChanged(hovering) }
        )
        panel.show(balloon)
        startLifetime()
        announce(nudge.text)
    }

    func dismiss(engaged: Bool = false, notify: Bool = true) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard panel.isShowing else { return }
        panel.dismiss()
        if notify, !engaged, let current { onIgnore?(current) }
        current = nil
        isHovered = false
    }

    // MARK: - Internal

    private func engage() {
        guard let nudge = current else { return }
        dismiss(engaged: true)
        onEngage?(nudge)
    }

    /// Kursor yang berada di atas balon menahannya: orang sedang membacanya.
    private func hoverChanged(_ hovering: Bool) {
        isHovered = hovering
        if hovering {
            dismissTimer?.invalidate()
            dismissTimer = nil
        } else {
            startLifetime()
        }
    }

    private func startLifetime() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.lifetime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isHovered else { return }
                self.dismiss()
            }
        }
    }

    /// Balon tidak bisa menerima fokus, jadi VoiceOver tidak menemukannya
    /// sendiri. Prioritas RENDAH: dikabarkan, tanpa memotong yang sedang
    /// dibacakan — ini sapaan yang tidak diminta.
    private func announce(_ text: String) {
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [
                                .announcement: text,
                                .priority: NSAccessibilityPriorityLevel.low.rawValue,
                             ])
    }
}
