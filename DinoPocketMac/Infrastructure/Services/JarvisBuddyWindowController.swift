//
//  JarvisBuddyWindowController.swift
//  Jarvis
//
//  macOS only – creates a transparent floating window that lets Jarvis
//  roam freely across the desktop (and across multiple displays).
//

import AppKit
import SpriteKit
import SwiftUI

private final class BuddyOverlayView: SKView {
    var shouldHandlePoint: ((CGPoint) -> Bool)?

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
    private var skView: BuddyOverlayView?
    private var dismissHandler: (() -> Void)?
    private let stopButton = NSButton(title: "Stop Buddy", target: nil, action: nil)
    private let controlStack = NSStackView()
    private var hoverTimer: Timer?

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

        // SKView fills the whole window
        let view = BuddyOverlayView(frame: CGRect(origin: .zero, size: totalFrame.size))
        view.allowsTransparency = true
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

        skView = view
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Public API

    func startBuddyMode(store: PetStore, onDismiss: (() -> Void)? = nil) {
        guard let window, let skView else { return }
        dismissHandler = onDismiss

        let totalFrame = JarvisBuddyWindowController.totalScreenFrame()
        window.setFrame(totalFrame, display: false)

        skView.frame = CGRect(origin: .zero, size: totalFrame.size)
        skView.presentScene(nil) // no SpriteKit character — 3D robot instead

        // Floating 3D robot (Robot.usdz) at the bottom-right of the desktop.
        robotHostingView?.removeFromSuperview()
        let robotSize: CGFloat = 260
        let host = NSHostingView(rootView: RobotCharacterView(size: robotSize))
        host.frame = CGRect(x: totalFrame.width - robotSize - 40,
                            y: 40,
                            width: robotSize, height: robotSize)
        host.autoresizingMask = [.minXMargin, .maxYMargin]
        skView.addSubview(host)
        robotHostingView = host

        // Only the control buttons are interactive; the rest stays click-through.
        skView.shouldHandlePoint = { [weak self] point in
            guard let self else { return false }
            return self.controlStack.frame.insetBy(dx: -8, dy: -8).contains(point)
        }

        skView.addSubview(controlStack, positioned: .above, relativeTo: nil)
        startHoverMonitoring()

        window.orderFrontRegardless()

    }

    func stopBuddyMode() {
        robotHostingView?.removeFromSuperview()
        robotHostingView = nil
        skView?.presentScene(nil)
        hoverTimer?.invalidate()
        hoverTimer = nil
        skView?.shouldHandlePoint = nil
        window?.ignoresMouseEvents = false
        window?.orderOut(nil)
    }

    @objc
    private func stopButtonTapped() {
        stopBuddyMode()
        dismissHandler?()
    }








    // MARK: - Helpers

    /// Returns the union rect of all connected screens (handles multi-display).
    static func totalScreenFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    private func startHoverMonitoring() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let window, let skView else { return }
            let mouseInScreen = NSEvent.mouseLocation
            let mouseInWindow = window.convertPoint(fromScreen: mouseInScreen)
            let mouseInView = skView.convert(mouseInWindow, from: nil)
            let shouldHandle = skView.shouldHandlePoint?(mouseInView) ?? false
            window.ignoresMouseEvents = !shouldHandle
        }
    }

}
