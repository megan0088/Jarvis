import AppKit
import Testing
@testable import Apl

/// Token warna diperiksa di kedua tampilan: mockup hanya digambar dalam dark,
/// jadi light mode paling mudah meleset tanpa ada yang sadar (spec B §12).
@MainActor
struct DesignTokenTests {

    private struct RGBA: Equatable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Double
    }

    private static let darkAccent = (red: 0x5E, green: 0xC4, blue: 0xD6)
    private static let lightAccent = (red: 0x12, green: 0x7A, blue: 0x8A)

    private func resolved(_ color: NSColor, in name: NSAppearance.Name) -> RGBA? {
        var result: RGBA?
        NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
            guard let rgb = color.usingColorSpace(.sRGB) else { return }
            result = RGBA(red: Int((rgb.redComponent * 255).rounded()),
                          green: Int((rgb.greenComponent * 255).rounded()),
                          blue: Int((rgb.blueComponent * 255).rounded()),
                          alpha: (Double(rgb.alphaComponent) * 100).rounded() / 100)
        }
        return result
    }

    private func accent(_ tone: (red: Int, green: Int, blue: Int), alpha: Double) -> RGBA {
        RGBA(red: tone.red, green: tone.green, blue: tone.blue, alpha: alpha)
    }

    @Test func accentComesFromTheAssetCatalogInBothAppearances() throws {
        let brand = try #require(NSColor(named: "AccentColor"))
        #expect(resolved(brand, in: .darkAqua) == accent(Self.darkAccent, alpha: 1))
        #expect(resolved(brand, in: .aqua) == accent(Self.lightAccent, alpha: 1))
    }

    @Test func userBubbleIsTheAccentAtSixteenAndTwelvePercent() {
        #expect(resolved(AppColor.userBubbleNSColor, in: .darkAqua) == accent(Self.darkAccent, alpha: 0.16))
        #expect(resolved(AppColor.userBubbleNSColor, in: .aqua) == accent(Self.lightAccent, alpha: 0.12))
    }

    @Test func stageGlowIsTheAccentAtTwentyAndTwelvePercent() {
        #expect(resolved(AppColor.stageGlowNSColor, in: .darkAqua) == accent(Self.darkAccent, alpha: 0.20))
        #expect(resolved(AppColor.stageGlowNSColor, in: .aqua) == accent(Self.lightAccent, alpha: 0.12))
    }
}
