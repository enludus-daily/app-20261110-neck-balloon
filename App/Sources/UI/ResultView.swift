import SwiftUI

/// 結果：点数（セリフの大きな数字が数え上がる）、風の言葉、首の動いた範囲の分度器、共有カード
struct ResultView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: SessionSummary
    @State private var shown = 0
    @State private var shareImage: Image?

    private var course: Course? { CourseLibrary.course(id: summary.courseID) }
    private var previousWeek: NeckRange? {
        guard let t = DayKey.ordinal(summary.date) else { return nil }
        let r = (7..<14).reduce(NeckRange()) { $0.merged(app.progress.days[DayKey.key(ordinal: t - $1)]?.range ?? NeckRange()) }
        return r.isEmpty ? nil : r
    }

    private var sky: SkyTime { course?.sky ?? .noon }

    var body: some View {
        ZStack {
            SkyBackdrop(sky: sky, drift: 0.5)
            ScrollView {
                VStack(spacing: 18) {
                    scoreBlock.padding(.top, 28)
                    if hSize == .regular {
                        HStack(alignment: .top, spacing: 18) { rangeBlock; statsBlock }
                    } else {
                        rangeBlock
                        statsBlock
                    }
                    if let img = shareImage {
                        ShareLink(item: img, preview: SharePreview("くびふうせん", image: img)) {
                            Label("カードを共有", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(LineButtonStyle())
                    }
                    Button { app.playAgain() } label: { Text("もう 1 回") }
                        .buttonStyle(PillButtonStyle())
                    Button { app.route = .home } label: { Text("ホームへ") }
                        .font(Theme.text(15, .bold))
                        .foregroundStyle(.white)
                        .onSkyText(sky)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: hSize == .regular ? 820 : 520)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.skyTime, sky)
        .task {
            shareImage = renderShareImage()
            // 数字が数え上がる（0.9 秒）
            if reduceMotion || app.forcedLocale != nil || !app.persist { shown = summary.score; return }
            for i in 0...20 {
                shown = summary.score * i / 20
                try? await Task.sleep(for: .milliseconds(45))
            }
        }
    }

    private var scoreBlock: some View {
        VStack(spacing: 4) {
            Text(verbatim: course?.title.text(locale) ?? "")
                .font(Theme.text(14, .bold)).foregroundStyle(Theme.palette(sky).onSkySoft)
            ZStack {
                // 満ちた輪の中に点数（輪は保った 1 回 1 回のしるし）
                CloudRing(fill: 1).frame(width: 230)
                Text(verbatim: "\(shown)")
                    .font(Theme.display(84, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            Text(summary.grade.title.text(locale))
                .font(Theme.display(28, .heavy))
                .foregroundStyle(Theme.gold)
            Text(summary.grade.note.text(locale))
                .font(Theme.text(15, .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .onSkyText(sky)
        .accessibilityElement(children: .combine)
    }

    private var rangeBlock: some View {
        PaperPanel(seed: 7) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("首の動いた範囲")
                    Spacer()
                    if previousWeek != nil {
                        HStack(spacing: 4) {
                            Rectangle().fill(Theme.balloonDeep).frame(width: 10, height: 1.5)
                            Text("先週").font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                RangeFan(range: summary.range, previous: previousWeek).frame(height: 120)
                HStack {
                    angle("左に倒す", summary.range.tiltLeft)
                    angle("右に倒す", summary.range.tiltRight)
                    angle("下", summary.range.down)
                    angle("上", summary.range.up)
                }
            }
        }
    }

    private func angle(_ label: LocalizedStringKey, _ v: Double) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(Int(v.rounded()))°").font(Theme.display(21, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.text(11, .medium)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsBlock: some View {
        PaperPanel(seed: 8) {
            VStack(alignment: .leading, spacing: 10) {
                Caption("今日の 1 分")
                row("ストレッチ", "\(summary.stretches)")
                row("なぎ（90 点以上）", "\(summary.perfect)")
                row("風が乱れた秒数", String(format: "%.1f", summary.fastSeconds))
                row("続けた日", "\(app.progress.streak(today: app.today))")
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.text(14, .medium)).foregroundStyle(Theme.ink.opacity(0.8))
            Spacer()
            Text(verbatim: value).font(Theme.display(19, .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }

    /// 共有カード（1080×1350）。映像や顔は入れない。風船と点数と範囲だけ
    @MainActor
    private func renderShareImage() -> Image {
        let card = ShareCard(summary: summary, courseTitle: course?.title.text(locale) ?? "", sky: sky,
                             gradeTitle: summary.grade.title.text(locale))
            .environment(\.locale, locale)
            .environment(\.skyTime, sky)
        let r = ImageRenderer(content: card)
        r.scale = 3
        if let ui = r.uiImage { return Image(uiImage: ui) }
        return Image(systemName: "wind")
    }
}

struct ShareCard: View {
    let summary: SessionSummary
    let courseTitle: String
    let sky: SkyTime
    let gradeTitle: String

    var body: some View {
        ZStack {
            SkyBackdrop(sky: sky, drift: 0.3)
            VStack(spacing: 8) {
                Text(verbatim: courseTitle).font(Theme.text(16, .bold)).foregroundStyle(.white.opacity(0.85))
                Balloon(tilt: .degrees(8), glow: 1).frame(height: 130)
                Text(verbatim: "\(summary.score)").font(Theme.display(72, .heavy)).foregroundStyle(.white)
                Text(verbatim: gradeTitle).font(Theme.display(20, .heavy)).foregroundStyle(Theme.gold)
                RangeFan(range: summary.range, onSky: true).frame(width: 200, height: 90)
                Text(verbatim: "Neck Balloon · \(summary.date)").font(Theme.text(10, .semibold)).kerning(1).foregroundStyle(.white.opacity(0.75))
            }
            .onSkyText(sky)
            .padding(24)
        }
        .frame(width: 360, height: 450)
    }
}
