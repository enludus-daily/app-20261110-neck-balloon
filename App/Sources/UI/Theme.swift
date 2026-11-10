import SwiftUI

/// 色・書体・形を 1 か所で決める（StudyReel のトーン：淡い sky の 1 系統＋peach の差し色）
enum Theme {
    // 地・文字・線
    static let ground = Color(hex: 0xF3F6F9)
    static let paper = Color(hex: 0xF8FAFC)
    static let ink = Color(hex: 0x2E3A46)
    static let inkSoft = Color(hex: 0x8E9AA6)
    static let line = Color(hex: 0xE3E9EF)

    // sky（主）：accent / soft / deep / mist
    static let sky = Color(hex: 0x9EC3E2)
    static let skySoft = Color(hex: 0xE1EDF6)
    static let skyDeep = Color(hex: 0x5E8DB8)
    static let skyMist = Color(hex: 0xEEF4FA)

    // peach（差し色：風船・満ちる輪・よかった印）
    static let peach = Color(hex: 0xF4BBA4)
    static let peachSoft = Color(hex: 0xFBE7DE)
    static let peachDeep = Color(hex: 0xC98468)

    // 空の時間帯（上 → 下）。どれも淡いまま、明るさと peach の混ざり方だけ変える
    static let dawnTop = Color(hex: 0xEEF4FA)
    static let dawnBottom = Color(hex: 0xFCEBE3)
    static let noonTop = Color(hex: 0xDCEAF5)
    static let noonBottom = Color(hex: 0xF5F8FB)
    static let duskTop = Color(hex: 0xDDE6F1)
    static let duskBottom = Color(hex: 0xF9DED2)
    static let nightTop = Color(hex: 0xCFDCEA)
    static let nightBottom = Color(hex: 0xE4E6F1)

    static func sky(_ t: SkyTime) -> LinearGradient {
        let (a, b): (Color, Color) = switch t {
        case .dawn: (dawnTop, dawnBottom)
        case .noon: (noonTop, noonBottom)
        case .dusk: (duskTop, duskBottom)
        case .night: (nightTop, nightBottom)
        }
        return LinearGradient(colors: [a, b], startPoint: .top, endPoint: .bottom)
    }

    // 書体：見出しと数字はセリフ、本文はサンセリフ。Dynamic Type に追従する
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .title) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // 形
    static let rLarge: CGFloat = 28
    static let rMedium: CGFloat = 18
    static let rSmall: CGFloat = 12
    static let hairline: CGFloat = 0.6

    static let shadow = Color(hex: 0x2E3A46).opacity(0.07)
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

/// 小さな見出し（字間を開けた大文字のラベル）
struct Caption: View {
    let key: LocalizedStringKey
    var color: Color = Theme.inkSoft

    init(_ key: LocalizedStringKey, color: Color = Theme.inkSoft) {
        self.key = key
        self.color = color
    }

    var body: some View {
        Text(key)
            .font(Theme.text(11, .medium))
            .kerning(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// 主なボタン：深い sky のカプセル（白い文字）
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(16, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(Theme.skyDeep))
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1).padding(2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 静かなボタン：細い線のカプセル
struct LineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(15, .medium))
            .foregroundStyle(Theme.skyDeep)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Theme.paper.opacity(0.7)))
            .overlay(Capsule().stroke(Theme.sky, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 雲の形のパネル（白い紙ではなく、すりガラスの雲。下辺に細い影の線）
struct CloudPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.rMedium, style: .continuous)
                    .fill(.white.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rMedium, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Theme.shadow, radius: 10, y: 4)
    }
}
