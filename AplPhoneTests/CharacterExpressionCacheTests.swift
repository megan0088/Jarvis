import Foundation
import RealityKit
import Testing
@testable import Apl

/// Memuat USDZ sungguhan dari bundle Apl.app (test host), bukan tiruan:
/// yang ingin dipastikan justru bahwa berkasnya terbaca dan hanya sekali.
@MainActor
struct CharacterExpressionCacheTests {

    @Test func everyExpressionIsListedOnce() {
        #expect(CharacterAsset.robot.allResourceNames
                == ["RobotBigSmile", "RobotFlat", "RobotO", "RobotSad", "RobotSmile"])
    }

    @Test func eachFileIsLoadedOnceAndHandedOutAsCopies() async throws {
        let cache = CharacterExpressionCache()

        let first = try #require(await cache.entity(named: "RobotFlat"))
        let second = try #require(await cache.entity(named: "RobotFlat"))

        #expect(first !== second)
        #expect(cache.loadedCount == 1)
    }

    @Test func missingFileYieldsNilEveryTime() async {
        let cache = CharacterExpressionCache()

        let first = await cache.entity(named: "NoSuchRobot")
        let second = await cache.entity(named: "NoSuchRobot")

        #expect(first == nil)
        #expect(second == nil)
        #expect(cache.loadedCount == 0)
    }
}
