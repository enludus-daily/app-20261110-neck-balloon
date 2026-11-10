import Foundation

/// 日本語と英語の 2 つを持つ文（手で用意したデータ用。画面の部品の文字は String Catalog）
struct Phrase: Equatable, Sendable {
    let ja: String
    let en: String

    init(_ ja: String, _ en: String) { self.ja = ja; self.en = en }

    func text(_ locale: Locale) -> String { locale.isJapanese ? ja : en }
}

extension Locale {
    var isJapanese: Bool { language.languageCode?.identifier == "ja" }
}

/// 動かす角度の大きさ（小さめから始める。設定で変えられる）
enum AngleSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    var scale: Double {
        switch self {
        case .small: 1.0
        case .medium: 1.3
        case .large: 1.6
        }
    }
}

/// 1 つのストレッチの動き
enum Move: String, Codable, CaseIterable, Sendable {
    case tiltRight, tiltLeft, chinDown, lookUp, turnRight, turnLeft
    case downRight, downLeft, upRight, upLeft
    // ゆっくり回す（8 か所の輪を順にくぐる）の 1 か所ずつ
    case arc0, arc1, arc2, arc3, arc4, arc5, arc6, arc7

    /// 小さめのときの到達点（度）
    var baseTarget: HeadPose {
        switch self {
        case .tiltRight: return HeadPose(yaw: 0, pitch: 0, roll: 22)
        case .tiltLeft: return HeadPose(yaw: 0, pitch: 0, roll: -22)
        case .chinDown: return HeadPose(yaw: 0, pitch: -20, roll: 0)
        case .lookUp: return HeadPose(yaw: 0, pitch: 15, roll: 0)
        case .turnRight: return HeadPose(yaw: 28, pitch: 0, roll: 0)
        case .turnLeft: return HeadPose(yaw: -28, pitch: 0, roll: 0)
        case .downRight: return HeadPose(yaw: 18, pitch: -16, roll: 0)
        case .downLeft: return HeadPose(yaw: -18, pitch: -16, roll: 0)
        case .upRight: return HeadPose(yaw: 18, pitch: 12, roll: 0)
        case .upLeft: return HeadPose(yaw: -18, pitch: 12, roll: 0)
        default:
            // 回す：倒す（roll）と うなずく（pitch）で円をえがく。arc0 が右、時計回り（下 → 左 → 上）
            let k = Double(arcIndex ?? 0)
            let a = k * .pi / 4
            return HeadPose(yaw: 0, pitch: -16 * sin(a), roll: 18 * cos(a))
        }
    }

    var arcIndex: Int? {
        switch self {
        case .arc0: 0
        case .arc1: 1
        case .arc2: 2
        case .arc3: 3
        case .arc4: 4
        case .arc5: 5
        case .arc6: 6
        case .arc7: 7
        default: nil
        }
    }

    var isArc: Bool { arcIndex != nil }

    func target(_ size: AngleSize) -> HeadPose { baseTarget * size.scale }

    /// 画面の上で輪を置く向き（x は右が +、y は上が +。長さ 1）
    var screenDirection: (x: Double, y: Double) {
        let t = baseTarget
        // 倒す・向くは左右、うなずく・見上げるは上下
        let x = t.roll / 22 + t.yaw / 28
        let y = t.pitch / 18
        let len = max(0.0001, (x * x + y * y).squareRoot())
        return (x / len, y / len)
    }

    /// 輪の中で保つ秒数（回すときは短く、通りぬける）
    var holdSeconds: Double { isArc ? 1.2 : 5 }

    var cue: Phrase {
        switch self {
        case .tiltRight: Phrase("右の耳を、右の肩へ", "Right ear toward right shoulder")
        case .tiltLeft: Phrase("左の耳を、左の肩へ", "Left ear toward left shoulder")
        case .chinDown: Phrase("あごを、ゆっくり胸へ", "Chin slowly to your chest")
        case .lookUp: Phrase("ゆっくり、空を見上げて", "Slowly look up at the sky")
        case .turnRight: Phrase("右の肩ごしに、ふり向く", "Look over your right shoulder")
        case .turnLeft: Phrase("左の肩ごしに、ふり向く", "Look over your left shoulder")
        case .downRight: Phrase("右ななめ下を、のぞきこむ", "Look down to the right")
        case .downLeft: Phrase("左ななめ下を、のぞきこむ", "Look down to the left")
        case .upRight: Phrase("右ななめ上の、雲を見る", "Look up to the right")
        case .upLeft: Phrase("左ななめ上の、雲を見る", "Look up to the left")
        default: Phrase("ゆっくり、首で円をえがく", "Slowly draw a circle with your head")
        }
    }
}

/// 空の時間帯（コースの世界）。色は sky の 1 系統の中で、明るさと差し色の peach の量だけ変える
enum SkyTime: String, Codable, CaseIterable, Sendable {
    case dawn, noon, dusk, night

    var name: Phrase {
        switch self {
        case .dawn: Phrase("朝もや", "Morning mist")
        case .noon: Phrase("昼の青", "Noon blue")
        case .dusk: Phrase("夕なぎ", "Evening calm")
        case .night: Phrase("夜の雲", "Night clouds")
        }
    }
}

/// 1 分ほどのコース（動きの並び）
struct Course: Identifiable, Equatable, Sendable {
    let id: String
    let title: Phrase
    let note: Phrase
    let sky: SkyTime
    let moves: [Move]
    let isPro: Bool

    /// 目安の秒数（近づく 3 秒＋保つ＋戻す 2 秒）
    var estimatedSeconds: Int {
        Int(moves.reduce(0.0) { $0 + ($1.isArc ? 2.2 : 3 + $1.holdSeconds + 2) }.rounded())
    }

    /// 回すを 1 つの動きとして数えた、ストレッチの数
    var stretchCount: Int {
        var n = 0
        var inArc = false
        for m in moves {
            if m.isArc { if !inArc { n += 1 }; inArc = true } else { n += 1; inArc = false }
        }
        return n
    }
}

/// 手で用意したコースの一覧（無料 8・Pro 16）
enum CourseLibrary {
    static let circleRight: [Move] = [.arc0, .arc1, .arc2, .arc3, .arc4, .arc5, .arc6, .arc7, .arc0]
    static let circleLeft: [Move] = [.arc4, .arc3, .arc2, .arc1, .arc0, .arc7, .arc6, .arc5, .arc4]

    static let all: [Course] = [
        // 無料
        Course(id: "first-sky", title: Phrase("はじめの空", "First Sky"), note: Phrase("倒す・うなずく・見上げる。まずは 4 つだけ", "Tilt, nod, look up. Just four to start"), sky: .dawn, moves: [.tiltRight, .tiltLeft, .chinDown, .lookUp], isPro: false),
        Course(id: "side-breeze", title: Phrase("左右のそよ風", "Side Breeze"), note: Phrase("耳を肩へ。首の横がのびる", "Ear to shoulder. Opens the sides of the neck"), sky: .noon, moves: [.tiltRight, .tiltLeft, .turnRight, .turnLeft, .tiltRight, .tiltLeft], isPro: false),
        Course(id: "nodding-cloud", title: Phrase("うなずく雲", "Nodding Cloud"), note: Phrase("うしろ側をのばす、うなずきの 1 分", "A minute of nods for the back of the neck"), sky: .noon, moves: [.chinDown, .lookUp, .chinDown, .turnRight, .turnLeft], isPro: false),
        Course(id: "lunch-minute", title: Phrase("昼休みの 1 分", "Lunch Minute"), note: Phrase("6 方向をひと通り", "All six directions, once each"), sky: .noon, moves: [.tiltRight, .tiltLeft, .chinDown, .turnRight, .turnLeft, .lookUp], isPro: false),
        Course(id: "look-back-bird", title: Phrase("ふり向く鳥", "Look-Back Bird"), note: Phrase("肩ごしにふり向く。画面を見すぎた日に", "Look over each shoulder. For long screen days"), sky: .dawn, moves: [.turnRight, .turnLeft, .turnRight, .turnLeft, .chinDown], isPro: false),
        Course(id: "drop-shoulders", title: Phrase("肩をおろす", "Drop the Shoulders"), note: Phrase("肩の力をぬいて、首の横と後ろ", "Let the shoulders go; sides and back"), sky: .dusk, moves: [.chinDown, .tiltRight, .tiltLeft, .chinDown], isPro: false),
        Course(id: "afternoon-up", title: Phrase("見上げる午後", "Afternoon Look-Up"), note: Phrase("うつむいた午後に、空を見上げる", "Look up after a heads-down afternoon"), sky: .noon, moves: [.lookUp, .tiltRight, .lookUp, .tiltLeft, .chinDown], isPro: false),
        Course(id: "one-round", title: Phrase("ひと回り", "One Round"), note: Phrase("最後に、ゆっくり円をえがく", "Finish with one slow circle"), sky: .dusk, moves: [.tiltRight, .chinDown, .tiltLeft] + circleRight, isPro: false),

        // Pro
        Course(id: "diagonal-dawn", title: Phrase("ななめの朝", "Diagonal Dawn"), note: Phrase("ななめ下をのぞきこむ。肩の上がのびる", "Look down diagonally; stretches above the shoulder"), sky: .dawn, moves: [.downRight, .downLeft, .upRight, .upLeft, .chinDown], isPro: true),
        Course(id: "two-circles", title: Phrase("ふたつの円", "Two Circles"), note: Phrase("右回り、左回り", "Clockwise, then counterclockwise"), sky: .noon, moves: circleRight + circleLeft, isPro: true),
        Course(id: "evening-glow", title: Phrase("夕焼けの帰り道", "Evening Glow"), note: Phrase("1 日の終わりに、ゆっくり全方向", "Every direction, slowly, at day's end"), sky: .dusk, moves: [.tiltRight, .tiltLeft, .downRight, .downLeft, .turnRight, .turnLeft, .lookUp], isPro: true),
        Course(id: "night-float", title: Phrase("夜の浮遊", "Night Float"), note: Phrase("眠る前の、静かなうなずき", "Quiet nods before sleep"), sky: .night, moves: [.chinDown, .downRight, .chinDown, .downLeft, .chinDown], isPro: true),
        Course(id: "meeting-break", title: Phrase("会議のあと", "After the Meeting"), note: Phrase("固まった首を、左右から", "Unlock a stiff neck from both sides"), sky: .noon, moves: [.turnRight, .tiltRight, .turnLeft, .tiltLeft, .lookUp, .chinDown], isPro: true),
        Course(id: "spiral-cloud", title: Phrase("うずまき雲", "Spiral Cloud"), note: Phrase("倒してから、円へつなぐ", "Tilt, then flow into a circle"), sky: .dusk, moves: [.tiltLeft] + circleLeft + [.tiltRight] + circleRight, isPro: true),
        Course(id: "commute-window", title: Phrase("帰りの窓", "Commute Window"), note: Phrase("ななめ上の景色を、左右で", "Look up diagonally, both sides"), sky: .dusk, moves: [.upRight, .upLeft, .turnRight, .turnLeft, .chinDown], isPro: true),
        Course(id: "deep-sea", title: Phrase("深い海へ", "Into the Deep"), note: Phrase("うなずきを深く、長く", "Deeper, longer nods"), sky: .night, moves: [.chinDown, .downLeft, .chinDown, .downRight, .chinDown, .lookUp], isPro: true),
        Course(id: "weathervane", title: Phrase("風見どり", "Weathervane"), note: Phrase("ふり向く、を 4 回", "Four slow look-backs"), sky: .noon, moves: [.turnRight, .turnLeft, .turnRight, .turnLeft, .upRight, .upLeft], isPro: true),
        Course(id: "morning-full", title: Phrase("朝の全身ならし", "Morning Warm-Up"), note: Phrase("起きぬけの首を、全方向に", "Wake the neck up in every direction"), sky: .dawn, moves: [.chinDown, .lookUp, .tiltRight, .tiltLeft, .turnRight, .turnLeft] + circleRight, isPro: true),
        Course(id: "star-gazing", title: Phrase("星をさがす", "Stargazing"), note: Phrase("夜空のあちこちを見上げる", "Look up all around the night sky"), sky: .night, moves: [.lookUp, .upRight, .lookUp, .upLeft, .chinDown], isPro: true),
        Course(id: "keyboard-rescue", title: Phrase("キーボードの合間", "Keyboard Break"), note: Phrase("前に出た首を、うしろへ戻す", "Reset a forward-leaning neck"), sky: .noon, moves: [.lookUp, .chinDown, .tiltRight, .tiltLeft, .downRight, .downLeft], isPro: true),
        Course(id: "slow-tide", title: Phrase("ゆっくり潮", "Slow Tide"), note: Phrase("左右に倒して、波のように", "Side to side, like a tide"), sky: .dusk, moves: [.tiltRight, .tiltLeft, .tiltRight, .tiltLeft, .tiltRight, .tiltLeft], isPro: true),
        Course(id: "three-circles", title: Phrase("みっつの円", "Three Circles"), note: Phrase("右・左・右。大きくゆっくり", "Right, left, right. Big and slow"), sky: .night, moves: circleRight + circleLeft + circleRight, isPro: true),
        Course(id: "phone-neck", title: Phrase("スマホ首のあと", "After Phone Neck"), note: Phrase("見下ろしたあとは、見上げる", "After looking down, look up"), sky: .dawn, moves: [.lookUp, .upLeft, .upRight, .lookUp, .turnRight, .turnLeft], isPro: true),
        Course(id: "sunset-balloon", title: Phrase("夕陽と風船", "Sunset Balloon"), note: Phrase("すべての動きを、ひとつずつ", "Every move, one by one"), sky: .dusk, moves: [.tiltRight, .tiltLeft, .chinDown, .lookUp, .turnRight, .turnLeft, .downRight, .downLeft, .upRight, .upLeft], isPro: true),
    ]

    static var free: [Course] { all.filter { !$0.isPro } }

    static func course(id: String) -> Course? { all.first { $0.id == id } }

    /// 今日のコース（日ごとに順番に回す。Pro は全コースから）
    static func today(dayOrdinal: Int, isPro: Bool) -> Course {
        let pool = isPro ? all : free
        let i = ((dayOrdinal % pool.count) + pool.count) % pool.count
        return pool[i]
    }
}
