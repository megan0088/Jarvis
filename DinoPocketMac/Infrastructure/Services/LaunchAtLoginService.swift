//
//  LaunchAtLoginService.swift
//  AplMac
//
//  Pembungkus `SMAppService.mainApp`.
//

import Foundation
import ServiceManagement

protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    /// Melempar bila sistem menolak; pemanggil harus mengembalikan toggle-nya.
    func setEnabled(_ enabled: Bool) throws
}

struct LaunchAtLoginService: LaunchAtLoginManaging {

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// `.requiresApproval` terjadi saat user pernah menolak app ini di
    /// System Settings › General › Login Items. Registrasi berikutnya "berhasil"
    /// tanpa app benar-benar diluncurkan, jadi UI harus bisa membedakannya
    /// alih-alih menampilkan toggle menyala yang berbohong.
    var needsUserApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }
}
