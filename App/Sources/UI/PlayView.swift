import UIKit
import SwiftUI

/// プレイ：空のまんなかに風船（自分の頭）、動きの向きに雲の輪。下に短い一文の案内だけ（Calm の 1 分の呼吸の画面の組み立て）
struct PlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let play: PlayModel

    private var s: StretchSession { play.session }

    var body: some View {
        ZStack {
            SkyBackdrop(sky: s.course.sky, drift: s.courseProgress)
            if hSize == .regular {
                HStack(spacing: 24) {
                    VStack(spacing: 0) {
                        topBar
                        stage
                        cue
                    }
                    sidePanel.frame(width: 280)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    topBar
                    stage
                    cue
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            overlays
        }
    }

    // MARK: 上

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { app.quit() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.75)))
            }
            .accessibilityLabel(Text("やめる"))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.6))
                    Capsule().fill(Theme.skyDeep).frame(width: geo.size.width * s.courseProgress)
                }
            }
            .frame(height: 3)
            Text(verbatim: "\(min(s.index + 1, s.course.moves.count)) / \(s.course.moves.count)")
                .font(Theme.serif(15)).monospacedDigit().foregroundStyle(Theme.ink.opacity(0.7))
        }
        .padding(.top, 8)
    }

    // MARK: 空（風船と輪）

    /// 画面に出す動き（戻している間は、いま終えた動き）
    private var shownMove: Move? {
        if s.phase == .returning, s.index > 0 { return s.course.moves[s.index - 1] }
        return s.move
    }

    private var shownProgress: Double {
        guard let m = shownMove else { return 0 }
        return StretchSession.measure(s.pose, toward: m.target(s.size)).along
    }

    private var stage: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let isArc = shownMove?.isArc ?? false
            let dir = shownMove?.screenDirection ?? (x: 0.0, y: 1.0)
            // 道の長さ。回すは画面のまんなかを中心に円をえがくので短め
            let r = min(w, h) * (isArc ? 0.3 : 0.42)
            // 戻る場所（まっすぐの向き）。回す以外は、道のまんなかが画面のまんなかに来るように、輪と反対へ半分ずらす
            // （風船が端に寄って、画面の片側だけが空く、をなくす。#15）
            let c = isArc ? CGPoint(x: w / 2, y: h / 2) : CGPoint(x: w / 2 - dir.x * r / 2, y: h / 2 + dir.y * r / 2)
            let ringPos = CGPoint(x: c.x + dir.x * r, y: c.y - dir.y * r)
            // 輪は風船よりひと回り大きく、風船がすっぽり入る。道の長さに対しては小さくして、
            // 向かい始めの風船と輪のあいだに空きを残す（今の角度と目標の差が、距離で見える）
            let ringSize = r * (isArc ? 1.1 : 0.95)
            let balloonHeight = ringSize * 0.82
            let along = max(-0.35, min(1.25, shownProgress))
            // ずれ：輪の中心からはずれた分を、進む向きと直角に。速すぎると風で揺れる
            let wobble = reduceMotion ? 0 : sin(play.now * 23) * s.gust * r * 0.12
            let perp = (x: -dir.y, y: dir.x)
            let side = min(0.6, s.offAxis) * r * 0.35 + wobble
            let bx = c.x + dir.x * r * along + perp.x * side
            let by = c.y - dir.y * r * along - perp.y * side
            let completeAge = play.now - play.completedAt
            let enterAge = play.now - play.enteredAt
            let reached = max(0, min(1, along))
            ZStack {
                if let m = shownMove {
                    let fill = s.phase == .returning ? 1 : s.holdFraction
                    if m.isArc {
                        // 回す：円の道を薄く
                        Circle()
                            .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                            .frame(width: r * 2, height: r * 2)
                            .position(c)
                    } else {
                        // 「ここまで倒す」の道：太く淡い帯。今の角度まで色がのびて、目標との差が形で分かる
                        Path { p in
                            p.move(to: c)
                            p.addLine(to: ringPos)
                        }
                        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: r * 0.3, lineCap: .round))
                        if s.phase != .returning {
                            Path { p in
                                p.move(to: c)
                                p.addLine(to: CGPoint(x: c.x + dir.x * r * reached, y: c.y - dir.y * r * reached))
                            }
                            .stroke(Theme.sky.opacity(0.45), style: StrokeStyle(lineWidth: r * 0.3, lineCap: .round))
                        }
                        // 道の中心の細い点線と、行き先の向きの小さな矢じり
                        Path { p in
                            p.move(to: c)
                            p.addLine(to: ringPos)
                        }
                        .stroke(Theme.skyDeep.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                        Chevron()
                            .stroke(Theme.skyDeep.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .frame(width: r * 0.12, height: r * 0.12)
                            .rotationEffect(.radians(atan2(-dir.y, dir.x)))
                            .position(x: c.x + dir.x * r * 0.5, y: c.y - dir.y * r * 0.5)
                            .opacity(s.phase == .reaching && along < 0.45 ? 1 : 0)
                    }
                    // 目標：淡い面と細い線の的。その上に雲の輪
                    Circle()
                        .fill(Color.white.opacity(s.phase == .holding ? 0.55 : 0.4))
                        .overlay(Circle().stroke(Theme.skyDeep.opacity(0.45), lineWidth: Theme.hairline))
                        .frame(width: ringSize * 0.74, height: ringSize * 0.74)
                        .position(ringPos)
                        .opacity(s.phase == .returning ? 0.5 : 1)
                    CloudRing(fill: fill, active: s.phase != .returning)
                        .frame(width: ringSize)
                        .scaleEffect(reduceMotion || enterAge > 0.4 ? 1 : 1 + 0.08 * (1 - enterAge / 0.4))
                        .position(ringPos)
                        .opacity(s.phase == .returning ? 0.55 : 1)
                    if !reduceMotion, completeAge < 0.7 {
                        let q = completeAge / 0.7
                        Circle()
                            .stroke(Theme.peachDeep.opacity(0.6 * (1 - q)), lineWidth: 2)
                            .frame(width: ringSize * (1.05 + 0.5 * q))
                            .position(ringPos)
                    }
                }
                // まんなかの印（戻る場所）
                Circle().stroke(Theme.ink.opacity(0.22), lineWidth: 1).frame(width: 12, height: 12).position(c)
                Balloon(tilt: .degrees(max(-30, min(30, s.pose.roll * 0.7))), glow: s.phase == .holding ? s.holdFraction : 0)
                    .frame(height: balloonHeight)
                    .position(x: bx, y: by + balloonHeight * 0.13)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.25, dampingFraction: 0.85), value: bx)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard play.input == .touch else { return }
                        play.touch(x: (v.location.x - c.x) / r, y: (c.y - v.location.y) / r)
                    }
                    .onEnded { _ in play.touchEnded() }
            )
        }
    }

    // MARK: 下（一文の案内）

    private var cue: some View {
        VStack(spacing: 6) {
            if let m = s.move ?? shownMove {
                Text(m.cue.text(locale))
                    .font(Theme.serif(22, .medium).italic())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .id(m.rawValue + "\(s.index)")
                    .transition(.opacity)
            }
            Text(phaseLine)
                .font(Theme.text(14))
                .foregroundStyle(s.gust > 0.4 ? Theme.peachDeep : Theme.inkSoft)
                .monospacedDigit()
        }
        .frame(minHeight: 70)
        .animation(.easeOut(duration: 0.25), value: s.index)
    }

    private var phaseLine: LocalizedStringKey {
        if s.gust > 0.4 { return "ゆっくり。風が乱れています" }
        switch s.phase {
        case .countIn: return "まっすぐ前を見て"
        case .reaching: return s.progress > 0.4 ? "あと少し。痛くないところまで" : "ゆっくり"
        case .holding:
            let left = max(0, Int((s.holdTarget * (1 - s.holdFraction)).rounded(.up)))
            return "そのまま \(left)"
        case .returning: return "まっすぐに戻して"
        case .finished: return "おつかれさま"
        }
    }

    // MARK: 横（Duo の内側など広い画面）

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Caption("Your head")
            HeadDial(pose: s.pose)
                .frame(width: 120, height: 120)
                .background(Circle().fill(.white.opacity(0.55)))
            Text(s.course.title.text(locale)).font(Theme.serif(24, .medium)).foregroundStyle(Theme.ink)
            Caption("Next")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(s.course.moves.enumerated().filter { $0.offset >= s.index && !($0.element.isArc && $0.offset > s.index) }.prefix(4)), id: \.offset) { item in
                    HStack(spacing: 8) {
                        MoveGlyph(move: item.element)
                        Text(item.element.cue.text(locale)).font(Theme.text(13))
                            .foregroundStyle(item.offset == s.index ? Theme.ink : Theme.inkSoft)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(s.score)").font(Theme.serif(40)).kerning(-2).monospacedDigit().foregroundStyle(Theme.ink)
                Caption("score")
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous).fill(.white.opacity(0.4)))
    }

    // MARK: 重ねる表示

    @ViewBuilder
    private var overlays: some View {
        if s.phase == .countIn, !play.frozen {
            let n = Int(s.countdown(at: play.now).rounded(.up))
            VStack(spacing: 6) {
                Text(verbatim: "\(max(1, n))").font(Theme.serif(80)).monospacedDigit().foregroundStyle(Theme.ink)
                Text("肩の力をぬいて、まっすぐ前を見て").font(Theme.text(14)).foregroundStyle(Theme.inkSoft)
            }
            .padding(28)
            .background(Circle().fill(.white.opacity(0.55)).frame(width: 240, height: 240))
            .allowsHitTesting(false)
        }
        switch play.sourceStatus {
        case .denied, .unavailable:
            sourceProblem(title: play.sourceStatus == .denied ? LocalizedStringKey("カメラの許可がありません") : LocalizedStringKey("この iPhone ではカメラで遊べません"))
        default:
            EmptyView()
        }
        // 見失ってもすぐには出さない（行きすぎで見えなくなっただけのときは、そのまま数える）
        if play.showFaceBack {
            VStack {
                Spacer()
                Text("顔を画面にもどしてください（iPhone は目の高さに）")
                    .font(Theme.text(13, .medium))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.85)))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 110)
            }
            .allowsHitTesting(false)
        }
        if play.flippedNotice {
            VStack {
                Text("左右を入れ替えました（設定で戻せます）")
                    .font(Theme.text(12))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.85)))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 60)
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }

    private func sourceProblem(title: LocalizedStringKey) -> some View {
        VStack(spacing: 14) {
            Text(title).font(Theme.serif(22, .medium)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text("カメラを使わずに、iPhone を傾けるか、指でなぞって同じコースを遊べます。")
                .font(Theme.text(14)).foregroundStyle(Theme.ink.opacity(0.75)).multilineTextAlignment(.center)
            Button { app.quit(); app.pendingCourse = s.course; app.switchInput(.tilt) } label: { Text("傾けて遊ぶ") }
                .buttonStyle(PillButtonStyle())
            Button { app.quit(); app.pendingCourse = s.course; app.switchInput(.touch) } label: { Text("指で遊ぶ") }
                .buttonStyle(LineButtonStyle())
            if play.sourceStatus == .denied {
                Button("設定でカメラを許可する") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(Theme.text(13))
                .foregroundStyle(Theme.skyDeep)
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous).fill(Theme.paper))
        .shadow(color: Theme.shadow, radius: 16, y: 6)
        .padding(24)
    }
}

/// 行き先を指す小さな矢じり（右向き。回して使う）
private struct Chevron: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
        return p
    }
}
