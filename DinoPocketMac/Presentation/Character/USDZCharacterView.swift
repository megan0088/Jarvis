//
//  USDZCharacterView.swift
//  AplMac
//
//  Companion 3D HealthAssistantRobot, dirender lewat RealityView (SwiftUI).
//  Satu berkas USDZ per ekspresi; berkas mana yang dimuat ditentukan
//  `CharacterAsset.expressions`, bukan oleh view ini.
//
//  CATATAN — tiga jalan buntu yang tidak perlu diulang.
//
//  1. Latar buram di Buddy Mode BUKAN berasal dari view ini, melainkan dari
//     `SKView` overlay selebar layar di `AplBuddyWindowController` (SKView
//     tanpa scene merender latar buram). Sudah diganti `NSView` polos.
//
//  2. Sempat diganti ke `ARView` demi `Environment.Background.color(.clear)`,
//     lalu disimpulkan "ARView mengabaikan PerspectiveCamera" karena mengubah
//     jarak kamera 0.71 → 5.0 nyaris tak berpengaruh. Kesimpulan itu KELIRU.
//     Penyebab sebenarnya bug skala di bawah: modelnya selebar 35 unit, jadi
//     butuh kamera ~90 unit untuk memuatnya — perubahan ke 5.0 memang tak
//     terlihat. Kamera berfungsi normal di kedua view.
//
//  3. Mengganti ekspresi dengan `.id(resourceName)` pada RealityView memang
//     bekerja, tetapi membangun ulang seluruh scene: karakter berkedip hilang
//     setiap kali mood berubah. Yang ditukar sekarang hanya isi `stage`,
//     dan model lama tetap terlihat sampai model baru selesai dimuat.
//

import SwiftUI
import RealityKit

struct USDZCharacterView: View {

    var size: CGFloat = 90
    var asset: CharacterAsset = .robot
    var behavior: CharacterBehavior = .idle

    /// Wadah yang hidup selama view ada; hanya isinya yang berganti.
    @State private var stage = Entity()

    var body: some View {
        RealityView { content in
            content.add(stage)

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
        }
        // Dikunci ke nama berkas, bukan ke `behavior`: dua perilaku yang
        // memakai wajah sama tidak perlu memuat ulang apa pun.
        .task(id: asset.resourceName(for: behavior)) {
            await show(asset.resourceName(for: behavior))
        }
        .frame(width: size, height: size)
    }

    /// Memuat satu ekspresi dan menukarnya ke dalam `stage`.
    ///
    /// Gagal muat tidak mengosongkan panggung — wajah sebelumnya dipertahankan.
    /// Itu juga yang terjadi saat `.task` dibatalkan karena mood berubah dua
    /// kali beruntun.
    @MainActor
    private func show(_ resourceName: String) async {
        guard let character = try? await Entity(named: resourceName, in: Bundle.main) else { return }

        // Normalisasi ke ukuran layar yang konsisten dan pusatkan di origin.
        // Origin model ada di kaki, jadi recentering inilah yang menahannya
        // agar tidak tenggelam.
        let bounds = character.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
        let factor = asset.targetExtent / maxDim

        // KALIKAN skala, jangan timpa. Ekspor USDZ kerap membawa skala bawaan
        // (robot lama datang dengan `scale = 0.01`, khas konversi cm ke m), dan
        // `visualBounds` sudah memperhitungkannya. Menulis `character.scale =
        // factor` membuang skala itu sehingga model membengkak puluhan kali —
        // extents jadi 35.0 × 32.3 × 10.2 alih-alih 0.35 × 0.32 × 0.10, dan
        // karakter memenuhi layar sebagai close-up yang tak terkenali.
        // Diukur, bukan ditebak.
        character.scale *= factor
        character.position = -bounds.center * factor

        playIdleMotion(on: character)

        stage.children.removeAll()
        stage.addChild(character)
    }

    /// Klip bawaan kalau ada; kalau tidak, napas buatan.
    ///
    /// Kelima ekspor HealthAssistantRobot statis — `availableAnimations`
    /// kosong — jadi cabang kedua inilah yang benar-benar jalan hari ini.
    /// Cabang pertama dibiarkan supaya ekspor beranimasi nanti langsung
    /// dipakai tanpa menyentuh view ini.
    @MainActor
    private func playIdleMotion(on character: Entity) {
        if let baked = character.availableAnimations.first {
            character.playAnimation(baked.repeat(), transitionDuration: 0.3, startsPaused: false)
            return
        }

        guard asset.idleBobHeight > 0 else { return }

        var lifted = character.transform
        lifted.translation.y += asset.idleBobHeight

        let bob = FromToByAnimation(
            to: lifted,
            duration: asset.idleBobDuration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )

        if let motion = try? AnimationResource.generate(with: bob) {
            character.playAnimation(motion.repeat(), transitionDuration: 0.3, startsPaused: false)
        }
    }
}

#Preview("Idle") {
    USDZCharacterView(size: 160)
        .padding()
}

#Preview("Celebrate") {
    USDZCharacterView(size: 160, behavior: .celebrate)
        .padding()
}
