import QuartzCore
import SwiftUI

/// はじめの 3 ページ。動く見本（風船が輪へ流れて満ちる）で見せる。
/// ページ送りは自前（TabView の page は使わない）。見本は 2 回くり返したら止まる（動き続ける画面を作らない）
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var demoRunning = false
    @State private var demoRun = 0

    private let cycle = 3.0
    /// ページごとに空が移る：朝焼け → 昼の青 → 夕暮れ
    private var sky: SkyTime { [SkyTime.dawn, .noon, .dusk][min(page, 2)] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < 2 {
                    Button("スキップ") { finish() }
                        .font(Theme.text(15, .bold))
                        .foregroundStyle(.white)
                        .onSkyText(sky)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TimelineView(.animation(paused: reduceMotion || !demoRunning)) { _ in
                demo(p: reduceMotion || !demoRunning ? 0.78 : (CACurrentMediaTime().truncatingRemainder(dividingBy: cycle)) / cycle)
            }
            .frame(maxWidth: 380, maxHeight: 330)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture { demoRun += 1 }
            .task(id: "\(page)-\(demoRun)") {
                demoRunning = !reduceMotion
                try? await Task.sleep(for: .seconds(cycle * 2))
                demoRunning = false
            }

            VStack(alignment: .leading, spacing: 10) {
                pageText
                if page == 2 { inputPicker.padding(.top, 6) }
            }
            .padding(20)
            .frame(maxWidth: 520, alignment: .leading)
            .background(PaperBack(seed: Double(page) + 40, radius: Theme.rLarge))
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .id(page)
            .transition(.opacity)

            Spacer(minLength: 12)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Theme.gold : .white.opacity(0.45)).frame(width: i == page ? 24 : 8, height: 8)
                }
            }
            .padding(.bottom, 16)
            .accessibilityHidden(true)

            Button {
                if page < 2 {
                    withAnimation(.easeOut(duration: 0.25)) { page += 1 }
                    Haptics.select()
                } else {
                    finish()
                }
            } label: {
                Text(page == 2 ? LocalizedStringKey("はじめる") : LocalizedStringKey("次へ"))
            }
            .buttonStyle(PillButtonStyle())
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(SkyBackdrop(sky: sky, drift: Double(page) * 0.3).id(sky).transition(.opacity))
        .animation(.easeOut(duration: 0.5), value: page)
        .environment(\.skyTime, sky)
    }

    @ViewBuilder
    private var pageText: some View {
        switch page {
        case 0:
            Caption("Neck Balloon")
            Text("首で、風船を運ぶ。").font(Theme.display(30, .heavy)).foregroundStyle(Theme.ink)
            Text("iPhone を机に立てて、首をゆっくり倒す・うなずく・横を向く。その動きで、風船が雲の輪へ流れていきます。")
                .font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        case 1:
            Caption("ゆっくり大きく")
            Text("ゆっくり、大きく、保つ。").font(Theme.display(30, .heavy)).foregroundStyle(Theme.ink)
            Text("速く動かすと風が乱れて点が減ります。輪の中で 3 秒保つと、輪が満ちます。痛いときは、すぐにやめてください。")
                .font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        default:
            Caption("プライバシー")
            Text("カメラは、向きを読むだけ。").font(Theme.display(28, .heavy)).foregroundStyle(Theme.ink)
            Text("顔の向きは iPhone の中だけで計算し、映像は保存も送信もしません。カメラを使わず、傾けたり指でなぞったりしても遊べます。")
                .font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inputPicker: some View {
        @Bindable var app = app
        return HStack(spacing: 8) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                let on = app.progress.settings.input == mode
                Button {
                    app.progress.settings.input = mode
                    Haptics.select()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.symbol).font(.system(size: 16, weight: .regular))
                        Text(mode.label).font(Theme.text(12, .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .foregroundStyle(on ? .white : Theme.inkSoft)
                    .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).fill(on ? Theme.balloonDeep : Theme.line.opacity(0.5)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).stroke(on ? Theme.balloonLine.opacity(0.5) : Theme.paperEdge, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func finish() {
        app.progress.hasOnboarded = true
    }

    /// 見本の絵：p（0〜1）で、風船がまんなかから右の輪へ流れ、輪が満ちる
    private func demo(p: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let reach = min(1, p / 0.45)
            let ease = reach * reach * (3 - 2 * reach)
            let fill = max(0, min(1, (p - 0.45) / 0.45))
            let ringX = w * 0.74, cx = w * 0.32
            ZStack {
                CloudRing(fill: fill)
                    .frame(width: h * 0.62)
                    .position(x: ringX, y: h * 0.42)
                Balloon(tilt: .degrees(14 * ease), glow: fill)
                    .frame(height: h * 0.52)
                    .position(x: cx + (ringX - cx) * ease, y: h * 0.42 + h * 0.08)
                if page == 1 {
                    Text("そのまま、3 秒")
                        .font(Theme.display(17, .heavy))
                        .foregroundStyle(.white)
                        .onSkyText(sky)
                        .position(x: w / 2, y: h * 0.92)
                }
            }
        }
        .aspectRatio(1.15, contentMode: .fit)
    }
}

extension InputMode {
    var symbol: String {
        switch self {
        case .camera: "face.dashed"
        case .tilt: "iphone.gen3.radiowaves.left.and.right"
        case .touch: "hand.point.up.left"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .camera: "カメラ"
        case .tilt: "傾ける"
        case .touch: "指"
        }
    }
}
