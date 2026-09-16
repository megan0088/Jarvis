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

    @State private var wellness = deps.makeWellnessViewModel()
    @State private var chat = deps.makeChatStore()
    // Catatan: wellness dibuat dari deps.wellnessStore yang sudah disimpan di
    // AppDependencies, sehingga hanya ada satu WellnessStore dalam seluruh app.
    @State private var buddySettings = deps.buddySettings
    @State private var profile = deps.profile

    @Environment(\.scenePhase) private var scenePhase
    @State var isBuddyMode = false

    init() {
        ReminderNotificationCenter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    chat.createReminder = Self.deps.makeCreateReminderUseCase()
                    await wellness.prepare()
                }
        }
        // Modifier Scene, bukan View. Tanpa ini jendela memakai ukuran bawaan
        // yang bisa memotong grid kartu dan sidebar. 1000×680 memuat dua kolom
        // LazyVGrid(.adaptive(minimum: 260)) plus sidebar 190pt dengan lega.
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                wellness.resumeSession()
                Task { await wellness.syncReminderHistory() }
            case .inactive, .background:
                wellness.pauseSession()
                if phase == .background { wellness.tick() }
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if profile.hasCompletedOnboarding {
            dashboard
        } else {
            OnboardingView(profile: profile, chat: chat,
                           onNotificationsGranted: {
                               // Reminder yang dibuat sebelum izin diberikan baru bisa dijadwalkan sekarang.
                               await Self.deps.reminderScheduler.sync(Self.deps.reminderStore.reminders, now: .now)
                           })
        }
    }

    @ViewBuilder
    private var dashboard: some View {
        DashboardTemplate(
            wellness: wellness,
            chat: chat,
            buddySettings: buddySettings,
            profile: profile,
            extraErasableStores: Self.deps.erasableStores,
            onBuddyMode: toggleBuddyMode,
            isBuddyModeActive: isBuddyMode
        )
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
        // Buddy Mode menyala sendiri begitu dashboard tampil.
        //
        // Sebelumnya ia hanya bisa dinyalakan lewat tombol di HomePage, dan
        // janji di layar onboarding — "a small robot lives on your desktop" —
        // baru terjadi kalau user menemukan tombol itu lebih dulu.
        //
        // Dijalankan sekali per kemunculan dashboard; menyalakan ulang saat
        // sudah aktif akan membangun ulang jendelanya tanpa alasan.
        .task {
            guard !isBuddyMode else { return }
            isBuddyMode = true
        }
    }
}
