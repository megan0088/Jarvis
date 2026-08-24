//
//  DeskTimeCard.swift
//  Jarvis
//
//  Organism: waktu hadir di depan Mac hari ini.
//
//  Dulu bernama ScreenTimeCard. Diganti karena namanya menjanjikan sesuatu yang
//  mustahil: FamilyControls.AuthorizationCenter dan DeviceActivityCenter
//  keduanya @available(macOS, unavailable), jadi screen time per-aplikasi tidak
//  bisa diketahui di Mac (spec §3.2). Yang benar-benar diukur adalah durasi
//  kehadiran di depan Mac ini — dan itulah yang sekarang dijanjikan namanya.
//

import SwiftUI

struct DeskTimeCard: View {
    let wellness: WellnessViewModel

    private var todayLabel: String {
        let secs = wellness.screenTimeHistory.first(where: { Calendar.current.isDateInToday($0.date) })?.duration ?? 0
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        return "\(h)h \(m)m"
    }

    var body: some View {
        DashCard(title: "Screen time", systemImage: "desktopcomputer") {
            Text(todayLabel)
                .font(.system(size: 26, weight: .medium))
        }
    }
}

#Preview {
    DeskTimeCard(wellness: .preview)
        .frame(width: 300)
        .padding()
}
