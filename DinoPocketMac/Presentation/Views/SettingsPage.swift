//
//  SettingsPage.swift
//  DinoPocketMac
//
//  Page: brain + persona preferences for the chat experience, and Buddy Mode
//  appearance.
//

import SwiftUI

struct SettingsPage: View {
    @Bindable var chat: ChatStore
    @Bindable var buddySettings: BuddySettingsStore

    var body: some View {
        Form {
            Section("Assistant") {
                Picker("Brain", selection: $chat.activeBrain) {
                    ForEach(BrainKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
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
    }
}

#Preview {
    NavigationStack {
        SettingsPage(chat: ChatStore(brains: [:]), buddySettings: BuddySettingsStore())
    }
}
