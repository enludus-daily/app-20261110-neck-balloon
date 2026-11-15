import SwiftUI

/// ホーム：今日の 1 分のコース（空の窓）、続けた日、この 7 日の首の範囲
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.skyTime) private var sky

    private var palette: SkyPalette { Theme.palette(sky) }

    var body: some View {
        ZStack {
            SkyBackdrop(sky: sky, drift: Double(app.todayOrdinal % 7) / 7)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 4) { hero; todayCard }.frame(maxWidth: .infinity)
                            VStack(spacing: 16) { weekCard; rangeCard; links }.frame(width: 340)
                        }
                    } else {
                        hero
                        todayCard
                        weekCard
                        rangeCard
                        links
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: hSize == .regular ? 920 : 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.todayCourse.sky.name.text(locale))
                    .font(Theme.text(13, .semibold)).foregroundStyle(palette.onSkySoft)
                Text("くびふうせん").font(Theme.display(30, .heavy)).foregroundStyle(palette.onSky)
            }
            .onSkyText(sky)
            Spacer()
            if !app.isPro {
                Button { app.sheet = .pro } label: {
                    Text("Pro").font(Theme.text(14, .heavy))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .foregroundStyle(Theme.ink)
                        .background(Capsule().fill(Theme.gold))
                }
            }
            Button { app.sheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundStyle(palette.onSky).frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("設定"))
        }
    }

    /// 今日の空に浮かぶ風船と、最初の輪（枠のない絵。空がそのまま背景）
    private var hero: some View {
        let c = app.todayCourse
        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let d = c.moves.first?.screenDirection ?? (x: 1.0, y: 0.0)
            CloudRing(fill: app.playedToday ? 1 : 0.0)
                .frame(width: h * 0.62)
                .position(x: w / 2 + d.x * w * 0.26, y: h * 0.46 - d.y * h * 0.22)
            Balloon(tilt: .degrees(7), glow: app.playedToday ? 1 : 0.2)
                .frame(height: h * 0.78)
                .position(x: w / 2 - d.x * w * 0.12, y: h * 0.52)
            Text(app.playedToday ? LocalizedStringKey("今日の 1 分：できた") : LocalizedStringKey("今日の 1 分"))
                .font(Theme.text(13, .bold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(palette.paper))
                .foregroundStyle(palette.washDeep)
                .position(x: 70, y: 18)
        }
        .frame(height: hSize == .regular ? 300 : 230)
    }

    private var todayCard: some View {
        let c = app.todayCourse
        return PaperPanel(seed: 1) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(c.title.text(locale)).font(Theme.display(26, .heavy)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(verbatim: "\(c.estimatedSeconds(app.progress.settings.leniency))s")
                        .font(Theme.display(16, .bold)).monospacedDigit().foregroundStyle(palette.washDeep)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(palette.washSoft))
                }
                Text(c.note.text(locale)).font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.78))
                HStack(spacing: 6) {
                    ForEach(Array(c.moves.filter { !$0.isArc }.prefix(8).enumerated()), id: \.offset) { _, m in MoveGlyph(move: m) }
                    if c.moves.contains(where: \.isArc) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.washDeep)
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
        }
    }

    /// この 7 日：遊んだ日は小さな風船、遊ばなかった日は小さな雲
    private var weekCard: some View {
        let days = app.progress.lastDays(7, today: app.today)
        let streak = app.progress.streak(today: app.today)
        return PaperPanel(seed: 2) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Caption("この 7 日")
                    Spacer()
                    Text("\(streak) 日つづけて").font(Theme.display(17, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                HStack(spacing: 0) {
                    ForEach(days, id: \.key) { d in
                        VStack(spacing: 6) {
                            if (d.record?.plays ?? 0) > 0 {
                                Balloon(showString: false).frame(height: 26)
                            } else {
                                Circle().fill(palette.washSoft).frame(width: 14, height: 14).frame(height: 26)
                            }
                            Text(verbatim: String(d.key.suffix(2))).font(Theme.text(11, d.key == app.today ? .heavy : .medium)).monospacedDigit()
                                .foregroundStyle(d.key == app.today ? palette.washDeep : Theme.inkSoft)
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
            PaperPanel(seed: 3) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Caption("首の動いた範囲")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSoft)
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
            Text(label).font(Theme.text(12, .medium)).foregroundStyle(Theme.inkSoft).frame(width: 64, alignment: .leading)
            Text(verbatim: "\(Int(v.rounded()))°").font(Theme.display(19, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }

    private var links: some View {
        HStack(spacing: 10) {
            linkButton("コース", "cloud.fill", .courses)
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
