//
//  FetchWellnessSummaryUseCase.swift
//  SharedCore
//
//  Potret wellness hari ini dalam satu nilai.
//

import Foundation

@MainActor
struct FetchWellnessSummaryUseCase {

    private let store: any WellnessStoring

    init(store: any WellnessStoring) {
        self.store = store
    }

    struct Output: Equatable {
        let deskTime: TimeInterval
        let water: Int
        let stretch: Int
        let meals: Int

        /// Metrik yang Mac TIDAK bisa ketahui tetap `nil`, bukan `0`.
        ///
        /// Nol adalah klaim. HealthKit tidak tersedia di macOS (spec §3.1), jadi
        /// menampilkan "0 langkah" adalah kebohongan berbentuk angka. Saat
        /// companion iPhone tiba, nilai-nilai ini berhenti nil dan kartu yang
        /// sama menyala tanpa perubahan di dashboard.
        let steps: Int? = nil
        let sleep: TimeInterval? = nil
        let heartRate: Double? = nil

        var deskTimeText: String {
            let total = Int(deskTime.rounded())
            let h = total / 3600, m = (total % 3600) / 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
    }

    func execute() -> Output {
        let g = store.goalProgress
        return Output(deskTime: store.todayScreenTime,
                      water: g.water,
                      stretch: g.stretch,
                      meals: g.meal)
    }
}
