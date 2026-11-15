import SwiftUI

// このアプリの世界：絵本の水彩の空。空の時間帯（朝焼け・昼の青・夕暮れ・夜と星）で、画面全体の色が大きく変わる。
// 文字と数字は丸い書体（絵本の字）。中身は空に置いた「水彩紙」の上に、藍のインクで書く。
// 色の段階は空ごとに 1 組（SkyPalette）。紙・インク・風船の色だけは、どの空でも同じ。

/// 1 つの空の色の組（上 → まんなか → 地平線、雲、雲の影、空の上の文字、紙の上の洗い色）
struct SkyPalette {
    let top: Color
    let mid: Color
    let bottom: Color
    /// 地平線の光（日の出・夕陽のにじみ）
    let glow: Color
    let cloud: Color
    /// 雲の下にたまる絵の具の色
    let cloudShade: Color
    /// 遠い丘（2 層）
    let hillFar: Color
    let hillNear: Color
    /// 太陽・月の色
    let sun: Color
    /// 空の上に直に置く文字
    let onSky: Color
    let onSkySoft: Color
    /// 紙の上で、この空の色として使う（分度器の扇・暦の濃さ・矢印）
    let wash: Color
    let washDeep: Color
    let washSoft: Color
    /// 紙の色（夜は月明かりで少し青い）
    let paper: Color
    let stars: Double
}

enum Theme {
    // 紙とインク（どの空でも同じ）
    static let paper = Color(hex: 0xFBF4E8)
    static let paperEdge = Color(hex: 0xD8C3A2)
    static let ink = Color(hex: 0x2B2948)
    static let inkSoft = Color(hex: 0x7C7690)
    static let line = Color(hex: 0xE8DCC8)

    // 風船（絵本の朱。主役なので、どの空でも同じ）
    static let balloon = Color(hex: 0xF08B72)
    static let balloonDeep = Color(hex: 0xD45F4C)
    static let balloonLight = Color(hex: 0xFFD8C6)
    static let balloonLine = Color(hex: 0xA94C3E)

    // 金（満ちる輪・太陽・よかった印）
    static let gold = Color(hex: 0xF7CB72)
    static let goldDeep = Color(hex: 0xC98A2E)

    static func palette(_ t: SkyTime) -> SkyPalette {
        switch t {
        case .dawn:
            SkyPalette(top: Color(hex: 0x434E88), mid: Color(hex: 0xD48BA2), bottom: Color(hex: 0xF8C28A),
                       glow: Color(hex: 0xFFE3B3), cloud: Color(hex: 0xFFEADF), cloudShade: Color(hex: 0xE09AAE),
                       hillFar: Color(hex: 0xB7839F), hillNear: Color(hex: 0x7D6191), sun: Color(hex: 0xFFD98F),
                       onSky: .white, onSkySoft: .white.opacity(0.8),
                       wash: Color(hex: 0xE59A86), washDeep: Color(hex: 0xA8566A), washSoft: Color(hex: 0xF8DCCD),
                       paper: paper, stars: 0.25)
        case .noon:
            SkyPalette(top: Color(hex: 0x3A78C6), mid: Color(hex: 0x76AFE2), bottom: Color(hex: 0xD3EAF7),
                       glow: Color(hex: 0xF6FCFF), cloud: .white, cloudShade: Color(hex: 0xAFCBEA),
                       hillFar: Color(hex: 0x9CC7B4), hillNear: Color(hex: 0x6FA48D), sun: Color(hex: 0xFFF1C2),
                       onSky: .white, onSkySoft: .white.opacity(0.82),
                       wash: Color(hex: 0x7FB0DE), washDeep: Color(hex: 0x2F69AE), washSoft: Color(hex: 0xDCEBF7),
                       paper: paper, stars: 0)
        case .dusk:
            SkyPalette(top: Color(hex: 0x2B285F), mid: Color(hex: 0x7A4E93), bottom: Color(hex: 0xEE9388),
                       glow: Color(hex: 0xFFC59E), cloud: Color(hex: 0xF5C3CF), cloudShade: Color(hex: 0x8F61A3),
                       hillFar: Color(hex: 0x6B4A86), hillNear: Color(hex: 0x3F3166), sun: Color(hex: 0xFFB185),
                       onSky: .white, onSkySoft: .white.opacity(0.8),
                       wash: Color(hex: 0xA987C4), washDeep: Color(hex: 0x5E3E8A), washSoft: Color(hex: 0xECE0F4),
                       paper: paper, stars: 0.45)
        case .night:
            SkyPalette(top: Color(hex: 0x0D1334), mid: Color(hex: 0x1C275E), bottom: Color(hex: 0x3B4285),
                       glow: Color(hex: 0x6C6AAE), cloud: Color(hex: 0x8D90C8), cloudShade: Color(hex: 0x262C66),
                       hillFar: Color(hex: 0x242A5E), hillNear: Color(hex: 0x141938), sun: Color(hex: 0xFFF3CF),
                       onSky: .white, onSkySoft: .white.opacity(0.78),
                       wash: Color(hex: 0x7F86C9), washDeep: Color(hex: 0x2D3680), washSoft: Color(hex: 0xE2E4F4),
                       paper: Color(hex: 0xF3EEF2), stars: 1)
        }
    }

    /// 絵本の丸い字（見出し・数字）。本文も丸い字の細め
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // 形（紙は角が大きくやわらかい）
    static let rLarge: CGFloat = 30
    static let rMedium: CGFloat = 22
    static let rSmall: CGFloat = 14
    static let hairline: CGFloat = 0.8
}

// MARK: いまの空（画面ごとに環境で渡す）

private struct SkyTimeKey: EnvironmentKey {
    static let defaultValue: SkyTime = .dusk
}

extension EnvironmentValues {
    var skyTime: SkyTime {
        get { self[SkyTimeKey.self] }
        set { self[SkyTimeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// 小さな見出し（丸い字、少し字間）。空の上では白、紙の上ではこの空の濃い洗い色
struct Caption: View {
    @Environment(\.skyTime) private var sky
    let key: LocalizedStringKey
    var onSky: Bool

    init(_ key: LocalizedStringKey, onSky: Bool = false) {
        self.key = key
        self.onSky = onSky
    }

    var body: some View {
        Text(key)
            .font(Theme.text(12, .bold))
            .kerning(0.6)
            .foregroundStyle(onSky ? Theme.palette(sky).onSkySoft : Theme.palette(sky).washDeep)
    }
}

/// 空の上に直に置く文字の影（明るい空の地平線でも読めるように、空の濃い色で薄くにじませる）
extension View {
    func onSkyText(_ sky: SkyTime) -> some View {
        shadow(color: Theme.palette(sky).top.opacity(0.45), radius: 6, y: 1)
    }
}

/// 主なボタン：風船の朱の、ふくらんだカプセル（上に光、下に濃い縁）
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                ZStack {
                    Capsule().fill(Theme.balloonDeep)
                    Capsule().fill(LinearGradient(colors: [Theme.balloon, Theme.balloonDeep], startPoint: .top, endPoint: .bottom))
                        .padding(.bottom, 3)
                    Capsule().fill(.white.opacity(0.28)).frame(height: 10).padding(.horizontal, 22)
                        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 6)
                        .blur(radius: 2)
                }
            )
            .shadow(color: Theme.balloonLine.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// 静かなボタン：空の上では白い線のカプセル、紙の上ではインクの線
struct LineButtonStyle: ButtonStyle {
    var onPaper = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(15, .semibold))
            .foregroundStyle(onPaper ? Theme.ink : .white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Capsule().fill(onPaper ? Theme.line.opacity(0.5) : .white.opacity(0.16)))
            .overlay(Capsule().stroke(onPaper ? Theme.paperEdge : .white.opacity(0.7), lineWidth: 1.2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 水彩紙のふち：角の丸い四角の辺を、ほんの少しだけ波打たせる（筆で塗った紙の縁）
struct WashShape: Shape {
    var seed: Double = 0
    var radius: CGFloat = Theme.rMedium
    var wobble: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        // 角丸の四角を、辺と角の弧に分けて点でたどり、外向きに小さく波打たせる
        let straightW = rect.width - 2 * r, straightH = rect.height - 2 * r
        let arc = CGFloat.pi / 2 * r
        let total = 2 * (straightW + straightH) + 4 * arc
        let steps = max(64, Int(total / 5))
        var path = Path()
        for i in 0...steps {
            let s = CGFloat(i) / CGFloat(steps) * total
            let (p, n) = Self.point(s, rect: rect, r: r, sw: straightW, sh: straightH, arc: arc)
            let t = Double(s / total)
            let w = wobble * CGFloat(sin(t * 2 * .pi * 7 + seed) * 0.6 + sin(t * 2 * .pi * 17 + seed * 2.3) * 0.4)
            let q = CGPoint(x: p.x + n.dx * w, y: p.y + n.dy * w)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }

    /// 周の長さ s の位置と、外向きの向き（上の辺の左端から時計回り）
    private static func point(_ s0: CGFloat, rect: CGRect, r: CGFloat, sw: CGFloat, sh: CGFloat, arc: CGFloat) -> (CGPoint, CGVector) {
        var s = s0
        func corner(_ c: CGPoint, _ start: CGFloat, _ s: CGFloat) -> (CGPoint, CGVector) {
            let a = start + (s / max(arc, 0.001)) * .pi / 2
            return (CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r), CGVector(dx: cos(a), dy: sin(a)))
        }
        if s <= sw { return (CGPoint(x: rect.minX + r + s, y: rect.minY), CGVector(dx: 0, dy: -1)) }
        s -= sw
        if s <= arc { return corner(CGPoint(x: rect.maxX - r, y: rect.minY + r), -.pi / 2, s) }
        s -= arc
        if s <= sh { return (CGPoint(x: rect.maxX, y: rect.minY + r + s), CGVector(dx: 1, dy: 0)) }
        s -= sh
        if s <= arc { return corner(CGPoint(x: rect.maxX - r, y: rect.maxY - r), 0, s) }
        s -= arc
        if s <= sw { return (CGPoint(x: rect.maxX - r - s, y: rect.maxY), CGVector(dx: 0, dy: 1)) }
        s -= sw
        if s <= arc { return corner(CGPoint(x: rect.minX + r, y: rect.maxY - r), .pi / 2, s) }
        s -= arc
        if s <= sh { return (CGPoint(x: rect.minX, y: rect.maxY - r - s), CGVector(dx: -1, dy: 0)) }
        s -= sh
        return corner(CGPoint(x: rect.minX + r, y: rect.minY + r), .pi, min(s, arc))
    }
}

/// 水彩紙のパネル（空の上に置く紙。縁に絵の具が少したまる）
struct PaperPanel<Content: View>: View {
    var seed: Double = 1
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PaperBack(seed: seed, radius: Theme.rMedium))
    }
}

/// 紙の地（パネル・タイル・案内の下に敷く）
struct PaperBack: View {
    @Environment(\.skyTime) private var sky
    var seed: Double = 1
    var radius: CGFloat = Theme.rMedium

    var body: some View {
        let p = Theme.palette(sky)
        ZStack {
            WashShape(seed: seed, radius: radius).fill(p.paper)
            // 縁にたまる絵の具（空の洗い色を、ごく薄く）
            WashShape(seed: seed, radius: radius)
                .stroke(p.wash.opacity(0.35), lineWidth: 3)
                .blur(radius: 2.5)
                .clipShape(WashShape(seed: seed, radius: radius))
            WashShape(seed: seed + 0.7, radius: radius)
                .stroke(Theme.paperEdge.opacity(0.55), lineWidth: 0.8)
        }
        .compositingGroup()
        .shadow(color: p.top.opacity(0.28), radius: 14, y: 6)
    }
}

/// シートの上の帯：空の上に白い題名と「閉じる」。帯の地は透明（空がそのまま続く）
extension View {
    func skySheetChrome(title: LocalizedStringKey, sky: SkyTime, close: @escaping () -> Void) -> some View {
        navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: close) { Text("閉じる").font(Theme.text(16, .bold)) }
                        .tint(.white)
                }
            }
    }
}
