//
//  EraseAllDataUseCase.swift
//  SharedCore
//
//  Menghapus seluruh data lokal Apl — menggantikan "hapus akun" sejak Sign in
//  with Apple dihapus (spec A §5).
//
//  Ada sebagai UseCase, bukan metode di satu store, karena penghapusan
//  menyentuh banyak penyimpanan dan masing-masing tahu detailnya sendiri. Dua
//  bug lolos justru saat satu komponen menebak isi komponen lain:
//
//    1. Daftar kunci wellness disalin tangan ke store lain, salah nama
//       ("wellness.customSchedules" vs "pet.customSchedules") dan melewatkan
//       sembilan kunci.
//    2. Penghapusan menyasar `UserDefaults.standard` sementara datanya ada di
//       suite app group — nol data terhapus, nol error.
//
//  UseCase ini tidak tahu satu pun nama kunci. Ia hanya menyuruh tiap
//  penyimpanan memusnahkan miliknya sendiri.
//

import Foundation

/// Apa pun yang menyimpan data pribadi dan harus ikut musnah saat pengguna
/// menghapus semua data.
///
/// Tidak mensyaratkan `AnyObject`: transcript percakapan disimpan oleh sebuah
/// struct berbasis berkas, dan ia HARUS bisa ikut dimusnahkan. Celah ketiga di
/// jalur ini muncul persis karena penyimpanan baru lupa didaftarkan.
@MainActor
protocol LocallyErasable {
    func eraseAllStoredData()
}

@MainActor
struct EraseAllDataUseCase {

    private let stores: [any LocallyErasable]
    private let clearNotifications: (() async -> Void)?

    /// - Parameters:
    ///   - stores: setiap penyimpanan yang memegang data pribadi.
    ///   - clearNotifications: pembatalan notifikasi terjadwal. Ditunggu sampai
    ///     selesai, supaya reminder lama tidak berbunyi setelah data dihapus.
    init(stores: [any LocallyErasable],
         clearNotifications: (() async -> Void)? = nil) {
        self.stores = stores
        self.clearNotifications = clearNotifications
    }

    struct Output: Equatable {
        /// Berapa penyimpanan yang dimusnahkan — dipakai test untuk memastikan
        /// tidak ada yang diam-diam terlewat.
        let erasedStoreCount: Int
    }

    @discardableResult
    func execute() async -> Output {
        for store in stores {
            store.eraseAllStoredData()
        }
        await clearNotifications?()
        return Output(erasedStoreCount: stores.count)
    }
}
