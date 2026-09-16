import Foundation
import Testing
@testable import Apl

@MainActor
private final class SpyStore: LocallyErasable {
    private(set) var eraseCount = 0
    func eraseAllStoredData() { eraseCount += 1 }
}

@MainActor
struct DeleteAccountUseCaseTests {

    /// Inti dari UseCase ini: TIDAK ADA penyimpanan yang boleh terlewat.
    /// Dua bug nyata lolos justru karena satu penyimpanan tidak ikut dihapus.
    @Test func erasesEveryStore() {
        let stores = [SpyStore(), SpyStore(), SpyStore()]
        var signedOut = false

        let output = DeleteAccountUseCase(stores: stores, signOut: { signedOut = true }).execute()

        #expect(output.erasedStoreCount == 3)
        #expect(stores.allSatisfy { $0.eraseCount == 1 })
        #expect(signedOut)
    }

    @Test func signsOutEvenWithNoStores() {
        var signedOut = false
        let output = DeleteAccountUseCase(stores: [], signOut: { signedOut = true }).execute()
        #expect(output.erasedStoreCount == 0)
        #expect(signedOut)
    }

    /// Tiap penyimpanan dihapus tepat sekali, bukan berkali-kali — penghapusan
    /// berulang menyembunyikan urutan yang salah.
    @Test func erasesExactlyOncePerStore() {
        let store = SpyStore()
        DeleteAccountUseCase(stores: [store], signOut: {}).execute()
        #expect(store.eraseCount == 1)
    }
}

@MainActor
struct WellnessStoreErasureTests {

    /// Penjaga langsung untuk bug kedua: `WellnessStore` menulis ke suite app
    /// group, sementara penghapusan dulu menyasar `UserDefaults.standard` —
    /// nol data terhapus, nol error.
    ///
    /// Nama suite sengaja ditulis literal di sini. Itu justru invarian yang
    /// dijaga: penghapusan harus mengenai suite tempat data benar-benar ada,
    /// bukan suite mana pun yang kebetulan dipegang pemanggil.
    @Test func eraseTargetsTheAppGroupSuiteNotStandard() throws {
        let suiteName = "group.com.ega.apl"
        let suite = try #require(UserDefaults(suiteName: suiteName))

        let probeKey = "wellness.goalProgress"
        suite.set(Data([0x01]), forKey: probeKey)
        #expect(suite.object(forKey: probeKey) != nil)

        WellnessStore().eraseAllStoredData()

        #expect(suite.object(forKey: probeKey) == nil,
                "eraseAllStoredData tidak menyentuh suite tempat data sesungguhnya berada")
    }

    /// Setiap kunci yang didaftarkan store ikut terhapus — kunci baru yang lupa
    /// dimasukkan ke `Keys.all` akan ketahuan di sini.
    @Test func eraseClearsEveryDeclaredKey() throws {
        let suite = try #require(UserDefaults(suiteName: "group.com.ega.apl"))
        for key in WellnessStore.persistenceKeys {
            suite.set(Data([0x01]), forKey: key)
        }

        WellnessStore().eraseAllStoredData()

        for key in WellnessStore.persistenceKeys {
            #expect(suite.object(forKey: key) == nil, "kunci \(key) tertinggal")
        }
    }
}
