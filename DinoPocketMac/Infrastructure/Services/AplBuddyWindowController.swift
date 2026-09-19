//
//  AplBuddyWindowController.swift
//  AplMac
//
//  Jendela melayang tembus pandang yang menampung karakter 3D di atas desktop,
//  melintasi seluruh layar yang terpasang.
//
//  Buddy Mode BERSIH (keputusan terkunci, spec Fase A §4.1): hanya karakter yang
//  tampil. Tanpa panel statistik, tanpa tombol di layar. Keluar lewat Esc.
//

import AppKit
import SwiftUI

/// Lapisan tembus pandang selebar seluruh layar yang menampung karakter.
///
/// Dulunya `SKView`, peninggalan karakter SpriteKit. Setelah karakter 2D
/// dikarantina, view ini tidak pernah lagi menampilkan scene — dan **SKView tanpa
/// scene merender latar buram**, sehingga seluruh desktop tertutup kotak abu-abu.
///
/// `NSView` polos tidak menggambar apa pun, jadi transparansinya gratis.
private final class BuddyOverlayView: NSView {
    var shouldHandlePoint: ((CGPoint) -> Bool)?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point), hit !== self {
            return hit
        }
        return shouldHandlePoint?(point) == true ? self : nil
    }
}

@MainActor
final class AplBuddyWindowController: NSWindowController {

    static let shared = AplBuddyWindowController(systemStatus: SystemStatusService())

    // MARK: - State

    private var robotHostingView: NSHostingView<BuddyCharacterHost>?
    private var overlay: BuddyOverlayView?
    private var dismissHandler: (() -> Void)?

    private var hoverTimer: Timer?
    private var strollTimer: Timer?
    private var moodTimer: Timer?
    private var escMonitor: Any?

    private var characterSize: CGFloat = CGFloat(BuddySettingsStore.defaultSize)
    private var isStrolling = false
    private var mood: SystemMood = .normal

    /// Dipasang app saat Buddy Mode menyala: klik pada karakter berarti
    /// "ajak bicara" (spec C1 §2 #4).
    var onCharacterTap: (() -> Void)?

    private let systemStatus: SystemStatusProviding

    /// Posisi karakter saat berkeliaran. `nil` berarti diam di sudut kanan bawah.
    private var strollOrigin: CGPoint?

    // MARK: - Lifecycle

    init(systemStatus: SystemStatusProviding) {
        self.systemStatus = systemStatus
        let totalFrame = AplBuddyWindowController.totalScreenFrame()
        let win = NSPanel(
            contentRect: totalFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false
        win.becomesKeyOnlyIfNeeded = true

        let view = BuddyOverlayView(frame: CGRect(origin: .zero, size: totalFrame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor.clear
        win.contentView = view

        super.init(window: win)
        overlay = view
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Public API

    /// Tidak menerima store: sejak Buddy Mode dibersihkan, karakter tidak lagi
    /// menampilkan statistik apa pun. Parameter `store` yang sempat bertahan
    /// hanyalah sisa era demo, dan membiarkannya memaksa pemanggil membuat
    /// instance WellnessStore kedua — dua sumber kebenaran untuk data yang sama.
    func startBuddyMode(settings: BuddySettingsStore,
                        onDismiss: (() -> Void)? = nil) {
        guard let window, let overlay else { return }

        dismissHandler = onDismiss
        characterSize = CGFloat(settings.size)
        isStrolling = settings.strolling
        strollOrigin = nil

        let totalFrame = Self.totalScreenFrame()
        window.setFrame(totalFrame, display: false)
        overlay.frame = CGRect(origin: .zero, size: totalFrame.size)

        apply(opacity: settings.opacity)
        apply(keepOnTop: settings.keepOnTop)

        mood = systemStatus.currentMood()

        robotHostingView?.removeFromSuperview()
        let host = NSHostingView(rootView: makeCharacterHost())
        host.frame = characterFrame(size: characterSize)
        host.autoresizingMask = [.minXMargin, .maxYMargin]

        // NSHostingView menggambar latarnya sendiri; tanpa ini, karakter yang
        // sudah bening tetap duduk di dalam kotak buram.
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor

        overlay.addSubview(host)
        robotHostingView = host

        // Hanya area karakter yang menangkap klik; sisanya tembus ke app lain.
        overlay.shouldHandlePoint = { [weak self] point in
            guard let self, let host = self.robotHostingView else { return false }
            return host.frame.contains(point)
        }

        startHoverMonitoring()
        startEscMonitoring()
        startMoodPolling()
        if isStrolling { scheduleNextStroll() }

        window.orderFrontRegardless()
    }

    func stopBuddyMode() {
        robotHostingView?.removeFromSuperview()
        robotHostingView = nil

        [hoverTimer, strollTimer, moodTimer].forEach { $0?.invalidate() }
        hoverTimer = nil; strollTimer = nil; moodTimer = nil

        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }

        overlay?.shouldHandlePoint = nil
        window?.ignoresMouseEvents = false
        window?.orderOut(nil)
    }

    // MARK: - Live settings

    func updateCharacterSize(_ size: CGFloat) {
        characterSize = size
        guard let host = robotHostingView else { return }
        host.rootView = makeCharacterHost()
        host.frame = characterFrame(size: size)
    }

    func apply(opacity: Double) {
        window?.alphaValue = CGFloat(BuddySettingsStore.clampOpacity(opacity))
    }

    /// Tanpa keep-on-top karakter tetap ada tapi tenggelam di belakang jendela
    /// kerja — `.normal` menaruhnya sejajar jendela biasa, bukan menyembunyikannya.
    func apply(keepOnTop: Bool) {
        window?.level = keepOnTop ? .floating : .normal
    }

    func apply(strolling: Bool) {
        isStrolling = strolling
        strollTimer?.invalidate()
        strollTimer = nil

        if strolling {
            scheduleNextStroll()
        } else {
            // Kembali ke sudut kanan bawah saat dimatikan, supaya karakter tidak
            // tertinggal di tengah layar tanpa cara mengembalikannya.
            strollOrigin = nil
            moveCharacter(to: characterFrame(size: characterSize), animated: true)
        }
    }

    // MARK: - Character host

    private func makeCharacterHost() -> BuddyCharacterHost {
        BuddyCharacterHost(size: characterSize, mood: mood)
    }

    private func refreshCharacter() {
        robotHostingView?.rootView = makeCharacterHost()
    }

    // MARK: - Esc to exit

    /// Jalan keluar dari Buddy Mode lewat keyboard. Monitor lokal cukup: panel
    /// ini `.nonactivatingPanel`, jadi saat user menekan Esc app inilah yang
    /// aktif bila memang sedang berinteraksi.
    ///
    /// Esc yang ditujukan ke jendela biasa (jendela utama, Settings, dialog)
    /// dibiarkan lewat. Di jendela utama Esc menghentikan jawaban (spec B §7),
    /// dan Buddy Mode dimatikan lewat tombol Hide Buddy di sana.
    private func startEscMonitoring() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // 53 = Esc
            if let target = event.window, target !== self?.window { return event }
            self?.stopBuddyMode()
            self?.dismissHandler?()
            return nil                                        // konsumsi event
        }
    }

    // MARK: - Mood

    private func startMoodPolling() {
        moodTimer?.invalidate()
        // 30 detik: cukup responsif untuk perubahan termal/daya, cukup jarang
        // agar tidak membangunkan CPU tanpa alasan (spec §10, beban baterai).
        moodTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let next = self.systemStatus.currentMood()
                guard next != self.mood else { return }
                self.mood = next
                self.refreshCharacter()
            }
        }
    }

    // MARK: - Strolling

    private func scheduleNextStroll() {
        strollTimer?.invalidate()
        // Jeda acak 20–60 detik, sesuai spec §4.1. Interval tetap akan terbaca
        // sebagai mesin, bukan makhluk.
        let delay = Double.random(in: 20...60)
        strollTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.strollToRandomSpot()
            }
        }
    }

    private func strollToRandomSpot() {
        guard isStrolling, let window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? window.frame

        let margin: CGFloat = 24
        let maxX = max(visible.width - characterSize - margin * 2, 1)
        let maxY = max(visible.height - characterSize - margin * 2, 1)

        let target = CGRect(
            x: visible.minX - window.frame.origin.x + margin + CGFloat.random(in: 0...maxX),
            y: visible.minY - window.frame.origin.y + margin + CGFloat.random(in: 0...maxY),
            width: characterSize, height: characterSize
        )

        strollOrigin = target.origin
        moveCharacter(to: target, animated: true)
        scheduleNextStroll()
    }

    private func moveCharacter(to frame: CGRect, animated: Bool) {
        guard let host = robotHostingView else { return }
        guard animated else { host.frame = frame; return }

        NSAnimationContext.runAnimationGroup { context in
            // Lambat dan ease-in-out: perpindahan cepat di atas jendela kerja
            // terasa mengganggu, bukan hidup.
            context.duration = 2.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            host.animator().frame = frame
        }
    }

    // MARK: - Geometry

    /// Karakter berdiri di pojok kanan bawah **area yang benar-benar terlihat**.
    ///
    /// Memakai `visibleFrame`, bukan `frame`: `frame` mencakup ruang di balik Dock
    /// dan menu bar, sehingga margin tetap dari tepi bawah layar menempatkan
    /// karakter tepat di belakang Dock.
    private func characterFrame(size: CGFloat) -> CGRect {
        let windowFrame = window?.frame ?? Self.totalScreenFrame()

        if let origin = strollOrigin {
            return CGRect(origin: origin, size: CGSize(width: size, height: size))
        }

        let margin: CGFloat = 24
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? windowFrame

        return CGRect(x: visible.maxX - windowFrame.origin.x - size - margin,
                      y: visible.minY - windowFrame.origin.y + margin,
                      width: size, height: size)
    }

    /// Union seluruh layar terpasang (menangani multi-display).
    static func totalScreenFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    /// Frame karakter dalam koordinat layar, beserta layar tempat ia berdiri.
    ///
    /// `nil` selama Buddy Mode mati atau karakter belum dipasang — pemanggil
    /// memakainya untuk memutuskan bahwa tidak ada yang bisa dijangkari.
    var characterScreenFrame: (rect: CGRect, screen: NSScreen)? {
        guard let window, let host = robotHostingView else { return nil }
        let rect = window.convertToScreen(host.frame)
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) })
                ?? NSScreen.main else { return nil }
        return (rect, screen)
    }

    /// Robot berhenti melangkah selama bubble terbuka: bubble dijangkari ke
    /// posisinya, dan jangkar yang bergerak 2,4 detik sekali akan menyeret
    /// kolom tulis yang sedang diketik.
    func pauseStrolling() {
        strollTimer?.invalidate()
        strollTimer = nil
    }

    func resumeStrolling() {
        guard isStrolling, strollTimer == nil else { return }
        scheduleNextStroll()
    }

    // MARK: - Click-through

    private func startHoverMonitoring() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let window = self.window, let overlay = self.overlay else { return }
                let mouseInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
                let mouseInView = overlay.convert(mouseInWindow, from: nil)
                window.ignoresMouseEvents = !(overlay.shouldHandlePoint?(mouseInView) ?? false)
            }
        }
    }

    // MARK: - Interaction

    /// Klik pada karakter berarti "ajak bicara" (spec C1 §2 #4).
    ///
    /// Kalimat sapaan acak yang dulu muncul di sini dihapus: ia tidak punya
    /// aturan, tidak punya kuota, dan tidak bisa dijawab. Sapaan yang muncul
    /// sendiri adalah urusan C2.
    fileprivate func characterTapped() {
        onCharacterTap?()
    }
}

// MARK: - SwiftUI host

/// Pembungkus SwiftUI untuk karakter di dalam jendela buddy: model 3D dan
/// penyesuaian halus terhadap `SystemMood`.
struct BuddyCharacterHost: View {
    let size: CGFloat
    let mood: SystemMood

    /// Mood mesin dipetakan ke perilaku karakter di sini, bukan di dalam view
    /// aset — pemilihan ekspresi adalah urusan aset, penerjemahan kondisi
    /// sistem adalah urusan buddy.
    ///
    /// `.busy` sengaja dibedakan dari `.normal`. Sebelumnya keduanya
    /// menghasilkan perilaku yang sama persis, sehingga perbedaan yang sudah
    /// susah payah dihitung `SystemMood.from(thermalState:...)` tidak pernah
    /// sampai ke layar.
    private var behavior: CharacterBehavior {
        switch mood {
        case .hot, .lowBattery: .sleepy
        case .busy:             .thinking
        case .normal:           .idle
        }
    }

    var body: some View {
        USDZCharacterView(size: size, asset: .robot, behavior: behavior)
            // Saat mesin panas atau baterai menipis, karakter meredup dan
            // sedikit menunduk — isyarat yang terbaca tanpa perlu teks.
            .opacity(mood == .hot || mood == .lowBattery ? 0.75 : 1.0)
            .scaleEffect(mood == .hot ? 0.96 : 1.0, anchor: .bottom)
            .animation(.easeInOut(duration: 0.6), value: mood)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture {
                AplBuddyWindowController.shared.characterTapped()
            }
    }
}
