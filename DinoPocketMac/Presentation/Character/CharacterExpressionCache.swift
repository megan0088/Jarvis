//
//  CharacterExpressionCache.swift
//  AplMac
//
//  Memuat tiap ekspresi USDZ sekali, lalu membagikan salinannya (spec B §6).
//
//  Tanpa cache, setiap pergantian mood membaca berkas dari disk lagi: robot
//  tertahan di wajah lama selama model baru dimuat, dan saat jawaban pendek
//  wajah "berpikir" muncul setelah jawabannya selesai. Jendela utama dan
//  Buddy berbagi satu instance, jadi satu berkas tidak pernah dimuat dua kali.
//

import Foundation
import RealityKit

@MainActor
final class CharacterExpressionCache {

    static let shared = CharacterExpressionCache()

    private let bundle: Bundle
    /// Model asli, tidak pernah dipasang ke scene. Yang dipasang selalu salinannya,
    /// jadi normalisasi skala di view tidak menumpuk pada model asli.
    private var templates: [String: Entity] = [:]
    /// Berkas yang gagal dimuat tidak dicari lagi setiap kali mood berubah.
    private var missing: Set<String> = []
    /// Pemuatan yang sedang berjalan: dua permintaan serentak berbagi satu baca berkas.
    private var loading: [String: Task<Entity?, Never>] = [:]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var loadedCount: Int { templates.count }

    /// Salinan siap pakai, atau nil bila berkas tidak ada atau gagal dimuat.
    func entity(named name: String) async -> Entity? {
        if let template = templates[name] {
            return template.clone(recursive: true)
        }
        if missing.contains(name) {
            return nil
        }

        let task: Task<Entity?, Never>
        if let running = loading[name] {
            task = running
        } else {
            let bundle = self.bundle
            task = Task { try? await Entity(named: name, in: bundle) }
            loading[name] = task
        }

        let template = await task.value
        loading[name] = nil
        guard let template else {
            missing.insert(name)
            return nil
        }
        templates[name] = template
        return template.clone(recursive: true)
    }

    /// Dipanggil saat app dibuka, supaya pergantian ekspresi pertama pun instan.
    func preload(_ asset: CharacterAsset) async {
        for name in asset.allResourceNames {
            _ = await entity(named: name)
        }
    }
}
