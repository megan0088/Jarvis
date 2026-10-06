//
//  PhoneSettingsView.swift
//  Apl (iPhone)
//
//  Settings (spec H §4.4): nama panggilan, Clear Conversation, Erase All Data.
//

import SwiftUI

struct PhoneSettingsView: View {
    let profile: ProfileStore
    let chat: ChatStore
    let eraseAllData: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nicknameDraft = ""
    @State private var isConfirmingClear = false
    @State private var isConfirmingErase = false

    #if DEBUG
    @AppStorage(ForcedAvailability.defaultsKey) private var forcedAvailability = ForcedAvailability.system.rawValue
    #endif

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nickname", text: $nicknameDraft)
                        .textContentType(.nickname)
                        .onSubmit { profile.setNickname(nicknameDraft) }
                } header: {
                    Text("What Apl calls you")
                }

                Section {
                    Button("Clear Conversation…") { isConfirmingClear = true }
                        .disabled(chat.messages.isEmpty)
                        .confirmationDialog("Clear this conversation?", isPresented: $isConfirmingClear,
                                            titleVisibility: .visible) {
                            Button("Clear Conversation", role: .destructive) {
                                Task { await chat.clearConversation() }
                            }
                        } message: {
                            Text("Apl will forget this conversation. Your reminders stay.")
                        }
                }

                Section {
                    Button("Erase All Data…", role: .destructive) { isConfirmingErase = true }
                        .confirmationDialog("Erase everything?", isPresented: $isConfirmingErase,
                                            titleVisibility: .visible) {
                            Button("Erase All Data", role: .destructive) {
                                Task {
                                    await eraseAllData()
                                    dismiss()
                                }
                            }
                        } message: {
                            Text("This removes your conversation, reminders, and nickname from this iPhone. "
                                 + "It can't be undone.")
                        }
                } footer: {
                    Text("Everything Apl knows is stored on this iPhone. Nothing is sent anywhere.")
                }

                #if DEBUG
                Section("Debug") {
                    Picker("Apple Intelligence", selection: $forcedAvailability) {
                        ForEach(ForcedAvailability.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                }
                #endif

                Section {
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        profile.setNickname(nicknameDraft)
                        dismiss()
                    }
                }
            }
            .onAppear { nicknameDraft = profile.nickname ?? "" }
        }
    }
}

#Preview("Settings") {
    PhoneSettingsView(profile: .preview(), chat: .preview(), eraseAllData: {})
}
