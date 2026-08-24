//
//  DeleteAccountUseCase.swift
//  SharedCore
//
//  Penghapusan akun berikut seluruh data lokalnya.
//
//  App Store Guideline 5.1.1(v): "If your app supports account creation, you
//  must also offer account deletion within the app."
//
//  Ada sebagai UseCase, bukan sebagai metode di `AccountStore`, karena
//  penghapusan menyentuh tiga penyimpanan yang berbeda dan masing-masing tahu
//  detailnya sendiri. Dua bug lolos justru saat satu komponen menebak isi
//  komponen lain:
//
//    1. Daftar kunci wellness disalin tangan ke AccountStore, salah nama
//       ("wellness.customSchedules" vs "pet.customSchedules") dan melewatkan
//       sembilan kunci.
//    2. AccountStore menghapus dari `UserDefaults.standard` sementara
//       WellnessStore menulis ke suite app group — nol data terhapus, nol error.
//
//  UseCase ini tidak tahu satu pun nama kunci. Ia hanya menyuruh tiap
//  penyimpanan memusnahkan miliknya sendiri.
//

import Foundation

/// Apa pun yang menyimpan data pribadi dan harus ikut musnah bersama akun.
///
/// Tidak mensyaratkan `AnyObject`: transcript percakapan disimpan oleh sebuah
/// struct berbasis berkas, dan ia HARUS bisa ikut dimusnahkan. Celah ketiga di
/// jalur ini muncul persis karena penyimpanan baru lupa didaftarkan.
@MainActor
protocol LocallyErasable {
    func eraseAllStoredData()
}

@MainActor
struct DeleteAccountUseCase {

    private let stores: [any LocallyErasable]
    private let signOut: () -> Void

    /// - Parameters:
    ///   - stores: setiap penyimpanan yang memegang data pribadi.
    ///   - signOut: pembuangan kredensial; dipisah karena Keychain bukan store
    ///     yang bisa "dihapus semua isinya" tanpa merusak milik app lain.
    init(stores: [any LocallyErasable], signOut: @escaping () -> Void) {
        self.stores = stores
        self.signOut = signOut
    }

    struct Output: Equatable {
        /// Berapa penyimpanan yang dimusnahkan — dipakai test untuk memastikan
        /// tidak ada yang diam-diam terlewat.
        let erasedStoreCount: Int
    }

    @discardableResult
    func execute() -> Output {
        for store in stores {
            store.eraseAllStoredData()
        }
        signOut()
        return Output(erasedStoreCount: stores.count)
    }
}
