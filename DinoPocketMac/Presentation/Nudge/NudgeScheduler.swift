//
//  NudgeScheduler.swift
//  Apl
//
//  Detak yang menanyakan satu pertanyaan: ada yang perlu dikatakan? (spec C2 §3)
//
//  Tidak memutuskan apa pun sendiri. Ia mengumpulkan keadaan, bertanya kepada
//  `NudgeRules`, lalu menjalankan jawabannya.
//

import AppKit
import Foundation

@MainActor
final class NudgeScheduler {

    /// Satu menit cukup: jendela reminder 5 menit, dan keadaan mesin berubah
    /// dalam hitungan menit. Di Low Power Mode melambat lima kali lipat —
    /// itulah jawaban atas beban baterai, bukan aturan diam (spec C2 §4).
    static let tick: TimeInterval = 60
    static let lowPowerTick: TimeInterval = 300

    private let reminders: any ReminderStoring
    private let status: any SystemStatusProviding
    private let history: NudgeHistory
    private let settings: BuddySettingsStore
    private let panel: NudgePanelController
    private let speaker: NudgeSpeaker
    private let signals: QuietSignalReader
    private let engage: (Nudge) -> Void
    private let now: () -> Date

    private var timer: Timer?
    private var lastMood: SystemMood?
    private var moodSince: Date?
    private var powerObserver: (any NSObjectProtocol)?

    init(reminders: any ReminderStoring,
         status: any SystemStatusProviding,
         history: NudgeHistory,
         settings: BuddySettingsStore,
         panel: NudgePanelController = .shared,
         speaker: NudgeSpeaker,
         signals: QuietSignalReader,
         engage: @escaping (Nudge) -> Void,
         now: @escaping () -> Date = { .now }) {
        self.reminders = reminders
        self.status = status
        self.history = history
        self.settings = settings
        self.panel = panel
        self.speaker = speaker
        self.signals = signals
        self.engage = engage
        self.now = now
    }

    func start() {
        stop()
        schedule()
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule() }
            }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        powerObserver = nil
        speaker.stop()
        panel.dismiss(engaged: false, notify: false)
    }

    private func schedule() {
        timer?.invalidate()
        let interval = ProcessInfo.processInfo.isLowPowerModeEnabled ? Self.lowPowerTick : Self.tick
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let moment = now()
        let mood = status.currentMood()
        if mood != lastMood {
            lastMood = mood
            moodSince = moment
        }
        history.prune(now: moment)

        guard let nudge = NudgeRules.next(now: moment,
                                          reminders: reminders.reminders,
                                          mood: mood,
                                          moodSince: moodSince,
                                          history: history.snapshot,
                                          signals: signals.read()) else { return }

        // Dicatat SEBELUM ditampilkan: lihat catatan di `NudgeHistory`.
        history.record(nudge, at: moment)
        panel.show(nudge,
                   onEngage: { [weak self] nudge in self?.engaged(nudge) },
                   onIgnore: { [weak self] _ in
                       guard let self else { return }
                       self.history.markIgnored(at: self.now())
                   })
        if settings.speaks {
            speaker.speak(nudge.text)
        }
    }

    private func engaged(_ nudge: Nudge) {
        speaker.stop()
        engage(nudge)
    }
}
