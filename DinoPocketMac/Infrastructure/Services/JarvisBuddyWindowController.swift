//
//  JarvisBuddyWindowController.swift
//  DinoPocketMac
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
final class JarvisBuddyWindowController: NSWindowController {

    static let shared = JarvisBuddyWindowController()

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
    private var greeting: String?

    private let systemStatus: SystemStatusProviding = SystemStatusService()

    /// Posisi karakter saat berkeliaran. `nil` berarti diam di sudut kanan bawah.
    private var strollOrigin: CGPoint?

    // MARK: - Lifecycle

    private init() {
        let totalFrame = JarvisBuddyWindowController.totalScreenFrame()
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

    func startBuddyMode(store: PetStore,
                        settings: BuddySettingsStore,
                        onDismiss: (() -> Void)? = nil) {
        guard let window, let overlay else { return }

        dismissHandler = onDismiss
        characterSize = CGFloat(settings.size)
        isStrolling = settings.strolling
        strollOrigin = nil
        greeting = nil

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
        BuddyCharacterHost(size: characterSize, mood: mood, greeting: greeting)
    }

    private func refreshCharacter() {
        robotHostingView?.rootView = makeCharacterHost()
    }

    // MARK: - Esc to exit

    /// Satu-satunya jalan keluar dari Buddy Mode, karena tidak ada tombol di
    /// layar. Monitor lokal cukup: panel ini `.nonactivatingPanel`, jadi saat
    /// user menekan Esc app inilah yang aktif bila memang sedang berinteraksi.
    private func startEscMonitoring() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // 53 = Esc
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

    /// Dipanggil karakter saat diklik: balon sapaan singkat yang menghilang
    /// sendiri. Tidak ada UI reminder di sini — Buddy Mode tetap bersih.
    fileprivate func characterTapped() {
        greeting = Self.greetings.randomElement()
        refreshCharacter()

        Timer.scheduledTimer(withTimeInterval: 2.6, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.greeting = nil
                self?.refreshCharacter()
            }
        }
    }

    private static let greetings = [
        "Hey there.",
        "Still going strong?",
        "Water break?",
        "Stretch those shoulders.",
        "I'm right here.",
    ]
}

// MARK: - SwiftUI host

/// Pembungkus SwiftUI untuk karakter di dalam jendela buddy: model 3D, balon
/// sapaan opsional, dan penyesuaian halus terhadap `SystemMood`.
struct BuddyCharacterHost: View {
    let size: CGFloat
    let mood: SystemMood
    let greeting: String?

    var body: some View {
        ZStack(alignment: .top) {
            RobotCharacterView(size: size)
                // Saat mesin panas atau baterai menipis, karakter meredup dan
                // sedikit menunduk — isyarat yang terbaca tanpa perlu teks.
                .opacity(mood == .hot || mood == .lowBattery ? 0.75 : 1.0)
                .scaleEffect(mood == .hot ? 0.96 : 1.0, anchor: .bottom)
                .animation(.easeInOut(duration: 0.6), value: mood)

            if let greeting {
                Text(greeting)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 6, y: 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .offset(y: -6)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture {
            JarvisBuddyWindowController.shared.characterTapped()
        }
        .animation(.easeInOut(duration: 0.2), value: greeting)
    }
}
