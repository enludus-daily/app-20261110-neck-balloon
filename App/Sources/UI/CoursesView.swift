import SwiftUI

/// コースの一覧（空の時間帯ごと）。Pro のコースは 1 回だけ試せる
struct CoursesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("無料で 8 コース、Pro で 24 コース。どれも 1 分前後です。")
                        .font(Theme.text(13)).foregroundStyle(Theme.inkSoft)
                    ForEach(SkyTime.allCases, id: \.self) { sky in
                        let list = CourseLibrary.all.filter { $0.sky == sky }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(sky.name.text(locale)).font(Theme.serif(20, .medium)).foregroundStyle(Theme.ink)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: hSize == .regular ? 220 : 150), spacing: 12)], spacing: 12) {
                                ForEach(list) { c in tile(c) }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle(Text("コース"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
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
                    SkyBackdrop(sky: c.sky, drift: Double(c.id.count % 5) / 5)
                    Balloon(tilt: .degrees(Double(c.moves.count % 3) * 6 - 6), showString: false)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if locked {
                        Text(app.progress.usedProTrial ? LocalizedStringKey("Pro") : LocalizedStringKey("1 回ためせる"))
                            .font(Theme.text(10, .medium))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.85)))
                            .foregroundStyle(Theme.peachDeep)
                            .padding(8)
                    } else if played {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.skyDeep).padding(8)
                    }
                }
                .frame(height: 82)
                .clipped()
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title.text(locale)).font(Theme.serif(16, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(c.note.text(locale)).font(Theme.text(11)).foregroundStyle(Theme.inkSoft).lineLimit(2, reservesSpace: true)
                    HStack(spacing: 3) {
                        ForEach(Array(c.moves.filter { !$0.isArc }.prefix(6).enumerated()), id: \.offset) { _, m in MoveGlyph(move: m) }
                        Spacer()
                        Text(verbatim: "\(c.estimatedSeconds)s").font(Theme.text(11)).monospacedDigit().foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: Theme.rMedium, style: .continuous).fill(.white.opacity(0.8)))
            .clipShape(RoundedRectangle(cornerRadius: Theme.rMedium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMedium, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .opacity(locked && app.progress.usedProTrial ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(c.title.text(locale)))
        .accessibilityHint(locked ? Text("Pro のコース") : Text(""))
    }
}
