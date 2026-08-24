//
//  ContentView.swift
//  Jarvis
//
//  Retro pixel-art redesign
//

import SwiftUI
import Observation
import SpriteKit
import Charts
#if os(iOS)
import ActivityKit
#endif

// MARK: - Retro Colour Palette

private extension Color {
    // Base — warm cream background
    static let retroBg          = Color(red: 0.902, green: 0.863, blue: 0.784)  // --bg-main    #E6DCC8
    static let retroTan         = Color(red: 0.839, green: 0.788, blue: 0.694)  // --bg-soft    #D6C9B1 (bezel)
    static let retroTanDark     = Color(red: 0.761, green: 0.710, blue: 0.608)  // --border     #C2B59B (bezel stroke)
    static let retroBezel       = Color(red: 0.761, green: 0.710, blue: 0.608)  // --border     #C2B59B

    // LCD / Screen
    static let retroScreen      = Color(red: 0.184, green: 0.243, blue: 0.204)  // --lcd-dark   #2F3E34
    static let retroCyan        = Color(red: 0.435, green: 0.561, blue: 0.463)  // --lcd-mid    #6F8F76
    static let retroYellow      = Color(red: 0.686, green: 0.765, blue: 0.643)  // --lcd-light  #AFC3A4

    // Panel cards (dark green)
    static let retroPanel       = Color(red: 0.247, green: 0.290, blue: 0.247)  // --panel      #3F4A3F
    static let retroPanelBorder = Color(red: 0.333, green: 0.384, blue: 0.333)  // --panel-soft #556255

    // Accents
    static let retroGreen       = Color(red: 0.435, green: 0.686, blue: 0.416)  // --green      #6FAF6A
    static let retroTeal        = Color(red: 0.435, green: 0.659, blue: 0.686)  // --blue       #6FA8AF
    static let retroRed         = Color(red: 0.776, green: 0.353, blue: 0.290)  // --red        #C65A4A
    static let retroOrange      = Color(red: 0.851, green: 0.549, blue: 0.227)  // --orange     #D98C3A

    // Text
    static let retroText        = Color(red: 0.949, green: 0.914, blue: 0.847)  // --text-light #F2E9D8 (on dark panels)
    static let retroTextDim     = Color(red: 0.686, green: 0.765, blue: 0.643)  // --lcd-light  #AFC3A4 (subdued on panel)
    static let retroTextDark    = Color(red: 0.184, green: 0.165, blue: 0.141)  // --text-main  #2F2A24 (on light bg)

    // Indicator dots
    static let retroDot1        = Color(red: 0.435, green: 0.686, blue: 0.416)  // --green      #6FAF6A
    static let retroDot2        = Color(red: 0.851, green: 0.549, blue: 0.227)  // --orange     #D98C3A
    static let retroDot3        = Color(red: 0.776, green: 0.353, blue: 0.290)  // --red        #C65A4A
}

// MARK: - ContentView

struct ContentView: View {
    @Bindable var store: WellnessStore
    var onBuddyMode: (() -> Void)? = nil
// Buddy mode activation property
#if os(macOS)
    var isBuddyModeActive = false
    @AppStorage("jarvis.hasSeenDemoGuide") private var hasSeenDemoGuide = false
#else
    var isBuddyModeActive: Bool { false }
#endif

    @State private var petScale: CGFloat = 1
    @State private var heartbeat = false
    @State private var heartbeatTimer: Timer?
    @State private var lifeTimer: Timer?
    @State private var showHearts = false
    @State private var isSleeping = false
    @State private var showDemoGuide = false
    @State private var selectedTab: RetroTab = .feed
#if os(iOS)
    @State var liveActivity: Activity<PetActivityAttributes>?
#endif
    @State private var jarvisScene = JarvisScene(size: CGSize(width: 320, height: 320))

    enum RetroTab { case feed, rest, buddy }

    var body: some View {
        GeometryReader { proxy in
            let metrics = LayoutMetrics(size: proxy.size)
            HStack(alignment: .top, spacing: 0) {
                // Left: CRT TV panel
                leftPanel(metrics)
                    .frame(width: metrics.leftPanelWidth)

                // Right: controls + cards
                rightPanel(metrics)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.retroBg)
        }
        .onAppear(perform: startTimers)
        .onDisappear(perform: stopTimers)
#if os(macOS)
        .sheet(isPresented: $showDemoGuide) {
            demoGuideSheet
        }
#endif
    }

    // MARK: - Left Panel (CRT TV)

    private func leftPanel(_ metrics: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            // CRT TV bezel
            crtBezel(metrics)

            // Status bar
            retroStatusBar
        }
        .padding(metrics.outerPadding)
    }

    private func crtBezel(_ metrics: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            // Screen area
            ZStack {
                // Screen background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.retroScreen)

                // SpriteKit Scene
                SpriteView(scene: jarvisScene, options: [.allowsTransparency])
                    .frame(width: metrics.sceneSize.width, height: metrics.sceneSize.height)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .scaleEffect(petScale)
                    .gesture(TapGesture().onEnded { squish() })
                    .gesture(DragGesture(minimumDistance: 10).onEnded { _ in pet() })
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: petScale)

                // Scanline overlay
                ScanlineOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if showHearts { HeartBurst() }
            }
            .frame(height: metrics.sceneSize.height)
            .padding(8)

            // Speaker / controls row
            HStack(spacing: 0) {
                // Indicator dots
                HStack(spacing: 6) {
                    Circle().fill(Color.retroDot1).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    Circle().fill(Color.retroDot2).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                    Circle().fill(Color.retroDot3).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                }

                Spacer()

                // Speaker grille dots
                SpeakerGrille()

                Spacer()

                // Right dots
                HStack(spacing: 6) {
                    ForEach(0..<3) { _ in
                        Circle().fill(Color.retroTanDark.opacity(0.7)).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.retroTan)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.retroTanDark, lineWidth: 3))
        )
        .overlay(
            // Bezel inner shadow
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.25), lineWidth: 1)
        )
        // Bottom action buttons row
        .overlay(alignment: .bottom) {
            bottomButtonRow
                .offset(y: 44)
        }
        .padding(.bottom, 50)
        .onAppear { updateScene(size: metrics.sceneSize) }
        .onChange(of: metrics.sceneSize) { _, size in updateScene(size: size) }
    }

    private var bottomButtonRow: some View {
        HStack(spacing: 8) {
            // "C" label
            Text("c")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.retroTextDark)

            retroBottomButton("Feed", color: Color.retroGreen) { feed() }
            retroBottomButton(isSleeping ? "Awake" : "Rest", color: Color.retroTeal) { toggleSleep() }

            // Pulse toggle styled as button
            retroPulseButton

            platformBottomButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.retroTan)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.retroTanDark, lineWidth: 2))
        )
    }

    private func retroBottomButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle().fill(color.opacity(0.9)).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.retroBg.opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.7), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.retroTextDark)
    }

    private var retroPulseButton: some View {
        Button {
            heartbeat.toggle()
            heartbeat ? startHeartbeat() : stopHeartbeat()
            jarvisScene.applyState(from: store, heartbeat: heartbeat)
        } label: {
            HStack(spacing: 4) {
                Circle().fill(Color.retroDot3.opacity(0.9)).frame(width: 7, height: 7)
                Text("Pulse")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(heartbeat ? Color.retroDot3.opacity(0.2) : Color.retroBg.opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.retroDot3.opacity(0.7), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.retroTextDark)
    }

    private var retroStatusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.retroOrange)
            Text(store.mood.label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.retroText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.retroPanel)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.retroPanelBorder), alignment: .top)
    }

    // MARK: - Right Panel

    private func rightPanel(_ metrics: LayoutMetrics) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Tab strip
                tabStrip
                    .padding(.horizontal, metrics.outerPadding)
                    .padding(.top, metrics.outerPadding)
                    .padding(.bottom, 10)

                // Cards
                VStack(alignment: .leading, spacing: 10) {
#if os(macOS)
                    demoCard
#endif
#if os(iOS)
                    liveActivityDemoCard
#endif
                    statusCard
                    wellnessCard
                }
                .padding(.horizontal, metrics.outerPadding)
                .padding(.bottom, metrics.outerPadding)
            }
        }
    }

    // MARK: - Tab Strip

    private var tabStrip: some View {
        HStack(spacing: 6) {
            retroTabButton("Feed", color: Color.retroGreen, tab: .feed) { feed() }
            retroTabButton("Rest", color: Color.retroTeal, tab: .rest) { toggleSleep() }
#if os(macOS)
            retroTabButton("Buddy Mode", color: Color.retroRed, tab: .buddy, dotStyle: .filled) {
                toggleBuddyMode()
            }
#endif
        }
    }

    private func retroTabButton(_ title: String, color: Color, tab: RetroTab, dotStyle: DotStyle = .circle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if dotStyle == .filled {
                    Circle().fill(color.opacity((tab == .buddy && isBuddyModeActive) ? 1.0 : 0.6))
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(tabIsActive(tab) ? color.opacity(0.85) : color.opacity(0.20))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(color.opacity(0.7), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(tabIsActive(tab) ? Color.white : color.opacity(0.9))
    }

    private func tabIsActive(_ tab: RetroTab) -> Bool {
        switch tab {
        case .feed:  return false    // stateless visual, action only
        case .rest:  return isSleeping
        case .buddy: return isBuddyModeActive
        }
    }

    enum DotStyle { case circle, filled }

    // MARK: - Demo Card

#if os(macOS)
    private var demoCard: some View {
        RetroCardView {
            // Header
            HStack(alignment: .center, spacing: 0) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.retroOrange)
                Text(" Demo Ready ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroText)
                retroDash
                Spacer()
                Text(isBuddyModeActive ? "Live" : "Standby")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroTextDim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 3).stroke(Color.retroPanelBorder, lineWidth: 1))
            }

            // Steps
            VStack(alignment: .leading, spacing: 6) {
                demoStep(n: 1, text: "Start Buddy Mode")
                demoStep(n: 2, text: "Trigger Minum, Stretch, atau Makan")
                demoStep(n: 3, text: "Tunjukkan tombol Sudah atau Belum")
            }
            .padding(.top, 6)

            // Guide link
            HStack {
                Spacer()
                Button {
                    hasSeenDemoGuide = true
                    showDemoGuide = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 10))
                        Text("Open Demo Guide")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundStyle(Color.retroTextDim)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private func demoStep(n: Int, text: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.retroGreen.opacity(0.3))
                    .frame(width: 18, height: 18)
                Text("\(n)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroGreen)
            }
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.retroText)
        }
    }

    private var demoGuideSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Jarvis Demo Guide")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.retroText)

            Text("Alur singkat supaya presentasi Buddy Mode rapi dan cepat dipahami.")
                .foregroundStyle(Color.retroTextDim)
                .font(.system(size: 13, design: .monospaced))

            VStack(alignment: .leading, spacing: 10) {
                demoGuideRow(title: "1. Aktifkan Buddy Mode", detail: "Jarvis akan pindah ke desktop overlay.")
                demoGuideRow(title: "2. Gunakan tombol trigger", detail: "Pilih Minum, Stretch, atau Makan di pojok kanan atas.")
                demoGuideRow(title: "3. Tunjukkan interaksi", detail: "Klik Sudah untuk menambah goal, atau Belum untuk snooze 10 menit.")
                demoGuideRow(title: "4. Klik Jarvis", detail: "Jarvis bereaksi, mengeluarkan suara, dan bisa membuka ChatGPT.")
            }

            HStack(spacing: 12) {
                Button("Close") { showDemoGuide = false }
                    .buttonStyle(.bordered)
                Button("Mark as Ready") { hasSeenDemoGuide = true; showDemoGuide = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(minWidth: 420)
        .background(Color.retroBg)
        .presentationDetents([.medium])
    }

    private func demoGuideRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Color.retroText)
            Text(detail).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.retroTextDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.retroPanel))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.retroPanelBorder.opacity(0.5), lineWidth: 1))
    }
#endif

    // MARK: - Status Card

    private var statusCard: some View {
        RetroCardView {
            // Header
            HStack(alignment: .center, spacing: 0) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.retroOrange)
                Text(" Jarvis Stats ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroText)
                retroDash
                Spacer()
                // Mood badge
                HStack(spacing: 3) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.retroOrange)
                    Text(store.mood.label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.retroOrange)
                }
            }

            // 2x2 Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statRow("Fullness",  value: "\(100 - store.hunger)%", progress: Double(100 - store.hunger) / 100, color: Color.retroGreen)
                statRow("Energy",    value: "\(store.energy)%",       progress: Double(store.energy) / 100,       color: Color.retroOrange)
                statRow("Affection", value: "\(store.affection)%",    progress: Double(store.affection) / 100,    color: Color.retroOrange)
                statRow("Last Fed",  value: store.lastFed.formatted(date: .omitted, time: .shortened), progress: nil, color: Color.retroTeal)
            }
            .padding(.top, 8)
        }
    }

    private func statRow(_ label: String, value: String, progress: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.retroTextDim)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroText)
            }
            if let progress {
                RetroProgressBar(progress: progress, color: color, segments: 10)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.retroBg))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.retroPanelBorder.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Wellness Card

    private var wellnessCard: some View {
        RetroCardView {
            // Header
            HStack(alignment: .center, spacing: 0) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.retroOrange)
                Text(" Wellness ")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroText)
                retroDash
                Spacer()
                Button(store.remindersEnabled ? "Stop Reminders" : "Enable Reminders") {
                    Task { await store.toggleReminders() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 3).fill(store.remindersEnabled ? Color.retroRed : Color.retroGreen))
            }

            // Wellness grid
            TimelineView(.periodic(from: .now, by: 60)) { context in
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    screenTimeTile(at: context.date)
                    wellnessTile(kind: .water)
                    wellnessTile(kind: .stretch)
                    wellnessTile(kind: .meal)
                }
                .padding(.top, 8)
            }

            // Reminder schedule
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("Reminder Schedule ")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.retroText)
                    retroDash
                }
                .padding(.top, 4)
                reminderScheduleRow
            }
        }
    }

    private func screenTimeTile(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Screen Time")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.retroTextDim)
                Spacer()
                Text(durationLabel(store.screenTimeToday(at: date)))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroText)
            }
            screenTimeChips(at: date)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.retroBg))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.retroPanelBorder.opacity(0.4), lineWidth: 1))
    }

    private func screenTimeChips(at date: Date) -> some View {
        let hours = min(Int(store.screenTimeToday(at: date) / 3600), 6)
        return HStack(spacing: 3) {
            ForEach(0..<6) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < hours ? Color.retroCyan.opacity(0.8) : Color.retroPanelBorder.opacity(0.3))
                    .frame(height: 8)
            }
            Image(systemName: "drop.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.retroCyan.opacity(0.5))
            Image(systemName: "drop.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.retroCyan.opacity(0.5))
            Image(systemName: "drop.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.retroCyan.opacity(0.5))
        }
    }

    private func wellnessTile(kind: WellnessStore.ReminderKind) -> some View {
        let summary = store.goalSummary[kind] ?? "0/0"
        let parts   = summary.split(separator: "/")
        let current = Int(parts.first ?? "0") ?? 0
        let total   = Int(parts.last ?? "0") ?? 1
        let color   = wellnessColor(for: kind)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(kind.title)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.retroTextDim)
                Spacer()
                Text(summary)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.retroText)
            }
            wellnessChips(current: current, total: total, color: color)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.retroBg))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.retroPanelBorder.opacity(0.4), lineWidth: 1))
    }

    private func wellnessChips(current: Int, total: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < current ? color.opacity(0.85) : Color.retroPanelBorder.opacity(0.25))
                        .frame(height: 12)
                    Text("\(i + 1)")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(i < current ? .white : Color.retroTextDim.opacity(0.6))
                }
            }
        }
    }

    private func wellnessColor(for kind: WellnessStore.ReminderKind) -> Color {
        switch kind {
        case .water:   return Color.retroCyan
        case .stretch: return Color.retroOrange
        case .meal:    return Color.retroGreen
        }
    }

    // MARK: - Reminder Schedule

    private var reminderScheduleRow: some View {
        let schedules = store.reminderSchedules
        let grouped = Dictionary(grouping: schedules, by: { $0.hour })
        let hours = grouped.keys.sorted()

        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 3) {
                // Hour labels row
                HStack(spacing: 3) {
                    ForEach(hours, id: \.self) { hour in
                        Text("\(hour)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.retroTextDim)
                            .frame(minWidth: 18, alignment: .center)
                    }
                }
                // Colored kind chips row
                HStack(spacing: 3) {
                    ForEach(hours, id: \.self) { hour in
                        if let items = grouped[hour], let first = items.first {
                            ZStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(wellnessColor(for: first.kind).opacity(0.75))
                                    .frame(minWidth: 18, minHeight: 12)
                                if items.count > 1 {
                                    Text("\(items.count)")
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared UI Helpers

    private var retroDash: some View {
        GeometryReader { geo in
            Path { p in
                let y = geo.size.height / 2
                var x: CGFloat = 0
                while x < geo.size.width {
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + 4, y: y))
                    x += 8
                }
            }
            .stroke(Color.retroPanelBorder.opacity(0.7), lineWidth: 1)
        }
        .frame(height: 1)
        .padding(.horizontal, 4)
    }

    // MARK: - Timers & Logic

    private func startTimers() {
        updateScene(size: jarvisScene.size)
        startHeartbeat()
        stopLifeTicking()
#if os(macOS)
        if !hasSeenDemoGuide {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showDemoGuide = true
            }
        }
#endif
        lifeTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in
                store.tick()
                updateLiveActivityState()
                jarvisScene.applyState(from: store, heartbeat: heartbeat)
            }
        }
    }

    private func stopTimers() {
        stopHeartbeat()
        stopLifeTicking()
    }

    private func updateScene(size: CGSize) {
        jarvisScene.scaleMode = .resizeFill
        jarvisScene.size = size
        jarvisScene.applyState(from: store, heartbeat: heartbeat)
    }

    private func squish() {
        animatePet(to: 0.9, settle: 1.05, delay: 0.25)
        store.squish()
        Haptics.squish()
        jarvisScene.squish()
        updateLiveActivityState()
    }

    private func pet() {
        animatePet(to: 1.1, settle: 1, delay: 0.2)
        store.pet()
        Haptics.pet()
        jarvisScene.pet()
        updateLiveActivityState()
        burstHearts()
    }

    private func feed() {
        store.feed()
        Haptics.feed()
        jarvisScene.feed()
        updateLiveActivityState()
        burstHearts()
    }

    private func toggleSleep() {
        isSleeping.toggle()
        if isSleeping {
            store.rest(); Haptics.rest(); jarvisScene.sleep()
        } else {
            store.wakeUp(); Haptics.pet(); jarvisScene.wake()
        }
        updateLiveActivityState()
    }

    private func animatePet(to scale: CGFloat, settle: CGFloat, delay: TimeInterval) {
        petScale = scale
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            petScale = settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { petScale = 1 }
        }
    }

    private func startHeartbeat() {
        guard heartbeat else { return }
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in Haptics.heartbeat() }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func stopLifeTicking() {
        lifeTimer?.invalidate()
        lifeTimer = nil
    }

    private func burstHearts() {
        showHearts = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { showHearts = false }
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        guard duration >= 60 else { return "00m" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: duration) ?? "00m"
    }
}

// MARK: - Layout Metrics

private struct LayoutMetrics {
    let size: CGSize
    var isCompact: Bool { size.width < 760 }
    var outerPadding: CGFloat { 12 }
    var leftPanelWidth: CGFloat { isCompact ? size.width : min(size.width * 0.44, 400) }
    var sceneSize: CGSize {
        let w = leftPanelWidth - outerPadding * 2 - 16
        let h = min(max(size.height * 0.46, 200), 340)
        return CGSize(width: w, height: h)
    }
}

// MARK: - Reusable Retro Views

struct RetroCardView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.retroPanel)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.retroPanelBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct RetroProgressBar: View {
    var progress: Double   // 0.0 – 1.0
    var color: Color
    var segments: Int = 10

    var body: some View {
        let filled = Int((progress * Double(segments)).rounded())
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < filled ? color : Color.retroPanelBorder.opacity(0.35))
                    .frame(height: 7)
            }
        }
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let lineCount = Int(geo.size.height / 4)
            VStack(spacing: 2) {
                ForEach(0..<lineCount, id: \.self) { _ in
                    Color.black.opacity(0.10)
                        .frame(height: 1)
                    Color.clear.frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
    }
}

struct SpeakerGrille: View {
    let cols = 8
    let rows = 2
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 6) {
                    ForEach(0..<cols, id: \.self) { _ in
                        Circle()
                            .fill(Color.retroTanDark.opacity(0.6))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
    }
}

// MARK: - Heart Burst

private struct HeartBurst: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                let angle = Double(index) / 3 * .pi
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink.opacity(0.7))
                    .scaleEffect(animate ? 1 : 0.1)
                    .offset(x: animate ? cos(angle) * 60 : 0,
                            y: animate ? sin(angle) * 60 : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.03), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Previews

#Preview("macOS") {
    ContentView(store: WellnessStore())
        .frame(width: 900, height: 640)
}

#Preview("iOS") {
    ContentView(store: WellnessStore())
}
