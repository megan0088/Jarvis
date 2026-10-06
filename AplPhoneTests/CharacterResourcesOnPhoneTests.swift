import Foundation
import Testing
@testable import Apl

/// Aset robot dirujuk dari folder Mac lewat `project.yml`, bukan disalin.
/// Kalau rujukannya salah, app tetap terbangun dan robotnya saja yang hilang.
@MainActor
struct CharacterResourcesOnPhoneTests {

    @Test func everyExpressionIsInThePhoneBundle() {
        for name in CharacterAsset.robot.allResourceNames {
            #expect(Bundle.main.url(forResource: name, withExtension: "usdz") != nil,
                    "\(name).usdz tidak ada di bundle iPhone")
        }
    }

    @Test func theCacheLoadsEveryExpression() async {
        let cache = CharacterExpressionCache()
        await cache.preload(.robot)
        #expect(cache.loadedCount == CharacterAsset.robot.allResourceNames.count)
    }
}
