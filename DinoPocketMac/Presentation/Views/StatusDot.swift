//
//  StatusDot.swift
//  Apl
//
//  Atom: small filled status indicator dot.
//

import SwiftUI

struct StatusDot: View {
    var color: Color = AppColor.online

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        StatusDot()
        StatusDot(color: .orange)
        StatusDot(color: .red)
    }
    .padding()
}
