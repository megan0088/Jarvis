import Foundation
import Testing
@testable import Apl

// MARK: - SystemMood

/// Pemetaan sengaja diuji sebagai fungsi murni: memverifikasinya lewat
/// `SystemStatusService` berarti harus memanaskan Mac atau menghabiskan baterai
/// sungguhan (spec §8).
struct SystemMoodTests {

    @Test func nominalAndChargedIsNormal() {
        #expect(SystemMood.from(thermalState: .nominal,
                                isLowPowerMode: false,
                                batteryPercent: 90,
                                isOnACPower: true) == .normal)
    }

    @Test func fairThermalReadsAsBusy() {
        #expect(SystemMood.from(thermalState: .fair,
                                isLowPowerMode: false,
                                batteryPercent: 90,
                                isOnACPower: true) == .busy)
    }

    @Test func seriousAndCriticalBothReadAsHot() {
        for state in [ProcessInfo.ThermalState.serious, .critical] {
            #expect(SystemMood.from(thermalState: state,
                                    isLowPowerMode: false,
                                    batteryPercent: 90,
                                    isOnACPower: true) == .hot)
        }
    }

    /// Panas kritis mengalahkan baterai rendah: ia satu-satunya kondisi yang
    /// bisa merusak perangkat, jadi ia yang harus terlihat.
    @Test func heatOutranksLowBattery() {
        #expect(SystemMood.from(thermalState: .critical,
                                isLowPowerMode: true,
                                batteryPercent: 5,
                                isOnACPower: false) == .hot)
    }

    @Test func lowPowerModeAloneIsEnough() {
        #expect(SystemMood.from(thermalState: .nominal,
                                isLowPowerMode: true,
                                batteryPercent: 100,
                                isOnACPower: true) == .lowBattery)
    }

    /// Baterai 15% sambil dicas bukan masalah — inilah kasus yang mudah salah
    /// kalau status daya diabaikan.
    @Test func lowBatteryWhileChargingIsNotLowBattery() {
        #expect(SystemMood.from(thermalState: .nominal,
                                isLowPowerMode: false,
                                batteryPercent: 15,
                                isOnACPower: true) == .normal)
    }

    @Test func lowBatteryOnBatteryPowerIsLowBattery() {
        #expect(SystemMood.from(thermalState: .nominal,
                                isLowPowerMode: false,
                                batteryPercent: 15,
                                isOnACPower: false) == .lowBattery)
    }

    /// Mac desktop tanpa baterai melaporkan nil; itu tidak boleh dibaca sebagai 0%.
    @Test func missingBatteryIsNotTreatedAsEmpty() {
        #expect(SystemMood.from(thermalState: .nominal,
                                isLowPowerMode: false,
                                batteryPercent: nil,
                                isOnACPower: false) == .normal)
    }
}

// MARK: - BuddySettingsStore

struct BuddySettingsStoreTests {

    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: "test.buddy.\(name)")!
        d.removePersistentDomain(forName: "test.buddy.\(name)")
        return d
    }

    @Test func defaultsAreSaneOnFirstLaunch() {
        let store = BuddySettingsStore(defaults: isolatedDefaults(#function))
        #expect(store.size == BuddySettingsStore.defaultSize)
        #expect(store.opacity == 1.0)
        #expect(store.keepOnTop == true)
        #expect(store.strolling == false)   // opt-in, spec §10
    }

    @Test func sizeIsClampedBothWays() {
        let store = BuddySettingsStore(defaults: isolatedDefaults(#function))
        store.size = 10_000
        #expect(store.size == BuddySettingsStore.sizeRange.upperBound)
        store.size = -5
        #expect(store.size == BuddySettingsStore.sizeRange.lowerBound)
    }

    @Test func opacityIsClampedBothWays() {
        let store = BuddySettingsStore(defaults: isolatedDefaults(#function))
        store.opacity = 5
        #expect(store.opacity == BuddySettingsStore.opacityRange.upperBound)
        store.opacity = 0
        #expect(store.opacity == BuddySettingsStore.opacityRange.lowerBound)
    }

    @Test func valuesSurviveRoundTrip() {
        let defaults = isolatedDefaults(#function)
        let first = BuddySettingsStore(defaults: defaults)
        first.size = 240
        first.opacity = 0.5
        first.keepOnTop = false
        first.strolling = true

        let second = BuddySettingsStore(defaults: defaults)
        #expect(second.size == 240)
        #expect(second.opacity == 0.5)
        #expect(second.keepOnTop == false)
        #expect(second.strolling == true)
    }

    /// `bool(forKey:)` mengembalikan false untuk kunci yang belum pernah diset,
    /// yang akan diam-diam mematikan default keepOnTop. Ini menjaganya.
    @Test func keepOnTopDefaultsTrueWhenNeverSet() {
        let defaults = isolatedDefaults(#function)
        #expect(defaults.object(forKey: "buddy.keepOnTop") == nil)
        #expect(BuddySettingsStore(defaults: defaults).keepOnTop == true)
    }
}

// MARK: - AppLauncherService

struct SystemSettingsPaneTests {

    @Test func everyPaneBuildsAtLeastOneValidURL() {
        for pane in SystemSettingsPane.allCases {
            #expect(!pane.candidateURLs.isEmpty, "pane \(pane.rawValue) tidak punya URL valid")
        }
    }

    /// Setiap pane spesifik wajib punya fallback ke System Settings umum,
    /// karena identifier pane berubah antar versi macOS dan tombol yang tidak
    /// berbuat apa-apa lebih buruk daripada jendela yang kurang tepat.
    @Test func specificPanesFallBackToRoot() {
        for pane in SystemSettingsPane.allCases where pane != .root {
            #expect(pane.candidateURLStrings.last == "x-apple.systempreferences:")
            #expect(pane.candidateURLStrings.count >= 2)
        }
    }

    @Test func everyCandidateUsesSystemSettingsScheme() {
        for pane in SystemSettingsPane.allCases {
            for url in pane.candidateURLs {
                #expect(url.scheme == "x-apple.systempreferences")
            }
        }
    }
}
