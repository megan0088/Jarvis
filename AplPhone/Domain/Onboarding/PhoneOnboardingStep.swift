//
//  PhoneOnboardingStep.swift
//  Apl (iPhone)
//
//  Tiga langkah perkenalan, tanpa akun (spec H §4.3).
//

import Foundation

enum PhoneOnboardingStep: Int, CaseIterable {
    case welcome, reminders, intelligence

    var next: PhoneOnboardingStep? { PhoneOnboardingStep(rawValue: rawValue + 1) }
    var previous: PhoneOnboardingStep? { PhoneOnboardingStep(rawValue: rawValue - 1) }

    /// Start selalu aktif: reminder dan robot berguna tanpa Apple Intelligence.
    var primaryTitle: String { next == nil ? "Start" : "Continue" }

    var position: String { "Step \(rawValue + 1) of \(Self.allCases.count)" }
}
