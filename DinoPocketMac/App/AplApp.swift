//
//  AplApp.swift
//  Apl
//
//  Created by Codex on 13/03/26.
//

import SwiftUI

@main
struct AplApp: App {
    /// Satu-satunya tempat implementasi konkret dipilih.
    private static let deps = AppDependencies.live()

    @State private var chat = deps.makeChatStore()
    @State private var reminders = deps.makeReminderListViewModel()
    @State private var buddySettings = deps.buddySettings
    @State private var shortcutSettings = deps.shortcutSettings
    @State private var nudgeHistory = deps.nudgeHistory
    @State private var speaker = NudgeSpeaker()
    @State private var nudges: NudgeScheduler?
    @State private var profile = deps.profile

    @State var isBuddyMode = false
    /// Dibaca extension macOS saat shortcut mengenai jendela utama.
    @State var composerFocus = ComposerFocus()
    @State private var shortcut = QuickAskShortcut()

    init() {
        ReminderNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.createReminder = Self.deps.makeCreateReminderUseCase()
                    // Kelima ekspresi dimuat di awal, supaya pergantian wajah
                    // pertama pun tidak menunggu disk (spec B §6).
                    await CharacterExpressionCache.shared.preload(.robot)
                }
        }
        // Judul jendela disembunyikan: stage dan header percakapan mengisi
        // bagian atas, dan latar jendela bisa diseret untuk memindahkannya.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(MainWindowLayout.defaultSize)
        .windowResizability(.contentMinSize)
        .commands {
            ConversationCommands()
        }

        Settings {
            SettingsWindow(profile: profile,
                           buddySettings: buddySettings,
                           shortcutSettings: shortcutSettings,
                           launchAtLogin: Self.deps.launchAtLogin,
                           eraseAllData: { await eraseAllData() })
        }
    }

    /// Erase All Data (spec B §8). Tiap penyimpanan memusnahkan miliknya
    /// sendiri; UseCase ini tidak tahu satu pun nama kunci atau suite.
    private func eraseAllData() async {
        if isBuddyMode { dismissFromBuddy() }
        nudges?.stop()
        let stores: [any LocallyErasable] = [profile, chat, buddySettings, shortcutSettings]
            + Self.deps.erasableStores
        await EraseAllDataUseCase(stores: stores,
                                  clearNotifications: { await Self.deps.reminderScheduler.cancelAll() })
            .execute()
    }

    @ViewBuilder
    private var rootView: some View {
        if profile.hasCompletedOnboarding {
            mainWindow
        } else {
            OnboardingView(profile: profile, chat: chat, launcher: Self.deps.appLauncher,
                           requestNotifications: {
                               let scheduler = Self.deps.reminderScheduler
                               let granted = await scheduler.requestAuthorization()
                               if granted {
                                   // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                                   await scheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                               }
                               return granted
                           },
                           shortcutPreset: shortcutSettings.preset)
        }
    }

    @ViewBuilder
    private var mainWindow: some View {
        MainWindow(chat: chat, reminders: reminders, launcher: Self.deps.appLauncher,
                   isBuddyModeOn: isBuddyMode, onToggleBuddy: toggleBuddyMode,
                   composerFocus: composerFocus)
        // Setiap preferensi buddy diterapkan langsung tanpa memulai ulang mode,
        // supaya kontrol di Settings terasa hidup saat digeser.
        .onChange(of: buddySettings.size) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.updateCharacterSize(CGFloat(value))
        }
        .onChange(of: buddySettings.opacity) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(opacity: value)
        }
        .onChange(of: buddySettings.keepOnTop) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(keepOnTop: value)
        }
        .onChange(of: buddySettings.strolling) { _, value in
            guard isBuddyMode else { return }
            AplBuddyWindowController.shared.apply(strolling: value)
        }
        .onChange(of: isBuddyMode) { _, active in
            if active {
                AplBuddyWindowController.shared.startBuddyMode(
                    settings: buddySettings,
                    onDismiss: { dismissFromBuddy() }
                )
                nudges?.start()
            } else {
                AplBuddyWindowController.shared.stopBuddyMode()
                nudges?.stop()
            }
        }
        // Buddy Mode menyala sendiri begitu jendela utama tampil.
        //
        // Dijalankan sekali per kemunculan; menyalakan ulang saat sudah aktif
        // akan membangun ulang jendelanya tanpa alasan.
        .task {
            guard !isBuddyMode else { return }
            isBuddyMode = true
        }
        // Shortcut global dan bubble (spec C1 §3).
        .task {
            QuickAskPanelController.shared.configure(
                .init(chat: chat,
                      reminders: reminders,
                      openMainWindow: { bringMainWindowForward() },
                      openIntelligenceSettings: { _ = Self.deps.appLauncher.open(.appleIntelligence) })
            )
            AplBuddyWindowController.shared.onCharacterTap = { handleQuickAskShortcut() }
            shortcutSettings.onChange = { preset in
                shortcutSettings.registrationFailed =
                    !shortcut.apply(preset, handler: { handleQuickAskShortcut() })
            }
            shortcutSettings.registrationFailed =
                !shortcut.apply(shortcutSettings.preset, handler: { handleQuickAskShortcut() })

            // Mesin proaktif (spec C2 §3). Ia tidak memutuskan apa pun sendiri;
            // NudgeRules yang memutuskan, dan ia hanya menjalankan jawabannya.
            let scheduler = NudgeScheduler(
                reminders: Self.deps.reminderStore,
                status: Self.deps.systemStatus,
                history: nudgeHistory,
                settings: buddySettings,
                speaker: speaker,
                signals: QuietSignalReader(
                    isBuddyRunning: { isBuddyMode },
                    isQuickAskOpen: { QuickAskPanelController.shared.isOpen },
                    isNudgeOnScreen: { NudgePanelController.shared.isShowing }
                ),
                engage: { nudge in
                    // Sapaan baru masuk percakapan saat diklik (spec C2 §2 #7).
                    chat.appendAssistantNote(nudge.text)
                    _ = QuickAskPanelController.shared.open()
                }
            )
            scheduler.start()
            nudges = scheduler
        }
    }
}
