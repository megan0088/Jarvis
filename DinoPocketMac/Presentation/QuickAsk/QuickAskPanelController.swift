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

    /// Mengaktifkan app mengangkat MAIN window-nya. Panel biasanya tidak bisa
    /// jadi main, jadi yang terangkat adalah jendela utama — dan satu klik pada
    /// robot memunculkan dua hal sekaligus: bubble dan jendela percakapan.
    /// Dengan ini panel-lah yang terangkat, dan jendela utama tetap di tempatnya.
    override var canBecomeMain: Bool { true }
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
    private let composerFocus = ComposerFocus()
    private var escMonitor: Any?
    /// Benar selama panel baru dibuka dan status key-nya belum tenang; lihat
    /// `claimKeyboardFocus()`.
    private var isSettling = false
    private var activationObserver: (any NSObjectProtocol)?
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

        claimKeyboardFocus(panel)
        return true
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        stopEscMonitoring()
        stopWaitingForActivation()
        isSettling = false
        panel.orderOut(nil)
        buddy.resumeStrolling()
        focus.restore()
    }

    /// Membuat panel menerima ketikan, melawan balapan aktivasi app.
    ///
    /// `NSApp.activate()` tidak langsung: saat app benar-benar menjadi aktif —
    /// satu putaran run loop kemudian — AppKit mengembalikan status key ke
    /// jendela utama, dan panel yang sudah dijadikan key kehilangannya lagi.
    /// Akibatnya huruf pertama yang diketik jatuh ke jendela utama, bukan ke
    /// bubble. Karena itu key ditegaskan tiga kali: sekarang, satu putaran
    /// kemudian, dan saat app benar-benar aktif.
    ///
    /// Selama penegasan itu berlangsung, `windowDidResignKey` diabaikan — kalau
    /// tidak, perebutan key oleh jendela utama akan langsung menutup bubble.
    private func claimKeyboardFocus(_ panel: QuickAskPanel) {
        isSettling = true
        panel.orderFrontRegardless()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        handOverToSwiftUI()

        stopWaitingForActivation()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let panel = self.panel, panel.isVisible else { return }
                    panel.makeKey()
                    self.handOverToSwiftUI()
                    self.settle()
                }
            }

        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            panel.makeKey()
            self.handOverToSwiftUI()
            self.settle()
        }
    }

    /// Panel yang key belum berarti ada yang menerima ketikan.
    ///
    /// Dua hal harus terjadi berurutan: hosting view menjadi first responder,
    /// lalu composer meminta fokus LAGI. Permintaan pertamanya (`.task` di
    /// `Composer`) berjalan saat view muncul — sebelum panel menjadi key — dan
    /// `@FocusState` yang disetel di jendela yang belum key terbuang begitu
    /// saja. Tanpa permintaan kedua ini, bubble tampak siap diketik tetapi
    /// menelan setiap huruf.
    private func handOverToSwiftUI() {
        guard let panel, let hostingView else { return }
        panel.initialFirstResponder = hostingView
        panel.makeFirstResponder(hostingView)
        composerFocus.request()
    }

    private func settle() {
        isSettling = false
        stopWaitingForActivation()
    }

    private func stopWaitingForActivation() {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        activationObserver = nil
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
            // Angkanya tidak dipakai: ia hanya penanda bahwa isi berubah
            // tinggi, dan posisi perlu dihitung ulang.
            onHeightChange: { [weak self] _ in
                self?.reposition()
            },
            focus: composerFocus
        )
        let host = NSHostingView(rootView: bubble)
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentView = host

        self.panel = panel
        hostingView = host
        return panel
    }

    /// Tinggi panel diambil dari tinggi IDEAL isinya, bukan dari tinggi panel
    /// yang berlaku sekarang.
    ///
    /// Keduanya sempat saling mengunci: composer yang diberi baris kedua tidak
    /// bisa tumbuh karena panel tidak tumbuh, dan panel tidak tumbuh karena
    /// isinya — yang sudah telanjur dibatasi tinggi panel — tidak meminta ruang
    /// lebih. Akibatnya baris pertama terpotong. `fittingSize` menghitung tinggi
    /// yang diminta isi tanpa batasan itu, jadi ia memutus kuncian.
    ///
    /// Jendela Cocoa tumbuh ke atas dari origin-nya, sementara bubble ini
    /// ditambatkan di tepi ATAS — karena itu posisi ikut dihitung ulang setiap
    /// kali tingginya berubah.
    private func reposition(anchor: (rect: CGRect, screen: NSScreen)? = nil) {
        guard let panel, let anchor = anchor ?? buddy.characterScreenFrame else { return }
        let ideal = hostingView?.fittingSize.height ?? panel.frame.height
        let frame = BubblePlacement.frame(robot: anchor.rect,
                                          screen: anchor.screen.visibleFrame,
                                          contentHeight: ideal)
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
        guard !isSettling else { return }
        close()
    }
}
