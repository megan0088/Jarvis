//
//  Composer.swift
//  Apl
//
//  Kolom tulis (spec B §5, §7): kapsul 40pt, tombol kirim bulat 28pt.
//  Return mengirim, ⇧Return menambah baris, Esc menghentikan jawaban.
//

import AppKit
import SwiftUI

struct Composer: View {
    @Binding var draft: String
    let state: ComposerState
    let onSend: () -> Void
    let onStop: () -> Void
    /// `nil` di bubble: di sana composer selalu fokus begitu panel muncul.
    var focus: ComposerFocus?

    @FocusState private var isFocused: Bool
    @State private var shiftReturn = ShiftReturnNewline()

    private var canSend: Bool {
        state.acceptsInput && state != .streaming
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField(state.placeholder, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .disabled(!state.acceptsInput)
                .onSubmit { submit() }
                .onKeyPress(.escape) {
                    guard state == .streaming else { return .ignored }
                    onStop()
                    return .handled
                }
                .padding(.vertical, 11)
            actionButton
                .padding(.bottom, 6)
        }
        .padding(.leading, Spacing.lg)
        .padding(.trailing, 6)
        .frame(minHeight: 40)
        .background(AppColor.controlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.separator))
        .task { isFocused = true }
        // Shortcut global yang mengenai jendela utama mengembalikan fokus ke
        // sini tanpa harus mengklik.
        .onChange(of: focus?.token) { _, _ in
            isFocused = true
        }
        .onChange(of: isFocused, initial: true) { _, focused in
            shiftReturn.isActive = focused
        }
        .onAppear { shiftReturn.start() }
        .onDisappear { shiftReturn.stop() }
    }

    @ViewBuilder
    private var actionButton: some View {
        if state == .streaming {
            Button { onStop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(RoundActionButtonStyle(isActive: true))
            .help("Stop (Esc)")
            .accessibilityLabel("Stop")
        } else {
            Button { submit() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(RoundActionButtonStyle(isActive: canSend))
            .disabled(!canSend)
            .help("Send (Return)")
            .accessibilityLabel("Send")
        }
    }

    private func submit() {
        guard canSend else { return }
        onSend()
    }
}

/// ⇧Return menyisipkan baris baru di posisi kursor.
///
/// `onKeyPress` tidak pernah menerima ⇧Return karena field editor AppKit
/// menangkapnya lebih dulu, dan tidak berbuat apa-apa dengannya. Monitor
/// lokal ini menyisipkan baris lewat field editor itu sendiri, hanya selama
/// composer fokus, supaya kolom satu baris lain (nama panggilan, judul
/// reminder) tidak ikut terpengaruh. ⌥Return bawaan tetap berfungsi.
@MainActor
private final class ShiftReturnNewline {
    var isActive = false
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isActive,
                  event.keyCode == 36,                                   // 36 = Return
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift,
                  let editor = event.window?.firstResponder as? NSTextView,
                  editor.isFieldEditor else { return event }
            editor.insertNewlineIgnoringFieldEditor(nil)
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Tombol bulat 28pt berwarna aksen. Ikonnya memakai warna latar teks,
/// sehingga tetap kontras di atas teal gelap (light) maupun teal terang (dark).
private struct RoundActionButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Color(nsColor: .textBackgroundColor) : Color.secondary)
            .frame(width: 28, height: 28)
            .background(Circle().fill(isActive ? AppColor.accent : AppColor.controlFill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Circle())
    }
}

#Preview("Composer · Light") {
    @Previewable @State var draft = "Remind me to stretch at 3 PM"
    VStack(spacing: Spacing.md) {
        Composer(draft: $draft, state: .ready, onSend: {}, onStop: {})
        Composer(draft: .constant(""), state: .streaming, onSend: {}, onStop: {})
        Composer(draft: .constant(""), state: .preparing, onSend: {}, onStop: {})
    }
    .padding()
    .frame(width: 560)
}

#Preview("Composer · Dark") {
    @Previewable @State var draft = ""
    VStack(spacing: Spacing.md) {
        Composer(draft: $draft, state: .unavailable("Enable Apple Intelligence in System Settings."),
                 onSend: {}, onStop: {})
        Composer(draft: .constant("Hello"), state: .ready, onSend: {}, onStop: {})
    }
    .padding()
    .frame(width: 560)
    .preferredColorScheme(.dark)
}
