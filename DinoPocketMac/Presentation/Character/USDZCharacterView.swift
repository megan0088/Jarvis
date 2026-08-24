//
//  USDZCharacterView.swift
//  DinoPocketMac
//
//  Companion 3D dari Robot.usdz, dirender lewat RealityView (SwiftUI).
//
//  CATATAN — dua jalan buntu yang tidak perlu diulang.
//
//  1. Latar buram di Buddy Mode BUKAN berasal dari view ini, melainkan dari
//     `SKView` overlay selebar layar di `JarvisBuddyWindowController` (SKView
//     tanpa scene merender latar buram). Sudah diganti `NSView` polos.
//
//  2. Sempat diganti ke `ARView` demi `Environment.Background.color(.clear)`,
//     lalu disimpulkan "ARView mengabaikan PerspectiveCamera" karena mengubah
//     jarak kamera 0.71 → 5.0 nyaris tak berpengaruh. Kesimpulan itu KELIRU.
//     Penyebab sebenarnya bug skala di bawah: modelnya selebar 35 unit, jadi
//     butuh kamera ~90 unit untuk memuatnya — perubahan ke 5.0 memang tak
//     terlihat. Kamera berfungsi normal di kedua view.
//
//  Di Wave 1 view ini menjadi implementasi `CharacterPresenting`, dan angka
//  framing di bawah pindah ke `CharacterAsset`.
//

import SwiftUI
import RealityKit

struct USDZCharacterView: View {

    var size: CGFloat = 90
    var asset: CharacterAsset = .robot
    var behavior: CharacterBehavior = .idle

    var body: some View {
        RealityView { content in
            guard let robot = try? await Entity(named: asset.resourceName, in: Bundle.main) else { return }

            // Normalisasi ke ukuran layar yang konsisten dan pusatkan di origin.
            // Origin Robot.usdz ada di kaki (bounds.center.y = 0.505), jadi
            // recentering inilah yang menahannya agar tidak tenggelam.
            let bounds = robot.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
            let target: Float = asset.targetExtent
            let factor = target / maxDim

            // KALIKAN skala, jangan timpa. Robot.usdz datang dengan
            // `scale = 0.01` bawaan (khas ekspor USDZ yang mengonversi cm ke m),
            // dan `visualBounds` sudah memperhitungkannya. Menulis
            // `robot.scale = factor` membuang skala 0.01 itu sehingga model
            // membengkak 31.9× — extents jadi 35.0 × 32.3 × 10.2 alih-alih
            // 0.35 × 0.32 × 0.10, dan karakter memenuhi layar sebagai close-up
            // yang tak terkenali. Diukur, bukan ditebak.
            robot.scale *= factor
            robot.position = -bounds.center * factor

            content.add(robot)

            // Key light so the white body reads with some shading.
            let key = DirectionalLight()
            key.light.intensity = asset.keyLightIntensity
            key.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(key)

            // Camera framing the character head-on.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = asset.fieldOfViewDegrees
            let eye = SIMD3<Float>(0, asset.cameraHeight, asset.cameraDistance)
            camera.position = eye
            camera.look(at: [0, 0, 0], from: eye, relativeTo: nil)
            content.add(camera)

            // Klip dipilih lewat nama yang didaftarkan aset. Jatuh ke klip
            // pertama bila namanya tidak ketemu — model baru yang belum lengkap
            // animasinya tetap bergerak alih-alih membeku.
            let wanted = asset.clipName(for: behavior)
            let clip = robot.availableAnimations.first { $0.name == wanted }
                ?? robot.availableAnimations.first
            if let clip {
                robot.playAnimation(clip.repeat(), transitionDuration: 0.3, startsPaused: false)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    USDZCharacterView(size: 160)
        .padding()
}
