//
//  ContentView.swift
//  Jarvis
//
//  Created by Codex on 13/03/26.
//

import SwiftUI
import Observation
import SpriteKit
import Charts
#if os(iOS)
import ActivityKit
#endif

struct ContentView: View {
    @Bindable var store: PetStore
    var onBuddyMode: (() -> Void)? = nil
#if os(macOS)
    var isBuddyModeActive = false
    @AppStorage("jarvis.hasSeenDemoGuide") private var hasSeenDemoGuide = false
#endif

    @State private var petScale: CGFloat = 1
    @State private var heartbeat = false
    @State private var heartbeatTimer: Timer?
    @State private var lifeTimer: Timer?
    @State private var showHearts = false
    @State private var isSleeping = false
    @State private var showDemoGuide = false
#if os(iOS)
    @State var liveActivity: Activity<PetActivityAttributes>?
#endif
    @State private var jarvisScene = JarvisScene(size: CGSize(width: 320, height: 320))

    var body: some View {
        GeometryReader { proxy in
            let metrics = LayoutMetrics(size: proxy.size)
            ScrollView(showsIndicators: false) {
                VStack(spacing: metrics.spacing) {
                    header(metrics)
                    content(metrics)
                }
                .frame(maxWidth: .infinity)
                .padding(metrics.padding)
            }
            .background(background)
        }
        .onAppear(perform: startTimers)
        .onDisappear(perform: stopTimers)
#if os(macOS)
        .sheet(isPresented: $showDemoGuide) {
            demoGuideSheet
        }
#endif
    }

    private func header(_ metrics: LayoutMetrics) -> some View {
        HStack(alignment: .top) {
            VStack(spacing: 6) {
                Text("Jarvis")
                    .font(metrics.isCompact ? .largeTitle.bold() : .system(size: 34, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

#if os(macOS)
            Button {
                showDemoGuide = true
            } label: {
                Label("Demo Guide", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.bordered)
#endif
        }
    }

    private func content(_ metrics: LayoutMetrics) -> some View {
        let layout = metrics.isCompact
            ? AnyLayout(VStackLayout(spacing: metrics.spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: metrics.spacing))

        return layout {
            petPanel(metrics)
            sidePanel(metrics)
        }
    }

    private func petPanel(_ metrics: LayoutMetrics) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: metrics.cornerRadius - 8, style: .continuous)
                        .fill(LinearGradient(colors: [.mint.opacity(0.45), .cyan.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))

                    SpriteView(scene: jarvisScene, options: [.allowsTransparency])
                        .frame(width: metrics.scene.width, height: metrics.scene.height)
                        .background(.clear)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius - 12, style: .continuous))
                        .scaleEffect(petScale)
                        .gesture(tapGesture)
                        .gesture(petGesture)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: petScale)

                    if showHearts {
                        HeartBurst()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: metrics.scene.height + 28)

                Label(store.mood.label, systemImage: "face.smiling")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(metrics.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: metrics.scene.height + 88)
        .onAppear { updateScene(size: metrics.scene) }
        .onChange(of: metrics.scene) { _, size in updateScene(size: size) }
    }

    private func sidePanel(_ metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.spacing) {
            controls(metrics)
#if os(macOS)
            demoCard
#endif
            statusCard
            wellnessCard
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func controls(_ metrics: LayoutMetrics) -> some View {
        ViewThatFits(in: metrics.isCompact ? .vertical : .horizontal) {
            controlStack(axis: .horizontal)
            controlStack(axis: .vertical)
        }
    }

    private func controlStack(axis: Axis) -> some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: 12) { controlItems }
            } else {
                VStack(spacing: 12) { controlItems }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlItems: some View {
        Group {
            actionButton("Feed", systemImage: "takeoutbag.and.cup.and.straw.fill", action: feed)
            actionButton(isSleeping ? "Awake" : "Rest", systemImage: isSleeping ? "sun.max.fill" : "power.sleep", action: toggleSleep)
            Toggle(isOn: $heartbeat) {
                Label("Pulse", systemImage: "heart.fill")
            }
            .toggleStyle(.switch)
            .onChange(of: heartbeat) { _, active in
                active ? startHeartbeat() : stopHeartbeat()
                jarvisScene.applyState(from: store, heartbeat: active)
            }
            platformControls
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Jarvis Stats", systemImage: "waveform.path.ecg.rectangle.fill")
                    .font(.headline)
                Spacer()
                Text("\(store.mood.emoji) \(store.mood.label)")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            LazyVGrid(columns: statusColumns, spacing: 12) {
                statTile("Fullness", value: "\(100 - store.hunger)%", tint: .green)
                statTile("Energy", value: "\(store.energy)%", tint: .blue)
                statTile("Affection", value: "\(store.affection)%", tint: .pink)
                statTile("Last Fed", value: store.lastFed.formatted(date: .omitted, time: .shortened), tint: .orange)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var wellnessCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Wellness", systemImage: "heart.text.square.fill")
                    .font(.headline)
                Spacer()
                Button(store.remindersEnabled ? "Stop Reminders" : "Enable Reminders") {
                    Task { await store.toggleReminders() }
                }
                .buttonStyle(.bordered)
            }

            TimelineView(.periodic(from: .now, by: 60)) { context in
                LazyVGrid(columns: statusColumns, spacing: 12) {
                    statTile("Screen Time", value: durationLabel(store.screenTimeToday(at: context.date)), tint: .cyan)
                    ForEach(PetStore.ReminderKind.allCases) { kind in
                        statTile(kind.title, value: store.goalSummary[kind] ?? "0/0", tint: statColor(for: kind))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Reminder Schedule")
                    .font(.subheadline.weight(.semibold))
                reminderScheduleChart
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var statusColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
    }

    private func statTile(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func statColor(for kind: PetStore.ReminderKind) -> Color {
        switch kind {
        case .water: .cyan
        case .stretch: .orange
        case .meal: .green
        }
    }

#if os(macOS)
    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Demo Ready", systemImage: "play.rectangle.fill")
                    .font(.headline)
                Spacer()
                Text(isBuddyModeActive ? "Live" : "Standby")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((isBuddyModeActive ? Color.green : Color.secondary).opacity(0.16), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                demoStep(icon: "1.circle.fill", text: "Start Buddy Mode")
                demoStep(icon: "2.circle.fill", text: "Trigger Minum, Stretch, atau Makan")
                demoStep(icon: "3.circle.fill", text: "Tunjukkan tombol Sudah atau Belum")
            }

            Button {
                hasSeenDemoGuide = true
                showDemoGuide = true
            } label: {
                Label("Open Demo Guide", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private func demoStep(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.mint)
            Text(text)
                .font(.subheadline)
        }
    }

    private var demoGuideSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Jarvis Demo Guide")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Alur singkat supaya presentasi Buddy Mode rapi dan cepat dipahami.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                demoGuideRow(title: "1. Aktifkan Buddy Mode", detail: "Jarvis akan pindah ke desktop overlay.")
                demoGuideRow(title: "2. Gunakan tombol trigger", detail: "Pilih Minum, Stretch, atau Makan di pojok kanan atas.")
                demoGuideRow(title: "3. Tunjukkan interaksi", detail: "Klik Sudah untuk menambah goal, atau Belum untuk snooze 10 menit.")
                demoGuideRow(title: "4. Klik Jarvis", detail: "Jarvis bereaksi, mengeluarkan suara, dan bisa membuka ChatGPT.")
            }

            HStack(spacing: 12) {
                Button("Close") {
                    showDemoGuide = false
                }
                .buttonStyle(.bordered)

                Button("Mark as Ready") {
                    hasSeenDemoGuide = true
                    showDemoGuide = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(minWidth: 420)
        .presentationDetents([.medium])
    }

    private func demoGuideRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
#endif

    private var reminderScheduleChart: some View {
        Chart(reminderChartData) { item in
            BarMark(
                x: .value("Time", item.hour),
                y: .value("Kind", item.kind.title)
            )
            .foregroundStyle(statColor(for: item.kind))
            .cornerRadius(6)
            .annotation(position: .overlay) {
                Image(systemName: symbol(for: item.kind))
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, through: 23, by: 3))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))
                    .foregroundStyle(.white.opacity(0.14))
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(String(format: "%02d", hour))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let title = value.as(String.self),
                       let kind = PetStore.ReminderKind.allCases.first(where: { $0.title == title }) {
                        Label(kind.title, systemImage: kind.icon)
                            .font(.caption)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(height: 180)
    }

    private var reminderChartData: [ReminderChartPoint] {
        store.reminderSchedules.map {
            ReminderChartPoint(kind: $0.kind, hour: Double($0.hour) + Double($0.minute) / 60)
        }
    }

    private func symbol(for kind: PetStore.ReminderKind) -> String {
        switch kind {
        case .water: "drop.fill"
        case .stretch: "figure.walk"
        case .meal: "fork.knife"
        }
    }

    private var tapGesture: some Gesture {
        TapGesture().onEnded { squish() }
    }

    private var petGesture: some Gesture {
        DragGesture(minimumDistance: 10).onEnded { _ in pet() }
    }

    private var background: some View {
        LinearGradient(colors: [.indigo.opacity(0.24), .teal.opacity(0.18), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

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
            store.rest()
            Haptics.rest()
            jarvisScene.sleep()
        } else {
            store.wakeUp()
            Haptics.pet()
            jarvisScene.wake()
        }
        updateLiveActivityState()
    }

    private func animatePet(to scale: CGFloat, settle: CGFloat, delay: TimeInterval) {
        petScale = scale
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            petScale = settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                petScale = 1
            }
        }
    }

    private func startHeartbeat() {
        guard heartbeat else { return }
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
            Haptics.heartbeat()
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showHearts = false
        }
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        guard duration >= 60 else { return "0m" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct ReminderChartPoint: Identifiable {
    let id = UUID()
    let kind: PetStore.ReminderKind
    let hour: Double
}

private struct LayoutMetrics {
    let size: CGSize

    var isCompact: Bool { size.width < 760 }
    var padding: CGFloat { isCompact ? 16 : 24 }
    var spacing: CGFloat { isCompact ? 16 : 24 }
    var cardPadding: CGFloat { isCompact ? 14 : 20 }
    var cornerRadius: CGFloat { isCompact ? 24 : 30 }

    var scene: CGSize {
        let width = min(max(size.width - padding * 2 - 28, 220), isCompact ? 420 : 620)
        let height = min(max(size.height * (isCompact ? 0.28 : 0.42), 220), isCompact ? 320 : 420)
        return CGSize(width: width, height: height)
    }
}

private struct HeartBurst: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<6) { index in
                let angle = Double(index) / 3 * .pi
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink.opacity(0.7))
                    .scaleEffect(animate ? 1 : 0.1)
                    .offset(x: animate ? cos(angle) * 70 : 0, y: animate ? sin(angle) * 70 : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.03), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

#Preview("iOS") {
    ContentView(store: PetStore())
}

#Preview("macOS") {
    ContentView(store: PetStore())
        .frame(width: 900, height: 640)
}
