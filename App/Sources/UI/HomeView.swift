import SwiftUI

/// ホーム：今日の 1 分のコース（空の窓）、続けた日、この 7 日の首の範囲
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: 18) {
                            todayCard.frame(maxWidth: .infinity)
                            VStack(spacing: 18) { weekCard; rangeCard }.frame(width: 340)
                        }
                    } else {
                        todayCard
                        weekCard
                        rangeCard
                    }
                    links
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: hSize == .regular ? 900 : 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Caption("Neck Balloon")
                Text("くびふうせん").font(Theme.serif(26, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
            }
            Spacer()
            if !app.isPro {
                Button { app.sheet = .pro } label: {
                    Text("Pro").font(Theme.serif(14, .medium).italic())
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .foregroundStyle(Theme.peachDeep)
                        .overlay(Capsule().stroke(Theme.peach, lineWidth: 1))
                }
            }
            Button { app.sheet = .settings } label: {
                Image(systemName: "gearshape").font(.system(size: 17)).foregroundStyle(Theme.inkSoft).frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("設定"))
        }
    }

    /// 今日のコース：空の窓に、風船と次の輪
    private var todayCard: some View {
        let c = app.todayCourse
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                SkyBackdrop(sky: c.sky, drift: Double(app.todayOrdinal % 7) / 7)
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    let d = c.moves.first?.screenDirection ?? (x: 1.0, y: 0.0)
                    CloudRing(fill: app.playedToday ? 1 : 0.0)
                        .frame(width: h * 0.5)
                        .position(x: w / 2 + d.x * w * 0.27, y: h * 0.5 - d.y * h * 0.28)
                    Balloon(tilt: .degrees(6), glow: app.playedToday ? 1 : 0)
                        .frame(height: h * 0.5)
                        .position(x: w / 2, y: h * 0.55)
                }
                VStack {
                    HStack {
                        Text(app.playedToday ? LocalizedStringKey("今日の 1 分：できた") : LocalizedStringKey("今日の 1 分"))
                            .font(Theme.text(12, .medium))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.7)))
                            .foregroundStyle(Theme.skyDeep)
                        Spacer()
                        Text(c.sky.name.text(locale))
                            .font(Theme.serif(13).italic())
                            .foregroundStyle(Theme.ink.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(14)
            }
            .frame(height: hSize == .regular ? 300 : 220)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.rLarge, topTrailingRadius: Theme.rLarge, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(c.title.text(locale)).font(Theme.serif(24, .medium)).kerning(-0.4).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(verbatim: "\(c.estimatedSeconds(app.progress.settings.leniency))s").font(Theme.serif(15)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                }
                Text(c.note.text(locale)).font(Theme.text(14)).foregroundStyle(Theme.ink.opacity(0.75))
                HStack(spacing: 6) {
                    ForEach(Array(c.moves.filter { !$0.isArc }.prefix(8).enumerated()), id: \.offset) { _, m in MoveGlyph(move: m) }
                    if c.moves.contains(where: \.isArc) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12)).foregroundStyle(Theme.skyDeep)
                    }
                }
                Button { app.startToday() } label: {
                    Label(app.playedToday ? LocalizedStringKey("もう 1 回") : LocalizedStringKey("はじめる"), systemImage: "wind")
                }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 4)
                Text(app.progress.settings.input.hint)
                    .font(Theme.text(12)).foregroundStyle(Theme.inkSoft)
            }
            .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous).fill(.white.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous).stroke(.white, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 12, y: 5)
    }

    /// この 7 日：遊んだ日は小さな風船
    private var weekCard: some View {
        let days = app.progress.lastDays(7, today: app.today)
        let streak = app.progress.streak(today: app.today)
        return CloudPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Caption("This week")
                    Spacer()
                    Text("\(streak) 日つづけて").font(Theme.serif(15, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                HStack(spacing: 0) {
                    ForEach(days, id: \.key) { d in
                        VStack(spacing: 6) {
                            if (d.record?.plays ?? 0) > 0 {
                                Balloon(showString: false).frame(height: 22)
                            } else {
                                Circle().stroke(Theme.line, lineWidth: 1).frame(width: 14, height: 14).frame(height: 22)
                            }
                            Text(verbatim: String(d.key.suffix(2))).font(Theme.text(11)).monospacedDigit()
                                .foregroundStyle(d.key == app.today ? Theme.skyDeep : Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("この 7 日"))
                .accessibilityValue(Text("\(days.filter { ($0.record?.plays ?? 0) > 0 }.count) 日"))
                if streak == 0, app.progress.totalDays > 0 {
                    Text("おかえりなさい。今日の 1 分から、また。").font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    /// この 7 日の首の範囲（分度器）
    private var rangeCard: some View {
        let week = app.progress.range(lastDays: 7, today: app.today)
        return Button { app.sheet = .records } label: {
            CloudPanel {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Caption("Range")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                    }
                    if week.isEmpty {
                        Text("1 回遊ぶと、首の動いた角度がここに描かれます。").font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                    } else {
                        HStack(alignment: .bottom, spacing: 16) {
                            RangeFan(range: week).frame(width: 130, height: 76)
                            VStack(alignment: .leading, spacing: 4) {
                                stat("倒す", week.tilt)
                                stat("向く", week.turn)
                                stat("うなずく", week.nod)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func stat(_ label: LocalizedStringKey, _ v: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label).font(Theme.text(12)).foregroundStyle(Theme.inkSoft).frame(width: 64, alignment: .leading)
            Text(verbatim: "\(Int(v.rounded()))°").font(Theme.serif(18, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }

    private var links: some View {
        HStack(spacing: 10) {
            linkButton("コース", "cloud", .courses)
            linkButton("記録", "chart.xyaxis.line", .records)
        }
    }

    private func linkButton(_ title: LocalizedStringKey, _ symbol: String, _ sheet: AppModel.Sheet) -> some View {
        Button { app.sheet = sheet; Haptics.select() } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(LineButtonStyle())
    }
}

extension InputMode {
    var hint: LocalizedStringKey {
        switch self {
        case .camera: "iPhone を目の高さに立てて、顔が映る位置で"
        case .tilt: "iPhone を両手で持ち、首といっしょに傾けて"
        case .touch: "指で風船を輪までゆっくりなぞって"
        }
    }
}
