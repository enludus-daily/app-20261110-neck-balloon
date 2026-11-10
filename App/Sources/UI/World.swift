import SwiftUI

// このアプリの世界：風船が自分の頭、雲の輪がストレッチの到達点、空の時間帯がコース、
// 首の動いた範囲は空に描く分度器（扇形）。どれも自作の Shape / Canvas で描く。

/// 風船（自分の頭）。目を閉じた静かな顔つき。tilt で傾く
struct Balloon: View {
    var tilt: Angle = .zero
    /// 0〜1：輪の中で保っている間、ほおが少し色づく
    var glow: Double = 0
    var showString = true

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, geo.size.height / 1.45)
            Canvas { ctx, size in
                let cx = size.width / 2
                let bw = w * 0.86, bh = w * 0.98
                let oval = CGRect(x: cx - bw / 2, y: 0, width: bw, height: bh)
                // ひも（ゆるい S 字）
                if showString {
                    var s = Path()
                    s.move(to: CGPoint(x: cx, y: bh + w * 0.06))
                    s.addCurve(to: CGPoint(x: cx, y: size.height),
                               control1: CGPoint(x: cx + w * 0.12, y: bh + w * 0.2),
                               control2: CGPoint(x: cx - w * 0.12, y: size.height - w * 0.12))
                    ctx.stroke(s, with: .color(Theme.inkSoft.opacity(0.7)), lineWidth: 1)
                }
                // 結び目
                var knot = Path()
                knot.move(to: CGPoint(x: cx - w * 0.05, y: bh + w * 0.065))
                knot.addLine(to: CGPoint(x: cx + w * 0.05, y: bh + w * 0.065))
                knot.addLine(to: CGPoint(x: cx, y: bh - w * 0.01))
                knot.closeSubpath()
                ctx.fill(knot, with: .color(Theme.peachDeep.opacity(0.8)))
                // 本体
                let shape = Path(ellipseIn: oval)
                ctx.fill(shape, with: .linearGradient(
                    Gradient(colors: [Theme.peachSoft, Theme.peach]),
                    startPoint: CGPoint(x: oval.minX, y: oval.minY), endPoint: CGPoint(x: oval.maxX, y: oval.maxY)))
                ctx.stroke(shape, with: .color(Theme.peachDeep.opacity(0.35)), lineWidth: 1)
                // 光：細い弧を 1 本だけ
                var hl = Path()
                hl.addArc(center: CGPoint(x: oval.midX, y: oval.midY), radius: bw * 0.36,
                          startAngle: .degrees(200), endAngle: .degrees(245), clockwise: false)
                ctx.stroke(hl, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: max(1.5, w * 0.025), lineCap: .round))
                // 顔：閉じた目（ゆるい弧）と、小さな口
                let eyeY = oval.midY - bh * 0.02
                for dx in [-bw * 0.17, bw * 0.17] {
                    var e = Path()
                    e.addArc(center: CGPoint(x: cx + dx, y: eyeY), radius: bw * 0.06,
                             startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                    ctx.stroke(e, with: .color(Theme.ink.opacity(0.75)), style: StrokeStyle(lineWidth: max(1.2, w * 0.022), lineCap: .round))
                }
                var m = Path()
                m.addArc(center: CGPoint(x: cx, y: eyeY + bh * 0.11), radius: bw * 0.035,
                         startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                ctx.stroke(m, with: .color(Theme.ink.opacity(0.6)), style: StrokeStyle(lineWidth: max(1, w * 0.018), lineCap: .round))
                // ほお
                for dx in [-bw * 0.27, bw * 0.27] {
                    let r = bw * 0.07
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + dx - r, y: eyeY + bh * 0.05, width: r * 2, height: r * 1.2)),
                             with: .color(Theme.peachDeep.opacity(0.12 + 0.25 * glow)))
                }
            }
            .rotationEffect(tilt, anchor: UnitPoint(x: 0.5, y: 0.35))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1 / 1.45, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// 雲の輪（ストレッチの到達点）。fill（0〜1）で peach の細い線が満ちていく
struct CloudRing: View {
    var fill: Double = 0
    var active = true

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = d * 0.36
                    // 雲のつぶを輪に並べる（固定の並びで、毎回同じ形）
                    let puffs = 14
                    for i in 0..<puffs {
                        let a = Double(i) / Double(puffs) * 2 * .pi
                        let pr = d * (i % 3 == 0 ? 0.105 : i % 3 == 1 ? 0.085 : 0.095)
                        let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - pr, y: p.y - pr, width: pr * 2, height: pr * 2)),
                                 with: .color(.white.opacity(active ? 0.92 : 0.6)))
                    }
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(Theme.sky.opacity(active ? 0.6 : 0.3)), lineWidth: Theme.hairline)
                }
                Circle()
                    .trim(from: 0, to: max(0, min(1, fill)))
                    .stroke(Theme.peachDeep.opacity(0.85), style: StrokeStyle(lineWidth: max(2, d * 0.02), lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: d * 0.92, height: d * 0.92)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// 背景の雲（固定の並び。動かさない）
struct SkyBackdrop: View {
    let sky: SkyTime
    /// 0〜1：雲を横に少しずらす（場面ごとに違う空に見せる）
    var drift: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.sky(sky)
                Canvas { ctx, size in
                    let clouds: [(x: Double, y: Double, s: Double)] = [(0.12, 0.16, 1.0), (0.78, 0.1, 0.7), (0.62, 0.42, 0.55), (0.2, 0.66, 0.8), (0.86, 0.78, 0.9)]
                    for c in clouds {
                        let w = size.width * 0.34 * c.s
                        let x = (c.x + drift * 0.06 * c.s).truncatingRemainder(dividingBy: 1.1) * size.width
                        let y = c.y * size.height
                        for (dx, dy, r) in [(-0.28, 0.05, 0.22), (0.0, -0.05, 0.3), (0.3, 0.06, 0.2)] {
                            let rr = w * r
                            ctx.fill(Path(ellipseIn: CGRect(x: x + w * dx - rr, y: y + w * dy - rr, width: rr * 2, height: rr * 2)),
                                     with: .color(.white.opacity(sky == .night ? 0.35 : 0.5)))
                        }
                    }
                    if sky == .night {
                        // 小さな星（固定の位置）
                        let stars: [(Double, Double)] = [(0.3, 0.08), (0.5, 0.2), (0.9, 0.3), (0.08, 0.4), (0.7, 0.6), (0.4, 0.86)]
                        for (sx, sy) in stars {
                            let p = CGPoint(x: sx * size.width, y: sy * size.height)
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.9)))
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 首の動いた範囲の分度器。左右に倒した角度を扇形で、うなずき・向きを細い弧で
struct RangeFan: View {
    let range: NeckRange
    /// 比べる範囲（前の週など。細い点線で）
    var previous: NeckRange?

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height * 0.92)
            let r = min(size.width / 2, size.height * 0.9) * 0.95
            // 目盛り（15° ごと）
            for deg in stride(from: -60.0, through: 60.0, by: 15) {
                let a = (deg - 90) * .pi / 180
                var t = Path()
                t.move(to: CGPoint(x: c.x + cos(a) * r * 0.92, y: c.y + sin(a) * r * 0.92))
                t.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                ctx.stroke(t, with: .color(Theme.inkSoft.opacity(deg == 0 ? 0.8 : 0.4)), lineWidth: Theme.hairline)
            }
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(-150), endAngle: .degrees(-30), clockwise: false)
            ctx.stroke(arc, with: .color(Theme.line), lineWidth: 1)
            // 倒した範囲（扇形）
            func wedge(_ from: Double, _ to: Double, radius: CGFloat) -> Path {
                var p = Path()
                p.move(to: c)
                p.addArc(center: c, radius: radius, startAngle: .degrees(from - 90), endAngle: .degrees(to - 90), clockwise: false)
                p.closeSubpath()
                return p
            }
            let left = min(60, range.tiltLeft), right = min(60, range.tiltRight)
            ctx.fill(wedge(-left, right, radius: r * 0.86), with: .color(Theme.sky.opacity(0.45)))
            ctx.stroke(wedge(-left, right, radius: r * 0.86), with: .color(Theme.skyDeep.opacity(0.6)), lineWidth: 1)
            if let p = previous {
                let pl = min(60, p.tiltLeft), pr = min(60, p.tiltRight)
                ctx.stroke(wedge(-pl, pr, radius: r * 0.86), with: .color(Theme.peachDeep.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            // 向いた範囲（内側の細い弧）
            var turn = Path()
            turn.addArc(center: c, radius: r * 0.5, startAngle: .degrees(-min(80, range.turnLeft) - 90),
                        endAngle: .degrees(min(80, range.turnRight) - 90), clockwise: false)
            ctx.stroke(turn, with: .color(Theme.peachDeep.opacity(0.8)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(Theme.ink))
        }
        .accessibilityElement()
        .accessibilityLabel(Text("首の動いた範囲"))
        .accessibilityValue(Text(verbatim: "\(Int(range.tiltLeft))° / \(Int(range.tiltRight))°"))
    }
}

/// 今の首の向きを、線の顔で見せる（映像は見せない）
struct HeadDial: View {
    let pose: HeadPose

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) * 0.42
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * 1.1, y: c.y - r * 1.1, width: r * 2.2, height: r * 2.2)),
                       with: .color(Theme.line), lineWidth: 1)
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .degrees(pose.roll))
            let ox = CGFloat(pose.yaw / 45) * r * 0.45
            let oy = CGFloat(-pose.pitch / 30) * r * 0.4
            g.stroke(Path(ellipseIn: CGRect(x: -r * 0.8, y: -r, width: r * 1.6, height: r * 2)),
                     with: .color(Theme.ink.opacity(0.75)), lineWidth: 1.2)
            for dx in [-r * 0.3, r * 0.3] {
                g.fill(Path(ellipseIn: CGRect(x: dx + ox - 2.5, y: oy - r * 0.15 - 2.5, width: 5, height: 5)), with: .color(Theme.ink))
            }
            var nose = Path()
            nose.move(to: CGPoint(x: ox, y: oy))
            nose.addLine(to: CGPoint(x: ox * 1.2, y: oy + r * 0.22))
            g.stroke(nose, with: .color(Theme.ink.opacity(0.6)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// 動きの小さな絵（コースの一覧で並べる矢印）
struct MoveGlyph: View {
    let move: Move

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) * 0.4
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 0.45, width: r * 0.9, height: r * 0.9)),
                       with: .color(Theme.inkSoft), lineWidth: 1)
            let d = move.screenDirection
            var p = Path()
            let tip = CGPoint(x: c.x + d.x * r, y: c.y - d.y * r)
            p.move(to: CGPoint(x: c.x + d.x * r * 0.5, y: c.y - d.y * r * 0.5))
            p.addLine(to: tip)
            ctx.stroke(p, with: .color(Theme.skyDeep), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 2.5, y: tip.y - 2.5, width: 5, height: 5)), with: .color(Theme.peachDeep))
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
