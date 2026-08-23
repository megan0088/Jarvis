//
//  ChatPage.swift
//  Jarvis
//
//  Page: functional chat surface — message history, persona switcher, and
//  a streaming-aware input row wired to ChatStore.
//

import SwiftUI

struct ChatPage: View {
    @Bindable var chat: ChatStore
    @State private var draft = ""

    private var canSend: Bool {
        !chat.isStreaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if let notice = chat.noticeMessage {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(AppColor.card)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(chat.messages) { message in
                        MessageBubble(message: message)
                    }
                    if chat.isStreaming {
                        HStack(spacing: Spacing.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Typing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }

            Divider()

            HStack(spacing: Spacing.sm) {
                TextField("Message Jarvis…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Persona", selection: $chat.persona) {
                    ForEach(Persona.allCases, id: \.self) { persona in
                        Text(persona.label).tag(persona)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Chat")
    }

    private func send() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }
}

#Preview {
    NavigationStack {
        ChatPage(chat: ChatStore(brains: [:]))
    }
}
