//
//  PhoneHomeView.swift
//  Apl (iPhone)
//
//  Layar utama, tata letak A (spec H §4.1): robot di atas, percakapan di
//  bawah, composer di atas keyboard.
//
//  Ekspresi robot dihitung CharacterMoodResolver setiap render. View ini hanya
//  memastikan ada render ulang tepat saat momen 3 detik berakhir.
//

import SwiftUI

struct PhoneHomeView: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let cache: CharacterExpressionCache
    let onOpenReminders: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSystemSettings: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var draft = ""
    @State private var availability: BrainAvailability?
    @State private var activatedAt: Date?
    /// Diperbarui saat momen berakhir, supaya body dievaluasi ulang.
    @State private var clock = Date.now
    @State private var headerMode: HomeHeaderMode = .full
    @State private var scroll = ScrollSnapshot()
    @FocusState private var isComposerFocused: Bool

    private struct ScrollSnapshot: Equatable {
        var distanceFromTop: Double = 0
        var contentHeight: Double = 0
        var viewportHeight: Double = 0
    }

    private var composerState: ComposerState {
        .current(availability: availability, isStreaming: chat.isStreaming)
    }

    /// Belum dicek dianggap tersedia, supaya robot tidak sempat tertidur saat app dibuka.
    private var isIntelligenceAvailable: Bool {
        guard let availability else { return true }
        return availability == .ready
    }

    private var moodInput: CharacterMoodInput {
        CharacterMoodInput(intelligenceAvailable: isIntelligenceAvailable,
                           isStreaming: chat.isStreaming,
                           lastEvent: chat.lastEvent,
                           windowActivatedAt: activatedAt)
    }

    /// Kapan reminder yang baru dibuat akan berbunyi — untuk "Reminder set for 3:00 PM".
    private var celebratedTime: Date? {
        guard let event = chat.lastEvent,
              case .reminderCreated(let id) = event.kind,
              let reminder = reminders.reminder(withID: id) else { return nil }
        return reminder.nextOccurrence(after: event.at)
    }

    var body: some View {
        // `clock` dibaca di sini agar pembaruannya memicu render ulang.
        let now = max(Date.now, clock)
        let resolution = CharacterMoodResolver.resolve(moodInput, now: now)
        let statusText = CharacterStatusText.text(for: resolution.behavior, now: now,
                                                  intelligenceAvailable: isIntelligenceAvailable,
                                                  celebratedTime: celebratedTime)
        let upcoming = reminders.rows(at: now).count

        VStack(spacing: 0) {
            topBar(upcoming: upcoming)

            PhoneHomeHeader(mode: headerMode, behavior: resolution.behavior, statusText: statusText,
                            isIntelligenceAvailable: isIntelligenceAvailable,
                            // Mitigasi baterai (spec H §5).
                            isAnimationPaused: scenePhase != .active
                                || ProcessInfo.processInfo.isLowPowerModeEnabled,
                            cache: cache)

            messageList

            VStack(spacing: Spacing.sm) {
                if let availability, availability != .ready {
                    PhoneAIBanner(availability: availability, onOpenSettings: onOpenSystemSettings)
                }
                PhoneComposer(draft: $draft, state: composerState,
                              onSend: { send() },
                              onStop: { chat.stopStreaming() },
                              isFocused: $isComposerFocused)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
        .task(id: resolution.reevaluateAt) {
            guard let next = resolution.reevaluateAt else { return }
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            clock = .now
        }
        // "Jendela aktif" di Mac = app menjadi aktif di iPhone (spec H §5).
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            activatedAt = .now
            // Pengguna mungkin baru menyalakan Apple Intelligence atau
            // notifikasi di Settings.
            Task {
                availability = await chat.availability()
                await reminders.refreshPermission()
            }
        }
        .onChange(of: scroll) { _, _ in updateHeader() }
        .onChange(of: isComposerFocused) { _, _ in updateHeader() }
        .onChange(of: dynamicTypeSize, initial: true) { _, _ in updateHeader() }
        // Jawaban yang utuh dikabarkan ke VoiceOver (spec H §6).
        .onChange(of: AnswerAnnouncementText.text(messages: chat.messages,
                                                  isStreaming: chat.isStreaming)) { _, text in
            guard let text else { return }
            AccessibilityNotification.Announcement(text).post()
        }
    }

    private func topBar(upcoming: Int) -> some View {
        HStack {
            Button(action: onOpenReminders) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "bell")
                    if let badge = BellBadge.text(upcomingCount: upcoming) {
                        Text(badge)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel(BellBadge.accessibilityLabel(upcomingCount: upcoming))

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            .accessibilityLabel("Settings")
        }
        .font(.title3)
        .tint(PhoneColor.accent)
        .padding(.horizontal, Spacing.lg)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(chat.messages) { message in
                        PhoneMessageRow(message: message, reminders: reminders,
                                        canRetry: !chat.isStreaming && message.id == chat.messages.last?.id,
                                        onRetry: { Task { await chat.retry(message.id) } })
                            .id(message.id)
                    }
                    if let notice = chat.noticeMessage {
                        Label(notice, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isComposerFocused = false }
            .onScrollGeometryChange(for: ScrollSnapshot.self) { geometry in
                ScrollSnapshot(distanceFromTop: geometry.contentOffset.y + geometry.contentInsets.top,
                               contentHeight: geometry.contentSize.height,
                               viewportHeight: geometry.containerSize.height)
            } action: { _, snapshot in
                scroll = snapshot
            }
            // Mengikuti pesan terakhir, termasuk saat ia memanjang.
            .onChange(of: chat.messages.last) { old, new in
                guard let new else { return }
                if old?.id == new.id {
                    proxy.scrollTo(new.id, anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(new.id, anchor: .bottom)
                    }
                }
            }
            .overlay {
                if chat.messages.isEmpty && !chat.isStreaming {
                    ContentUnavailableView {
                        Label("Say hi to Apl", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Ask anything, or try “Remind me to stretch at 3 PM”.")
                    }
                }
            }
        }
    }

    private func updateHeader() {
        headerMode = HomeHeaderMode.resolve(current: headerMode,
                                            distanceFromTop: scroll.distanceFromTop,
                                            contentHeight: scroll.contentHeight,
                                            viewportHeight: scroll.viewportHeight,
                                            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                                            isKeyboardVisible: isComposerFocused)
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await chat.send(text) }
    }
}

#Preview("Home") {
    PhoneHomeView(chat: .preview(), reminders: .preview(), cache: CharacterExpressionCache(),
                  onOpenReminders: {}, onOpenSettings: {}, onOpenSystemSettings: {})
}

#Preview("Home · Empty · Dark") {
    PhoneHomeView(chat: .preview([]), reminders: .preview([]), cache: CharacterExpressionCache(),
                  onOpenReminders: {}, onOpenSettings: {}, onOpenSystemSettings: {})
        .preferredColorScheme(.dark)
}
