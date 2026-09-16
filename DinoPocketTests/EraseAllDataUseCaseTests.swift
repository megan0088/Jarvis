import Foundation
import Testing
@testable import Apl

@MainActor
private final class EraseLog {
    var entries: [String] = []
}

@MainActor
private final class SpyStore: LocallyErasable {
    let name: String
    let log: EraseLog
    private(set) var eraseCount = 0

    init(_ name: String, log: EraseLog) {
        self.name = name
        self.log = log
    }

    func eraseAllStoredData() {
        eraseCount += 1
        log.entries.append(name)
    }
}

@MainActor
struct EraseAllDataUseCaseTests {

    /// Inti dari UseCase ini: TIDAK ADA penyimpanan yang boleh terlewat, dan
    /// masing-masing dihapus tepat sekali.
    @Test func erasesEveryStoreExactlyOnce() async {
        let log = EraseLog()
        let stores = [SpyStore("a", log: log), SpyStore("b", log: log), SpyStore("c", log: log)]

        let output = await EraseAllDataUseCase(stores: stores).execute()

        #expect(output.erasedStoreCount == 3)
        #expect(stores.allSatisfy { $0.eraseCount == 1 })
    }

    @Test func worksWithNoStores() async {
        let output = await EraseAllDataUseCase(stores: []).execute()
        #expect(output.erasedStoreCount == 0)
    }

    /// Notifikasi dibatalkan SETELAH data dihapus dan DITUNGGU sampai selesai —
    /// reminder lama tidak boleh tetap berbunyi setelah pengguna menghapus semuanya.
    @Test func clearsNotificationsAfterErasingStores() async {
        let log = EraseLog()
        let store = SpyStore("store", log: log)

        await EraseAllDataUseCase(stores: [store],
                                  clearNotifications: { log.entries.append("notifications") }).execute()

        #expect(log.entries == ["store", "notifications"])
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
