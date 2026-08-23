//
//  WalkingJarvisScene.swift
//  Jarvis
//
//  macOS only – SKScene that makes Jarvis roam freely across the desktop.
//  The scene is sized to cover all connected screens; the Jarvis sprite walks
//  left/right, bounces at the screen edges, and occasionally idles.
//

#if os(macOS)
import SpriteKit
import AppKit
import AVFoundation

final class WalkingJarvisScene: SKScene {
    private enum ChatDestination {
        static let url = URL(string: "https://chatgpt.com")!
    }

    private struct VoiceStyle {
        let language: String
        let volume: Float
        let rate: Float
        let pitch: Float

        static let tap = VoiceStyle(language: "en-US", volume: 0.24, rate: 0.58, pitch: 1.5)
        static let reply = VoiceStyle(language: "en-US", volume: 0.31, rate: 0.47, pitch: 1.15)
        static let reminder = VoiceStyle(language: "en-US", volume: 0.28, rate: 0.56, pitch: 1.35)
    }

    private struct AssistantSignal {
        let header: String
        let detail: String
        let accent: NSColor
    }

    // Called when the user presses Escape or the scene should be dismissed.
    var onDismiss: (() -> Void)?

    // MARK: - Jarvis node tree (same visual as JarvisScene)
    private let jarvisRoot    = SKNode()
    private let body          = SKShapeNode(rectOf: CGSize(width: 144, height: 172), cornerRadius: 42)
    private let belly         = SKShapeNode(rectOf: CGSize(width: 96, height: 104), cornerRadius: 32)
    private let coreGlow      = SKShapeNode(circleOfRadius: 32)
    private let head          = SKShapeNode(rectOf: CGSize(width: 132, height: 102), cornerRadius: 34)
    private let snout         = SKShapeNode(rectOf: CGSize(width: 92, height: 56), cornerRadius: 22)
    private let lowerJaw      = SKShapeNode(rectOf: CGSize(width: 80, height: 18), cornerRadius: 9)
    private let leftEye       = SKShapeNode(rectOf: CGSize(width: 18, height: 20), cornerRadius: 6)
    private let rightEye      = SKShapeNode(rectOf: CGSize(width: 18, height: 20), cornerRadius: 6)
    private let leftBlush     = SKShapeNode(circleOfRadius: 8)
    private let rightBlush    = SKShapeNode(circleOfRadius: 8)
    private let tail          = SKShapeNode()
    private let spikes        = SKShapeNode()
    private let leftLeg       = SKShapeNode(rectOf: CGSize(width: 22, height: 36), cornerRadius: 10)
    private let rightLeg      = SKShapeNode(rectOf: CGSize(width: 22, height: 36), cornerRadius: 10)
    private let leftArm       = SKShapeNode(rectOf: CGSize(width: 14, height: 30), cornerRadius: 7)
    private let rightArm      = SKShapeNode(rectOf: CGSize(width: 14, height: 30), cornerRadius: 7)
    private let hudPanel      = SKShapeNode(rectOf: CGSize(width: 280, height: 112), cornerRadius: 22)
    private let hudGlow       = SKShapeNode(rectOf: CGSize(width: 284, height: 116), cornerRadius: 24)
    private let radarOuterRing = SKShapeNode(circleOfRadius: 28)
    private let radarInnerRing = SKShapeNode(circleOfRadius: 16)
    private let scanLine      = SKShapeNode(rectOf: CGSize(width: 44, height: 2), cornerRadius: 1)
    private let moodLabel     = SKLabelNode(fontNamed: "SFProDisplay-Semibold")
    private let statsLabel    = SKLabelNode(fontNamed: "SFMono-Regular")
    private let statusLabel   = SKLabelNode(fontNamed: "SFProText-Regular")
    private let goalLabel     = SKLabelNode(fontNamed: "SFMono-Regular")
    private let reactionLabel = SKLabelNode(fontNamed: "SFProDisplay-Bold")
    private let reminderPrompt = SKShapeNode(rectOf: CGSize(width: 360, height: 150), cornerRadius: 26)
    private let reminderTitle = SKLabelNode(fontNamed: "SFProDisplay-Bold")
    private let reminderBodyTop = SKLabelNode(fontNamed: "SFProText-Regular")
    private let reminderBodyBottom = SKLabelNode(fontNamed: "SFProText-Regular")
    private let doneButton = SKShapeNode(rectOf: CGSize(width: 120, height: 38), cornerRadius: 14)
    private let laterButton = SKShapeNode(rectOf: CGSize(width: 120, height: 38), cornerRadius: 14)

    // MARK: - State
    private var store: PetStore
    private var isIdle = false
    private var currentMood: PetStore.Mood
    private var lastChatOpenAt: TimeInterval = 0
    private var lastClickVoiceAt: TimeInterval = 0
    private var lastReplyVoiceAt: TimeInterval = 0
    private var lastReminderVoiceAt: TimeInterval = 0
    private let walkSpeed: CGFloat = 170   // points per second
    private let jarvisHalfWidth: CGFloat = 110
    private let jarvisHalfHeight: CGFloat = 120
    private let cursorChaseDistance: CGFloat = 220
    private var shownReminderKeys: Set<String> = []
    private var lastReminderBucket = -1
    private var activeReminder: PetStore.BuddyReminder?
    private let clickSpeech = AVSpeechSynthesizer()
    private let replySpeech = AVSpeechSynthesizer()
    private let reminderSpeech = AVSpeechSynthesizer()
    private let idleScale: CGFloat = 0.68
    private let activeScale: CGFloat = 0.82
    private let reminderScale: CGFloat = 1.0

    // Ground level – Jarvis sits at ~10% from bottom of the scene.
    private var groundY: CGFloat { size.height * 0.10 }

    // MARK: - Init
    init(size: CGSize, store: PetStore) {
        self.store = store
        self.currentMood = store.mood
        super.init(size: size)
        anchorPoint = .zero          // origin at bottom-left (matches NSScreen)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) { fatalError("not used") }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        view.allowsTransparency = true

        buildJarvis()
        jarvisRoot.position = CGPoint(x: size.width / 2, y: groundY + 90)
        jarvisRoot.setScale(idleScale)
        addChild(jarvisRoot)

        startIdleAnimations()
        setupHUD()
        setupReminderPrompt()
        applyExpression(animated: false)
        refreshHUD()
        checkReminderPrompt(force: true)
        scheduleNextBehavior()
    }

    // MARK: - Build Jarvis

    private func buildJarvis() {
        // Body
        body.fillColor  = RobotStyle.shell
        body.strokeColor = RobotStyle.outline
        body.lineWidth = 1.5
        jarvisRoot.addChild(body)

        coreGlow.fillColor = RobotStyle.bellyGlow(for: store.mood)
        coreGlow.strokeColor = .clear
        coreGlow.position = CGPoint(x: 0, y: -4)
        coreGlow.alpha = 0.9
        body.addChild(coreGlow)

        belly.fillColor  = RobotStyle.bellyGlow(for: store.mood)
        belly.strokeColor = .clear
        belly.position   = CGPoint(x: 0, y: -8)
        body.addChild(belly)

        // Head
        head.fillColor  = RobotStyle.shell
        head.strokeColor = RobotStyle.outline
        head.lineWidth = 1.5
        head.position   = CGPoint(x: 0, y: 92)
        jarvisRoot.addChild(head)

        snout.fillColor  = RobotStyle.facePanel
        snout.strokeColor = .clear
        snout.position   = CGPoint(x: 0, y: 0)
        head.addChild(snout)

        lowerJaw.fillColor  = RobotStyle.accent(for: store.mood)
        lowerJaw.strokeColor = .clear
        lowerJaw.position   = CGPoint(x: 0, y: -18)
        snout.addChild(lowerJaw)

        // Nostrils
        let nostrilL = SKShapeNode(circleOfRadius: 3.5)
        nostrilL.fillColor = RobotStyle.accent(for: store.mood)
        nostrilL.strokeColor = .clear
        nostrilL.position = CGPoint(x: -28, y: 22)
        let nostrilR = nostrilL.copy() as! SKShapeNode
        nostrilR.position = CGPoint(x: 28, y: 22)
        snout.addChild(nostrilL); snout.addChild(nostrilR)

        // Teeth
        let teethPath = CGMutablePath()
        teethPath.addRoundedRect(in: CGRect(x: -18, y: 18, width: 36, height: 8), cornerWidth: 4, cornerHeight: 4)
        let teeth = SKShapeNode(path: teethPath)
        teeth.fillColor = RobotStyle.accent(for: store.mood); teeth.strokeColor = .clear
        teeth.alpha = 0.7
        snout.addChild(teeth)

        // Eyes & blush
        leftEye.fillColor = RobotStyle.accent(for: store.mood); leftEye.strokeColor = .clear
        leftEye.position  = CGPoint(x: -22, y: 10)
        rightEye.fillColor = RobotStyle.accent(for: store.mood); rightEye.strokeColor = .clear
        rightEye.position  = CGPoint(x: 22, y: 10)
        head.addChild(leftEye); head.addChild(rightEye)

        leftBlush.fillColor  = RobotStyle.blush(for: store.mood)
        leftBlush.strokeColor = .clear
        leftBlush.position   = CGPoint(x: -38, y: -16)
        rightBlush.fillColor  = RobotStyle.blush(for: store.mood)
        rightBlush.strokeColor = .clear
        rightBlush.position   = CGPoint(x: 38, y: -16)
        head.addChild(leftBlush); head.addChild(rightBlush)

        // Tail
        tail.path = RobotStyle.antennaPath()
        tail.fillColor = .clear
        tail.strokeColor = RobotStyle.accent(for: store.mood)
        tail.lineWidth = 4
        tail.position = CGPoint(x: 0, y: 132)
        tail.zPosition = -1
        jarvisRoot.addChild(tail)

        // Spikes
        let sp = CGMutablePath()
        for i in 0..<5 {
            let x = CGFloat(i - 2) * 26
            sp.move(to: CGPoint(x: x, y: 70))
            sp.addLine(to: CGPoint(x: x + 12, y: 110))
            sp.addLine(to: CGPoint(x: x + 24, y: 70))
        }
        let capPath = CGMutablePath()
        capPath.addRoundedRect(in: CGRect(x: -18, y: 0, width: 36, height: 8), cornerWidth: 4, cornerHeight: 4)
        spikes.path = capPath
        spikes.fillColor = RobotStyle.accent(for: store.mood)
        spikes.strokeColor = .clear
        spikes.zPosition = -0.5
        spikes.position = CGPoint(x: 0, y: 152)
        jarvisRoot.addChild(spikes)

        // Arms & legs
        leftArm.fillColor = RobotStyle.shell; leftArm.strokeColor = RobotStyle.limbOutline
        leftArm.lineWidth = 1
        leftArm.position  = CGPoint(x: -84, y: 4); leftArm.zRotation = -.pi/8
        rightArm.fillColor = RobotStyle.shell; rightArm.strokeColor = RobotStyle.limbOutline
        rightArm.lineWidth = 1
        rightArm.position  = CGPoint(x: 84, y: 4); rightArm.zRotation = .pi/8
        jarvisRoot.addChild(leftArm); jarvisRoot.addChild(rightArm)

        leftLeg.fillColor = RobotStyle.shell
        leftLeg.strokeColor = RobotStyle.limbOutline
        leftLeg.lineWidth = 1
        leftLeg.position = CGPoint(x: -24, y: -114)
        rightLeg.fillColor = RobotStyle.shell
        rightLeg.strokeColor = RobotStyle.limbOutline
        rightLeg.lineWidth = 1
        rightLeg.position = CGPoint(x: 24, y: -114)
        jarvisRoot.addChild(leftLeg); jarvisRoot.addChild(rightLeg)
    }

    // MARK: - Idle animations (bob + blink + tail swing)

    private func startIdleAnimations() {
        let float = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 12, duration: 1.2),
            SKAction.moveBy(x: 0, y: -12, duration: 1.2)
        ]))
        body.run(float)

        let glowPulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.8),
            SKAction.fadeAlpha(to: 0.55, duration: 0.8)
        ]))
        coreGlow.run(glowPulse)

        // Tail swing
        let swing = SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: CGFloat(12).degreesToRadians, duration: 0.7, shortestUnitArc: true),
            SKAction.rotate(toAngle: CGFloat(-10).degreesToRadians, duration: 0.7, shortestUnitArc: true)
        ]))
        tail.run(swing)

        // Blink loop
        runBlinkLoop()
    }

    private func setupHUD() {
        hudGlow.fillColor = .clear
        hudGlow.strokeColor = NSColor.systemCyan.withAlphaComponent(0.18)
        hudGlow.lineWidth = 1.5
        hudGlow.glowWidth = 12
        hudGlow.position = CGPoint(x: 176, y: size.height - 86)
        hudGlow.zPosition = 49
        addChild(hudGlow)

        hudPanel.fillColor = NSColor(red: 0.03, green: 0.08, blue: 0.16, alpha: 0.80)
        hudPanel.strokeColor = NSColor.systemCyan.withAlphaComponent(0.48)
        hudPanel.lineWidth = 1.2
        hudPanel.position = CGPoint(x: 176, y: size.height - 86)
        hudPanel.zPosition = 50
        addChild(hudPanel)

        radarOuterRing.strokeColor = NSColor.systemCyan.withAlphaComponent(0.55)
        radarOuterRing.fillColor = .clear
        radarOuterRing.lineWidth = 1.1
        radarOuterRing.position = CGPoint(x: 98, y: 14)
        hudPanel.addChild(radarOuterRing)

        radarInnerRing.strokeColor = NSColor.systemCyan.withAlphaComponent(0.28)
        radarInnerRing.fillColor = NSColor.systemCyan.withAlphaComponent(0.08)
        radarInnerRing.lineWidth = 1
        radarInnerRing.position = CGPoint(x: 98, y: 14)
        hudPanel.addChild(radarInnerRing)

        scanLine.fillColor = NSColor.systemCyan.withAlphaComponent(0.85)
        scanLine.strokeColor = .clear
        scanLine.position = CGPoint(x: 98, y: 14)
        scanLine.zRotation = .pi / 8
        scanLine.glowWidth = 3
        hudPanel.addChild(scanLine)
        scanLine.run(
            .repeatForever(
                .sequence([
                    .rotate(byAngle: .pi, duration: 1.8),
                    .rotate(byAngle: .pi, duration: 1.8)
                ])
            ),
            withKey: "scanSweep"
        )

        moodLabel.fontSize = 20
        moodLabel.horizontalAlignmentMode = .left
        moodLabel.verticalAlignmentMode = .center
        moodLabel.position = CGPoint(x: -122, y: 22)
        hudPanel.addChild(moodLabel)

        statsLabel.fontSize = 14
        statsLabel.horizontalAlignmentMode = .left
        statsLabel.verticalAlignmentMode = .center
        statsLabel.fontColor = NSColor.systemCyan.withAlphaComponent(0.92)
        statsLabel.position = CGPoint(x: -122, y: -4)
        hudPanel.addChild(statsLabel)

        statusLabel.fontSize = 12
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.verticalAlignmentMode = .center
        statusLabel.fontColor = NSColor.white.withAlphaComponent(0.86)
        statusLabel.position = CGPoint(x: -122, y: -28)
        hudPanel.addChild(statusLabel)

        goalLabel.fontSize = 12
        goalLabel.horizontalAlignmentMode = .left
        goalLabel.verticalAlignmentMode = .center
        goalLabel.fontColor = NSColor.systemMint.withAlphaComponent(0.92)
        goalLabel.position = CGPoint(x: -122, y: -48)
        hudPanel.addChild(goalLabel)

        reactionLabel.fontSize = 14
        reactionLabel.horizontalAlignmentMode = .center
        reactionLabel.verticalAlignmentMode = .center
        reactionLabel.alpha = 0
        reactionLabel.zPosition = 72
        addChild(reactionLabel)
    }

    private func setupReminderPrompt() {
        reminderPrompt.fillColor = NSColor(red: 0.02, green: 0.08, blue: 0.14, alpha: 0.95)
        reminderPrompt.strokeColor = NSColor.systemCyan.withAlphaComponent(0.46)
        reminderPrompt.lineWidth = 1.1
        reminderPrompt.glowWidth = 10
        reminderPrompt.zPosition = 60
        reminderPrompt.alpha = 0
        reminderPrompt.isHidden = true
        addChild(reminderPrompt)

        reminderTitle.fontSize = 18
        reminderTitle.horizontalAlignmentMode = .left
        reminderTitle.verticalAlignmentMode = .center
        reminderTitle.position = CGPoint(x: -154, y: 42)
        reminderPrompt.addChild(reminderTitle)

        reminderBodyTop.fontSize = 14
        reminderBodyTop.horizontalAlignmentMode = .left
        reminderBodyTop.verticalAlignmentMode = .center
        reminderBodyTop.position = CGPoint(x: -154, y: 12)
        reminderBodyTop.fontColor = NSColor.white.withAlphaComponent(0.96)
        reminderPrompt.addChild(reminderBodyTop)

        reminderBodyBottom.fontSize = 14
        reminderBodyBottom.horizontalAlignmentMode = .left
        reminderBodyBottom.verticalAlignmentMode = .center
        reminderBodyBottom.position = CGPoint(x: -154, y: -10)
        reminderBodyBottom.fontColor = NSColor.white.withAlphaComponent(0.9)
        reminderPrompt.addChild(reminderBodyBottom)

        configureButton(doneButton, title: "CONFIRM", name: "doneButton", color: NSColor.systemGreen)
        doneButton.position = CGPoint(x: -72, y: -50)
        reminderPrompt.addChild(doneButton)

        configureButton(laterButton, title: "SNOOZE", name: "laterButton", color: NSColor.systemOrange)
        laterButton.position = CGPoint(x: 72, y: -50)
        reminderPrompt.addChild(laterButton)
    }

    private func configureButton(_ button: SKShapeNode, title: String, name: String, color: NSColor) {
        button.name = name
        button.fillColor = color
        button.strokeColor = .clear
        button.lineWidth = 0

        let label = SKLabelNode(fontNamed: "SFProDisplay-Semibold")
        label.text = title
        label.fontSize = 14
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = .zero
        label.name = name
        button.addChild(label)
    }

    private func runBlinkLoop() {
        let close = SKAction.run { [weak self] in self?.setEyes(closed: true) }
        let open  = SKAction.run { [weak self] in self?.setEyes(closed: false) }
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 2.5...5.0)),
            close,
            SKAction.wait(forDuration: 0.12),
            open
        ])
        run(SKAction.repeatForever(blink), withKey: "blink")
    }

    private func setEyes(closed: Bool) {
        let newPath = RobotStyle.eyePath(closed: closed)
        leftEye.path = newPath
        rightEye.path = newPath
    }

    private func applyExpression(animated: Bool) {
        let accent = RobotStyle.accent(for: currentMood)
        let mouthPath = CGMutablePath()

        switch currentMood {
        case .happy:
            mouthPath.move(to: CGPoint(x: -16, y: -6))
            mouthPath.addQuadCurve(to: CGPoint(x: 16, y: -6), control: CGPoint(x: 0, y: -20))
            lowerJaw.yScale = 1.15
            if animated {
                let laugh = SKAction.sequence([
                    SKAction.rotate(byAngle: 0.05, duration: 0.08),
                    SKAction.rotate(byAngle: -0.10, duration: 0.08),
                    SKAction.rotate(byAngle: 0.05, duration: 0.08),
                    SKAction.rotate(toAngle: 0.0, duration: 0.08)
                ])
                head.run(laugh, withKey: "laugh")
            }
        case .hungry:
            mouthPath.move(to: CGPoint(x: -12, y: -10))
            mouthPath.addQuadCurve(to: CGPoint(x: 12, y: -10), control: CGPoint(x: 0, y: -4))
            lowerJaw.yScale = 1.0
        case .sleepy:
            mouthPath.move(to: CGPoint(x: -10, y: -7))
            mouthPath.addQuadCurve(to: CGPoint(x: 10, y: -7), control: CGPoint(x: 0, y: -11))
            lowerJaw.yScale = 0.9
        case .angry:
            mouthPath.move(to: CGPoint(x: -14, y: -12))
            mouthPath.addLine(to: CGPoint(x: 14, y: -12))
            lowerJaw.yScale = 0.85
            if animated {
                let shake = SKAction.sequence([
                    SKAction.moveBy(x: -3, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 6, y: 0, duration: 0.05),
                    SKAction.moveBy(x: -3, y: 0, duration: 0.05)
                ])
                head.run(shake, withKey: "angryShake")
            }
        case .calm:
            mouthPath.move(to: CGPoint(x: -10, y: -8))
            mouthPath.addQuadCurve(to: CGPoint(x: 10, y: -8), control: CGPoint(x: 0, y: -10))
            lowerJaw.yScale = 1.0
        }

        let mouthLine = snout.childNode(withName: "mouthLine") as? SKShapeNode ?? {
            let node = SKShapeNode()
            node.name = "mouthLine"
            node.lineWidth = 3
            node.strokeColor = accent
            node.fillColor = .clear
            snout.addChild(node)
            return node
        }()

        mouthLine.path = mouthPath
        mouthLine.strokeColor = accent
        leftEye.fillColor = accent
        rightEye.fillColor = accent
        leftBlush.fillColor = RobotStyle.blush(for: currentMood)
        rightBlush.fillColor = RobotStyle.blush(for: currentMood)
        setEyes(closed: currentMood == .sleepy)
    }

    // MARK: - Walking leg animation

    private func startWalkingLegs() {
        let leftKick = SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.35, duration: 0.22),
            SKAction.rotate(toAngle: -0.35, duration: 0.22)
        ]))
        let rightKick = SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: -0.35, duration: 0.22),
            SKAction.rotate(toAngle: 0.35, duration: 0.22)
        ]))
        leftLeg.run(leftKick, withKey: "legL")
        rightLeg.run(rightKick, withKey: "legR")
    }

    private func stopWalkingLegs() {
        leftLeg.removeAction(forKey: "legL")
        rightLeg.removeAction(forKey: "legR")
        leftLeg.run(SKAction.rotate(toAngle: 0, duration: 0.15))
        rightLeg.run(SKAction.rotate(toAngle: 0, duration: 0.15))
    }

    // MARK: - Behavior scheduler

    private func scheduleNextBehavior() {
        let delay = Double.random(in: 0.8...2.5)
        let action = SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in self?.pickNextBehavior() }
        ])
        run(action, withKey: "behavior")
    }

    private func pickNextBehavior() {
        let roll = Int.random(in: 0...5)
        switch roll {
        case 0, 1:  // roam freely
            roamToRandomPoint()
        case 2:     // visit dock / menu-bar style edges
            roamToPoint(edgeDestination())
        case 3:     // chase cursor when it is reasonably close
            if let cursorTarget = cursorDestination() {
                roamToPoint(cursorTarget)
            } else {
                roamToRandomPoint()
            }
        case 4:     // idle pause
            stopWalking()
            isIdle = true
            let pause = SKAction.sequence([
                SKAction.wait(forDuration: Double.random(in: 0.6...1.6)),
                SKAction.run { [weak self] in
                    self?.isIdle = false
                    self?.scheduleNextBehavior()
                }
            ])
            run(pause, withKey: "behavior")
            return
        default:    // little hop
            hop()
        }
        scheduleNextBehavior()
    }

    private func roamToRandomPoint() {
        roamToPoint(randomDestination())
    }

    private func roamToPoint(_ target: CGPoint) {
        isIdle = false
        startWalkingLegs()
        setCharacterScale(activeScale)
        let deltaX = target.x - jarvisRoot.position.x
        flipJarvis(facingRight: deltaX >= 0)
        let distance = hypot(deltaX, target.y - jarvisRoot.position.y)
        let duration = max(1.2, Double(distance / walkSpeed))
        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        jarvisRoot.run(move, withKey: "walk")
    }

    func stopWalking() {
        jarvisRoot.removeAction(forKey: "walk")
        stopWalkingLegs()
        if activeReminder == nil {
            setCharacterScale(idleScale)
        }
    }

    private func playClickVoiceIfNeeded() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastClickVoiceAt > 0.9 else { return }
        guard !clickSpeech.isSpeaking else { return }

        lastClickVoiceAt = now
        speak("boop", with: clickSpeech, style: .tap)
    }

    private func playReplyVoiceForClick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastReplyVoiceAt > 2.1 else { return }
        guard !replySpeech.isSpeaking else { return }

        lastReplyVoiceAt = now
        let phrase: String
        switch currentMood {
        case .happy:
            phrase = "hehe, I'm here"
        case .calm:
            phrase = "ready to keep you company"
        case .hungry:
            phrase = "I'm still hungry"
        case .sleepy:
            phrase = "I'm sleepy, but still here"
        case .angry:
            phrase = "don't ignore me"
        }

        speak(phrase, with: replySpeech, style: .reply)
    }

    private func playReminderVoice(for kind: PetStore.ReminderKind) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastReminderVoiceAt > 1.2 else { return }
        guard !reminderSpeech.isSpeaking else { return }

        lastReminderVoiceAt = now
        let phrase: String
        switch kind {
        case .water:
            phrase = "sip sip"
        case .stretch:
            phrase = "stretch time"
        case .meal:
            phrase = "snack time"
        }

        speak(phrase, with: reminderSpeech, style: .reminder)
    }

    private func speak(_ phrase: String, with synthesizer: AVSpeechSynthesizer, style: VoiceStyle) {
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: style.language)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = style.volume
        utterance.rate = style.rate
        utterance.pitchMultiplier = style.pitch
        synthesizer.speak(utterance)
    }

    private func playReminderAnimation(for kind: PetStore.ReminderKind) {
        switch kind {
        case .water:
            currentMood = .calm
            applyExpression(animated: true)
            refreshHUD()
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.25, duration: 0.18),
                SKAction.scale(to: 1.0, duration: 0.24)
            ])
            coreGlow.run(.repeat(pulse, count: 2), withKey: "waterPulse")
            showReaction(text: "thirsty", color: .systemCyan)
        case .stretch:
            currentMood = .sleepy
            applyExpression(animated: true)
            refreshHUD()
            let leftStretch = SKAction.sequence([
                SKAction.rotate(toAngle: -.pi / 2.6, duration: 0.18),
                SKAction.rotate(toAngle: -.pi / 8, duration: 0.22)
            ])
            let rightStretch = SKAction.sequence([
                SKAction.rotate(toAngle: .pi / 2.6, duration: 0.18),
                SKAction.rotate(toAngle: .pi / 8, duration: 0.22)
            ])
            leftArm.run(.repeat(leftStretch, count: 2), withKey: "stretchLeft")
            rightArm.run(.repeat(rightStretch, count: 2), withKey: "stretchRight")
            showReaction(text: "stiff", color: .systemOrange)
        case .meal:
            currentMood = .hungry
            applyExpression(animated: true)
            refreshHUD()
            let bellyPulse = SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.16),
                SKAction.scale(to: 1.0, duration: 0.22)
            ])
            belly.run(.repeat(bellyPulse, count: 2), withKey: "mealBelly")
            head.run(SKAction.sequence([
                SKAction.moveBy(x: 0, y: -6, duration: 0.12),
                SKAction.moveBy(x: 0, y: 6, duration: 0.16)
            ]), withKey: "mealNod")
            showReaction(text: "hungry", color: .systemYellow)
        }
    }

    private func playCompletionAnimation(for kind: PetStore.ReminderKind) {
        let hop = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 24, duration: 0.16),
            SKAction.moveBy(x: 0, y: -24, duration: 0.18)
        ])
        jarvisRoot.run(hop, withKey: "successHop")

        switch kind {
        case .water:
            showReaction(text: "refreshed", color: .systemCyan)
        case .stretch:
            showReaction(text: "fresh", color: .systemGreen)
        case .meal:
            showReaction(text: "full", color: .systemPink)
        }
    }

    private func playSnoozeAnimation(for kind: PetStore.ReminderKind) {
        currentMood = .angry
        applyExpression(animated: true)
        refreshHUD()

        let sulk = SKAction.sequence([
            SKAction.moveBy(x: -10, y: 0, duration: 0.08),
            SKAction.moveBy(x: 20, y: 0, duration: 0.08),
            SKAction.moveBy(x: -10, y: 0, duration: 0.08)
        ])
        head.run(sulk, withKey: "sulk")

        switch kind {
        case .water:
            showReaction(text: "drink later", color: .systemTeal)
        case .stretch:
            showReaction(text: "maybe later", color: .systemOrange)
        case .meal:
            showReaction(text: "not hungry yet", color: .systemRed)
        }
    }

    private func microStateLabel(for mood: PetStore.Mood) -> String {
        switch mood {
        case .happy:
            "Happy"
        case .calm:
            "Ready"
        case .hungry:
            "Hungry"
        case .sleepy:
            "Sleepy"
        case .angry:
            "Grumpy"
        }
    }

    private func showReaction(text: String, color: NSColor) {
        reactionLabel.removeAllActions()
        reactionLabel.text = text.uppercased()
        reactionLabel.fontColor = color
        reactionLabel.position = CGPoint(x: jarvisRoot.position.x, y: jarvisRoot.position.y + 170)
        reactionLabel.alpha = 0
        reactionLabel.setScale(0.92)
        reactionLabel.run(
            SKAction.sequence([
                SKAction.group([
                    SKAction.fadeAlpha(to: 1, duration: 0.12),
                    SKAction.scale(to: 1, duration: 0.12),
                    SKAction.moveBy(x: 0, y: 10, duration: 0.12)
                ]),
                SKAction.wait(forDuration: 0.6),
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.22),
                    SKAction.moveBy(x: 0, y: 10, duration: 0.22)
                ])
            ])
        )
    }

    private func setCharacterScale(_ scale: CGFloat) {
        jarvisRoot.run(
            SKAction.scale(to: scale, duration: 0.22),
            withKey: "characterScale"
        )
    }

    func minimizeCharacter() {
        activeReminder = nil
        setCharacterScale(idleScale)
        reactionLabel.removeAllActions()
        reactionLabel.alpha = 0
        reminderPrompt.removeAllActions()
        reminderPrompt.isHidden = true
        reminderPrompt.alpha = 0
    }

    func resetGoal(_ kind: PetStore.ReminderKind) {
        store.resetGoalProgress(for: kind)
        refreshHUD()
        let text: String
        switch kind {
        case .water:
            text = "water reset"
        case .stretch:
            text = "stretch reset"
        case .meal:
            text = "meal reset"
        }
        showReaction(text: text, color: .systemGray)
    }

    private func hop() {
        let jump = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 60, duration: 0.25),
            SKAction.moveBy(x: 0, y: -60, duration: 0.25)
        ])
        jarvisRoot.run(jump, withKey: "hop")
    }

    // MARK: - Flip direction

    private func flipJarvis(facingRight: Bool) {
        let scaleX: CGFloat = facingRight ? 1.0 : -1.0
        jarvisRoot.run(SKAction.scaleX(to: scaleX, duration: 0.15))
    }

    // MARK: - Update (called every frame)

    override func update(_ currentTime: TimeInterval) {
        let bounds = playableBounds
        if !bounds.contains(jarvisRoot.position) {
            jarvisRoot.position.x = min(max(jarvisRoot.position.x, bounds.minX), bounds.maxX)
            jarvisRoot.position.y = min(max(jarvisRoot.position.y, bounds.minY), bounds.maxY)
        }
        hudGlow.position = CGPoint(x: 176, y: size.height - 86)
        hudPanel.position = CGPoint(x: 176, y: size.height - 86)
        reminderPrompt.position = CGPoint(x: jarvisRoot.position.x, y: jarvisRoot.position.y + 190)
        checkReminderPrompt()
    }

    // MARK: - Click / tap to pet

    override func mouseDown(with event: NSEvent) {
        let loc = event.location(in: self)
        if activeReminder != nil, handleReminderTap(at: loc) {
            return
        }
        // Hit test approx bounding box
        let jarvisPosition = jarvisRoot.position
        let hitRect = CGRect(x: jarvisPosition.x - 120, y: jarvisPosition.y - 120,
                             width: 240, height: 240)
        if hitRect.contains(loc) {
            reactToClick()
            openChatGPTIfNeeded(at: event.timestamp)
        }
    }

    private func reactToClick() {
        store.pet()
        currentMood = store.mood
        applyExpression(animated: true)
        playClickVoiceIfNeeded()
        playReplyVoiceForClick()
        setCharacterScale(activeScale)
        showReaction(text: "happy", color: .systemPink)
        // Wiggle
        let wiggle = SKAction.sequence([
            SKAction.rotate(byAngle: 0.08, duration: 0.1),
            SKAction.rotate(byAngle: -0.16, duration: 0.15),
            SKAction.rotate(byAngle: 0.08, duration: 0.1),
            SKAction.rotate(toAngle: 0, duration: 0.1)
        ])
        jarvisRoot.run(wiggle)

        // Blush pulse
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.18)
        ])
        leftBlush.run(pulse); rightBlush.run(pulse)

        // Floating heart
        spawnHeart()
    }

    private func handleReminderTap(at location: CGPoint) -> Bool {
        let nodes = nodes(at: location)
        if nodes.contains(where: { $0.name == "doneButton" }) {
            completeActiveReminder()
            return true
        }
        if nodes.contains(where: { $0.name == "laterButton" }) {
            snoozeActiveReminder()
            return true
        }
        return false
    }

    private func refreshHUD() {
        let signal = assistantSignal()
        moodLabel.text = "JARVIS // \(microStateLabel(for: currentMood).uppercased())"
        moodLabel.fontColor = signal.accent
        statsLabel.text = "SAT \(100 - store.hunger)%  ENG \(store.energy)%  LINK \(store.affection)%"
        statusLabel.text = "\(signal.header) // \(signal.detail)"
        goalLabel.text = "H2O \(store.goalSummary[.water] ?? "0/6")  FLEX \(store.goalSummary[.stretch] ?? "0/6")  FUEL \(store.goalSummary[.meal] ?? "0/3")  SCR \(screenTimeLabel())"
        hudPanel.strokeColor = signal.accent.withAlphaComponent(0.48)
        hudGlow.strokeColor = signal.accent.withAlphaComponent(0.20)
        radarOuterRing.strokeColor = signal.accent.withAlphaComponent(0.55)
        radarInnerRing.strokeColor = signal.accent.withAlphaComponent(0.30)
        radarInnerRing.fillColor = signal.accent.withAlphaComponent(0.08)
        scanLine.fillColor = signal.accent.withAlphaComponent(0.88)
    }

    private func checkReminderPrompt(force: Bool = false) {
        let now = Date()
        let interval = max(store.buddyReminderPollingInterval, 1)
        let bucket = Int(now.timeIntervalSince1970 / interval)
        guard force || bucket != lastReminderBucket else { return }
        lastReminderBucket = bucket

        guard let reminder = store.buddyReminder(at: now) else { return }
        guard shownReminderKeys.insert(reminder.key).inserted else { return }

        let event = PetStore.ReminderEvent(
            id: reminder.key,
            kind: reminder.schedule.kind,
            date: now,
            message: "\(reminder.schedule.title): prompt shown"
        )
        store.recordReminder(event)
        showReminder(reminder)
    }

    func triggerDemoReminder(_ kind: PetStore.ReminderKind, at date: Date = .now) {
        let reminder = store.demoReminder(for: kind, at: date)
        shownReminderKeys.remove(reminder.key)
        store.recordReminder(
            PetStore.ReminderEvent(
                id: reminder.key,
                kind: reminder.schedule.kind,
                date: date,
                message: "\(reminder.schedule.title): demo prompt shown"
            )
        )
        showReminder(reminder)
    }

    private func showReminder(_ reminder: PetStore.BuddyReminder) {
        activeReminder = reminder
        reminderTitle.text = "\(icon(for: reminder.schedule.kind)) \(promptTitle(for: reminder.schedule.kind))"
        reminderBodyTop.text = promptLine(for: reminder.schedule.kind)
        reminderBodyBottom.text = "Confirm logs progress. Snooze delays for 10 minutes."
        playReminderVoice(for: reminder.schedule.kind)
        playReminderAnimation(for: reminder.schedule.kind)
        setCharacterScale(reminderScale)
        reminderPrompt.removeAllActions()
        reminderPrompt.isHidden = false
        reminderPrompt.setScale(0.9)
        reminderPrompt.alpha = 0
        reminderPrompt.run(
            SKAction.group([
                SKAction.fadeAlpha(to: 1, duration: 0.2),
                SKAction.scale(to: 1, duration: 0.2)
            ])
        )
    }

    private func dismissReminderPrompt() {
        activeReminder = nil
        setCharacterScale(idleScale)
        let sequence = SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.18),
            SKAction.run { [weak self] in
                self?.reminderPrompt.isHidden = true
            }
        ])
        reminderPrompt.run(sequence)
    }

    private func completeActiveReminder() {
        guard let activeReminder else { return }
        let kind = activeReminder.schedule.kind
        store.completeReminder(activeReminder)
        if kind == .meal {
            store.feed()
        } else if kind == .stretch {
            store.rest()
        } else {
            store.pet()
        }
        currentMood = store.mood
        applyExpression(animated: true)
        refreshHUD()
        playCompletionAnimation(for: kind)
        spawnHeart()
        dismissReminderPrompt()
    }

    private func snoozeActiveReminder() {
        guard let activeReminder else { return }
        let kind = activeReminder.schedule.kind
        store.snoozeReminder(activeReminder, until: Date().addingTimeInterval(600))
        store.recordReminder(
            PetStore.ReminderEvent(
                id: activeReminder.key + ".snooze." + String(Int(Date().timeIntervalSince1970)),
                kind: kind,
                date: .now,
                message: "\(activeReminder.schedule.title): snoozed 10 menit"
            )
        )
        playSnoozeAnimation(for: kind)
        dismissReminderPrompt()
    }

    private func icon(for kind: PetStore.ReminderKind) -> String {
        switch kind {
        case .water: "💧"
        case .stretch: "🧘"
        case .meal: "🍽"
        }
    }

    private func promptTitle(for kind: PetStore.ReminderKind) -> String {
        switch kind {
        case .water: "HYDRATION PROTOCOL"
        case .stretch: "MOBILITY PROTOCOL"
        case .meal: "NUTRITION PROTOCOL"
        }
    }

    private func promptLine(for kind: PetStore.ReminderKind) -> String {
        switch kind {
        case .water: "Hydration level trending low. Water intake is advised."
        case .stretch: "Extended desk posture detected. Stand up and reset mobility."
        case .meal: "Fuel window is active. Do not skip this meal cycle."
        }
    }

    private func screenTimeLabel() -> String {
        let totalMinutes = Int(store.todayScreenTime / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02dh%02dm", hours, minutes)
    }

    private func assistantSignal() -> AssistantSignal {
        if let activeReminder {
            switch activeReminder.schedule.kind {
            case .water:
                return AssistantSignal(header: "ADVISORY", detail: "Hydration window active", accent: .systemCyan)
            case .stretch:
                return AssistantSignal(header: "WARNING", detail: "Mobility reset required", accent: .systemOrange)
            case .meal:
                return AssistantSignal(header: "WARNING", detail: "Nutrition window active", accent: .systemYellow)
            }
        }

        if store.energy <= 24 {
            return AssistantSignal(header: "WARNING", detail: "Energy reserves are low", accent: .systemOrange)
        }

        if store.hunger >= 76 {
            return AssistantSignal(header: "WARNING", detail: "Fuel reserves are dropping", accent: .systemYellow)
        }

        if store.affection <= 24 {
            return AssistantSignal(header: "NOTICE", detail: "Companion link is fading", accent: .systemPink)
        }

        if store.todayScreenTime >= 4 * 60 * 60 {
            return AssistantSignal(header: "NOTICE", detail: "Screen exposure threshold exceeded", accent: .systemTeal)
        }

        return AssistantSignal(header: "NOMINAL", detail: "All systems stable", accent: .systemMint)
    }

    func containsInteractiveContent(at point: CGPoint) -> Bool {
        let jarvisFrame = CGRect(
            x: jarvisRoot.position.x - 120,
            y: jarvisRoot.position.y - 120,
            width: 240,
            height: 240
        )

        if jarvisFrame.contains(point) {
            return true
        }

        guard !reminderPrompt.isHidden, reminderPrompt.alpha > 0.01 else {
            return false
        }

        let promptFrame = reminderPrompt.calculateAccumulatedFrame().insetBy(dx: -12, dy: -12)
        return promptFrame.contains(point)
    }

    private func spawnHeart() {
        let heart = SKLabelNode(text: "❤️")
        heart.fontSize = 24
        heart.alpha = 0
        heart.position = CGPoint(x: jarvisRoot.position.x,
                                 y: jarvisRoot.position.y + 130)
        addChild(heart)
        let seq = SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.moveBy(x: 0, y: 30, duration: 0.7),
            SKAction.fadeOut(withDuration: 0.25),
            SKAction.removeFromParent()
        ])
        heart.run(seq)
    }

    // MARK: - Keyboard (Escape to exit)

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onDismiss?()
        }
    }

    private var playableBounds: CGRect {
        CGRect(
            x: jarvisHalfWidth,
            y: groundY + 90,
            width: max(0, size.width - (jarvisHalfWidth * 2)),
            height: max(0, size.height - (groundY + 90) - jarvisHalfHeight)
        )
    }

    private func randomDestination() -> CGPoint {
        let bounds = playableBounds
        let x = CGFloat.random(in: bounds.minX...bounds.maxX)
        let y = CGFloat.random(in: bounds.minY...bounds.maxY)
        return CGPoint(x: x, y: y)
    }

    private func edgeDestination() -> CGPoint {
        let bounds = playableBounds
        let targets = [
            CGPoint(x: bounds.minX + 40, y: bounds.minY + 20),
            CGPoint(x: bounds.maxX - 40, y: bounds.minY + 20),
            CGPoint(x: bounds.minX + 80, y: bounds.maxY - 30),
            CGPoint(x: bounds.maxX - 80, y: bounds.maxY - 30)
        ]
        return targets.randomElement() ?? randomDestination()
    }

    private func cursorDestination() -> CGPoint? {
        guard
            let view,
            let window = view.window
        else {
            return nil
        }

        let cursorInWindow = window.mouseLocationOutsideOfEventStream
        let cursorInView = view.convert(cursorInWindow, from: nil)
        let target = convertPoint(fromView: cursorInView)
        let bounds = playableBounds
        guard bounds.contains(target) else { return nil }

        let distance = hypot(target.x - jarvisRoot.position.x, target.y - jarvisRoot.position.y)
        guard distance <= cursorChaseDistance else { return nil }
        return target
    }

    private func openChatGPTIfNeeded(at timestamp: TimeInterval) {
        guard timestamp - lastChatOpenAt > 0.8 else { return }
        lastChatOpenAt = timestamp
        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()

        let bundleIdentifiers = [
            "com.openai.chat",
            "com.openai.chatgpt",
        ]

        for bundleIdentifier in bundleIdentifiers {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
                return
            }
        }

        let candidatePaths = [
            "/Applications/ChatGPT.app",
            "\(NSHomeDirectory())/Applications/ChatGPT.app",
        ]

        for path in candidatePaths {
            let appURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
                return
            }
        }

        if let appScheme = URL(string: "chatgpt://"), workspace.urlForApplication(toOpen: appScheme) != nil {
            workspace.open(appScheme)
            return
        }

        workspace.open(ChatDestination.url)
    }

    override func didEvaluateActions() {
        if activeReminder == nil, reactionLabel.alpha < 0.05 {
            currentMood = store.mood
        }
        applyExpression(animated: false)
        refreshHUD()
    }
}

private extension CGFloat {
    var degreesToRadians: CGFloat { self * .pi / 180 }
}
#endif
