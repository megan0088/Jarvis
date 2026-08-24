//
//  RobotCharacterView.swift
//  DinoPocketMac
//
//  Companion 3D dari Robot.usdz, dirender lewat RealityKit.
//
//  Memakai `ARView` (NSViewRepresentable), BUKAN `RealityView`. Alasannya satu dan
//  menentukan: Buddy Mode butuh latar bening, dan `RealityViewEnvironment` di macOS
//  hanya menyediakan `.default` dan `.skybox(_:)` — tidak ada kontrol warna latar,
//  sehingga RealityView selalu merender latar buram di atas desktop.
//  `ARView.Environment.Background.color(_:)` menerima NSColor, jadi `.clear` bisa.
//
//  Di Wave 1 view ini menjadi implementasi `CharacterPresenting`, dan angka-angka
//  framing di bawah pindah ke `CharacterAsset`.
//

import SwiftUI
import RealityKit
import AppKit

struct RobotCharacterView: NSViewRepresentable {

    var size: CGFloat = 90

    // MARK: - Framing

    /// Sisi terpanjang model setelah normalisasi, dalam satuan dunia.
    private static let targetExtent: Float = 0.35

    private static let fieldOfViewDegrees: Float = 30

    /// Jarak kamera diturunkan dari geometri model, bukan ditebak.
    ///
    /// `Robot.usdz` punya extents x=1.096, y=1.012, z=0.320 — lebih lebar daripada
    /// tinggi. Dinormalisasi ke sisi terpanjang 0.35, lebarnya jadi 0.350 dan
    /// tingginya 0.323. Pada frame persegi, lebar yang membatasi.
    ///
    /// FOV RealityKit bersifat vertikal secara default (`fieldOfViewOrientation`
    /// = `.vertical`), jadi tinggi bidang pandang = 2 · d · tan(fov/2).
    /// Agar karakter mengisi ~92% lebar frame:
    ///
    ///     d = 0.350 / 0.92 / (2 · tan(15°)) ≈ 0.71
    ///
    /// Menghasilkan isian 92% lebar dan 85% tinggi — rapat tanpa terpotong, dan
    /// menyisakan ~8% ruang untuk gerak animasi idle. Jarak lama 0.9 hanya
    /// mengisi 72.6%, sehingga lebih dari seperempat kotak jadi margin kosong dan
    /// karakter tampak mengambang jauh lebih kecil daripada ukuran kotaknya.
    private static let cameraDistance: Float = 0.71

    private static let cameraHeight: Float = 0.02

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> ARView {
        let view = ARView(frame: CGRect(x: 0, y: 0, width: size, height: size))

        // Rantai transparansi. Ketiganya harus benar; satu saja buram, seluruh
        // jendela buddy jadi kotak buram di atas desktop.
        view.environment.background = .color(.clear)
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor

        let anchor = AnchorEntity(world: .zero)
        view.scene.addAnchor(anchor)

        let key = DirectionalLight()
        key.light.intensity = 2500
        key.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
        anchor.addChild(key)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = Self.fieldOfViewDegrees
        let eye = SIMD3<Float>(0, Self.cameraHeight, Self.cameraDistance)
        camera.position = eye
        camera.look(at: [0, 0, 0], from: eye, relativeTo: nil)
        anchor.addChild(camera)

        Task { @MainActor in
            guard let robot = try? await Entity(named: "Robot", in: Bundle.main) else {
                // Model gagal dimuat: biarkan bening, jangan tampilkan kotak rusak.
                // Fallback avatar sederhana adalah pekerjaan Wave 1 (spec §9).
                return
            }

            // Normalisasi ke ukuran layar yang konsisten dan pusatkan di origin.
            // Origin Robot.usdz ada di kaki (center.y = 0.505), jadi recentering
            // ini yang membuatnya tidak tenggelam di bawah frame.
            let bounds = robot.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
            let factor = Self.targetExtent / maxDim
            robot.scale = SIMD3<Float>(repeating: factor)
            robot.position = -bounds.center * factor

            anchor.addChild(robot)

            // Robot.usdz membawa dua klip berdurasi sama ("global scene animation"
            // dan "default subtree animation"); yang pertama sudah benar.
            if let idle = robot.availableAnimations.first {
                robot.playAnimation(idle.repeat(), transitionDuration: 0.3, startsPaused: false)
            }
        }

        return view
    }

    func updateNSView(_ nsView: ARView, context: Context) {
        // Ukuran diatur oleh frame view induk; tidak ada yang perlu disinkronkan.
    }
}

#Preview {
    RobotCharacterView(size: 160)
        .frame(width: 160, height: 160)
        .padding()
}
