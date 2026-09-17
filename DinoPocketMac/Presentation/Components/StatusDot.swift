//
//  StatusDot.swift
//  Apl
//
//  Atom: small filled status indicator dot.
//

import SwiftUI

struct StatusDot: View {
    var color: Color = AppColor.statusOK

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

#Preview("Light") {
    HStack(spacing: Spacing.sm) {
        StatusDot()
        StatusDot(color: AppColor.statusWarning)
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: Spacing.sm) {
        StatusDot()
        StatusDot(color: AppColor.statusWarning)
    }
    .padding()
    .preferredColorScheme(.dark)
}
