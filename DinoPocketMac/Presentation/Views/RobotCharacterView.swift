//
//  RobotCharacterView.swift
//  DinoPocketMac
//
//  Companion 3D dari Robot.usdz, dirender lewat RealityView (SwiftUI).
//
//  CATATAN — jangan ganti ke ARView.
//  Pernah dicoba karena `ARView.Environment.Background.color(_:)` menawarkan latar
//  bening yang tidak dimiliki `RealityViewEnvironment`. Transparansinya memang
//  bekerja, TAPI ARView di macOS mengabaikan `PerspectiveCamera` yang ditaruh di
//  scene: render tetap close-up ekstrem meski jarak kamera diubah 0.71 → 5.0, dan
//  meski model didorong 2 unit menjauh. Diverifikasi lewat snapshot PNG.
//  RealityView menghormati kamera, dan ternyata latar buram yang terlihat di Buddy
//  Mode datang dari `SKView` overlay-nya, bukan dari view ini.
//
//  Di Wave 1 view ini menjadi implementasi `CharacterPresenting`, dan angka
//  framing di bawah pindah ke `CharacterAsset`.
//

import SwiftUI
import RealityKit

struct RobotCharacterView: View {

    var size: CGFloat = 90

    /// Jarak kamera. 0.9 adalah nilai yang terbukti secara visual menampilkan
    /// karakter utuh. Geometri model (extents 1.096 × 1.012 × 0.320, dinormalisasi
    /// ke 0.35) memberi isian ~72.6% lebar frame pada jarak ini — ada margin, tapi
    /// karakternya utuh. Merapatkannya adalah penyetelan Wave 1 lewat `CharacterAsset`,
    /// bukan tebakan yang diubah tanpa bisa dilihat.
    private static let cameraDistance: Float = 0.9

    var body: some View {
        RealityView { content in
            guard let robot = try? await Entity(named: "Robot", in: Bundle.main) else { return }

            // Normalisasi ke ukuran layar yang konsisten dan pusatkan di origin.
            // Origin Robot.usdz ada di kaki (bounds.center.y = 0.505), jadi
            // recentering inilah yang menahannya agar tidak tenggelam.
            let bounds = robot.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
            let target: Float = 0.35
            let factor = target / maxDim
            robot.scale = SIMD3<Float>(repeating: factor)
            robot.position = -bounds.center * factor

            content.add(robot)

            // Key light so the white body reads with some shading.
            let key = DirectionalLight()
            key.light.intensity = 2500
            key.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(key)

            // Camera framing the character head-on.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 30
            let eye = SIMD3<Float>(0, 0.02, Self.cameraDistance)
            camera.position = eye
            camera.look(at: [0, 0, 0], from: eye, relativeTo: nil)
            content.add(camera)

            // Robot.usdz membawa dua klip berdurasi sama ("global scene animation"
            // dan "default subtree animation"); yang pertama sudah benar.
            if let idle = robot.availableAnimations.first {
                robot.playAnimation(idle.repeat(), transitionDuration: 0.3, startsPaused: false)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    RobotCharacterView(size: 160)
        .padding()
}
