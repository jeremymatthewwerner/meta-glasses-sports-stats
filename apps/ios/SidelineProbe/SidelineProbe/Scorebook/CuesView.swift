import SidelineCore
import SwiftUI

/// Play clock face with start/stop buttons, under the lens bar.
struct PlayClockBar: View {
    @Environment(ScorebookModel.self) private var model
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            clockRow
            if let cue = model.lastCue {
                Label(cue, systemImage: "speaker.wave.2")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .sheet(isPresented: $showSettings) { CueSettingsView() }
    }

    private var clockRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer").foregroundStyle(.secondary)
            Text(model.clockShown.map { String($0) } ?? "––")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
                .frame(minWidth: 36, alignment: .leading)
                .accessibilityLabel(model.clockShown.map { "Play clock \($0) seconds" } ?? "Play clock stopped")
            Spacer()
            Button("40") { model.startPlayClock(40) }
            Button("25") { model.startPlayClock(25) }
            if model.playClock.isRunning {
                Button { model.stopPlayClock() } label: { Image(systemName: "stop.fill") }
                    .accessibilityLabel("Stop play clock")
            }
            Button { showSettings = true } label: {
                Image(systemName: model.cues.playClockVoice || model.cues.announceSituation ? "speaker.wave.2" : "speaker.slash")
            }
            .accessibilityLabel("Player cues")
        }
        .buttonStyle(.bordered)
        .font(.footnote.bold())
    }

    private var color: Color {
        guard let s = model.clockShown else { return .secondary }
        return s <= 5 ? .red : (s <= 10 ? .orange : .primary)
    }
}

/// What the wearer hears: play clock countdown, situation, score, own stats.
struct CueSettingsView: View {
    @Environment(ScorebookModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var jersey = ""

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle("Count down the play clock", isOn: $model.cues.playClockVoice)
                    Toggle("Start it after each called play", isOn: $model.cues.autoStartClock)
                    Picker("Clock", selection: $model.cues.clockRule) {
                        ForEach(CueSettings.ClockRule.allCases) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("Play clock")
                } footer: {
                    Text("Says 20, 10, 5, 4, 3, 2, 1, “Time!”. Auto-start counts from when you began calling the play, about when the ball was whistled dead. You can also say “start the clock”, “25 clock” or “stop the clock”.")
                }

                Section("After each play") {
                    Toggle("Down, distance and spot", isOn: $model.cues.announceSituation)
                    Toggle("Score changes", isOn: $model.cues.announceScore)
                }

                Section {
                    Picker("My team", selection: Binding(get: { model.cues.me?.team }, set: { setMe(team: $0) })) {
                        Text("Not playing").tag(TeamSide?.none)
                        Text(model.game.away.name).tag(TeamSide?.some(.away))
                        Text(model.game.home.name).tag(TeamSide?.some(.home))
                    }
                    if model.cues.me != nil {
                        TextField("My jersey number", text: $jersey)
                            .keyboardType(.numberPad)
                            .onChange(of: jersey) { _, v in if let n = Int(v), (0...99).contains(n) { setMe(jersey: n) } }
                        Toggle("My stats when I'm in the play", isOn: $model.cues.announceMyStats)
                    }
                } header: {
                    Text("Player mode")
                } footer: {
                    Text("“You: 3 catches, 52 yards.” after plays you're named in.")
                }

                Section {
                    Slider(value: $model.cues.voiceRate, in: 0.35...0.65) { Text("Speed") } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                    Button("Play a sample") {
                        model.speaker.say(CueComposer.situation(model.game) + " 10. 5. 4. 3. 2. 1. Time!")
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Cues play through the phone's audio output: your glasses' speakers when they're connected over Bluetooth. They pause while you're calling a play.")
                }
            }
            .navigationTitle("Player cues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onAppear { jersey = model.cues.me.map { String($0.jersey) } ?? "" }
        }
    }

    private func setMe(team: TeamSide?) {
        guard let team else { model.cues.me = nil; return }
        model.cues.me = PlayerKey(team: team, jersey: model.cues.me?.jersey ?? Int(jersey) ?? 0)
    }

    private func setMe(jersey n: Int) {
        guard let team = model.cues.me?.team else { return }
        model.cues.me = PlayerKey(team: team, jersey: n)
    }
}
