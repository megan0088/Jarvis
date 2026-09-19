//
//  HotKeyRegistering.swift
//  Apl
//
//  Hotkey global tanpa izin Accessibility (spec C1 §5).
//
//  `RegisterEventHotKey` dipilih, bukan `CGEventTap`: event tap butuh izin
//  Accessibility yang tidak bisa didapat app sandbox di Mac App Store, dan ia
//  membaca SETIAP tombol yang ditekan pengguna. Carbon hanya memberi tahu saat
//  satu kombinasi yang didaftarkan ditekan.
//
//  Pendaftaran disembunyikan di balik protokol karena test berjalan di dalam
//  Apl.app dan tidak boleh mendaftarkan tombol sungguhan ke sistem.
//

import Carbon.HIToolbox
import Foundation

@MainActor
protocol HotKeyRegistering: AnyObject {
    /// `false` bila sistem menolak — biasanya karena kombinasinya sudah dipegang
    /// pihak lain.
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool
    func unregister()
}

@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistering {

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?

    /// 'APL1' — penanda milik app ini di daftar hotkey proses.
    private static let signature = OSType(0x4150_4C31)

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        unregister()
        self.handler = handler

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(),
                                            hotKeyEventHandler,
                                            1,
                                            &spec,
                                            Unmanaged.passUnretained(self).toOpaque(),
                                            &eventHandler)
        guard installed == noErr else {
            self.handler = nil
            return false
        }

        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let registered = RegisterEventHotKey(keyCode, modifiers, id,
                                             GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        handler = nil
    }

    fileprivate func fire() {
        handler?()
    }
}

/// Callback C: berjalan di main run loop, jadi isolasinya ditegaskan, bukan
/// dilompati dengan `Task` yang menunda satu putaran.
private let hotKeyEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { registrar.fire() }
    return noErr
}

/// Menerjemahkan pilihan pengguna jadi pendaftaran, dan menjaga hanya ada satu
/// yang aktif.
@MainActor
final class QuickAskShortcut {

    private let registrar: any HotKeyRegistering

    init(registrar: any HotKeyRegistering = CarbonHotKeyRegistrar()) {
        self.registrar = registrar
    }

    /// `false` hanya bila sistem menolak kombinasinya. `.off` selalu berhasil:
    /// tidak mendaftarkan apa pun adalah hasil yang diminta.
    @discardableResult
    func apply(_ preset: ShortcutPreset, handler: @escaping () -> Void) -> Bool {
        registrar.unregister()
        guard let keyCode = preset.keyCode else { return true }
        return registrar.register(keyCode: keyCode, modifiers: preset.modifiers, handler: handler)
    }

    func stop() {
        registrar.unregister()
    }
}
