import SwiftUI

/// コースの一覧（空の時間帯ごと）。Pro のコースは 1 回だけ試せる
struct CoursesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.skyTime) private var sky

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("無料で 8 コース、Pro で 24 コース。どれも 1 分前後です。")
                        .font(Theme.text(14, .medium)).foregroundStyle(.white.opacity(0.85))
                        .onSkyText(sky)
                    ForEach(SkyTime.allCases, id: \.self) { t in
                        let list = CourseLibrary.all.filter { $0.sky == t }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                // 空の時間帯の小さな見本の丸
                                Circle()
                                    .fill(LinearGradient(colors: [Theme.palette(t).top, Theme.palette(t).mid, Theme.palette(t).bottom], startPoint: .top, endPoint: .bottom))
                                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
                                    .frame(width: 22, height: 22)
                                Text(t.name.text(locale)).font(Theme.display(21, .heavy)).foregroundStyle(.white)
                            }
                            .onSkyText(sky)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: hSize == .regular ? 220 : 150), spacing: 12)], spacing: 12) {
                                ForEach(list) { c in tile(c).environment(\.skyTime, c.sky) }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(SkyBackdrop(sky: sky, drift: 0.4))
            .skySheetChrome(title: "コース", sky: sky) { dismiss() }
        }
    }

    private func tile(_ c: Course) -> some View {
        let locked = c.isPro && !app.isPro
        let played = app.progress.history.contains { $0.courseID == c.id }
        return Button {
            Haptics.select()
            app.start(c)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    SkyBackdrop(sky: c.sky, drift: Double(c.id.count % 5) / 5, mini: true)
                    Balloon(tilt: .degrees(Double(c.moves.count % 3) * 6 - 6), showString: false)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if locked {
                        Text(app.progress.usedProTrial ? LocalizedStringKey("Pro") : LocalizedStringKey("1 回ためせる"))
                            .font(Theme.text(10, .heavy))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.gold))
                            .foregroundStyle(Theme.ink)
                            .padding(8)
                    } else if played {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.gold))
                            .padding(8)
                    }
                }
                .frame(height: 86)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.rMedium - 4, topTrailingRadius: Theme.rMedium - 4, style: .continuous))
                .padding([.horizontal, .top], 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title.text(locale)).font(Theme.display(16, .heavy)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(c.note.text(locale)).font(Theme.text(11)).foregroundStyle(Theme.inkSoft).lineLimit(2, reservesSpace: true)
                    HStack(spacing: 3) {
                        ForEach(Array(c.moves.filter { !$0.isArc }.prefix(4).enumerated()), id: \.offset) { _, m in MoveGlyph(move: m) }
                        if c.moves.contains(where: { $0.isArc }) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.palette(c.sky).washDeep)
                        }
                        Spacer(minLength: 2)
                        Text(verbatim: "\(c.estimatedSeconds(app.progress.settings.leniency))s").font(Theme.text(11, .bold)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                            .fixedSize()
                    }
                }
                .padding(10)
            }
            .background(PaperBack(seed: Double(c.id.count), radius: Theme.rMedium))
            .opacity(locked && app.progress.usedProTrial ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(c.title.text(locale)))
        .accessibilityHint(locked ? Text("Pro のコース") : Text(""))
    }
}
