//
//  DeskTimeCard.swift
//  Apl
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

    /// Sumbernya `summary`, sama dengan yang dipakai "Summarize my day".
    ///
    /// Sebelumnya kartu ini membaca `screenTimeHistory` — hanya sesi yang SUDAH
    /// tersimpan — sehingga tertulis "0h 0m" sepanjang app dipakai, sementara
    /// ringkasan di layar yang sama menyebut angka lain untuk hal yang sama.
    private var todayLabel: String { wellness.summary.deskTimeText }

    var body: some View {
        DashCard(title: "Desk time", systemImage: "desktopcomputer") {
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
