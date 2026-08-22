//
//  RobotStyle.swift
//  Jarvis
//
//  Shared robot palette and geometry used by iOS and macOS scenes.
//

import CoreGraphics

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

enum RobotChargeKind: CaseIterable {
    case battery
    case orb
    case bolt
}

enum RobotStyle {
    static let shell = PlatformColor.white
    static let outline = PlatformColor.black.withAlphaComponent(0.08)
    static let limbOutline = PlatformColor.black.withAlphaComponent(0.06)
    static let facePanel = PlatformColor(red: 28 / 255, green: 33 / 255, blue: 48 / 255, alpha: 1.0)

    static func accent(for mood: PetStore.Mood) -> PlatformColor {
        switch mood {
        case .happy:
            return PlatformColor(red: 0.10, green: 0.85, blue: 0.95, alpha: 1.0)
        case .calm:
            return PlatformColor(red: 0.36, green: 0.76, blue: 0.96, alpha: 1.0)
        case .hungry:
            return PlatformColor(red: 1.00, green: 0.67, blue: 0.25, alpha: 1.0)
        case .sleepy:
            return PlatformColor(red: 0.58, green: 0.58, blue: 0.96, alpha: 1.0)
        case .angry:
            return PlatformColor(red: 1.00, green: 0.37, blue: 0.34, alpha: 1.0)
        }
    }

    static func blush(for mood: PetStore.Mood) -> PlatformColor {
        accent(for: mood).withAlphaComponent(0.30)
    }

    static func bellyGlow(for mood: PetStore.Mood) -> PlatformColor {
        accent(for: mood).withAlphaComponent(0.16)
    }

    static func eyePath(closed: Bool) -> CGPath {
        if closed {
            return CGPath(
                roundedRect: CGRect(x: -8, y: -1.5, width: 16, height: 3),
                cornerWidth: 1.5,
                cornerHeight: 1.5,
                transform: nil
            )
        }

        return CGPath(
            roundedRect: CGRect(x: -8, y: -8, width: 16, height: 16),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )
    }

    static func antennaPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 26))
        return path
    }
}
