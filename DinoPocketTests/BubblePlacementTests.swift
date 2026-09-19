import CoreGraphics
import Testing
@testable import Apl

struct BubblePlacementTests {

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func robot(x: CGFloat) -> CGRect {
        CGRect(x: x, y: 100, width: 120, height: 120)
    }

    @Test func sitsToTheRightWhenThereIsRoom() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen, contentHeight: 180)
        #expect(frame.minX == 400 + 120 + BubblePlacement.gap)
        #expect(frame.width == BubblePlacement.width)
    }

    /// Tepi atas bubble sejajar tepi atas karakter — "sejajar kepala".
    @Test func topAlignsWithTheCharacter() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen, contentHeight: 180)
        #expect(frame.maxY == robot(x: 400).maxY)
    }

    @Test func flipsToTheLeftWhenTheRightEdgeIsClose() {
        let frame = BubblePlacement.frame(robot: robot(x: 1260), screen: screen, contentHeight: 180)
        #expect(frame.maxX == 1260 - BubblePlacement.gap)
    }

    @Test func staysInsideTheScreenWhenBothSidesAreTight() {
        let narrow = CGRect(x: 0, y: 0, width: 500, height: 400)
        let frame = BubblePlacement.frame(robot: CGRect(x: 190, y: 100, width: 120, height: 120),
                                          screen: narrow, contentHeight: 180)
        #expect(frame.minX >= narrow.minX)
        #expect(frame.maxX <= narrow.maxX)
        #expect(frame.minY >= narrow.minY)
        #expect(frame.maxY <= narrow.maxY)
    }

    @Test func tallContentStopsAtTheCeiling() {
        let frame = BubblePlacement.frame(robot: robot(x: 400), screen: screen, contentHeight: 900)
        #expect(frame.height == BubblePlacement.maxHeight)
    }

    /// Layar sekunder punya origin bukan nol. Hari ini robot terkunci di layar
    /// utama, tapi geometrinya tidak boleh ikut terkunci.
    @Test func followsTheCharacterOntoASecondDisplay() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let frame = BubblePlacement.frame(robot: CGRect(x: 2800, y: 300, width: 120, height: 120),
                                          screen: second, contentHeight: 180)
        #expect(frame.minX >= second.minX)
        #expect(frame.maxX <= second.maxX)
    }

    /// Karakter di dasar layar: bubble tidak boleh menggantung di bawah tepi.
    @Test func doesNotHangBelowTheScreen() {
        let frame = BubblePlacement.frame(robot: CGRect(x: 400, y: 0, width: 120, height: 120),
                                          screen: screen, contentHeight: 260)
        #expect(frame.minY >= screen.minY)
    }
}
