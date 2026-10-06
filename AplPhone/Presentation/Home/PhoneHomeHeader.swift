//
//  PhoneHomeHeader.swift
//  Apl (iPhone)
//
//  Robot, nama, dan status (spec H §4.1). Dua bentuk — penuh dan ringkas —
//  dipilih `HomeHeaderMode`.
//
//  SATU `PhoneCharacterView` dipakai di kedua bentuk; yang berganti hanya tata
//  letak dan ukurannya. Dua view di dua cabang `if` berarti scene RealityKit
//  dibongkar setiap kali header berubah bentuk, dan robotnya berkedip.
//

import SwiftUI

struct PhoneHomeHeader: View {
    let mode: HomeHeaderMode
    let behavior: CharacterBehavior
    let statusText: String
    let isIntelligenceAvailable: Bool
    let isAnimationPaused: Bool
    let cache: CharacterExpressionCache

    /// Selisih keduanya harus sama dengan `HomeHeaderMode.collapseGain`.
    static let fullRobotSize: CGFloat = 150
    static let compactRobotSize: CGFloat = 44

    private var isFull: Bool { mode == .full }
    private var robotSize: CGFloat { isFull ? Self.fullRobotSize : Self.compactRobotSize }

    var body: some View {
        let layout = isFull
            ? AnyLayout(VStackLayout(spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.md))

        layout {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [PhoneColor.stageGlow, .clear], center: .center,
                                         startRadius: 0, endRadius: robotSize * 0.75))
                    .frame(width: robotSize * 1.5, height: robotSize * 1.5)
                    .accessibilityHidden(true)
                PhoneCharacterView(size: robotSize, behavior: behavior,
                                   isPaused: isAnimationPaused, cache: cache)
            }
            .frame(width: robotSize, height: robotSize)

            VStack(alignment: isFull ? .center : .leading, spacing: 2) {
                Text("Apl")
                    .font(.system(isFull ? .title2 : .headline, design: .rounded, weight: .semibold))
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(isIntelligenceAvailable ? PhoneColor.statusOK : PhoneColor.statusWarning)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if !isFull { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .animation(.snappy(duration: 0.25), value: mode)
    }
}

#Preview("Header · Full") {
    PhoneHomeHeader(mode: .full, behavior: .greet, statusText: "Good afternoon!",
                    isIntelligenceAvailable: true, isAnimationPaused: false,
                    cache: CharacterExpressionCache())
}

#Preview("Header · Compact · Dark") {
    PhoneHomeHeader(mode: .compact, behavior: .thinking, statusText: "Thinking…",
                    isIntelligenceAvailable: true, isAnimationPaused: false,
                    cache: CharacterExpressionCache())
        .preferredColorScheme(.dark)
}
