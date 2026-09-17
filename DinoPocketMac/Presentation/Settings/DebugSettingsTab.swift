//
//  DebugSettingsTab.swift
//  Apl
//
//  KHUSUS DEBUG: memaksa status Apple Intelligence (spec B §8).
//

#if DEBUG
import SwiftUI

struct DebugSettingsTab: View {
    @AppStorage(ForcedAvailability.defaultsKey) private var forced: ForcedAvailability = .system

    var body: some View {
        Form {
            Picker("Apple Intelligence", selection: $forced) {
                ForEach(ForcedAvailability.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Text("The main window re-checks this each time it becomes active. Debug builds only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

#Preview("Debug · Light") {
    DebugSettingsTab()
        .frame(width: 480, height: 200)
}

#Preview("Debug · Dark") {
    DebugSettingsTab()
        .frame(width: 480, height: 200)
        .preferredColorScheme(.dark)
}
#endif
