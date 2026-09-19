//
//  QuickAskPanelController.swift
//  Apl
//
//  Panel kecil yang menampung bubble (spec C1 §3–§4).
//
//  `.nonactivatingPanel` + `canBecomeKey` adalah pasangan yang membuat panel
//  bisa diketik tanpa memaksa seluruh app tampil seperti jendela dokumen.
//  `.fullScreenAuxiliary` yang membuatnya muncul di atas app layar penuh —
//  tanpa itu shortcut terasa rusak persis saat orang paling membutuhkannya.
//

import AppKit
import SwiftUI

private final class QuickAskPanel: NSPanel {
    /// Tanpa ini panel borderless tidak pernah jadi key window, dan composer
    /// tidak pernah menerima satu huruf pun.
    override var canBecomeKey: Bool { true }
}

@MainActor
final class QuickAskPanelController: NSObject, NSWindowDelegate {

    static let shared = QuickAskPanelController()

    struct Context {
        let chat: ChatStore
        let reminders: ReminderListViewModel
        let openMainWindow: () -> Void
        let openIntelligenceSettings: () -> Void
    }

    private var context: Context?
    private var panel: QuickAskPanel?
    private var hostingView: NSHostingView<QuickAskBubble>?
    private let focus = FocusRestorer()
    private var escMonitor: Any?
    private var contentHeight: CGFloat = BubblePlacement.maxHeight
    private let buddy: AplBuddyWindowController

    init(buddy: AplBuddyWindowController = .shared) {
        self.buddy = buddy
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func configure(_ context: Context) {
        self.context = context
    }

    var isOpen: Bool { panel?.isVisible == true }

    /// `false` berarti tidak ada jangkar — robot belum terpasang. Pemanggil
    /// yang memutuskan apa gantinya (jendela utama).
    @discardableResult
    func toggle() -> Bool {
        if isOpen {
            close()
            return true
        }
        return open()
    }

    @discardableResult
    func open() -> Bool {
        guard let context, let anchor = buddy.characterScreenFrame else { return false }

        let panel = self.panel ?? makePanel(context)
        // Fokus dicatat SEBELUM app diaktifkan, kalau tidak yang tercatat Apl.
        focus.remember()
        buddy.pauseStrolling()
        reposition(anchor: anchor)
        startEscMonitoring()

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        return true
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        stopEscMonitoring()
        panel.orderOut(nil)
        buddy.resumeStrolling()
        focus.restore()
    }

    // MARK: - Panel

    private func makePanel(_ context: Context) -> QuickAskPanel {
        let panel = QuickAskPanel(
            contentRect: CGRect(origin: .zero,
                                size: CGSize(width: BubblePlacement.width,
                                             height: BubblePlacement.maxHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let bubble = QuickAskBubble(
            chat: context.chat,
            reminders: context.reminders,
            onOpenMainWindow: { [weak self] in
                self?.close()
                context.openMainWindow()
            },
            onOpenIntelligenceSettings: context.openIntelligenceSettings,
            onHeightChange: { [weak self] height in
                self?.contentHeight = height
                self?.reposition()
            }
        )
        let host = NSHostingView(rootView: bubble)
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentView = host

        self.panel = panel
        hostingView = host
        return panel
    }

    private func reposition(anchor: (rect: CGRect, screen: NSScreen)? = nil) {
        guard let panel, let anchor = anchor ?? buddy.characterScreenFrame else { return }
        let frame = BubblePlacement.frame(robot: anchor.rect,
                                          screen: anchor.screen.visibleFrame,
                                          contentHeight: contentHeight)
        panel.setFrame(frame, display: true)
    }

    @objc private func screenParametersChanged() {
        guard isOpen else { return }
        reposition()
    }

    // MARK: - Esc

    /// Monitor lokal menerima event sebelum responder chain, jadi Esc di sini
    /// tidak pernah sampai ke `Composer.onKeyPress(.escape)` — hentikan dan
    /// tutup hanya diputuskan di satu tempat.
    ///
    /// Monitor Esc milik Buddy meneruskan event yang ditujukan ke jendela lain,
    /// jadi Esc di bubble tidak mematikan Buddy Mode.
    private func startEscMonitoring() {
        stopEscMonitoring()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel,
                  event.keyCode == 53,                  // 53 = Esc
                  event.window === panel else { return event }
            if self.context?.chat.isStreaming == true {
                self.context?.chat.stopStreaming()
            } else {
                self.close()
            }
            return nil
        }
    }

    private func stopEscMonitoring() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
    }

    // MARK: - NSWindowDelegate

    /// Klik di luar bubble, atau app lain diaktifkan. Jawaban yang sedang
    /// mengalir TIDAK dihentikan — ia tetap ditulis ke ChatStore dan muncul
    /// utuh di jendela utama (spec C1 §6).
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
