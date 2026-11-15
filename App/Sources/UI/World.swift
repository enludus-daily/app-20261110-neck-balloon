import SwiftUI

// このアプリの世界：絵本の水彩の空。風船が自分の頭、水彩の雲の輪がストレッチの到達点、
// 空の時間帯（朝焼け・昼の青・夕暮れ・夜と星）がコース、首の動いた範囲は紙に描く分度器（扇形）。
// どれも自作の Shape / Canvas で描く。動き続ける絵は作らない（雲は場面ごとに少しずれるだけ）。

/// 決まった並びの乱数（毎回同じ絵になる）
struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}

/// 水彩の空：3 色のにじみ、地平線の光、太陽か月、水彩の雲、星、遠い丘、紙の目
struct SkyBackdrop: View, Equatable {
    let sky: SkyTime
    /// 0〜1：雲を横に少しずらす（場面ごとに違う空に見せる）
    var drift: Double = 0
    /// 小さな窓（コースのタイル）では、丘と紙の目を省く
    var mini = false
    var hills = true

    var body: some View {
        Canvas { ctx, size in
            Self.paint(&ctx, size: size, sky: sky, drift: drift, mini: mini, hills: hills)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    static func paint(_ ctx: inout GraphicsContext, size: CGSize, sky: SkyTime, drift: Double, mini: Bool, hills: Bool) {
        let p = Theme.palette(sky)
        let w = size.width, h = size.height
        let full = CGRect(origin: .zero, size: size)
        // 1. 空の 3 色
        ctx.fill(Path(full), with: .linearGradient(Gradient(stops: [
            .init(color: p.top, location: 0), .init(color: p.mid, location: 0.55), .init(color: p.bottom, location: 1),
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        // 2. 地平線の光（にじんだ大きな楕円）
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: max(w, h) * 0.08))
            l.fill(Path(ellipseIn: CGRect(x: -w * 0.2, y: h * 0.72, width: w * 1.4, height: h * 0.5)), with: .color(p.glow.opacity(sky == .night ? 0.35 : 0.6)))
        }
        // 3. 水彩のむら（色の濃い所と薄い所。紙に水で広げた感じ）
        var rnd = SeededRandom(UInt64(sky.hashSeed))
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: max(w, h) * 0.06))
            for _ in 0..<(mini ? 3 : 6) {
                let x = rnd.next() * w, y = rnd.next() * h * 0.8, r = (0.18 + rnd.next() * 0.25) * max(w, h)
                let c = rnd.next() > 0.5 ? p.top : p.mid
                l.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.5, width: r * 2, height: r)), with: .color(c.opacity(0.18)))
            }
        }
        // 4. 星（夜はたくさん、夕暮れと朝焼けは上のほうに少し）
        if p.stars > 0 {
            var sr = SeededRandom(97)
            let count = Int(Double(mini ? 18 : 70) * p.stars)
            for i in 0..<count {
                let x = sr.next() * w, y = sr.next() * h * (sky == .night ? 0.75 : 0.35)
                let big = i % 9 == 0
                let r: CGFloat = big ? 1.8 : 0.6 + sr.next() * 0.9
                let o = (0.45 + sr.next() * 0.55) * (sky == .night ? 1 : 0.7)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(o)))
                if big, !mini {
                    var s = Path()
                    s.move(to: CGPoint(x: x - 5, y: y)); s.addLine(to: CGPoint(x: x + 5, y: y))
                    s.move(to: CGPoint(x: x, y: y - 5)); s.addLine(to: CGPoint(x: x, y: y + 5))
                    ctx.stroke(s, with: .color(.white.opacity(o * 0.5)), lineWidth: 0.6)
                }
            }
        }
        // 5. 太陽か月
        let unit = min(w, h)
        switch sky {
        case .dawn: sun(&ctx, c: CGPoint(x: w * 0.3, y: h * 0.84), r: unit * 0.16, color: p.sun, glow: p.glow)
        case .noon: sun(&ctx, c: CGPoint(x: w * 0.82, y: h * 0.12), r: unit * 0.08, color: p.sun, glow: .white)
        case .dusk: sun(&ctx, c: CGPoint(x: w * 0.7, y: h * 0.8), r: unit * 0.18, color: p.sun, glow: p.glow)
        case .night: moon(&ctx, c: CGPoint(x: w * 0.8, y: h * 0.13), r: unit * 0.075, color: p.sun)
        }
        // 6. 水彩の雲（固定の並び。drift で横に少しずれる）
        let clouds: [(x: Double, y: Double, s: Double)] = mini
            ? [(0.2, 0.3, 1.1), (0.8, 0.62, 0.9)]
            : [(0.1, 0.17, 1.0), (0.74, 0.26, 0.8), (0.42, 0.46, 0.62), (0.16, 0.62, 0.85), (0.86, 0.66, 1.0)]
        for (i, c) in clouds.enumerated() {
            let cw = w * (mini ? 0.5 : 0.42) * c.s
            let span = 1.3
            let x = ((c.x + drift * 0.12 * c.s + 0.15).truncatingRemainder(dividingBy: span) - 0.15) * w
            cloud(&ctx, at: CGPoint(x: x, y: c.y * h), width: cw, palette: p, seed: i, night: sky == .night)
        }
        // 7. 遠い丘（2 層、にじんだ縁）
        if hills, !mini {
            hill(&ctx, size: size, base: 0.9, amp: 0.035, freq: 1.3, phase: 0.8, color: p.hillFar.opacity(0.75))
            hill(&ctx, size: size, base: 0.95, amp: 0.03, freq: 2.1, phase: 2.4, color: p.hillNear.opacity(0.85))
        }
        // 8. 紙の目（ごく薄い点）
        if !mini {
            var g = SeededRandom(7)
            let n = Int(w * h / 900)
            for i in 0..<n {
                let x = g.next() * w, y = g.next() * h
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(i % 2 == 0 ? Color.white.opacity(0.07) : Color.black.opacity(0.04)))
            }
        }
    }

    private static func sun(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, color: Color, glow: Color) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: r * 0.9))
            l.fill(Path(ellipseIn: CGRect(x: c.x - r * 2, y: c.y - r * 2, width: r * 4, height: r * 4)), with: .color(glow.opacity(0.55)))
        }
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: r * 0.06))
            l.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(0.95)))
        }
    }

    private static func moon(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, color: Color) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: r * 1.2))
            l.fill(Path(ellipseIn: CGRect(x: c.x - r * 2.4, y: c.y - r * 2.4, width: r * 4.8, height: r * 4.8)), with: .color(color.opacity(0.18)))
        }
        // 三日月：大きな円から、ずらした円を抜く
        var m = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        m = m.subtracting(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 1.2, width: r * 2, height: r * 2)))
        ctx.fill(m, with: .color(color))
    }

    /// 雲：やわらかい丸を重ね、にじませる。下に絵の具がたまり、縁が少し濃くなる
    static func cloud(_ ctx: inout GraphicsContext, at o: CGPoint, width cw: CGFloat, palette p: SkyPalette, seed: Int, night: Bool) {
        let puffs: [(Double, Double, Double)] = [(-0.32, 0.06, 0.2), (-0.12, -0.08, 0.27), (0.12, -0.12, 0.3), (0.34, 0.04, 0.21), (0.0, 0.1, 0.26)]
        var body = Path()
        for (k, (dx, dy, r)) in puffs.enumerated() {
            let wob = 1 + 0.08 * sin(Double(seed * 5 + k))
            let rr = cw * r * wob
            body.addEllipse(in: CGRect(x: o.x + cw * dx - rr, y: o.y + cw * dy - rr * 0.85, width: rr * 2, height: rr * 1.7))
        }
        let alpha = night ? 0.4 : 0.85
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: cw * 0.035))
            l.fill(body, with: .color(p.cloud.opacity(alpha)))
        }
        // 下にたまる影
        ctx.drawLayer { l in
            l.clip(to: body)
            l.addFilter(.blur(radius: cw * 0.06))
            l.fill(Path(ellipseIn: CGRect(x: o.x - cw * 0.45, y: o.y + cw * 0.08, width: cw * 0.9, height: cw * 0.28)),
                   with: .color(p.cloudShade.opacity(night ? 0.5 : 0.45)))
        }
        // 縁のにじみ（水彩の乾いた縁）
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: cw * 0.01))
            l.stroke(body, with: .color(p.cloudShade.opacity(night ? 0.18 : 0.14)), lineWidth: 1.2)
        }
    }

    private static func hill(_ ctx: inout GraphicsContext, size: CGSize, base: Double, amp: Double, freq: Double, phase: Double, color: Color) {
        let w = size.width, h = size.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        let steps = 40
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let y = (base - amp * (sin(t * .pi * freq + phase) * 0.7 + sin(t * .pi * freq * 2.7 + phase) * 0.3)) * h
            p.addLine(to: CGPoint(x: t * w, y: y))
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 1.2))
            l.fill(p, with: .color(color))
        }
    }
}

extension SkyTime {
    var hashSeed: Int {
        switch self {
        case .dawn: 11
        case .noon: 23
        case .dusk: 37
        case .night: 53
        }
    }
}

/// 風船（自分の頭）。絵本のやわらかい絵：水彩の朱、にじんだ光、手で描いた線、ねむった顔。tilt で傾く
struct Balloon: View {
    var tilt: Angle = .zero
    /// 0〜1：輪の中で保っている間、ほおが色づき、顔がほころぶ
    var glow: Double = 0
    var showString = true

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, geo.size.height / 1.45)
            Canvas { ctx, size in
                Self.draw(&ctx, size: size, w: w, glow: glow, showString: showString)
            }
            .rotationEffect(tilt, anchor: UnitPoint(x: 0.5, y: 0.35))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1 / 1.45, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// 風船の形：上が丸く、下がすぼまる（しずくを逆さにした形）
    static func shape(cx: CGFloat, w: CGFloat) -> Path {
        let bw = w * 0.88, bh = w * 1.0
        var p = Path()
        let top = CGPoint(x: cx, y: 0)
        let bottom = CGPoint(x: cx, y: bh)
        p.move(to: bottom)
        p.addCurve(to: CGPoint(x: cx - bw / 2, y: bh * 0.42),
                   control1: CGPoint(x: cx - bw * 0.2, y: bh * 0.96), control2: CGPoint(x: cx - bw / 2, y: bh * 0.72))
        p.addCurve(to: top, control1: CGPoint(x: cx - bw / 2, y: bh * 0.15), control2: CGPoint(x: cx - bw * 0.28, y: 0))
        p.addCurve(to: CGPoint(x: cx + bw / 2, y: bh * 0.42), control1: CGPoint(x: cx + bw * 0.28, y: 0), control2: CGPoint(x: cx + bw / 2, y: bh * 0.15))
        p.addCurve(to: bottom, control1: CGPoint(x: cx + bw / 2, y: bh * 0.72), control2: CGPoint(x: cx + bw * 0.2, y: bh * 0.96))
        p.closeSubpath()
        return p
    }

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, w: CGFloat, glow: Double, showString: Bool) {
        let cx = size.width / 2
        let bw = w * 0.88, bh = w * 1.0
        let body = shape(cx: cx, w: w)
        let lw = max(1.2, w * 0.022)
        // ひも（ゆるい S 字、手描きの細い線）
        if showString {
            var s = Path()
            s.move(to: CGPoint(x: cx, y: bh + w * 0.07))
            s.addCurve(to: CGPoint(x: cx - w * 0.02, y: size.height),
                       control1: CGPoint(x: cx + w * 0.16, y: bh + w * 0.22),
                       control2: CGPoint(x: cx - w * 0.16, y: size.height - w * 0.14))
            ctx.stroke(s, with: .color(Color(hex: 0x5E4F72).opacity(0.75)), style: StrokeStyle(lineWidth: max(1, w * 0.014), lineCap: .round))
        }
        // 結び目（小さな三角とふくらみ）
        var knot = Path()
        knot.move(to: CGPoint(x: cx - w * 0.055, y: bh + w * 0.075))
        knot.addQuadCurve(to: CGPoint(x: cx + w * 0.055, y: bh + w * 0.075), control: CGPoint(x: cx, y: bh + w * 0.11))
        knot.addLine(to: CGPoint(x: cx, y: bh - w * 0.01))
        knot.closeSubpath()
        ctx.fill(knot, with: .color(Theme.balloonDeep))
        ctx.stroke(knot, with: .color(Theme.balloonLine.opacity(0.7)), style: StrokeStyle(lineWidth: lw * 0.7, lineJoin: .round))
        // 本体：水彩の朱（中は明るく、縁に色がたまる）
        ctx.fill(body, with: .radialGradient(Gradient(colors: [Theme.balloonLight, Theme.balloon, Theme.balloonDeep]),
                                              center: CGPoint(x: cx - bw * 0.15, y: bh * 0.32), startRadius: 0, endRadius: bw * 0.78))
        ctx.drawLayer { l in
            l.clip(to: body)
            l.addFilter(.blur(radius: w * 0.04))
            l.stroke(body, with: .color(Theme.balloonLine.opacity(0.45)), lineWidth: w * 0.08)
        }
        // 光：にじんだ大きな光と、小さなはっきりした光
        ctx.drawLayer { l in
            l.clip(to: body)
            l.addFilter(.blur(radius: w * 0.05))
            l.fill(Path(ellipseIn: CGRect(x: cx - bw * 0.36, y: bh * 0.1, width: bw * 0.34, height: bh * 0.28)), with: .color(.white.opacity(0.55)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: cx - bw * 0.27, y: bh * 0.16, width: bw * 0.1, height: bh * 0.07)), with: .color(.white.opacity(0.9)))
        // 手描きの輪郭（少しずらして 2 回なぞる）
        ctx.stroke(body, with: .color(Theme.balloonLine.opacity(0.75)), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
        var off = ctx
        off.translateBy(x: w * 0.008, y: -w * 0.006)
        off.stroke(body, with: .color(Theme.balloonLine.opacity(0.25)), style: StrokeStyle(lineWidth: lw * 0.6, lineJoin: .round))
        // 顔：ねむった目（下向きの弧）、小さな口。保っている間はほほえむ
        let eyeY = bh * 0.5
        let eye = Color(hex: 0x3B2A3E)
        for dx in [-bw * 0.16, bw * 0.16] {
            var e = Path()
            e.addArc(center: CGPoint(x: cx + dx, y: eyeY - bw * 0.02), radius: bw * 0.06,
                     startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
            ctx.stroke(e, with: .color(eye.opacity(0.85)), style: StrokeStyle(lineWidth: lw * 1.1, lineCap: .round))
        }
        var m = Path()
        let smile = 0.03 + 0.02 * glow
        m.addArc(center: CGPoint(x: cx, y: eyeY + bh * 0.085), radius: bw * smile,
                 startAngle: .degrees(15), endAngle: .degrees(165), clockwise: false)
        ctx.stroke(m, with: .color(eye.opacity(0.7)), style: StrokeStyle(lineWidth: lw * 0.9, lineCap: .round))
        // ほお（にじんだ丸）
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: w * 0.02))
            for dx in [-bw * 0.28, bw * 0.28] {
                let r = bw * 0.075
                l.fill(Path(ellipseIn: CGRect(x: cx + dx - r, y: eyeY + bh * 0.03, width: r * 2, height: r * 1.3)),
                       with: .color(Color(hex: 0xE2486A).opacity(0.25 + 0.35 * glow)))
            }
        }
    }
}

/// 水彩の雲の輪（ストレッチの到達点）。fill（0〜1）で金の線が満ちていく
struct CloudRing: View {
    @Environment(\.skyTime) private var sky
    var fill: Double = 0
    var active = true

    var body: some View {
        let p = Theme.palette(sky)
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = d * 0.36
                    // 雲のつぶを輪に並べる（固定の並びで、毎回同じ形）
                    var ring = Path()
                    let puffs = 13
                    for i in 0..<puffs {
                        let a = Double(i) / Double(puffs) * 2 * .pi - .pi / 2
                        let pr = d * (i % 3 == 0 ? 0.11 : i % 3 == 1 ? 0.088 : 0.098)
                        let q = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                        ring.addEllipse(in: CGRect(x: q.x - pr, y: q.y - pr * 0.9, width: pr * 2, height: pr * 1.8))
                    }
                    let night = sky == .night
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: d * 0.012))
                        l.fill(ring, with: .color((night ? Color(hex: 0xC9CBEF) : p.cloud).opacity(active ? 0.95 : 0.55)))
                    }
                    // 下側に絵の具がたまる
                    ctx.drawLayer { l in
                        l.clip(to: ring)
                        l.addFilter(.blur(radius: d * 0.04))
                        for i in 0..<puffs {
                            let a = Double(i) / Double(puffs) * 2 * .pi - .pi / 2
                            let q = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r + d * 0.06)
                            let pr = d * 0.07
                            l.fill(Path(ellipseIn: CGRect(x: q.x - pr, y: q.y - pr * 0.5, width: pr * 2, height: pr)),
                                   with: .color(p.cloudShade.opacity(active ? 0.45 : 0.25)))
                        }
                    }
                    ctx.stroke(ring, with: .color(p.cloudShade.opacity(active ? 0.25 : 0.12)), lineWidth: 1)
                }
                // 満ちる線（金。にじんだ光をうしろに）
                Circle()
                    .trim(from: 0, to: max(0, min(1, fill)))
                    .stroke(Theme.gold.opacity(0.7), style: StrokeStyle(lineWidth: max(4, d * 0.05), lineCap: .round))
                    .blur(radius: d * 0.02)
                    .rotationEffect(.degrees(-90))
                    .frame(width: d * 0.72, height: d * 0.72)
                Circle()
                    .trim(from: 0, to: max(0, min(1, fill)))
                    .stroke(Theme.gold, style: StrokeStyle(lineWidth: max(2.5, d * 0.024), lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: d * 0.72, height: d * 0.72)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// 首の動いた範囲の分度器（紙の上に描く）。左右に倒した角度を水彩の扇形で、向いた範囲を金の弧で
struct RangeFan: View {
    @Environment(\.skyTime) private var sky
    let range: NeckRange
    /// 比べる範囲（前の週など。朱の点線で）
    var previous: NeckRange?
    /// 空の上に直に描く（共有カード）
    var onSky = false

    var body: some View {
        let p = Theme.palette(sky)
        let ink = onSky ? Color.white : Theme.ink
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height * 0.92)
            let r = min(size.width / 2, size.height * 0.9) * 0.95
            // 目盛り（15° ごと）
            for deg in stride(from: -60.0, through: 60.0, by: 15) {
                let a = (deg - 90) * .pi / 180
                var t = Path()
                t.move(to: CGPoint(x: c.x + cos(a) * r * (deg == 0 ? 0.86 : 0.92), y: c.y + sin(a) * r * (deg == 0 ? 0.86 : 0.92)))
                t.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                ctx.stroke(t, with: .color(ink.opacity(deg == 0 ? 0.6 : 0.3)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(-150), endAngle: .degrees(-30), clockwise: false)
            ctx.stroke(arc, with: .color(ink.opacity(0.25)), lineWidth: 1)
            func wedge(_ from: Double, _ to: Double, radius: CGFloat) -> Path {
                var path = Path()
                path.move(to: c)
                path.addArc(center: c, radius: radius, startAngle: .degrees(from - 90), endAngle: .degrees(to - 90), clockwise: false)
                path.closeSubpath()
                return path
            }
            let left = min(60, range.tiltLeft), right = min(60, range.tiltRight)
            let fan = wedge(-left, right, radius: r * 0.84)
            // 水彩の扇：中は薄く、縁に色がたまる
            ctx.fill(fan, with: .radialGradient(Gradient(colors: [p.wash.opacity(0.25), p.wash.opacity(0.6)]),
                                                 center: c, startRadius: 0, endRadius: r * 0.84))
            ctx.drawLayer { l in
                l.clip(to: fan)
                l.addFilter(.blur(radius: 2))
                l.stroke(fan, with: .color(p.washDeep.opacity(0.55)), lineWidth: 3)
            }
            if let prev = previous {
                let pl = min(60, prev.tiltLeft), pr = min(60, prev.tiltRight)
                ctx.stroke(wedge(-pl, pr, radius: r * 0.84), with: .color(Theme.balloonDeep.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 4]))
            }
            // 向いた範囲（内側の金の弧）
            var turn = Path()
            turn.addArc(center: c, radius: r * 0.5, startAngle: .degrees(-min(80, range.turnLeft) - 90),
                        endAngle: .degrees(min(80, range.turnRight) - 90), clockwise: false)
            ctx.stroke(turn, with: .color(onSky ? Theme.gold : Theme.goldDeep), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(Theme.balloonDeep))
        }
        .accessibilityElement()
        .accessibilityLabel(Text("首の動いた範囲"))
        .accessibilityValue(Text(verbatim: "\(Int(range.tiltLeft))° / \(Int(range.tiltRight))°"))
    }
}

/// 今の首の向きを、絵本の顔で見せる（映像は見せない）
struct HeadDial: View {
    @Environment(\.skyTime) private var sky
    let pose: HeadPose

    var body: some View {
        let p = Theme.palette(sky)
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) * 0.42
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.15, y: c.y - r * 1.15, width: r * 2.3, height: r * 2.3)), with: .color(p.washSoft))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r * 1.15, y: c.y - r * 1.15, width: r * 2.3, height: r * 2.3)),
                       with: .color(p.wash.opacity(0.6)), lineWidth: 1)
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .degrees(pose.roll))
            let ox = CGFloat(pose.yaw / 45) * r * 0.45
            let oy = CGFloat(-pose.pitch / 30) * r * 0.4
            let face = Path(ellipseIn: CGRect(x: -r * 0.8, y: -r, width: r * 1.6, height: r * 2))
            g.fill(face, with: .color(Theme.balloonLight))
            g.stroke(face, with: .color(Theme.balloonLine.opacity(0.7)), lineWidth: 1.4)
            for dx in [-r * 0.3, r * 0.3] {
                g.fill(Path(ellipseIn: CGRect(x: dx + ox - 3, y: oy - r * 0.15 - 3, width: 6, height: 6)), with: .color(Theme.ink))
            }
            var nose = Path()
            nose.move(to: CGPoint(x: ox, y: oy))
            nose.addLine(to: CGPoint(x: ox * 1.2, y: oy + r * 0.22))
            g.stroke(nose, with: .color(Theme.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// 動きの小さな絵（紙の上で並べる矢印）
struct MoveGlyph: View {
    @Environment(\.skyTime) private var sky
    let move: Move

    var body: some View {
        let p = Theme.palette(sky)
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) * 0.42
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.15, y: c.y - r * 1.15, width: r * 2.3, height: r * 2.3)), with: .color(p.washSoft))
            let d = move.screenDirection
            var path = Path()
            let tip = CGPoint(x: c.x + d.x * r * 0.85, y: c.y - d.y * r * 0.85)
            path.move(to: CGPoint(x: c.x - d.x * r * 0.4, y: c.y + d.y * r * 0.4))
            path.addLine(to: tip)
            ctx.stroke(path, with: .color(p.washDeep), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 3, y: tip.y - 3, width: 6, height: 6)), with: .color(Theme.balloonDeep))
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
