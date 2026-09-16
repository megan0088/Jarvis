//
//  ChatPage.swift
//  Apl
//
//  Page: functional chat surface — message history and
//  a streaming-aware input row wired to ChatStore.
//

import SwiftUI

struct ChatPage: View {
    @Bindable var chat: ChatStore
    @State private var draft = ""
    @State private var availability: BrainAvailability?

    private var canSend: Bool {
        !chat.isStreaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if case .ready = availability {
                conversation
            } else if let availability {
                AIUnavailableCard(availability: availability)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            availability = await chat.availability()
        }
    }

    private var conversation: some View {
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
                TextField("Message Apl…", text: $draft)
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
        ChatPage(chat: ChatStore(brain: nil))
    }
}
