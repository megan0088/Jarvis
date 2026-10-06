import Testing
@testable import Apl

struct HomeHeaderModeTests {

    private func resolve(current: HomeHeaderMode = .full, distance: Double = 0,
                         content: Double = 200, viewport: Double = 400,
                         accessibility: Bool = false, keyboard: Bool = false) -> HomeHeaderMode {
        HomeHeaderMode.resolve(current: current, distanceFromTop: distance,
                               contentHeight: content, viewportHeight: viewport,
                               isAccessibilitySize: accessibility, isKeyboardVisible: keyboard)
    }

    @Test func shortConversationKeepsTheRobotLarge() {
        #expect(resolve(distance: 0, content: 200, viewport: 400) == .full)
    }

    @Test func scrolledLongConversationCollapsesTheHeader() {
        #expect(resolve(distance: 300, content: 1200, viewport: 400) == .compact)
    }

    /// Jebakannya: percakapan yang hanya meluber SELAMA header besar. Kalau ia
    /// meringkas, ruang bertambah, isinya muat lagi, gulirnya kembali nol, dan
    /// header membesar — berulang tanpa henti.
    @Test func contentThatWouldFitAfterCollapsingDoesNotCollapse() {
        let gain = HomeHeaderMode.collapseGain
        #expect(resolve(current: .full, distance: 60, content: 400 + gain - 1, viewport: 400) == .full)
        #expect(resolve(current: .full, distance: 60, content: 400 + gain + 40, viewport: 400) == .compact)
    }

    /// Setelah ringkas, sedikit menggulir ke atas tidak langsung membesarkan
    /// lagi; baru di paling atas.
    @Test func compactStaysCompactUntilTheTop() {
        #expect(resolve(current: .compact, distance: 12, content: 1200, viewport: 550) == .compact)
        #expect(resolve(current: .compact, distance: 0, content: 1200, viewport: 550) == .full)
    }

    /// Tarikan karet di puncak memberi jarak negatif.
    @Test func rubberBandAtTheTopIsStillTheTop() {
        #expect(resolve(current: .compact, distance: -40, content: 1200, viewport: 550) == .full)
    }

    /// Di ukuran aksesibilitas, robot 150pt menyisakan dua baris teks.
    @Test func accessibilitySizesAlwaysUseTheCompactHeader() {
        #expect(resolve(distance: 0, content: 50, viewport: 400, accessibility: true) == .compact)
    }

    @Test func anOpenKeyboardAlwaysUsesTheCompactHeader() {
        #expect(resolve(distance: 0, content: 50, viewport: 400, keyboard: true) == .compact)
    }
}
