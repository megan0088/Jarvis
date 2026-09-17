//
//  StatusLine.swift
//  Apl
//
//  Titik status + kalimat di bawah nama robot. Ukuran huruf diatur pemanggil.
//

import SwiftUI

struct StatusLine: View {
    let text: String
    var isWarning = false

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(color: isWarning ? AppColor.statusWarning : AppColor.statusOK)
            Text(text)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    VStack(alignment: .leading) {
        StatusLine(text: "Here when you need me")
        StatusLine(text: "Apple Intelligence is off", isWarning: true)
    }
    .font(.callout)
    .padding()
}

#Preview("Dark") {
    StatusLine(text: "Thinking…")
        .font(.callout)
        .padding()
        .preferredColorScheme(.dark)
}
