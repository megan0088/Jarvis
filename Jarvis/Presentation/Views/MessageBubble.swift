//
//  MessageBubble.swift
//  Jarvis
//
//  Molecule: role-styled chat bubble. User messages align trailing with an
//  accent tint; assistant messages align leading on the card background.
//

#if os(macOS)
import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        Text(message.text)
            .padding(Spacing.sm)
            .background(
                isUser ? AppColor.accent.opacity(0.15) : AppColor.card,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        MessageBubble(message: ChatMessage(id: UUID(), role: .user, text: "Hello Jarvis!", date: .now))
        MessageBubble(message: ChatMessage(id: UUID(), role: .assistant, text: "Hi Ega, how can I help?", date: .now))
    }
    .padding()
    .frame(width: 320)
}
#endif
