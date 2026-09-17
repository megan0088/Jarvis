//
//  USDZCharacterView.swift
//  AplMac
//
//  Companion 3D HealthAssistantRobot, dirender lewat RealityView (SwiftUI).
//  Satu berkas USDZ per ekspresi; berkas mana yang dimuat ditentukan
//  `CharacterAsset.expressions`, bukan oleh view ini. Model diambil dari
//  `CharacterExpressionCache`, bukan dibaca dari disk setiap kali.
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
//     dan model lama tetap terlihat sampai model baru siap.
//

import SwiftUI
import RealityKit

struct USDZCharacterView: View {

    var size: CGFloat = 90
    var asset: CharacterAsset = .robot
    var behavior: CharacterBehavior = .idle
    /// Menjeda gerak napas tanpa membongkar scene — saat jendela tidak aktif
    /// atau Low Power Mode (spec B §12).
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Wadah yang hidup selama view ada; hanya isinya yang berganti.
    @State private var stage = Entity()
    @State private var motion: AnimationPlaybackController?
    /// Naik setiap kali ekspresi berganti, memicu efek "pop".
    @State private var swapCount = 0

    /// Model dipasang ulang saat berkasnya ATAU Reduce Motion berubah, karena
    /// gerak napas dipasang bersama model.
    private struct Appearance: Hashable {
        let resourceName: String
        let reduceMotion: Bool
    }

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
        .task(id: Appearance(resourceName: asset.resourceName(for: behavior), reduceMotion: reduceMotion)) {
            await show(asset.resourceName(for: behavior))
        }
        .onChange(of: isPaused) { _, paused in
            if paused { motion?.pause() } else { motion?.resume() }
        }
        // "Pop" singkat saat wajah berganti, supaya pergantian terbaca
        // sebagai reaksi, bukan kedipan.
        .keyframeAnimator(initialValue: CGFloat(1), trigger: swapCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(0.92, duration: 0.05)
                SpringKeyframe(1, duration: 0.13)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(CharacterStatusText.accessibilityLabel(for: behavior))
        .accessibilityAddTraits(.isImage)
    }

    /// Mengambil satu ekspresi dari cache dan menukarnya ke dalam `stage`.
    ///
    /// Gagal muat tidak mengosongkan panggung — wajah sebelumnya dipertahankan,
    /// dan stage tetap menampilkan nama, status, serta Up next (spec B §9).
    /// Task yang sudah dibatalkan tidak boleh menukar apa pun: dengan cache,
    /// permintaan lama bisa selesai SETELAH permintaan yang lebih baru.
    @MainActor
    private func show(_ resourceName: String) async {
        guard let character = await CharacterExpressionCache.shared.entity(named: resourceName),
              !Task.isCancelled else { return }

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

        let isSwap = !stage.children.isEmpty
        stage.children.removeAll()
        stage.addChild(character)

        // Reduce Motion mematikan napas dan pop (spec B §7).
        motion = reduceMotion ? nil : playIdleMotion(on: character)
        if isPaused { motion?.pause() }
        if isSwap && !reduceMotion { swapCount += 1 }
    }

    /// Klip bawaan kalau ada; kalau tidak, napas buatan.
    ///
    /// Kelima ekspor HealthAssistantRobot statis — `availableAnimations`
    /// kosong — jadi cabang kedua inilah yang benar-benar jalan hari ini.
    /// Cabang pertama dibiarkan supaya ekspor beranimasi nanti langsung
    /// dipakai tanpa menyentuh view ini.
    @MainActor
    private func playIdleMotion(on character: Entity) -> AnimationPlaybackController? {
        if let baked = character.availableAnimations.first {
            return character.playAnimation(baked.repeat(), transitionDuration: 0.3, startsPaused: false)
        }

        guard asset.idleBobHeight > 0 else { return nil }

        var lifted = character.transform
        lifted.translation.y += asset.idleBobHeight

        let bob = FromToByAnimation(
            to: lifted,
            duration: asset.idleBobDuration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )

        guard let resource = try? AnimationResource.generate(with: bob) else { return nil }
        return character.playAnimation(resource.repeat(), transitionDuration: 0.3, startsPaused: false)
    }
}

#Preview("Idle · Light") {
    USDZCharacterView(size: 160)
        .padding()
}

#Preview("Thinking · Dark") {
    USDZCharacterView(size: 160, behavior: .thinking)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Celebrate") {
    USDZCharacterView(size: 160, behavior: .celebrate)
        .padding()
}
