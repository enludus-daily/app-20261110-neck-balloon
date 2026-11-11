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
    /// 保つ秒数（判定のゆるさで変わる）
    var holdTarget: Double
    /// いちばん深く届いた割合（1 で輪のまんなか。1 を超えると大きく伸ばせた）
    var maxProgress: Double = 0
    /// 輪の中で保った秒数
    var held: Double = 0
    /// 速すぎた（風が乱れた）秒数
    var fastSeconds: Double = 0
    /// 時間切れで次へ進んだ
    var timedOut = false

    init(move: Move, holdTarget: Double) {
        self.move = move
        self.holdTarget = holdTarget
    }

    /// 0〜100。届いた深さ 40・保った長さ 30・ゆっくり 30。
    /// 深さは目標の角度（1）で満点。行きすぎても減らさない
    var score: Int {
        let reach = max(0, min(1, maxProgress))
        let hold = min(1, held / max(0.1, holdTarget))
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

    /// 戻ったとみなす割合
    static let neutralZone = 0.3
    /// これより速いと風が乱れる（度/秒）
    static let fastSpeed = 55.0
    /// 1 つの動きの時間切れ（秒）
    static let stepTimeout = 20.0
    static let countInSeconds = 3.0

    /// 顔を見失ったときに「行きすぎ」とみなす、最後に読めた割合（ここより目標の側で見失ったら、よく伸びている）
    static let lostCarryFrom = 0.5

    let course: Course
    let size: AngleSize
    let leniency: Leniency
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
    /// 輪から少しはみ出した時刻（短いぶれなら「保つ」を続ける）
    private var outSince: Double?
    /// 顔を見失った時刻（見えている間は nil）
    private(set) var lostSince: Double?
    /// 見失ったのが目標へ向かう途中・目標の近くだった（＝行きすぎ。最後の向きのまま数える）
    private(set) var lostWhileReaching = false
    /// 最後の時刻
    private(set) var now: Double = 0

    init(course: Course, size: AngleSize, leniency: Leniency = .loose) {
        self.course = course
        self.size = size
        self.leniency = leniency
        self.results = course.moves.map { StepResult(move: $0, holdTarget: $0.holdSeconds(leniency)) }
    }

    var move: Move? { index < course.moves.count ? course.moves[index] : nil }
    var target: HeadPose? { move?.target(size) }
    var isFinished: Bool { phase == .finished }

    /// 風の乱れ（0〜1。速すぎるほど大きい。画面で風船が揺れる）
    var gust: Double { max(0, min(1, (speed - 35) / 40)) }

    /// 今の動きで保った割合（0〜1。輪が満ちていく）
    var holdFraction: Double {
        guard move != nil, index < results.count else { return 0 }
        return min(1, results[index].held / max(0.1, results[index].holdTarget))
    }

    /// 今の動きで保つ秒数
    var holdTarget: Double { index < results.count ? results[index].holdTarget : 0 }

    /// 顔が見えない
    var isLost: Bool { lostSince != nil }

    /// 顔を見失ったまま、行きすぎとしても数えられないとき（「顔を画面にもどして」と静かに案内する）
    var needsFaceBack: Bool {
        guard let since = lostSince else { return false }
        if phase == .countIn || phase == .finished { return true }
        return !lostWhileReaching || now - since > leniency.lostGrace
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
        // 見失ったあとの最初の向きは、見失う前と比べない（戻ってきた分を「速すぎ」にしない）
        if let lp = lastPose, dt > 0 {
            let instant = (newPose - lp).length / dt
            speed = speed * 0.6 + instant * 0.4
        }
        lastTime = t
        now = t
        lastPose = newPose
        pose = newPose
        lostSince = nil
        lostWhileReaching = false

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
            // 行きすぎは輪の中（上限で弾かない）。行きすぎた分だけ、中心からのずれも広く許す
            let offRatio = off / max(1, along)
            let inside = along >= leniency.enterZone && offRatio < leniency.enterOff
            let stillInside = along >= leniency.leaveZone && offRatio < leniency.leaveOff
            if phase == .reaching, inside {
                phase = .holding
                outSince = nil
            } else if phase == .holding {
                if stillInside {
                    outSince = nil
                } else if let o = outSince {
                    // 短いぶれ（wobbleGrace 以内）では「保つ」を途切れさせない
                    if t - o > leniency.wobbleGrace {
                        phase = .reaching
                        outSince = nil
                    }
                } else {
                    outSince = t
                }
            }
            if phase == .holding {
                // 速く動いている間は、保った時間に数えない
                if !fast { results[index].held += dt }
                if results[index].held >= results[index].holdTarget { completeStep(at: t) }
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

    /// 顔が見えないとき（カメラが顔を見失った）に、時間だけを進める（t は秒）。
    /// 目標へ向かう途中・目標の近くで見失ったら、カメラが読めないほど大きく伸ばした（行きすぎ）とみなし、
    /// 最後に読めた向きのまま、`leniency.lostGrace` 秒までは「保つ」を数える。
    /// それより長い・目標から遠いところで見失ったときは、数えも時間切れも止めて待つ（責めない）。
    mutating func updateLost(at t: Double) {
        guard let start = startTime else { return }
        let dt = lastTime.map { max(0, min(0.25, t - $0)) } ?? 0
        lastTime = t
        now = t
        // 次に顔が見えたとき、見失う前の向きと比べて「速すぎ」にしない
        lastPose = nil
        speed *= 0.6
        if lostSince == nil {
            lostSince = t
            lostWhileReaching = (phase == .reaching || phase == .holding) && progress >= Self.lostCarryFrom
        }

        switch phase {
        case .finished, .returning:
            return
        case .countIn:
            if t - start >= Self.countInSeconds {
                phase = .reaching
                stepStart = t
            }
            return
        case .reaching, .holding:
            break
        }
        guard index < results.count else { phase = .finished; return }
        let since = lostSince ?? t
        if lostWhileReaching, t - since <= leniency.lostGrace {
            // 行きすぎ：深さは満点、輪の中で保っているとみなす
            results[index].maxProgress = max(results[index].maxProgress, 1)
            if phase == .reaching { phase = .holding }
            outSince = nil
            results[index].held += dt
            if results[index].held >= results[index].holdTarget { completeStep(at: t) }
        } else {
            if phase == .holding { phase = .reaching }
            outSince = nil
            // 見えない間は時間切れへ進めない
            stepStart += dt
        }
    }

    private mutating func completeStep(at t: Double) {
        outSince = nil
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
