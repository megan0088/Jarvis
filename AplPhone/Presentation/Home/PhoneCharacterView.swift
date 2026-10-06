//
//  PhoneCharacterView.swift
//  Apl (iPhone)
//
//  Robot 3D lewat RealityView (spec H §4.1, §8). Satu berkas USDZ per
//  ekspresi; berkas mana yang dimuat ditentukan `CharacterAsset.expressions`.
//
//  Dua pelajaran dari versi Mac yang dibawa ke sini:
//  - Yang ditukar hanya isi `stage`. Mengganti ekspresi dengan `.id()` pada
//    RealityView membangun ulang scene dan robot berkedip hilang.
//  - Skala DIKALIKAN, bukan ditimpa: ekspor USDZ membawa skala bawaan.
//

import RealityKit
import SwiftUI

struct PhoneCharacterView: View {

    var size: CGFloat = 150
    var asset: CharacterAsset = .robot
    var behavior: CharacterBehavior = .idle
    /// Menjeda gerak napas tanpa membongkar scene — saat app tidak aktif atau
    /// Low Power Mode (spec H §5).
    var isPaused = false
    let cache: CharacterExpressionCache

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage = Entity()
    @State private var motion: AnimationPlaybackController?
    @State private var swapCount = 0

    private struct Appearance: Hashable {
        let resourceName: String
        let reduceMotion: Bool
    }

    var body: some View {
        RealityView { content in
            // Kamera virtual: tanpa ini iOS boleh memilih kamera perangkat.
            content.camera = .virtual
            content.add(stage)

            let key = DirectionalLight()
            key.light.intensity = asset.keyLightIntensity
            key.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(key)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = asset.fieldOfViewDegrees
            let eye = SIMD3<Float>(0, asset.cameraHeight, asset.cameraDistance)
            camera.look(at: [0, 0, 0], from: eye, relativeTo: nil)
            content.add(camera)
        }
        .task(id: Appearance(resourceName: asset.resourceName(for: behavior), reduceMotion: reduceMotion)) {
            await show(asset.resourceName(for: behavior))
        }
        .onChange(of: isPaused) { _, paused in
            if paused { motion?.pause() } else { motion?.resume() }
        }
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

    /// Gagal muat tidak mengosongkan panggung: wajah sebelumnya dipertahankan.
    /// Task yang sudah dibatalkan tidak menukar apa pun.
    @MainActor
    private func show(_ resourceName: String) async {
        guard let character = await cache.entity(named: resourceName),
              !Task.isCancelled else { return }

        let bounds = character.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.0001)
        let factor = asset.targetExtent / maxDim
        character.scale *= factor
        character.position = -bounds.center * factor

        let isSwap = !stage.children.isEmpty
        stage.children.removeAll()
        stage.addChild(character)

        motion = reduceMotion ? nil : playIdleMotion(on: character)
        if isPaused { motion?.pause() }
        if isSwap && !reduceMotion { swapCount += 1 }
    }

    /// Kelima ekspor statis, jadi napasnya buatan.
    @MainActor
    private func playIdleMotion(on character: Entity) -> AnimationPlaybackController? {
        if let baked = character.availableAnimations.first {
            return character.playAnimation(baked.repeat(), transitionDuration: 0.3, startsPaused: false)
        }
        guard asset.idleBobHeight > 0 else { return nil }

        var lifted = character.transform
        lifted.translation.y += asset.idleBobHeight
        let bob = FromToByAnimation(to: lifted, duration: asset.idleBobDuration, timing: .easeInOut,
                                    bindTarget: .transform, repeatMode: .autoReverse)
        guard let resource = try? AnimationResource.generate(with: bob) else { return nil }
        return character.playAnimation(resource.repeat(), transitionDuration: 0.3, startsPaused: false)
    }
}

#Preview("Idle") {
    PhoneCharacterView(cache: CharacterExpressionCache())
        .padding()
}

#Preview("Thinking · Dark") {
    PhoneCharacterView(behavior: .thinking, cache: CharacterExpressionCache())
        .padding()
        .preferredColorScheme(.dark)
}
