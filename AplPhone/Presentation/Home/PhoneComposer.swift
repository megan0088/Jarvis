//
//  PhoneComposer.swift
//  Apl (iPhone)
//
//  Kolom tulis (spec H §4.1): kapsul multi-baris dengan tombol kirim bulat,
//  yang menjadi tombol stop selama Apl menjawab.
//

import SwiftUI

struct PhoneComposer: View {
    @Binding var draft: String
    let state: ComposerState
    let onSend: () -> Void
    let onStop: () -> Void
    var isFocused: FocusState<Bool>.Binding

    private var canSend: Bool {
        state.acceptsInput && state != .streaming
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField(state.placeholder, text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .focused(isFocused)
                .disabled(!state.acceptsInput)
                .padding(.vertical, 10)
            actionButton
                .padding(.bottom, 5)
        }
        .padding(.leading, Spacing.lg)
        .padding(.trailing, 6)
        .background(PhoneColor.controlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.separator))
    }

    @ViewBuilder
    private var actionButton: some View {
        if state == .streaming {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.footnote.weight(.bold))
            }
            .buttonStyle(RoundActionStyle(isActive: true))
            .accessibilityLabel("Stop")
        } else {
            Button {
                guard canSend else { return }
                onSend()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(RoundActionStyle(isActive: canSend))
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
    }
}

/// Tombol bulat 32pt berwarna aksen, dengan area sentuh 44pt.
private struct RoundActionStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? PhoneColor.onAccent : Color.secondary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(isActive ? PhoneColor.accent : PhoneColor.controlFill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .frame(width: 32, height: 32)
    }
}

#Preview("Composer") {
    @Previewable @State var draft = "Remind me to stretch at 3 PM"
    @Previewable @FocusState var focused: Bool
    VStack(spacing: Spacing.md) {
        PhoneComposer(draft: $draft, state: .ready, onSend: {}, onStop: {}, isFocused: $focused)
        PhoneComposer(draft: .constant(""), state: .streaming, onSend: {}, onStop: {}, isFocused: $focused)
        PhoneComposer(draft: .constant(""), state: .unavailable("Off"), onSend: {}, onStop: {}, isFocused: $focused)
    }
    .padding()
}
