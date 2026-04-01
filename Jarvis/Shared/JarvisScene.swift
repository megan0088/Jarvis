//
//  JarvisScene.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

import SpriteKit
import AudioToolbox

#if os(macOS)
import AppKit
typealias UIColor = NSColor
#else
import UIKit
#endif


final class JarvisScene: SKScene {
    private let body = SKShapeNode(rectOf: CGSize(width: 150, height: 180), cornerRadius: 40)
    private let belly = SKShapeNode(rectOf: CGSize(width: 96, height: 110), cornerRadius: 28)
    private let coreGlow = SKShapeNode(circleOfRadius: 32)
    private let head = SKShapeNode(rectOf: CGSize(width: 120, height: 90), cornerRadius: 28)
    private let snout = SKShapeNode(rectOf: CGSize(width: 86, height: 54), cornerRadius: 18)
    private let lowerJaw = SKShapeNode(rectOf: CGSize(width: 76, height: 16), cornerRadius: 8)
    private let mouthLine = SKShapeNode()
    private let teeth = SKShapeNode()
    private let jarvisNode = SKNode()
    private let leftEye = SKShapeNode(rectOf: CGSize(width: 16, height: 16), cornerRadius: 3)
    private let rightEye = SKShapeNode(rectOf: CGSize(width: 16, height: 16), cornerRadius: 3)
    private let leftBlush = SKShapeNode(circleOfRadius: 6)
    private let rightBlush = SKShapeNode(circleOfRadius: 6)
    private let tail = SKShapeNode(path: {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -10, y: -10))
        p.addLine(to: CGPoint(x: 90, y: 12))
        p.addQuadCurve(to: CGPoint(x: -10, y: 10), control: CGPoint(x: 50, y: -40))
        p.closeSubpath()
        return p
    }())
    private let spikes = SKShapeNode()
    private let leftArm = SKShapeNode(rectOf: CGSize(width: 14, height: 30), cornerRadius: 7)
    private let rightArm = SKShapeNode(rectOf: CGSize(width: 14, height: 30), cornerRadius: 7)
    private let leftLeg = SKShapeNode(rectOf: CGSize(width: 22, height: 36), cornerRadius: 10)
    private let rightLeg = SKShapeNode(rectOf: CGSize(width: 22, height: 36), cornerRadius: 10)
    private let mountainLeft = SKShapeNode()
    private let mountainRight = SKShapeNode()
    private let cloud1 = SKShapeNode()
    private let cloud2 = SKShapeNode()
    private let ground = SKShapeNode()

    private var heartbeatOn = false
    private var currentMood: PetStore.Mood = .calm
    private var isSleepingState = false

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.4)
        scaleMode = .resizeFill
        backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
#if os(macOS)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
#else
        view.isOpaque = false
        view.backgroundColor = .clear
#endif

        setupBackground()
        jarvisNode.position = .zero
        addChild(jarvisNode)
        setupBody()
        setupHead()
        setupFace()
        setupTail()
        setupLimbs()
        setupSpikes()
        startIdle()
    }

    private func setupBody() {
        body.fillColor = RobotStyle.shell
        body.strokeColor = RobotStyle.outline
        body.lineWidth = 1.5
        body.position = .zero
        jarvisNode.addChild(body)

        coreGlow.fillColor = RobotStyle.bellyGlow(for: .calm)
        coreGlow.strokeColor = .clear
        coreGlow.position = CGPoint(x: 0, y: -4)
        coreGlow.alpha = 0.9
        body.addChild(coreGlow)

        belly.fillColor = RobotStyle.bellyGlow(for: .calm)
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 0, y: -8)
        body.addChild(belly)
    }

    private func setupHead() {
        head.fillColor = RobotStyle.shell
        head.strokeColor = RobotStyle.outline
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 84)
        jarvisNode.addChild(head)

        snout.fillColor = RobotStyle.facePanel
        snout.strokeColor = .clear
        snout.position = CGPoint(x: 0, y: 4)
        head.addChild(snout)

        lowerJaw.fillColor = RobotStyle.accent(for: .calm)
        lowerJaw.strokeColor = .clear
        lowerJaw.position = CGPoint(x: 0, y: -16)
        snout.addChild(lowerJaw)

        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -14, y: -6))
        mouthPath.addQuadCurve(to: CGPoint(x: 14, y: -6), control: CGPoint(x: 0, y: -14))
        mouthLine.path = mouthPath
        mouthLine.lineWidth = 3
        mouthLine.strokeColor = RobotStyle.accent(for: .calm)
        mouthLine.fillColor = .clear
        snout.addChild(mouthLine)

        let teethPath = CGMutablePath()
        teethPath.addRoundedRect(in: CGRect(x: -18, y: 18, width: 36, height: 8), cornerWidth: 4, cornerHeight: 4)
        teeth.path = teethPath
        teeth.fillColor = RobotStyle.accent(for: .calm)
        teeth.strokeColor = .clear
        teeth.alpha = 0.7
        snout.addChild(teeth)

        let nostrilL = SKShapeNode(circleOfRadius: 3.5)
        nostrilL.fillColor = RobotStyle.accent(for: .calm)
        nostrilL.strokeColor = .clear
        nostrilL.position = CGPoint(x: -26, y: 22)
        let nostrilR = nostrilL.copy() as! SKShapeNode
        nostrilR.position = CGPoint(x: 26, y: 22)
        snout.addChild(nostrilL)
        snout.addChild(nostrilR)
    }

    private func setupTail() {
        tail.path = RobotStyle.antennaPath()
        tail.strokeColor = RobotStyle.accent(for: .calm)
        tail.lineWidth = 4
        tail.fillColor = .clear
        tail.position = CGPoint(x: 0, y: 132)
        tail.zPosition = -1
        jarvisNode.addChild(tail)

        let swing = SKAction.sequence([
            SKAction.rotate(toAngle: CGFloat(8).degreesToRadians, duration: 0.7, shortestUnitArc: true),
            SKAction.rotate(toAngle: CGFloat(-8).degreesToRadians, duration: 0.7, shortestUnitArc: true)
        ])
        tail.run(SKAction.repeatForever(swing))
    }

    private func setupFace() {
        let eyesY: CGFloat = 8
        leftEye.fillColor = RobotStyle.accent(for: .calm)
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -20, y: eyesY)
        rightEye.fillColor = RobotStyle.accent(for: .calm)
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: 20, y: eyesY)

        leftBlush.fillColor = RobotStyle.blush(for: .calm)
        leftBlush.strokeColor = .clear
        leftBlush.position = CGPoint(x: -34, y: -14)
        rightBlush.fillColor = RobotStyle.blush(for: .calm)
        rightBlush.strokeColor = .clear
        rightBlush.position = CGPoint(x: 34, y: -14)

        head.addChild(leftEye)
        head.addChild(rightEye)
        head.addChild(leftBlush)
        head.addChild(rightBlush)
    }

    // MARK: - Animations

    private func startIdle() {
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 12, duration: 1.2),
            SKAction.moveBy(x: 0, y: -12, duration: 1.2)
        ])
        jarvisNode.run(SKAction.repeatForever(float))

        let glowPulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.8),
            SKAction.fadeAlpha(to: 0.55, duration: 0.8)
        ])
        coreGlow.run(SKAction.repeatForever(glowPulse))

        runBlinkLoop()
        applyExpression(animated: false)
    }

    private func runBlinkLoop() {
        let close = SKAction.run { [weak self] in self?.setEyes(closed: true) }
        let open = SKAction.run { [weak self] in self?.setEyes(closed: false) }
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 2.5...5.0)),
            close,
            SKAction.wait(forDuration: 0.12),
            open
        ])
        run(SKAction.repeatForever(blink), withKey: "blink")
    }

    private func pauseBlinking() {
        removeAction(forKey: "blink")
    }

    private func resumeBlinking() {
        removeAction(forKey: "blink")
        runBlinkLoop()
    }

    private func setEyes(closed: Bool) {
        let newPath = RobotStyle.eyePath(closed: closed)
        leftEye.run(SKAction.scale(to: 1.0, duration: 0.0)) // ensure any animations stop
        rightEye.run(SKAction.scale(to: 1.0, duration: 0.0))
        leftEye.path = newPath
        rightEye.path = newPath
    }

    private func applyExpression(animated: Bool) {
        let accent = RobotStyle.accent(for: currentMood)
        let mouthPath = CGMutablePath()
        let eyeClosed = isSleepingState || currentMood == .sleepy

        switch currentMood {
        case .happy:
            mouthPath.move(to: CGPoint(x: -16, y: -6))
            mouthPath.addQuadCurve(to: CGPoint(x: 16, y: -6), control: CGPoint(x: 0, y: -20))
            lowerJaw.yScale = 1.15
            head.removeAction(forKey: "angryShake")
            body.removeAction(forKey: "angryShake")
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
            head.removeAction(forKey: "angryShake")
            body.removeAction(forKey: "angryShake")
        case .sleepy:
            mouthPath.move(to: CGPoint(x: -10, y: -7))
            mouthPath.addQuadCurve(to: CGPoint(x: 10, y: -7), control: CGPoint(x: 0, y: -11))
            lowerJaw.yScale = 0.9
            head.removeAction(forKey: "angryShake")
            body.removeAction(forKey: "angryShake")
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
                body.run(shake, withKey: "angryShake")
            }
        case .calm:
            mouthPath.move(to: CGPoint(x: -10, y: -8))
            mouthPath.addQuadCurve(to: CGPoint(x: 10, y: -8), control: CGPoint(x: 0, y: -10))
            lowerJaw.yScale = 1.0
            head.removeAction(forKey: "angryShake")
            body.removeAction(forKey: "angryShake")
        }

        mouthLine.path = mouthPath
        mouthLine.strokeColor = accent
        teeth.fillColor = accent
        leftEye.fillColor = accent
        rightEye.fillColor = accent
        setEyes(closed: eyeClosed)
    }

    func squish() {
        let squish = SKAction.sequence([
            SKAction.scaleX(to: 1.05, y: 0.92, duration: 0.12),
            SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.18)
        ])
        body.run(squish)
        head.run(squish)
    }

    func pet() {
        let wiggle = SKAction.sequence([
            SKAction.rotate(byAngle: 0.06, duration: 0.12),
            SKAction.rotate(byAngle: -0.12, duration: 0.16),
            SKAction.rotate(byAngle: 0.06, duration: 0.12),
            SKAction.rotate(toAngle: 0, duration: 0.12)
        ])
        body.run(wiggle)
        head.run(wiggle)
        pulseBlush()
    }

    func feed() {
        pulseBelly()
        tail.run(SKAction.rotate(byAngle: 0.2, duration: 0.15))
        chomp()
        spawnCharge(RobotChargeKind.allCases.randomElement() ?? .battery)
        playCrunch()
    }

    func sleep() {
        isSleepingState = true
        setEyes(closed: true)
        body.run(SKAction.fadeAlpha(to: 0.85, duration: 0.4))
        head.run(SKAction.fadeAlpha(to: 0.85, duration: 0.4))
        addSleepBubble()
        addZParticles()
        pauseBlinking()
        let rotate = SKAction.rotate(toAngle: -.pi / 2, duration: 0.4, shortestUnitArc: true)
        let move = SKAction.move(to: CGPoint(x: 0, y: -40), duration: 0.4)
        jarvisNode.run(SKAction.group([rotate, move]), withKey: "sleepPose")
    }

    func wake() {
        isSleepingState = false
        setEyes(closed: false)
        body.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))
        head.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))
        removeSleepBubble()
        removeZParticles()
        resumeBlinking()
        let rotate = SKAction.rotate(toAngle: 0, duration: 0.35, shortestUnitArc: true)
        let move = SKAction.move(to: .zero, duration: 0.35)
        jarvisNode.run(SKAction.group([rotate, move]), withKey: "sleepPose")
    }

    func applyState(from store: PetStore, heartbeat: Bool) {
        heartbeatOn = heartbeat
        currentMood = store.mood
        let accent = RobotStyle.accent(for: store.mood)
        body.fillColor = RobotStyle.shell
        head.fillColor = RobotStyle.shell
        leftArm.fillColor = RobotStyle.shell
        rightArm.fillColor = RobotStyle.shell
        leftLeg.fillColor = RobotStyle.shell
        rightLeg.fillColor = RobotStyle.shell
        belly.fillColor = RobotStyle.bellyGlow(for: store.mood)
        coreGlow.fillColor = RobotStyle.bellyGlow(for: store.mood)
        tail.strokeColor = accent
        spikes.fillColor = accent
        lowerJaw.fillColor = accent
        mouthLine.strokeColor = accent
        teeth.fillColor = accent
        leftEye.fillColor = accent
        rightEye.fillColor = accent
        leftBlush.fillColor = RobotStyle.blush(for: store.mood)
        rightBlush.fillColor = RobotStyle.blush(for: store.mood)
        applyExpression(animated: true)
        if heartbeat {
            let beat = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.2),
                SKAction.scale(to: 1.0, duration: 0.2)
            ])
            body.run(SKAction.repeatForever(beat), withKey: "heartbeat")
            head.run(SKAction.repeatForever(beat), withKey: "heartbeat_head")
        } else {
            body.removeAction(forKey: "heartbeat")
            head.removeAction(forKey: "heartbeat_head")
            body.setScale(1.0)
            head.setScale(1.0)
        }
    }

    private func pulseBlush() {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.18)
        ])
        leftBlush.run(pulse)
        rightBlush.run(pulse)
    }

    private func pulseBelly() {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.14),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        belly.run(pulse)
    }

    private func chomp() {
        let open = SKAction.moveBy(x: 0, y: -6, duration: 0.08)
        let close = SKAction.moveBy(x: 0, y: 6, duration: 0.12)
        lowerJaw.run(SKAction.sequence([open, close]))
    }

    private func spawnCharge(_ kind: RobotChargeKind) {
        let node: SKShapeNode
        switch kind {
        case .battery:
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: -18, y: -12, width: 36, height: 24), cornerWidth: 8, cornerHeight: 8)
            node = SKShapeNode(path: path)
            node.fillColor = RobotStyle.accent(for: .calm)
            node.strokeColor = .white.withAlphaComponent(0.85)
            node.lineWidth = 1.8
            let cap = SKShapeNode(rectOf: CGSize(width: 6, height: 10), cornerRadius: 2)
            cap.fillColor = .white.withAlphaComponent(0.9)
            cap.strokeColor = .clear
            cap.position = CGPoint(x: 21, y: 0)
            node.addChild(cap)
        case .orb:
            node = SKShapeNode(circleOfRadius: 15)
            node.fillColor = RobotStyle.accent(for: .happy)
            node.strokeColor = .white.withAlphaComponent(0.8)
            node.lineWidth = 1.6
        case .bolt:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -6, y: 18))
            path.addLine(to: CGPoint(x: 2, y: 18))
            path.addLine(to: CGPoint(x: -4, y: 2))
            path.addLine(to: CGPoint(x: 10, y: 2))
            path.addLine(to: CGPoint(x: -6, y: -18))
            path.addLine(to: CGPoint(x: -1, y: -2))
            path.addLine(to: CGPoint(x: -14, y: -2))
            path.closeSubpath()
            node = SKShapeNode(path: path)
            node.fillColor = RobotStyle.accent(for: .hungry)
            node.strokeColor = .white.withAlphaComponent(0.8)
            node.lineWidth = 1.4
        }

        node.position = CGPoint(x: 0, y: -140)
        node.zPosition = 2
        addChild(node)

        let path = SKAction.move(to: CGPoint(x: 0, y: 40), duration: 0.5)
        path.timingMode = .easeIn
        let shrink = SKAction.scale(to: 0.4, duration: 0.5)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let nom = SKAction.run { self.showNom() }
        let remove = SKAction.removeFromParent()
        node.run(SKAction.sequence([
            SKAction.group([path, shrink]),
            fade,
            nom,
            remove
        ]))
    }

    private func showNom() {
        let label = SKLabelNode(text: "Charge!")
        label.fontName = "HelveticaNeue-Bold"
        label.fontSize = 16
        label.fontColor = UIColor.white
        label.position = CGPoint(x: 0, y: 90)
        label.alpha = 0.0
        addChild(label)
        let appear = SKAction.fadeIn(withDuration: 0.1)
        let move = SKAction.moveBy(x: 0, y: 20, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([appear, move, fade, remove]))
    }

    private func playCrunch() {
        // Uses a built-in system sound as lightweight crunchy feedback.
        // Sound ID 1104 is a short "Tock" click; replace with custom file if available.
        AudioServicesPlaySystemSound(1104)
    }

    private func addSleepBubble() {
        removeSleepBubble()
        let bubble = SKShapeNode(circleOfRadius: 10)
        bubble.name = "sleepBubble"
        bubble.fillColor = UIColor.white.withAlphaComponent(0.85)
        bubble.strokeColor = .clear
        bubble.position = CGPoint(x: -80, y: 90)
        let grow = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.6)
        ])
        bubble.run(SKAction.repeatForever(grow))
        addChild(bubble)
    }

    private func removeSleepBubble() {
        childNode(withName: "sleepBubble")?.removeFromParent()
    }

    private func addZParticles() {
        if let existing = childNode(withName: "zzz") {
            existing.removeFromParent()
        }
        let z = SKLabelNode(text: "Z z z")
        z.name = "zzz"
        z.fontName = "HelveticaNeue-Bold"
        z.fontSize = 18
        z.fontColor = UIColor.white.withAlphaComponent(0.8)
        z.position = CGPoint(x: -60, y: 110)
        let float = SKAction.sequence([
            SKAction.moveBy(x: -4, y: 18, duration: 1.2),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.0),
            SKAction.moveBy(x: 4, y: -18, duration: 0.0)
        ])
        z.run(SKAction.repeatForever(float))
        addChild(z)
    }

    private func removeZParticles() {
        childNode(withName: "zzz")?.removeFromParent()
    }

    private func setupBackground() {
        let sky = SKShapeNode(rectOf: CGSize(width: size.width * 1.2, height: size.height * 1.4), cornerRadius: 40)
        sky.fillColor = UIColor(red: 220/255, green: 240/255, blue: 255/255, alpha: 0.9)
        sky.strokeColor = .clear
        sky.position = CGPoint(x: 0, y: 20)
        sky.zPosition = -5
        addChild(sky)

        ground.path = CGPath(rect: CGRect(x: -size.width/1.2, y: -120, width: size.width * 1.4, height: 120), transform: nil)
        ground.fillColor = UIColor(red: 160/255, green: 200/255, blue: 140/255, alpha: 1.0)
        ground.strokeColor = .clear
        ground.zPosition = -4.5
        addChild(ground)

        let mountainPath = CGMutablePath()
        mountainPath.move(to: CGPoint(x: -size.width/1.8, y: -40))
        mountainPath.addLine(to: CGPoint(x: -40, y: 120))
        mountainPath.addLine(to: CGPoint(x: size.width/10, y: -40))
        mountainPath.closeSubpath()
        mountainLeft.path = mountainPath
        mountainLeft.fillColor = UIColor(red: 80/255, green: 170/255, blue: 120/255, alpha: 1.0)
        mountainLeft.strokeColor = .clear
        mountainLeft.zPosition = -4
        addChild(mountainLeft)

        let mountainPath2 = CGMutablePath()
        mountainPath2.move(to: CGPoint(x: size.width/2.2, y: -40))
        mountainPath2.addLine(to: CGPoint(x: 80, y: 160))
        mountainPath2.addLine(to: CGPoint(x: -size.width/7, y: -40))
        mountainPath2.closeSubpath()
        mountainRight.path = mountainPath2
        mountainRight.fillColor = UIColor(red: 70/255, green: 150/255, blue: 110/255, alpha: 1.0)
        mountainRight.strokeColor = .clear
        mountainRight.zPosition = -3
        addChild(mountainRight)

        cloud1.path = cloudPath(width: 120, height: 50)
        cloud1.fillColor = UIColor.white.withAlphaComponent(0.9)
        cloud1.strokeColor = .clear
        cloud1.position = CGPoint(x: -80, y: 140)
        cloud1.zPosition = -2
        addChild(cloud1)
        animateCloud(cloud1, distance: size.width/1.5, duration: 14)

        cloud2.path = cloudPath(width: 90, height: 40)
        cloud2.fillColor = UIColor.white.withAlphaComponent(0.85)
        cloud2.strokeColor = .clear
        cloud2.position = CGPoint(x: 120, y: 180)
        cloud2.zPosition = -2
        addChild(cloud2)
        animateCloud(cloud2, distance: size.width/1.2, duration: 16)
    }

    private func cloudPath(width: CGFloat, height: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: -width * 0.4, y: -height * 0.5, width: width * 0.6, height: height * 0.9))
        p.addEllipse(in: CGRect(x: -width * 0.1, y: -height * 0.3, width: width * 0.6, height: height))
        p.addEllipse(in: CGRect(x: width * 0.25, y: -height * 0.4, width: width * 0.55, height: height * 0.9))
        return p
    }

    private func animateCloud(_ node: SKNode, distance: CGFloat, duration: TimeInterval) {
        let move = SKAction.sequence([
            SKAction.moveBy(x: -distance, y: 0, duration: duration),
            SKAction.moveBy(x: distance, y: 0, duration: 0)
        ])
        node.run(SKAction.repeatForever(move))
    }

    private func setupLimbs() {
        leftArm.fillColor = RobotStyle.shell
        leftArm.strokeColor = RobotStyle.limbOutline
        leftArm.lineWidth = 1
        leftArm.position = CGPoint(x: -88, y: 8)
        leftArm.zRotation = -.pi / 10

        rightArm.fillColor = RobotStyle.shell
        rightArm.strokeColor = RobotStyle.limbOutline
        rightArm.lineWidth = 1
        rightArm.position = CGPoint(x: 88, y: 8)
        rightArm.zRotation = .pi / 10

        leftLeg.fillColor = RobotStyle.shell
        leftLeg.strokeColor = RobotStyle.limbOutline
        leftLeg.lineWidth = 1
        leftLeg.position = CGPoint(x: -28, y: -118)

        rightLeg.fillColor = RobotStyle.shell
        rightLeg.strokeColor = RobotStyle.limbOutline
        rightLeg.lineWidth = 1
        rightLeg.position = CGPoint(x: 28, y: -118)

        jarvisNode.addChild(leftArm)
        jarvisNode.addChild(rightArm)
        jarvisNode.addChild(leftLeg)
        jarvisNode.addChild(rightLeg)
    }

    private func setupSpikes() {
        let spikePath = CGMutablePath()
        spikePath.addRoundedRect(in: CGRect(x: -18, y: 0, width: 36, height: 8), cornerWidth: 4, cornerHeight: 4)
        spikes.path = spikePath
        spikes.fillColor = RobotStyle.accent(for: .calm)
        spikes.strokeColor = .clear
        spikes.zPosition = -0.5
        spikes.position = CGPoint(x: 0, y: 152)
        jarvisNode.addChild(spikes)
    }
}

private extension CGFloat {
    var degreesToRadians: CGFloat { self * .pi / 180 }
}
