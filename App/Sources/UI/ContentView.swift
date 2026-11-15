import SwiftUI

// iPhone Duo では、内側の画面が regular × regular、外側の画面がほかの iPhone と同じ size class になる。
// 画面の大きさ・向き・機種ではなく size class で並べ方を変える（Apple「Preparing your app for iPhone Duo」）。
struct ContentView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var systemLocale

    var body: some View {
        @Bindable var app = app
        ZStack {
            if !app.progress.hasOnboarded {
                OnboardingView().transition(.opacity)
            } else {
                switch app.route {
                case .home:
                    HomeView().transition(.opacity)
                case .play:
                    if let p = app.play {
                        PlayView(play: p).id(ObjectIdentifier(p)).transition(.opacity)
                    } else {
                        HomeView()
                    }
                case .result:
                    if let s = app.lastSummary { ResultView(summary: s).transition(.opacity) } else { HomeView() }
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: app.route)
        .animation(.easeOut(duration: 0.35), value: app.progress.hasOnboarded)
        .sheet(item: $app.sheet) { sheet in
            Group {
                switch sheet {
                case .courses: CoursesView()
                case .records: RecordsView()
                case .settings: SettingsView()
                case .pro: ProView()
                case .permission: PermissionView()
                }
            }
            .environment(app)
            .environment(\.locale, app.forcedLocale ?? systemLocale)
            .environment(\.skyTime, app.todayCourse.sky)
        }
        .environment(\.locale, app.forcedLocale ?? systemLocale)
        // 今日の空（朝焼け・昼の青・夕暮れ・夜と星）で、画面全体の色が変わる。プレイと結果は、そのコースの空
        .environment(\.skyTime, app.todayCourse.sky)
        // 空そのものが明るさを決めるので、システムの見た目は明るいほうに固定する（紙の上の文字はいつも藍のインク）
        .preferredColorScheme(.light)
    }
}
