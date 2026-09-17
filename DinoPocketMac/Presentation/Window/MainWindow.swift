//
//  MainWindow.swift
//  Apl
//
//  Jendela utama, layout A · Companion stage (spec B §5–§6): stage karakter di
//  kiri, percakapan di kanan. Di bawah 820pt stage diringkas menjadi header.
//
//  Ekspresi robot dihitung CharacterMoodResolver setiap render. View ini hanya
//  memastikan ada render ulang tepat saat momen 3 detik berakhir.
//

import SwiftUI

struct MainWindow: View {
    let chat: ChatStore
    let reminders: ReminderListViewModel
    let launcher: AppLaunching
    let isBuddyModeOn: Bool
    let onToggleBuddy: () -> Void

    @Environment(\.openSettings) private var openSettings
    @Environment(\.appearsActive) private var appearsActive

    @State private var availability: BrainAvailability?
    @State private var windowActivatedAt: Date?
    /// Diperbarui saat momen berakhir, supaya body dievaluasi ulang.
    @State private var clock = Date.now
    @State private var isConfirmingClear = false

    var body: some View {
        // `clock` dibaca di sini agar pembaruannya memicu render ulang. Waktu
        // yang dipakai tetap "sekarang": kejadian baru bisa lebih muda dari
        // pembaruan `clock` terakhir.
        let now = max(Date.now, clock)
        let resolution = CharacterMoodResolver.resolve(moodInput, now: now)
        let statusText = CharacterStatusText.text(for: resolution.behavior, now: now,
                                                  intelligenceAvailable: isIntelligenceAvailable,
                                                  celebratedTime: celebratedTime)
        // Mitigasi baterai (spec B §12, deviasi 11).
        let isAnimationPaused = !appearsActive || ProcessInfo.processInfo.isLowPowerModeEnabled

        GeometryReader { proxy in
            let isCompact = MainWindowLayout.isCompact(width: proxy.size.width)
            HStack(spacing: 0) {
                if !isCompact {
                    CharacterStage(behavior: resolution.behavior,
                                   statusText: statusText,
                                   reminders: reminders,
                                   isBuddyModeOn: isBuddyModeOn,
                                   isAnimationPaused: isAnimationPaused,
                                   onToggleBuddy: onToggleBuddy,
                                   onOpenSettings: { openSettings() },
                                   onOpenNotificationSettings: { _ = launcher.open(.notifications) })
                        .padding([.leading, .top, .bottom], MainWindowLayout.stageInset)
                }
                VStack(spacing: 0) {
                    if isCompact {
                        CompactStageHeader(behavior: resolution.behavior,
                                           statusText: statusText,
                                           reminders: reminders,
                                           isBuddyModeOn: isBuddyModeOn,
                                           isAnimationPaused: isAnimationPaused,
                                           onToggleBuddy: onToggleBuddy,
                                           onOpenSettings: { openSettings() })
                        Divider()
                    }
                    ConversationView(chat: chat,
                                     reminders: reminders,
                                     availability: availability,
                                     showsDateHeader: !isCompact,
                                     onOpenIntelligenceSettings: { _ = launcher.open(.appleIntelligence) })
                }
            }
        }
        // Judul jendela disembunyikan; stage dan header mengisi area tombol jendela.
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: MainWindowLayout.minimumSize.width, minHeight: MainWindowLayout.minimumSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: resolution.reevaluateAt) {
            guard let next = resolution.reevaluateAt else { return }
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            clock = .now
        }
        .onChange(of: appearsActive, initial: true) { _, isActive in
            guard isActive else { return }
            windowActivatedAt = .now
            // Pengguna mungkin baru menyalakan Apple Intelligence atau
            // notifikasi di System Settings (spec B §9).
            Task {
                availability = await chat.availability()
                await reminders.refreshPermission()
            }
        }
        .focusedSceneValue(\.clearConversationRequest, chat.messages.isEmpty ? nil : $isConfirmingClear)
        .confirmationDialog("Clear this conversation?", isPresented: $isConfirmingClear,
                            titleVisibility: .visible) {
            Button("Clear Conversation", role: .destructive) {
                Task { await chat.clearConversation() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apl will forget this conversation. Your reminders stay.")
        }
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
                           windowActivatedAt: windowActivatedAt)
    }

    /// Kapan reminder yang baru dibuat akan berbunyi — untuk "Reminder set for 3:00 PM".
    private var celebratedTime: Date? {
        guard let event = chat.lastEvent,
              case .reminderCreated(let id) = event.kind,
              let reminder = reminders.reminder(withID: id) else { return nil }
        return reminder.nextOccurrence(after: event.at)
    }
}

#Preview("Main window · Dark") {
    MainWindow(chat: .preview(), reminders: .preview(), launcher: AppLauncherService(),
               isBuddyModeOn: false, onToggleBuddy: {})
        .frame(width: 1000, height: 680)
        .preferredColorScheme(.dark)
}

#Preview("Main window · Light") {
    MainWindow(chat: .preview(), reminders: .preview(), launcher: AppLauncherService(),
               isBuddyModeOn: true, onToggleBuddy: {})
        .frame(width: 1000, height: 680)
}

#Preview("Main window · Compact · Dark") {
    MainWindow(chat: .preview(), reminders: .preview(), launcher: AppLauncherService(),
               isBuddyModeOn: false, onToggleBuddy: {})
        .frame(width: 740, height: 520)
        .preferredColorScheme(.dark)
}
