import Carbon.HIToolbox
import Testing
@testable import Apl

@MainActor
final class FakeHotKeyRegistrar: HotKeyRegistering {
    var registered: (keyCode: UInt32, modifiers: UInt32)?
    var registerCount = 0
    var unregisterCount = 0
    /// Disetel test untuk meniru macOS yang menolak kombinasinya.
    var refuses = false
    private var handler: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        registerCount += 1
        guard !refuses else { return false }
        registered = (keyCode, modifiers)
        self.handler = handler
        return true
    }

    func unregister() {
        unregisterCount += 1
        registered = nil
        handler = nil
    }

    func simulatePress() { handler?() }
}

@MainActor
struct QuickAskShortcutTests {

    @Test func applyingAPresetRegistersItsKey() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        #expect(shortcut.apply(.optionCommandA, handler: {}))
        #expect(registrar.registered?.keyCode == UInt32(kVK_ANSI_A))
        #expect(registrar.registered?.modifiers == UInt32(optionKey | cmdKey))
    }

    @Test func pressingTheKeyCallsTheHandler() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        var fired = 0
        _ = shortcut.apply(.optionSpace, handler: { fired += 1 })
        registrar.simulatePress()
        #expect(fired == 1)
    }

    /// Mengganti pilihan tidak boleh meninggalkan tombol lama terdaftar.
    @Test func changingPresetReplacesTheRegistration() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        _ = shortcut.apply(.optionSpace, handler: {})
        _ = shortcut.apply(.optionCommandA, handler: {})
        #expect(registrar.unregisterCount == 2)     // sekali sebelum tiap pendaftaran
        #expect(registrar.registered?.keyCode == UInt32(kVK_ANSI_A))
    }

    @Test func offRegistersNothingAndReportsSuccess() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        #expect(shortcut.apply(.off, handler: {}))
        #expect(registrar.registerCount == 0)
        #expect(registrar.registered == nil)
    }

    /// Kombinasi yang ditolak sistem dilaporkan, bukan ditelan diam-diam.
    @Test func refusedRegistrationIsReported() {
        let registrar = FakeHotKeyRegistrar()
        registrar.refuses = true
        let shortcut = QuickAskShortcut(registrar: registrar)
        #expect(shortcut.apply(.optionSpace, handler: {}) == false)
    }

    @Test func stoppingUnregisters() {
        let registrar = FakeHotKeyRegistrar()
        let shortcut = QuickAskShortcut(registrar: registrar)
        _ = shortcut.apply(.optionSpace, handler: {})
        shortcut.stop()
        #expect(registrar.registered == nil)
    }
}
