import Foundation
import Testing
@testable import Jarvis

@MainActor
struct CharacterAssetTests {

    /// Perilaku yang tidak punya klip sendiri harus jatuh ke idle, bukan nil —
    /// model baru yang belum lengkap animasinya tetap bergerak alih-alih membeku.
    @Test func unknownBehaviorFallsBackToIdle() {
        let asset = CharacterAsset.robot
        #expect(asset.clipName(for: .greet) == asset.clipName(for: .idle))
        #expect(asset.clipName(for: .sleepy) == asset.clipName(for: .idle))
    }

    @Test func idleClipIsDeclared() {
        #expect(CharacterAsset.robot.clipName(for: .idle) != nil)
    }

    /// Kewajiban kredit hilang sendiri saat aset milik sendiri dipakai —
    /// tidak ada yang perlu ingat menghapus baris di layar About.
    @Test func attributionDisappearsForOwnAsset() {
        let mine = CharacterAsset(
            resourceName: "Mine", targetExtent: 0.35,
            cameraDistance: 0.9, cameraHeight: 0.02,
            fieldOfViewDegrees: 30, keyLightIntensity: 2500,
            clips: [.idle: "idle"], attribution: nil
        )
        #expect(mine.attribution == nil)
        #expect(CharacterAsset.robot.attribution != nil)
    }
}

struct TrackFocusSessionTests {

    @Test func inactiveAlwaysPauses() {
        #expect(TrackFocusSessionUseCase.shouldPause(event: .becameInactive, idleSeconds: 0))
    }

    @Test func activeNeverPauses() {
        #expect(!TrackFocusSessionUseCase.shouldPause(event: .becameActive, idleSeconds: 99_999))
    }

    /// Inti dari UseCase ini: app yang dibiarkan terbuka semalaman tetap
    /// `.active`, jadi tanpa ambang idle seluruh malam tercatat sebagai kerja.
    @Test func periodicCheckPausesOnlyPastTheIdleThreshold() {
        let threshold = TrackFocusSessionUseCase.idleThreshold
        #expect(!TrackFocusSessionUseCase.shouldPause(event: .periodicCheck, idleSeconds: threshold - 1))
        #expect(TrackFocusSessionUseCase.shouldPause(event: .periodicCheck, idleSeconds: threshold))
        #expect(TrackFocusSessionUseCase.shouldPause(event: .periodicCheck, idleSeconds: 8 * 3600))
    }
}
