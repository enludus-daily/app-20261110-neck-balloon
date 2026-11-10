import SwiftUI

/// 記録：続けた日、4 週の暦（Pro は 1 年）、首の範囲の移り変わり（Pro は週ごとのグラフ）
struct RecordsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    calendar
                    rangeNow
                    weekly
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(Text("記録"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            big("\(app.progress.streak(today: app.today))", "続けた日")
            big("\(app.progress.totalDays)", "遊んだ日")
            big("\(app.progress.totalPlays)", "遊んだ回数")
        }
    }

    private func big(_ v: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: v).font(Theme.serif(34)).kerning(-1.5).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.rMedium, style: .continuous).fill(.white.opacity(0.7)))
    }

    /// 暦：遊んだ日の濃さは、その日のいちばんの点で 4 段階
    private var calendar: some View {
        let weeks = app.isPro ? 52 : 4
        let days = app.progress.lastDays(weeks * 7, today: app.today)
        return CloudPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption(app.isPro ? LocalizedStringKey("1 year") : LocalizedStringKey("4 weeks"))
                    Spacer()
                    if !app.isPro {
                        Button { app.sheet = .pro } label: { Text("1 年分は Pro").font(Theme.text(11)).foregroundStyle(Theme.peachDeep) }
                    }
                }
                Canvas { ctx, size in
                    let cols = weeks
                    let gap: CGFloat = 2
                    let cell = min((size.width - gap * CGFloat(cols - 1)) / CGFloat(cols), (size.height - gap * 6) / 7)
                    for (i, d) in days.enumerated() {
                        let col = i / 7, row = i % 7
                        let rect = CGRect(x: CGFloat(col) * (cell + gap), y: CGFloat(row) * (cell + gap), width: cell, height: cell)
                        let score = d.record?.bestScore ?? -1
                        let color: Color = switch score {
                        case 90...: Theme.skyDeep
                        case 75..<90: Theme.sky
                        case 55..<75: Theme.sky.opacity(0.6)
                        case 0..<55: Theme.skySoft
                        default: Theme.line.opacity(0.6)
                        }
                        ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.25), with: .color(color))
                    }
                }
                .frame(height: app.isPro ? 70 : 120)
                .accessibilityElement()
                .accessibilityLabel(Text("遊んだ日の暦"))
                .accessibilityValue(Text("\(days.filter { ($0.record?.plays ?? 0) > 0 }.count) 日"))
            }
        }
    }

    private var rangeNow: some View {
        let week = app.progress.range(lastDays: 7, today: app.today)
        let first = app.progress.history.first?.range
        return CloudPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("Range · 7 days")
                    Spacer()
                    if first != nil {
                        HStack(spacing: 4) {
                            Rectangle().fill(Theme.peachDeep).frame(width: 10, height: 1)
                            Text("はじめの日").font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                if week.isEmpty {
                    Text("この 7 日はまだ遊んでいません。今日の 1 分で、首の角度が描かれます。")
                        .font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                } else {
                    RangeFan(range: week, previous: first).frame(height: 130)
                    HStack {
                        cell("倒す", week.tilt)
                        cell("向く", week.turn)
                        cell("うなずく", week.nod)
                    }
                }
                Text("角度はカメラで読んだめやすです。医療の測定ではありません。")
                    .font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func cell(_ label: LocalizedStringKey, _ v: Double) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(Int(v.rounded()))°").font(Theme.serif(22, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    /// 週ごとの範囲の合計（Pro）。無料は、ぼかした見本と一文
    private var weekly: some View {
        let values = app.progress.weeklyTilt(weeks: 8, today: app.today)
        let maxV = max(1, values.max() ?? 1)
        return CloudPanel {
            VStack(alignment: .leading, spacing: 10) {
                Caption("Weekly range · 8 weeks")
                ZStack {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                            VStack(spacing: 4) {
                                Capsule()
                                    .fill(i == values.count - 1 ? Theme.peach : Theme.sky)
                                    .frame(width: 14, height: max(4, 100 * v / maxV))
                                Text(verbatim: v > 0 ? "\(Int(v))" : "–").font(Theme.text(9)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 124, alignment: .bottom)
                    .blur(radius: app.isPro ? 0 : 6)
                    if !app.isPro {
                        Button { app.sheet = .pro } label: {
                            Text("週ごとの移り変わりは Pro")
                                .font(Theme.text(13, .medium))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(.white.opacity(0.9)))
                                .foregroundStyle(Theme.skyDeep)
                        }
                    }
                }
            }
        }
    }
}
