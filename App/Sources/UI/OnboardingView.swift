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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < 2 {
                    Button("スキップ") { finish() }
                        .font(Theme.text(14))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TimelineView(.animation(paused: reduceMotion || !demoRunning)) { _ in
                demo(p: reduceMotion || !demoRunning ? 0.78 : (CACurrentMediaTime().truncatingRemainder(dividingBy: cycle)) / cycle)
            }
            .frame(maxWidth: 360, maxHeight: 320)
            .padding(.horizontal, 28)
            .contentShape(Rectangle())
            .onTapGesture { demoRun += 1 }
            .task(id: "\(page)-\(demoRun)") {
                demoRunning = !reduceMotion
                try? await Task.sleep(for: .seconds(cycle * 2))
                demoRunning = false
            }

            VStack(alignment: .leading, spacing: 12) {
                pageText
                if page == 2 { inputPicker.padding(.top, 6) }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .id(page)
            .transition(.opacity)

            Spacer(minLength: 12)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Theme.skyDeep : Theme.line).frame(width: i == page ? 22 : 8, height: 8)
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
        .background(Theme.sky(.dawn).ignoresSafeArea())
    }

    @ViewBuilder
    private var pageText: some View {
        switch page {
        case 0:
            Caption("Neck Balloon", color: Theme.skyDeep)
            Text("首で、風船を運ぶ。").font(Theme.serif(32, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
            Text("iPhone を机に立てて、首をゆっくり倒す・うなずく・横を向く。その動きで、風船が雲の輪へ流れていきます。")
                .font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        case 1:
            Caption("Slow & wide", color: Theme.skyDeep)
            Text("ゆっくり、大きく、保つ。").font(Theme.serif(32, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
            Text("速く動かすと風が乱れて点が減ります。輪の中で 3 秒保つと、輪が満ちます。痛いときは、すぐにやめてください。")
                .font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
        default:
            Caption("Privacy", color: Theme.skyDeep)
            Text("カメラは、向きを読むだけ。").font(Theme.serif(30, .medium)).kerning(-0.5).foregroundStyle(Theme.ink)
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
                        Text(mode.label).font(Theme.text(12, .medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .foregroundStyle(on ? Theme.skyDeep : Theme.inkSoft)
                    .background(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).fill(on ? Theme.skySoft : .white.opacity(0.5)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rSmall, style: .continuous).stroke(on ? Theme.sky : Theme.line, lineWidth: 1))
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
                SkyBackdrop(sky: page == 1 ? .noon : .dawn)
                CloudRing(fill: fill)
                    .frame(width: h * 0.62)
                    .position(x: ringX, y: h * 0.42)
                Balloon(tilt: .degrees(14 * ease), glow: fill)
                    .frame(height: h * 0.52)
                    .position(x: cx + (ringX - cx) * ease, y: h * 0.42 + h * 0.08)
                if page == 1 {
                    Text("そのまま、3 秒")
                        .font(Theme.serif(15).italic())
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .position(x: w / 2, y: h * 0.9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
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
