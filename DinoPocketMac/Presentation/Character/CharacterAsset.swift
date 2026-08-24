//
//  CharacterAsset.swift
//  DinoPocketMac
//
//  Deskripsi aset karakter sebagai DATA, bukan kode.
//
//  Tujuannya satu: mengganti model 3D cukup dengan menambah satu literal di
//  bawah, tanpa menyentuh view, window controller, atau logika framing. Aset
//  final belum ada, jadi ini bukan abstraksi spekulatif — penggantian memang
//  sudah dijadwalkan.
//

import Foundation

/// Apa yang sedang dilakukan karakter. Nama klip animasi TIDAK dipakai di sini;
/// pemetaannya hidup di `CharacterAsset.clips`, sehingga model dengan penamaan
/// klip berbeda tidak memaksa perubahan kode.
enum CharacterBehavior: Hashable, Sendable {
    case idle
    case greet
    case sleepy
    case celebrate
}

/// Kredit yang wajib ditampilkan untuk aset pihak ketiga.
/// `nil` berarti aset milik sendiri — dan baris kredit di About hilang otomatis.
struct Attribution: Equatable, Sendable {
    let author: String
    let url: String
    let license: String

    var displayText: String { "3D character by \(author) (\(url)) — \(license)" }

    static let sketchfabRobot = Attribution(
        author: "l0wpoly",
        url: "sketchfab.com/l0wpoly",
        license: "Sketchfab Standard License"
    )
}

struct CharacterAsset: Equatable, Sendable {

    /// Nama resource di bundle, tanpa ekstensi.
    let resourceName: String

    /// Sisi terpanjang model setelah normalisasi, dalam satuan dunia.
    /// Model dinormalisasi otomatis, jadi aset baru boleh dibuat pada skala apa pun.
    let targetExtent: Float

    let cameraDistance: Float
    let cameraHeight: Float
    let fieldOfViewDegrees: Float
    let keyLightIntensity: Float

    /// Perilaku → nama klip animasi di dalam berkas USDZ.
    let clips: [CharacterBehavior: String]

    let attribution: Attribution?

    /// Resolusi berjenjang, supaya model yang belum punya animasi lengkap tidak
    /// pecah: perilaku yang diminta, lalu idle, lalu klip pertama apa pun.
    func clipName(for behavior: CharacterBehavior) -> String? {
        clips[behavior] ?? clips[.idle]
    }
}

extension CharacterAsset {

    /// Aset sementara. Digantikan model buatan sendiri; saat itu terjadi,
    /// `attribution` menjadi nil dan kewajiban kredit lenyap dengan sendirinya.
    ///
    /// Angka kamera diturunkan dari geometri model yang diukur, bukan ditebak:
    /// extents 1.096 × 1.012 × 0.320 dinormalisasi ke 0.35.
    static let robot = CharacterAsset(
        resourceName: "Robot",
        targetExtent: 0.35,
        cameraDistance: 0.9,
        cameraHeight: 0.02,
        fieldOfViewDegrees: 30,
        keyLightIntensity: 2500,
        // Robot.usdz membawa dua klip berdurasi sama; yang pertama adalah idle-nya.
        clips: [.idle: "global scene animation"],
        attribution: .sketchfabRobot
    )
}
