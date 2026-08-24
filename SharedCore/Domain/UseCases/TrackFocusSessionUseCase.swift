//
//  TrackFocusSessionUseCase.swift
//  SharedCore
//
//  Mulai dan hentikan penghitungan waktu di depan Mac.
//
//  Ada sebagai UseCase karena keputusan "kapan sesi dianggap berhenti" bukan
//  urusan penyimpanan maupun urusan View. `scenePhase` saja tidak cukup: app
//  yang dibiarkan terbuka semalaman tetap `.active`, dan tanpa ambang idle
//  seluruh malam itu tercatat sebagai waktu kerja.
//

import Foundation

/// Berapa lama sejak input terakhir. Diverifikasi lolos App Sandbox (spec §3.4).
protocol IdleTimeProviding: Sendable {
    var secondsSinceLastInput: TimeInterval { get }
}

@MainActor
struct TrackFocusSessionUseCase {

    /// Ambang idle sebelum sesi dianggap berakhir.
    ///
    /// Lima menit: cukup panjang agar membaca dokumen atau menonton video tidak
    /// memutus sesi, cukup pendek agar meninggalkan meja tidak diam-diam
    /// tercatat sebagai waktu kerja.
    nonisolated static let idleThreshold: TimeInterval = 5 * 60

    private let store: any WellnessStoring
    private let idle: IdleTimeProviding

    init(store: any WellnessStoring, idle: IdleTimeProviding) {
        self.store = store
        self.idle = idle
    }

    enum Event: Equatable {
        case becameActive
        case becameInactive
        case periodicCheck
    }

    /// Fungsi murni yang menentukan keputusannya — bisa diuji tanpa jam nyata.
    nonisolated static func shouldPause(event: Event, idleSeconds: TimeInterval) -> Bool {
        switch event {
        case .becameInactive: true
        case .becameActive:   false
        case .periodicCheck:  idleSeconds >= idleThreshold
        }
    }

    func handle(_ event: Event, now: Date = .now) {
        if Self.shouldPause(event: event, idleSeconds: idle.secondsSinceLastInput) {
            // Sesi dihentikan pada saat input TERAKHIR, bukan sekarang — kalau
            // tidak, seluruh durasi idle ikut terhitung sebagai waktu kerja.
            let stoppedAt = event == .periodicCheck
                ? now.addingTimeInterval(-idle.secondsSinceLastInput)
                : now
            store.pauseScreenTime(at: stoppedAt)
        } else if event == .becameActive {
            store.resumeScreenTime(at: now)
        }
    }
}
