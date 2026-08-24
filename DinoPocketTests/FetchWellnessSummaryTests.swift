import Foundation
import Testing
@testable import Jarvis

@MainActor
struct FetchWellnessSummaryTests {

    private func store(water: Int = 0, stretch: Int = 0, meal: Int = 0,
                       desk: TimeInterval = 0) -> FakeWellnessStore {
        let s = FakeWellnessStore()
        s.goalProgress = WellnessGoalProgress(date: .now, water: water, stretch: stretch, meal: meal)
        s.todayScreenTime = desk
        return s
    }

    @Test func readsTodaysNumbersFromTheStore() {
        let output = FetchWellnessSummaryUseCase(store: store(water: 3, stretch: 1, meal: 2, desk: 8_040)).execute()
        #expect(output.water == 3)
        #expect(output.stretch == 1)
        #expect(output.meals == 2)
        #expect(output.deskTime == 8_040)
    }

    /// Invarian paling penting di seluruh lapisan wellness.
    ///
    /// Nol adalah KLAIM. HealthKit tidak tersedia di macOS (spec §3.1), jadi
    /// menampilkan "0 langkah" adalah kebohongan berbentuk angka pada app yang
    /// menyebut dirinya wellness. Metrik yang tidak diketahui harus nil, supaya
    /// kartu bisa menawarkan "hubungkan iPhone" alih-alih berbohong.
    @Test func unknowableMetricsAreNilNeverZero() {
        let output = FetchWellnessSummaryUseCase(store: store()).execute()
        #expect(output.steps == nil)
        #expect(output.sleep == nil)
        #expect(output.heartRate == nil)
    }

    @Test func deskTimeTextDropsHoursWhenUnderAnHour() {
        #expect(FetchWellnessSummaryUseCase(store: store(desk: 1_500)).execute().deskTimeText == "25m")
        #expect(FetchWellnessSummaryUseCase(store: store(desk: 8_040)).execute().deskTimeText == "2h 14m")
    }

    /// Hari yang benar-benar kosong tetap menghasilkan nol yang JUJUR — angka
    /// itu memang diketahui, berbeda dengan langkah yang tidak bisa diketahui.
    @Test func genuinelyZeroDayReportsZero() {
        let output = FetchWellnessSummaryUseCase(store: store()).execute()
        #expect(output.water == 0)
        #expect(output.deskTime == 0)
    }
}
