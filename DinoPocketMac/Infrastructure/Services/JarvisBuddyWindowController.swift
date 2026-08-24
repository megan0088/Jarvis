//
//  JarvisBuddyWindowController.swift
//  Jarvis
//
//  macOS only – creates a transparent floating window that lets Jarvis
//  roam freely across the desktop (and across multiple displays).
//

import AppKit
import SwiftUI

/// Lapisan tembus pandang selebar seluruh layar yang menampung karakter.
///
/// Dulunya `SKView`, peninggalan karakter SpriteKit. Setelah karakter 2D
/// dikarantina, view ini tidak pernah lagi menampilkan scene — dan **SKView tanpa
/// scene merender latar buram**, sehingga seluruh desktop tertutup kotak abu-abu.
/// Itulah "background tidak bening" yang terlihat, bukan salah RealityView.
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

final class JarvisBuddyWindowController: NSWindowController {

    // MARK: - Singleton / lifecycle

    static let shared = JarvisBuddyWindowController()

    private var robotHostingView: NSView?
    private var overlay: BuddyOverlayView?
    private var dismissHandler: (() -> Void)?
    private let stopButton = NSButton(title: "Stop Buddy", target: nil, action: nil)
    private let controlStack = NSStackView()
    private var hoverTimer: Timer?
    private var characterSize: CGFloat = CGFloat(BuddySettingsStore.defaultSize)

    private init() {
        // Build a borderless, transparent window that covers all screens.
        let totalFrame = JarvisBuddyWindowController.totalScreenFrame()
        let win = NSPanel(
            contentRect: totalFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.level = .floating                     // always on top
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = false            // we DO want clicks
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false
        win.becomesKeyOnlyIfNeeded = true

        // Lapisan tembus pandang memenuhi seluruh window
        let view = BuddyOverlayView(frame: CGRect(origin: .zero, size: totalFrame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor.clear
        win.contentView = view

        super.init(window: win)

        stopButton.bezelStyle = .rounded
        stopButton.controlSize = .large
        stopButton.title = "Stop Buddy"
        stopButton.target = self
        stopButton.action = #selector(stopButtonTapped)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.setButtonType(.momentaryPushIn)


        controlStack.orientation = .horizontal
        controlStack.spacing = 10
        controlStack.alignment = .centerY
        controlStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        [stopButton].forEach(controlStack.addArrangedSubview)

        view.addSubview(controlStack)
        NSLayoutConstraint.activate([
            controlStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            controlStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        overlay = view
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Public API

    func startBuddyMode(store: PetStore,
                        size: CGFloat = CGFloat(BuddySettingsStore.defaultSize),
                        onDismiss: (() -> Void)? = nil) {
        guard let window, let overlay else { return }
        dismissHandler = onDismiss
        characterSize = size

        let totalFrame = JarvisBuddyWindowController.totalScreenFrame()
        window.setFrame(totalFrame, display: false)

        overlay.frame = CGRect(origin: .zero, size: totalFrame.size)

        // Floating 3D robot (Robot.usdz) at the bottom-right of the desktop.
        robotHostingView?.removeFromSuperview()
        let host = NSHostingView(rootView: RobotCharacterView(size: size))
        host.frame = Self.characterFrame(size: size, in: totalFrame)
        host.autoresizingMask = [.minXMargin, .maxYMargin]

        // Bagian dari rantai transparansi: NSHostingView menggambar latarnya
        // sendiri, jadi ARView yang sudah bening pun tetap tertutup kotak buram
        // kalau baris-baris ini dilewat.
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor

        overlay.addSubview(host)
        robotHostingView = host

        // Only the control buttons are interactive; the rest stays click-through.
        overlay.shouldHandlePoint = { [weak self] point in
            guard let self else { return false }
            return self.controlStack.frame.insetBy(dx: -8, dy: -8).contains(point)
        }

        overlay.addSubview(controlStack, positioned: .above, relativeTo: nil)
        startHoverMonitoring()

        window.orderFrontRegardless()

    }

    func stopBuddyMode() {
        robotHostingView?.removeFromSuperview()
        robotHostingView = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
        overlay?.shouldHandlePoint = nil
        window?.ignoresMouseEvents = false
        window?.orderOut(nil)
    }

    @objc
    private func stopButtonTapped() {
        stopBuddyMode()
        dismissHandler?()
    }








    // MARK: - Helpers

    /// Perubahan ukuran diterapkan langsung tanpa memulai ulang Buddy Mode,
    /// supaya slider di Settings terasa hidup saat digeser.
    func updateCharacterSize(_ size: CGFloat) {
        characterSize = size
        guard let window,
              let host = robotHostingView as? NSHostingView<RobotCharacterView> else { return }
        host.rootView = RobotCharacterView(size: size)
        host.frame = Self.characterFrame(size: size, in: window.frame)
    }

    /// Karakter berdiri di pojok kanan bawah **area yang benar-benar terlihat**.
    ///
    /// Memakai `visibleFrame`, bukan `frame`: `frame` mencakup ruang di balik Dock
    /// dan menu bar, sehingga margin tetap dari tepi bawah layar menempatkan
    /// karakter tepat di belakang Dock. `visibleFrame` sudah mengecualikan
    /// keduanya, jadi posisinya ikut menyesuaikan sendiri saat Dock dipindah,
    /// disembunyikan, atau berubah ukuran.
    private static func characterFrame(size: CGFloat, in windowFrame: CGRect) -> CGRect {
        let margin: CGFloat = 24
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? windowFrame

        // visibleFrame memakai koordinat layar global; overlay memakai koordinat
        // window yang beroriginkan sudut kiri-bawah gabungan seluruh layar.
        let x = visible.maxX - windowFrame.origin.x - size - margin
        let y = visible.minY - windowFrame.origin.y + margin

        return CGRect(x: x, y: y, width: size, height: size)
    }

    /// Returns the union rect of all connected screens (handles multi-display).
    static func totalScreenFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    private func startHoverMonitoring() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let window, let overlay else { return }
            let mouseInScreen = NSEvent.mouseLocation
            let mouseInWindow = window.convertPoint(fromScreen: mouseInScreen)
            let mouseInView = overlay.convert(mouseInWindow, from: nil)
            let shouldHandle = overlay.shouldHandlePoint?(mouseInView) ?? false
            window.ignoresMouseEvents = !shouldHandle
        }
    }

}
