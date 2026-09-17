//
//  DebugAvailabilityBrain.swift
//  AplMac
//
//  KHUSUS DEBUG. Membungkus AppleBrain supaya status Apple Intelligence bisa
//  dipaksa dari tab Debug di Settings (spec B §8). Hanya dengan cara ini
//  banner, robot tertidur, dan composer "Getting ready…" bisa diuji tanpa
//  mengubah pengaturan sistem. Tidak dikompilasi di Release.
//

#if DEBUG
import Foundation

enum ForcedAvailability: String, CaseIterable, Identifiable {
    case system
    case ready
    case notEnabled
    case notEligible
    case downloading

    static let defaultsKey = "debug.forcedAvailability"

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "Use system status"
        case .ready: "Ready"
        case .notEnabled: "Not enabled"
        case .notEligible: "Device not eligible"
        case .downloading: "Model downloading"
        }
    }

    /// nil berarti pakai status sistem. Teksnya sama persis dengan yang
    /// dilaporkan AppleBrain, supaya yang diuji adalah tampilan sungguhan.
    var availability: BrainAvailability? {
        switch self {
        case .system: nil
        case .ready: .ready
        case .notEnabled: .unavailable("Enable Apple Intelligence in System Settings.")
        case .notEligible: .unavailable("Apple Intelligence isn't available on this device.")
        case .downloading: .needsSetup("The on-device model is downloading. Try again later.")
        }
    }

    static func current(in defaults: UserDefaults) -> ForcedAvailability {
        defaults.string(forKey: defaultsKey).flatMap(ForcedAvailability.init(rawValue:)) ?? .system
    }
}

struct DebugAvailabilityBrain: Brain {
    let base: Brain
    let defaults: UserDefaults

    func availability() async -> BrainAvailability {
        if let forced = ForcedAvailability.current(in: defaults).availability {
            return forced
        }
        return await base.availability()
    }

    func reply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        base.reply(to: history)
    }

    func resetConversation() async {
        await base.resetConversation()
    }
}
#endif
