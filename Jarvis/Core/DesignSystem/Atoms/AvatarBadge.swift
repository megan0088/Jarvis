//
//  AvatarBadge.swift
//  Jarvis
//
//  Atom: circular tinted avatar badge with a centered SF Symbol.
//

#if os(macOS)
import SwiftUI

struct AvatarBadge: View {
    var systemImage: String = "person.fill"

    var body: some View {
        Circle()
            .fill(AppColor.accent.opacity(0.15))
            .overlay {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColor.accent)
                    .font(.system(size: 20, weight: .medium))
            }
            .frame(width: 44, height: 44)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        AvatarBadge()
        AvatarBadge(systemImage: "sparkles")
    }
    .padding()
}
#endif
