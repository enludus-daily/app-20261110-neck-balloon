import Foundation

/// 首の動いた範囲（度。まっすぐを 0 とした、いちばん大きく動いた角度）
struct NeckRange: Equatable, Sendable, Codable {
    var tiltRight: Double = 0
    var tiltLeft: Double = 0
    var up: Double = 0
    var down: Double = 0
    var turnRight: Double = 0
    var turnLeft: Double = 0

    mutating func include(_ p: HeadPose) {
        tiltRight = max(tiltRight, p.roll)
        tiltLeft = max(tiltLeft, -p.roll)
        up = max(up, p.pitch)
        down = max(down, -p.pitch)
        turnRight = max(turnRight, p.yaw)
        turnLeft = max(turnLeft, -p.yaw)
    }

    func merged(_ o: NeckRange) -> NeckRange {
        NeckRange(tiltRight: max(tiltRight, o.tiltRight), tiltLeft: max(tiltLeft, o.tiltLeft), up: max(up, o.up),
                  down: max(down, o.down), turnRight: max(turnRight, o.turnRight), turnLeft: max(turnLeft, o.turnLeft))
    }

    /// 倒す（左右の平均）
    var tilt: Double { (tiltRight + tiltLeft) / 2 }
    /// 向く（左右の平均）
    var turn: Double { (turnRight + turnLeft) / 2 }
    /// うなずく＋見上げる
    var nod: Double { up + down }

    var isEmpty: Bool { tilt == 0 && turn == 0 && nod == 0 }
}

/// 1 つの動きの結果
struct StepResult: Equatable, Sendable, Codable {
    let move: Move
    /// いちばん深く届いた割合（1 で輪のまんなか。1 を超えると大きく伸ばせた）
    var maxProgress: Double = 0
    /// 輪の中で保った秒数
    var held: Double = 0
    /// 速すぎた（風が乱れた）秒数
    var fastSeconds: Double = 0
    /// 時間切れで次へ進んだ
    var timedOut = false

    /// 0〜100。届いた深さ 40・保った長さ 30・ゆっくり 30
    var score: Int {
        let reach = min(1, maxProgress / 1.1)
        let hold = min(1, held / move.holdSeconds)
        let smooth = max(0, 1 - fastSeconds / 1.5)
        return Int((100 * (0.4 * reach + 0.3 * hold + 0.3 * smooth)).rounded())
    }
}

/// ストレッチの 1 回分の遊び。画面・カメラから切り離した状態の計算（テストできる）。
/// 決まり：ゆっくり大きく伸ばして、雲の輪の中で保つほど点が高い。速く動かすと風が乱れて点が減る。
struct StretchSession: Sendable {
    enum Phase: Equatable, Sendable {
        /// 始まる前の数え（秒）
        case countIn
        /// 輪へ向かう
        case reaching
        /// 輪の中で保つ
        case holding
        /// まっすぐへ戻す
        case returning
        case finished
    }

    /// 輪に入ったとみなす割合と、出たとみなす割合（行ったり来たりでちらつかないように差をつける）
    static let enterZone = 0.85
    static let leaveZone = 0.72
    /// 戻ったとみなす割合
    static let neutralZone = 0.3
    /// これより速いと風が乱れる（度/秒）
    static let fastSpeed = 55.0
    /// 1 つの動きの時間切れ（秒）
    static let stepTimeout = 20.0
    static let countInSeconds = 3.0

    let course: Course
    let size: AngleSize
    private(set) var phase: Phase = .countIn
    private(set) var index = 0
    private(set) var results: [StepResult]
    private(set) var pose: HeadPose = .zero
    /// 今の動きの、輪までの割合（負なら反対向き）
    private(set) var progress: Double = 0
    /// 輪の中心からのずれ（割合）
    private(set) var offAxis: Double = 0
    /// 首の速さ（度/秒、ならした値）
    private(set) var speed: Double = 0
    private(set) var range = NeckRange()
    private(set) var startTime: Double?
    private(set) var stepStart: Double = 0
    private var lastTime: Double?
    private var lastPose: HeadPose?

    init(course: Course, size: AngleSize) {
        self.course = course
        self.size = size
        self.results = course.moves.map { StepResult(move: $0) }
    }

    var move: Move? { index < course.moves.count ? course.moves[index] : nil }
    var target: HeadPose? { move?.target(size) }
    var isFinished: Bool { phase == .finished }

    /// 風の乱れ（0〜1。速すぎるほど大きい。画面で風船が揺れる）
    var gust: Double { max(0, min(1, (speed - 35) / 40)) }

    /// 今の動きで保った割合（0〜1。輪が満ちていく）
    var holdFraction: Double {
        guard let m = move, index < results.count else { return 0 }
        return min(1, results[index].held / m.holdSeconds)
    }

    /// 全体の点（0〜100。終わった動きの平均）
    var score: Int {
        let done = results.prefix(phase == .finished ? results.count : index)
        guard !done.isEmpty else { return 0 }
        return Int((Double(done.reduce(0) { $0 + $1.score }) / Double(done.count)).rounded())
    }

    /// 進んだ割合（0〜1）
    var courseProgress: Double {
        guard !course.moves.isEmpty else { return 1 }
        return min(1, (Double(index) + (phase == .returning ? 1 : holdFraction * 0.9)) / Double(course.moves.count))
    }

    func countdown(at t: Double) -> Double {
        guard let s = startTime else { return Self.countInSeconds }
        return max(0, Self.countInSeconds - (t - s))
    }

    /// 割合：今の向きを、目標の向きへの射影で測る（1 で輪のまんなか）
    static func measure(_ pose: HeadPose, toward target: HeadPose) -> (along: Double, off: Double) {
        let len2 = target.dot(target)
        guard len2 > 0 else { return (0, 0) }
        let along = pose.dot(target) / len2
        let rest = pose - target * along
        return (along, rest.length / len2.squareRoot())
    }

    /// 新しい向きを入れる（t は秒）
    mutating func update(pose newPose: HeadPose, at t: Double) {
        if startTime == nil { startTime = t }
        let dt = lastTime.map { max(0, min(0.25, t - $0)) } ?? 0
        if let lp = lastPose, dt > 0 {
            let instant = (newPose - lp).length / dt
            speed = speed * 0.6 + instant * 0.4
        }
        lastTime = t
        lastPose = newPose
        pose = newPose

        switch phase {
        case .finished:
            return
        case .countIn:
            if t - (startTime ?? t) >= Self.countInSeconds {
                phase = .reaching
                stepStart = t
            }
            return
        default:
            break
        }

        range.include(newPose)
        guard let m = move else { phase = .finished; return }
        let (along, off) = Self.measure(newPose, toward: m.target(size))
        progress = along
        offAxis = off
        let fast = speed > Self.fastSpeed

        switch phase {
        case .reaching, .holding:
            results[index].maxProgress = max(results[index].maxProgress, along)
            if fast { results[index].fastSeconds += dt }
            if phase == .reaching, along >= Self.enterZone, off < 0.6 {
                phase = .holding
            } else if phase == .holding, along < Self.leaveZone || off >= 0.75 {
                phase = .reaching
            }
            if phase == .holding {
                // 速く動いている間は、保った時間に数えない
                if !fast { results[index].held += dt }
                if results[index].held >= m.holdSeconds { completeStep(at: t) }
            } else if t - stepStart >= Self.stepTimeout {
                results[index].timedOut = true
                completeStep(at: t)
            }
        case .returning:
            // 回す：次の輪へそのままつなぐ。ほかは、まっすぐに戻してから次へ
            let back = Self.measure(newPose, toward: course.moves[index - 1].target(size)).along
            if back < Self.neutralZone || (move?.isArc ?? false) {
                phase = .reaching
                stepStart = t
            }
        case .countIn, .finished:
            break
        }
    }

    private mutating func completeStep(at t: Double) {
        index += 1
        if index >= course.moves.count {
            phase = .finished
        } else {
            phase = .returning
            stepStart = t
        }
    }

    /// まとめ（結果の画面と記録へ）
    func summary(date: String) -> SessionSummary {
        SessionSummary(date: date, courseID: course.id, score: score, range: range,
                       stretches: course.stretchCount, perfect: results.filter { $0.score >= 90 }.count,
                       fastSeconds: results.reduce(0) { $0 + $1.fastSeconds })
    }
}

/// 1 回分のまとめ
struct SessionSummary: Equatable, Sendable, Codable {
    let date: String
    let courseID: String
    let score: Int
    let range: NeckRange
    let stretches: Int
    /// 90 点以上の動きの数
    let perfect: Int
    let fastSeconds: Double

    /// 点数の言葉
    var grade: Grade { Grade(score: score) }
}

enum Grade: Equatable, Sendable {
    case calm, gentle, breezy, gusty

    init(score: Int) {
        switch score {
        case 90...: self = .calm
        case 75..<90: self = .gentle
        case 55..<75: self = .breezy
        default: self = .gusty
        }
    }

    var title: Phrase {
        switch self {
        case .calm: Phrase("なぎ", "Calm")
        case .gentle: Phrase("そよ風", "Gentle breeze")
        case .breezy: Phrase("やや風", "Breezy")
        case .gusty: Phrase("つむじ風", "Gusty")
        }
    }

    var note: Phrase {
        switch self {
        case .calm: Phrase("ゆっくり、大きく。風船がまっすぐ届きました", "Slow and wide. The balloon floated straight in")
        case .gentle: Phrase("いい流れ。あと少し長く保てると、なぎ", "Nice flow. Hold a little longer for Calm")
        case .breezy: Phrase("もう少しゆっくり動かすと、風が静まります", "Move a bit slower and the wind settles")
        case .gusty: Phrase("速すぎると風が乱れます。痛くない範囲で、ゆっくり", "Too fast stirs the wind. Go slow, only as far as is comfortable")
        }
    }
}
