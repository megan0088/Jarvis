//
//  SettingsPage.swift
//  DinoPocketMac
//
//  Page: assistant preferences and Buddy Mode appearance.
//

import SwiftUI

struct SettingsPage: View {
    @Bindable var chat: ChatStore
    @Bindable var buddySettings: BuddySettingsStore

    @State private var appleAvailability: BrainAvailability?

    var body: some View {
        Form {
            Section("Assistant") {
                // Rilis hanya punya satu otak, jadi tidak ada yang perlu dipilih —
                // yang berguna bagi pengguna adalah tahu apakah otak itu siap.
                LabeledContent("Apple Intelligence") {
                    switch appleAvailability {
                    case .ready:
                        Label("Ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    case .needsSetup(let reason), .unavailable(let reason):
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .labelStyle(.titleAndIcon)
                            .multilineTextAlignment(.trailing)
                    case nil:
                        ProgressView().controlSize(.small)
                    }
                }

                #if DEBUG
                // Ollama hanya tersedia di build DEBUG; tidak pernah ikut rilis.
                Picker("Brain (debug)", selection: $chat.activeBrain) {
                    ForEach(BrainKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                #endif

                Picker("Persona", selection: $chat.persona) {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        Text(persona.label).tag(persona)
                    }
                }
            }

            Section("Buddy") {
                LabeledContent("Character size") {
                    HStack(spacing: 12) {
                        Slider(
                            value: $buddySettings.size,
                            in: BuddySettingsStore.sizeRange,
                            step: 10
                        )
                        Text("\(Int(buddySettings.size)) pt")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Text("Takes effect immediately while Buddy Mode is running.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task {
            appleAvailability = await chat.availability(of: .apple)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsPage(chat: ChatStore(brains: [:]), buddySettings: BuddySettingsStore())
    }
}
