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

    var body: some View {
        ZStack {
            SkyBackdrop(sky: course?.sky ?? .noon, drift: 0.5)
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
                        .font(Theme.text(15))
                        .foregroundStyle(Theme.skyDeep)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: hSize == .regular ? 820 : 520)
                .frame(maxWidth: .infinity)
            }
        }
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
        VStack(spacing: 6) {
            Caption(course.map { LocalizedStringKey($0.title.text(locale)) } ?? "Result", color: Theme.skyDeep)
            Text(verbatim: "\(shown)")
                .font(Theme.serif(96))
                .kerning(-4)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(summary.grade.title.text(locale))
                .font(Theme.serif(26, .medium).italic())
                .foregroundStyle(Theme.peachDeep)
            Text(summary.grade.note.text(locale))
                .font(Theme.text(14))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var rangeBlock: some View {
        CloudPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("Range")
                    Spacer()
                    if previousWeek != nil {
                        HStack(spacing: 4) {
                            Rectangle().fill(Theme.peachDeep).frame(width: 10, height: 1)
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
            Text(verbatim: "\(Int(v.rounded()))°").font(Theme.serif(20, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
            Text(label).font(Theme.text(11)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsBlock: some View {
        CloudPanel {
            VStack(alignment: .leading, spacing: 10) {
                Caption("Today")
                row("ストレッチ", "\(summary.stretches)")
                row("なぎ（90 点以上）", "\(summary.perfect)")
                row("風が乱れた秒数", String(format: "%.1f", summary.fastSeconds))
                row("続けた日", "\(app.progress.streak(today: app.today))")
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.text(14)).foregroundStyle(Theme.ink.opacity(0.8))
            Spacer()
            Text(verbatim: value).font(Theme.serif(18, .medium)).monospacedDigit().foregroundStyle(Theme.ink)
        }
    }

    /// 共有カード（1080×1350）。映像や顔は入れない。風船と点数と範囲だけ
    @MainActor
    private func renderShareImage() -> Image {
        let card = ShareCard(summary: summary, courseTitle: course?.title.text(locale) ?? "", sky: course?.sky ?? .noon,
                             gradeTitle: summary.grade.title.text(locale))
            .environment(\.locale, locale)
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
            VStack(spacing: 10) {
                Text(verbatim: courseTitle).font(Theme.serif(16).italic()).foregroundStyle(Theme.ink.opacity(0.7))
                Balloon(tilt: .degrees(8), glow: 1).frame(height: 130)
                Text(verbatim: "\(summary.score)").font(Theme.serif(72)).kerning(-3).foregroundStyle(Theme.ink)
                Text(verbatim: gradeTitle).font(Theme.serif(20, .medium).italic()).foregroundStyle(Theme.peachDeep)
                RangeFan(range: summary.range).frame(width: 200, height: 90)
                Text(verbatim: "Neck Balloon · \(summary.date)").font(Theme.text(10)).kerning(1).foregroundStyle(Theme.inkSoft)
            }
            .padding(24)
        }
        .frame(width: 360, height: 450)
    }
}
