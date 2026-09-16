//
//  AppColors.swift
//  Apl
//
//  Semantic HIG color tokens for the macOS dashboard design system.
//

import SwiftUI

/// Semantic color namespace. No hardcoded hex — everything resolves to a
/// system/AppKit-backed color so it adapts automatically to light/dark and
/// accent-color changes.
enum AppColor {
    static let accent = Color.accentColor
    static let card = Color(nsColor: .controlBackgroundColor)
    static let groupedBackground = Color(nsColor: .windowBackgroundColor)

    static let online = Color.green
}
