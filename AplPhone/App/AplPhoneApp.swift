//
//  AplPhoneApp.swift
//  Apl (iPhone)
//
//  Titik masuk companion iPhone (spec H). Isinya tumbuh di Task 6–8.
//

import SwiftUI

@main
struct AplPhoneApp: App {
    private static let cache = CharacterExpressionCache()

    var body: some Scene {
        WindowGroup {
            RobotProbeView(cache: Self.cache)
        }
    }
}

/// SEMENTARA (Task 3). Dibuang di Task 6.
private struct RobotProbeView: View {
    let cache: CharacterExpressionCache
    @State private var behavior: CharacterBehavior = .idle

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [PhoneColor.stageGlow, .clear],
                                         center: .center, startRadius: 0, endRadius: 140))
                    .frame(width: 280, height: 280)
                PhoneCharacterView(size: 200, behavior: behavior, cache: cache)
            }
            Picker("Expression", selection: $behavior) {
                ForEach(CharacterBehavior.allCases, id: \.self) { Text(String(describing: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}
