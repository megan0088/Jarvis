import Foundation
import Testing
@testable import Apl

@MainActor
struct CharacterAssetTests {

    /// Perilaku yang belum punya ekspresinya sendiri harus jatuh ke wajah
    /// default, bukan ke nama kosong — karakter tidak boleh punya jalan
    /// menuju "tidak ada model".
    @Test func unknownBehaviorFallsBackToDefaultExpression() {
        let sparse = CharacterAsset(
            defaultExpression: "RobotFlat",
            expressions: [.idle: "RobotFlat"],
            targetExtent: 0.35, cameraDistance: 0.9, cameraHeight: 0.02,
            fieldOfViewDegrees: 30, keyLightIntensity: 2500,
            idleBobHeight: 0.012, idleBobDuration: 1.8, attribution: nil
        )
        #expect(sparse.resourceName(for: .celebrate) == "RobotFlat")
        #expect(sparse.resourceName(for: .thinking) == "RobotFlat")
    }

    /// Setiap perilaku harus punya berkasnya sendiri pada aset yang dikirim.
    /// Kalau satu case ditambahkan ke `CharacterBehavior` tanpa ekspresinya,
    /// tes inilah yang jatuh — bukan pengguna yang menemukannya.
    @Test func everyBehaviorHasItsOwnExpression() {
        let asset = CharacterAsset.robot
        for behavior in CharacterBehavior.allCases {
            #expect(asset.expressions[behavior] != nil, "\(behavior) belum punya ekspresi")
        }
        #expect(Set(asset.expressions.values).count == CharacterBehavior.allCases.count)
    }

    /// Senyum lebar disimpan untuk perayaan supaya tetap berarti; wajah datar
    /// yang jadi wajah diam. Kalau pemetaan ini tertukar, ekspresi kehilangan
    /// maknanya tanpa ada yang error.
    @Test func restingFaceIsNeutralAndCelebrationIsTheBigSmile() {
        let asset = CharacterAsset.robot
        #expect(asset.resourceName(for: .idle) == "RobotFlat")
        #expect(asset.resourceName(for: .celebrate) == "RobotBigSmile")
        #expect(asset.resourceName(for: .idle) != asset.resourceName(for: .celebrate))
    }

    /// Kewajiban kredit hilang sendiri saat aset milik sendiri dipakai —
    /// tidak ada yang perlu ingat menghapus baris di layar About. Robot
    /// Sketchfab sudah diganti model sendiri, jadi kredit itu memang harus nil.
    @Test func attributionDisappearsForOwnAsset() {
        #expect(CharacterAsset.robot.attribution == nil)
    }

    /// Aset statis tanpa klip tetap harus bergerak, kalau tidak karakter
    /// membeku seperti gambar.
    @Test func staticAssetStillDeclaresIdleMotion() {
        #expect(CharacterAsset.robot.idleBobHeight > 0)
        #expect(CharacterAsset.robot.idleBobDuration > 0)
    }
}
