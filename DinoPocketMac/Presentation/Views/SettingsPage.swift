//
//  SettingsPage.swift
//  Jarvis
//
//  Page: brain + persona preferences for the chat experience.
//

import SwiftUI

struct SettingsPage: View {
    @Bindable var chat: ChatStore

    var body: some View {
        Form {
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
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsPage(chat: ChatStore(brains: [:]))
    }
}
