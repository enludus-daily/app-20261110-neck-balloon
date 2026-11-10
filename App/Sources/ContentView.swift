import SwiftUI

// ひな形の画面。その日のアプリで置き換える。
// iPhone Duo では、内側の画面が regular × regular、外側の画面がほかの iPhone と同じ size class になる。
// 画面の大きさ・向き・機種ではなく size class で並べ方を変える（Apple Tech Talk「Prepare your app for iPhone Duo」）。
struct ContentView: View {
    // UserDefaults を使う（PrivacyInfo.xcprivacy に CA92.1 で申告済み）
    @AppStorage("tally.count") private var count = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // 広い画面（iPhone Duo の内側など）: 横に並べる
                HStack(spacing: 48) {
                    counter
                    buttons(axis: .vertical)
                }
            } else {
                VStack(spacing: 24) {
                    counter
                    buttons(axis: .horizontal)
                }
            }
        }
        .padding()
    }

    private var counter: some View {
        Text("\(count)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel("回数 \(count)")
    }

    @ViewBuilder
    private func buttons(axis: Axis) -> some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        layout {
            Button("リセット", role: .destructive) { apply { $0.reset() } }
                .buttonStyle(.bordered)
            Button("1 たす") { apply { $0.increment() } }
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
    }

    private func apply(_ change: (inout Tally) -> Void) {
        var tally = Tally(count: count)
        change(&tally)
        withAnimation { count = tally.count }
    }
}

#Preview {
    ContentView()
}
