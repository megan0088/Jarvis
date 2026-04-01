//
//  JarvisBuddyWindowController.swift
//  Jarvis
//
//  macOS only – creates a transparent floating window that lets Jarvis
//  roam freely across the desktop (and across multiple displays).
//

#if os(macOS)
import AppKit
import SpriteKit

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

    private var walkingScene: WalkingJarvisScene?
    private var skView: BuddyOverlayView?
    private var dismissHandler: (() -> Void)?
    private let smallButton = NSButton(title: "Small", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop Buddy", target: nil, action: nil)
    private let waterButton = NSButton(title: "Minum", target: nil, action: nil)
    private let stretchButton = NSButton(title: "Stretch", target: nil, action: nil)
    private let mealButton = NSButton(title: "Makan", target: nil, action: nil)
    private let resetWaterButton = NSButton(title: "Reset Water", target: nil, action: nil)
    private let resetStretchButton = NSButton(title: "Reset Stretch", target: nil, action: nil)
    private let resetMealButton = NSButton(title: "Reset Meal", target: nil, action: nil)
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

        configureTriggerButton(smallButton, title: "Small", action: #selector(makeCharacterSmall))
        configureTriggerButton(waterButton, title: "Minum", action: #selector(triggerWaterReminder))
        configureTriggerButton(stretchButton, title: "Stretch", action: #selector(triggerStretchReminder))
        configureTriggerButton(mealButton, title: "Makan", action: #selector(triggerMealReminder))
        configureTriggerButton(resetWaterButton, title: "Reset Water", action: #selector(resetWaterGoal))
        configureTriggerButton(resetStretchButton, title: "Reset Stretch", action: #selector(resetStretchGoal))
        configureTriggerButton(resetMealButton, title: "Reset Meal", action: #selector(resetMealGoal))

        controlStack.orientation = .horizontal
        controlStack.spacing = 10
        controlStack.alignment = .centerY
        controlStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        [smallButton, waterButton, stretchButton, mealButton, resetWaterButton, resetStretchButton, resetMealButton, stopButton].forEach(controlStack.addArrangedSubview)

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

        let scene = WalkingJarvisScene(size: totalFrame.size, store: store)
        // When Escape is pressed inside the scene, also notify the App to sync state.
        scene.onDismiss = { [weak self] in
            self?.stopBuddyMode()
            onDismiss?()
        }
        walkingScene = scene
        skView.shouldHandlePoint = { [weak self, weak scene] point in
            guard let self, let scene else { return false }
            if self.controlStack.frame.insetBy(dx: -8, dy: -8).contains(point) {
                return true
            }
            let scenePoint = scene.convertPoint(fromView: point)
            return scene.containsInteractiveContent(at: scenePoint)
        }

        skView.frame = CGRect(origin: .zero, size: totalFrame.size)
        skView.presentScene(scene)
        skView.addSubview(controlStack, positioned: .above, relativeTo: nil)
        startHoverMonitoring()

        window.orderFrontRegardless()
    }

    func stopBuddyMode() {
        walkingScene?.stopWalking()
        walkingScene = nil
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

    @objc
    private func makeCharacterSmall() {
        walkingScene?.minimizeCharacter()
    }

    @objc
    private func triggerWaterReminder() {
        walkingScene?.triggerDemoReminder(.water)
    }

    @objc
    private func triggerStretchReminder() {
        walkingScene?.triggerDemoReminder(.stretch)
    }

    @objc
    private func triggerMealReminder() {
        walkingScene?.triggerDemoReminder(.meal)
    }

    @objc
    private func resetWaterGoal() {
        walkingScene?.resetGoal(.water)
    }

    @objc
    private func resetStretchGoal() {
        walkingScene?.resetGoal(.stretch)
    }

    @objc
    private func resetMealGoal() {
        walkingScene?.resetGoal(.meal)
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

    private func configureTriggerButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }
}
#endif
