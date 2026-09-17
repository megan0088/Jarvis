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
    @State private var profile = deps.profile

    @State var isBuddyMode = false

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

        // SEMENTARA: halaman Settings lama ditampung jendela ⌘, sampai
        // jendela Settings bertab menggantikannya.
        Settings {
            SettingsPage(chat: chat, buddySettings: buddySettings, profile: profile,
                         extraErasableStores: Self.deps.erasableStores)
                .frame(width: 480, height: 560)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if profile.hasCompletedOnboarding {
            mainWindow
        } else {
            OnboardingView(profile: profile, chat: chat,
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
        }
    }

    @ViewBuilder
    private var mainWindow: some View {
        MainWindow(chat: chat, reminders: reminders, launcher: Self.deps.appLauncher,
                   isBuddyModeOn: isBuddyMode, onToggleBuddy: toggleBuddyMode)
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
            } else {
                AplBuddyWindowController.shared.stopBuddyMode()
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
    }
}
