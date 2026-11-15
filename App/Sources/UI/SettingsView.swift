import SwiftUI

/// 設定：遊び方（入力・角度）、音と振動、お知らせ、Pro、使い方とプライバシー
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.skyTime) private var sky
    @State private var reminderOn = false
    @State private var reminderHour = 15
    @State private var workOn = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $app.progress.settings.input) {
                        ForEach(InputMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
                    } label: { Text("遊び方") }
                    Picker(selection: $app.progress.settings.size) {
                        Text("小さめ").tag(AngleSize.small)
                        Text("ふつう").tag(AngleSize.medium)
                        Text("大きめ").tag(AngleSize.large)
                    } label: { Text("動かす角度") }
                    Picker(selection: $app.progress.settings.leniency) {
                        ForEach(Leniency.allCases, id: \.self) { l in Text(verbatim: l.name.text(locale)).tag(l) }
                    } label: { Text("判定のゆるさ") }
                    Toggle(isOn: $app.progress.settings.mirror) { Text("左右を入れ替える（カメラ）") }
                } header: { SettingsHeader("遊び方") } footer: {
                    SettingsFooter("はじめは「小さめ」「ゆるめ」がおすすめです。「ゆるめ」は輪が広く、3 秒保てば満ちます（「ふつう」は 4 秒）。痛いとき・しびれがあるときは、すぐにやめてください。")
                }
                .listRowBackground(Theme.palette(sky).paper)

                Section {
                    Toggle(isOn: $app.progress.settings.sound) { Text("音") }
                    Toggle(isOn: $app.progress.settings.haptics) { Text("振動") }
                } header: { SettingsHeader("音と振動") }
                .listRowBackground(Theme.palette(sky).paper)

                Section {
                    Toggle(isOn: $reminderOn) { Text("毎日のお知らせ") }
                    if reminderOn {
                        Stepper(value: $reminderHour, in: 6...22) {
                            Text("\(reminderHour) 時")
                        }
                    }
                    Toggle(isOn: $workOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("仕事中、1 時間ごとの 1 分（Pro）")
                            Text("平日 10〜18 時").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!app.isPro)
                    if app.reminderDenied {
                        Text("通知が許可されていません。設定アプリの「通知」から許可できます。")
                            .font(.footnote).foregroundStyle(Theme.balloonDeep)
                    }
                } header: { SettingsHeader("お知らせ") }
                .listRowBackground(Theme.palette(sky).paper)

                Section {
                    if app.isPro {
                        Label("Pro を使っています", systemImage: "checkmark.seal")
                    } else {
                        Button { app.sheet = .pro } label: { Text("Pro を見る") }
                    }
                    Button { Task { await app.store.restore() } } label: { Text("購入を復元") }
                } header: { SettingsHeader("Pro") }
                .listRowBackground(Theme.palette(sky).paper)

                Section {
                    Button { dismiss(); app.progress.hasOnboarded = false } label: { Text("使い方をもう一度見る") }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("プライバシー").font(.subheadline.weight(.medium))
                        Text("顔の向きは iPhone の中だけで計算します。カメラの映像は保存も送信もしません。記録はこの iPhone の中だけに残ります。アカウント・広告・解析はありません。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("このアプリは医療機器ではありません。症状の改善を約束するものではありません。")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { SettingsHeader("このアプリについて") }
                .listRowBackground(Theme.palette(sky).paper)
            }
            .scrollContentBackground(.hidden)
            .background(SkyBackdrop(sky: sky, drift: 0.2))
            .tint(Theme.balloonDeep)
            .fontDesign(.rounded)
            .skySheetChrome(title: "設定", sky: sky) { dismiss() }
            .onAppear {
                reminderOn = app.progress.settings.dailyReminderHour != nil
                reminderHour = app.progress.settings.dailyReminderHour ?? 15
                workOn = app.progress.settings.workReminder != nil
            }
            .onChange(of: reminderOn) { _, on in Task { await app.setDailyReminder(on ? reminderHour : nil) } }
            .onChange(of: reminderHour) { _, h in if reminderOn { Task { await app.setDailyReminder(h) } } }
            .onChange(of: workOn) { _, on in Task { await app.setWorkReminder(on ? WorkReminder() : nil) } }
            .onChange(of: app.progress.settings) { _, _ in app.applyFeel() }
        }
    }
}

/// 設定の見出し（空の上に白い丸い字）
private struct SettingsHeader: View {
    @Environment(\.skyTime) private var sky
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }

    var body: some View {
        Text(key).font(Theme.text(13, .heavy)).foregroundStyle(.white).textCase(nil).onSkyText(sky)
    }
}

private struct SettingsFooter: View {
    @Environment(\.skyTime) private var sky
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }

    var body: some View {
        Text(key).font(Theme.text(12, .medium)).foregroundStyle(.white.opacity(0.88)).onSkyText(sky)
    }
}
