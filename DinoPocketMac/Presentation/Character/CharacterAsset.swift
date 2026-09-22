//
//  CharacterAsset.swift
//  AplMac
//
//  Deskripsi aset karakter sebagai DATA, bukan kode.
//
//  Tujuannya satu: mengganti model 3D cukup dengan menambah satu literal di
//  bawah, tanpa menyentuh view, window controller, atau logika framing.
//  Penggantian itu sudah terjadi: robot Sketchfab sementara diganti
//  HealthAssistantRobot buatan sendiri, dan memang tidak ada file lain yang
//  perlu diubah selain berkas ini.
//

import Foundation

/// Apa yang sedang dilakukan karakter. Nama berkas TIDAK dipakai di sini;
/// pemetaannya hidup di `CharacterAsset.expressions`, sehingga aset dengan
/// penamaan berbeda tidak memaksa perubahan kode.
enum CharacterBehavior: Hashable, Sendable, CaseIterable {
    case idle
    case greet
    case sleepy
    case celebrate
    case thinking
    /// Murung. Memakai wajah yang sama dengan `.sleepy`, tetapi artinya lain:
    /// `.sleepy` berarti mesin panas atau baterai menipis, `.sad` berarti Apl
    /// kalah suit. Satu wajah, dua sebab — dan sebab itu yang dipisahkan.
    case sad
}

/// Kredit yang wajib ditampilkan untuk aset pihak ketiga.
/// `nil` berarti aset milik sendiri — dan baris kredit di About hilang otomatis.
struct Attribution: Equatable, Sendable {
    let author: String
    let url: String
    let license: String

    var displayText: String { "3D character by \(author) (\(url)) — \(license)" }
}

struct CharacterAsset: Equatable, Sendable {

    /// Berkas yang dipakai untuk `.idle`, sekaligus jaring pengaman untuk
    /// perilaku yang belum punya ekspresinya sendiri. Non-optional dengan
    /// sengaja: karakter tidak boleh punya jalan menuju "tidak ada model".
    let defaultExpression: String

    /// Perilaku → nama berkas USDZ di bundle, tanpa ekstensi.
    ///
    /// Satu berkas per ekspresi, bukan satu berkas dengan banyak klip. Itu
    /// mengikuti bentuk asetnya: kelima ekspor berbagi mesh dan tekstur badan
    /// yang identik dan hanya berbeda pada tekstur wajah, tanpa klip animasi
    /// sama sekali.
    let expressions: [CharacterBehavior: String]

    /// Sisi terpanjang model setelah normalisasi, dalam satuan dunia.
    /// Model dinormalisasi otomatis, jadi aset baru boleh dibuat pada skala apa pun.
    let targetExtent: Float

    let cameraDistance: Float
    let cameraHeight: Float
    let fieldOfViewDegrees: Float
    let keyLightIntensity: Float

    /// Tinggi ayunan napas, dalam satuan dunia yang sama dengan `targetExtent`.
    ///
    /// Aset ini statis — tidak ada satu pun klip di dalam berkasnya — jadi
    /// tanpa gerak buatan karakter membeku seperti gambar. Nol mematikannya,
    /// yang menjadi pilihan benar begitu ada ekspor beranimasi.
    let idleBobHeight: Float
    let idleBobDuration: TimeInterval

    let attribution: Attribution?

    /// Resolusi berjenjang, supaya perilaku yang belum punya ekspresinya
    /// sendiri tetap menampilkan wajah default alih-alih hilang.
    func resourceName(for behavior: CharacterBehavior) -> String {
        expressions[behavior] ?? defaultExpression
    }

    /// Semua berkas yang mungkin tampil, tanpa duplikat — untuk dimuat di awal.
    var allResourceNames: [String] {
        Set(expressions.values).union([defaultExpression]).sorted()
    }
}

extension CharacterAsset {

    /// HealthAssistantRobot — model sendiri, jadi `attribution` nil dan
    /// kewajiban kredit di Settings lenyap dengan sendirinya.
    ///
    /// Angka kamera diturunkan dari geometri yang diukur, bukan ditebak:
    /// extents 3.24 × 1.56 × 3.31 (Blender, Z-up, metersPerUnit 1)
    /// dinormalisasi ke 0.35 pada sisi terpanjang. Siluetnya hampir sama
    /// dengan robot lama setelah normalisasi — 0.343 × 0.35 lawan
    /// 0.35 × 0.32 — sehingga jarak dan FOV kamera lama tetap membingkai pas.
    static let robot = CharacterAsset(
        defaultExpression: "RobotFlat",
        // Wajah dipilih dari apa yang dikomunikasikan keadaan, bukan dari
        // selera: senyum lebar disimpan untuk perayaan supaya tetap berarti,
        // dan wajah datar yang jadi wajah diam.
        expressions: [
            .idle:      "RobotFlat",
            .greet:     "RobotSmile",
            .celebrate: "RobotBigSmile",
            .sleepy:    "RobotSad",
            .thinking:  "RobotO",
            .sad:       "RobotSad",
        ],
        targetExtent: 0.35,
        cameraDistance: 0.9,
        cameraHeight: 0.02,
        fieldOfViewDegrees: 30,
        keyLightIntensity: 2500,
        idleBobHeight: 0.012,
        idleBobDuration: 1.8,
        attribution: nil
    )
}
