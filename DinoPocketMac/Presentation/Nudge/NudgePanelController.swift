//
//  NudgePanelController.swift
//  Apl
//
//  Panel pasif untuk sapaan yang tidak diminta (spec C2 §3, §5).
//
//  `NudgePanel` sengaja TIDAK meng-override `canBecomeKey`. Itulah seluruh
//  jaminannya: balon yang datang tanpa diminta tidak punya jalan untuk mencuri
//  ketikan siapa pun — bukan karena ada bendera yang menahannya, tetapi karena
//  kemampuannya memang tidak ada.
//

import AppKit
import SwiftUI

private final class NudgePanel: NSPanel {}

@MainActor
final class NudgePanelController {

    static let shared = NudgePanelController()
    static let maxWidth: CGFloat = 300
    /// Umur balon bila tidak disentuh.
    static let lifetime: TimeInterval = 8

    private var panel: NudgePanel?
    private var hosting: NSHostingView<NudgeBalloon>?
    private var dismissTimer: Timer?
    private var current: Nudge?
    private var onEngage: ((Nudge) -> Void)?
    private var onIgnore: ((Nudge) -> Void)?
    private var isHovered = false
    private let buddy: AplBuddyWindowController

    init(buddy: AplBuddyWindowController = .shared) {
        self.buddy = buddy
    }

    var isShowing: Bool { panel?.isVisible == true }

    func show(_ nudge: Nudge,
              onEngage: @escaping (Nudge) -> Void,
              onIgnore: @escaping (Nudge) -> Void) {
        guard let anchor = buddy.characterScreenFrame else { return }
        dismiss(engaged: false, notify: false)

        current = nudge
        self.onEngage = onEngage
        self.onIgnore = onIgnore

        let balloon = NudgeBalloon(
            text: nudge.text,
            onTap: { [weak self] in self?.engage() },
            onHoverChange: { [weak self] hovering in self?.hoverChanged(hovering) }
        )
        let host = NSHostingView(rootView: balloon)
        host.sizingOptions = [.intrinsicContentSize]
        hosting = host

        let panel = self.panel ?? makePanel()
        panel.contentView = host
        let size = CGSize(width: min(host.fittingSize.width, Self.maxWidth),
                          height: host.fittingSize.height)
        panel.setFrame(BubblePlacement.frame(robot: anchor.rect,
                                             screen: anchor.screen.visibleFrame,
                                             size: size),
                       display: true)

        buddy.pauseStrolling()
        panel.orderFrontRegardless()
        startLifetime()
        announce(nudge.text)
    }

    func dismiss(engaged: Bool = false, notify: Bool = true) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        buddy.resumeStrolling()
        if notify, !engaged, let current { onIgnore?(current) }
        current = nil
        isHovered = false
    }

    // MARK: - Internal

    private func makePanel() -> NudgePanel {
        let panel = NudgePanel(contentRect: CGRect(x: 0, y: 0, width: Self.maxWidth, height: 44),
                               styleMask: [.borderless, .nonactivatingPanel],
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
