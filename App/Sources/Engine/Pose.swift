import Foundation

/// 頭の向き（度）。画面・カメラから切り離した、ただの値。
/// - roll：右の耳を右の肩へ倒すと +（左へ倒すと −）
/// - pitch：見上げると +（あごを引くと −）
/// - yaw：右を向くと +（左を向くと −）
struct HeadPose: Equatable, Sendable, Codable {
    var yaw: Double
    var pitch: Double
    var roll: Double

    static let zero = HeadPose(yaw: 0, pitch: 0, roll: 0)

    static func + (a: HeadPose, b: HeadPose) -> HeadPose { HeadPose(yaw: a.yaw + b.yaw, pitch: a.pitch + b.pitch, roll: a.roll + b.roll) }
    static func - (a: HeadPose, b: HeadPose) -> HeadPose { HeadPose(yaw: a.yaw - b.yaw, pitch: a.pitch - b.pitch, roll: a.roll - b.roll) }
    static func * (a: HeadPose, k: Double) -> HeadPose { HeadPose(yaw: a.yaw * k, pitch: a.pitch * k, roll: a.roll * k) }

    func dot(_ o: HeadPose) -> Double { yaw * o.yaw + pitch * o.pitch + roll * o.roll }
    var length: Double { dot(self).squareRoot() }

    /// 左右を入れ替える（前面カメラの鏡像で向きが逆になる端末のため）
    var mirrored: HeadPose { HeadPose(yaw: -yaw, pitch: pitch, roll: -roll) }

    /// 2 つの向きのあいだ（t = 0 で self、1 で o）
    func mix(_ o: HeadPose, _ t: Double) -> HeadPose { self + (o - self) * t }
}

/// 頭の向きを出すもの（前面カメラ・端末の傾き・指・テスト用の決まった動き）。
/// CI のシミュレータではカメラが使えないので、テストと撮影は `ScriptedPoseSource` で動かす。
@MainActor
protocol HeadPoseSource: AnyObject {
    /// 新しい向きが届いたとき（時刻は CACurrentMediaTime と同じ秒）
    var onPose: ((HeadPose, Double) -> Void)? { get set }
    var status: PoseSourceStatus { get }
    func start()
    func stop()
}

enum PoseSourceStatus: Equatable, Sendable {
    case idle
    case running
    /// 顔が見えない（カメラの外・暗い）
    case lost
    /// 許可がない
    case denied
    /// この端末では使えない
    case unavailable
}

/// どの入力で遊ぶか
enum InputMode: String, Codable, CaseIterable, Sendable {
    /// 前面カメラで顔の向きを読む
    case camera
    /// iPhone を両手で持って傾ける
    case tilt
    /// 指でなぞる
    case touch
}

/// ぶれをならす（指数移動平均）。速さの計算がノイズで跳ねないようにする
struct PoseSmoother: Sendable {
    /// 0〜1。大きいほど新しい値に早く追いつく
    var alpha: Double = 0.35
    private(set) var value: HeadPose?

    init(alpha: Double = 0.35) { self.alpha = alpha }

    mutating func push(_ p: HeadPose) -> HeadPose {
        guard let v = value else { value = p; return p }
        let next = v.mix(p, alpha)
        value = next
        return next
    }

    mutating func reset() { value = nil }
}

/// 前面カメラの左右の向きが逆になっていたら気づく。
/// 「右に倒す」の案内で、反対側へ大きく倒したまま 1.5 秒続いたら、左右を入れ替える合図を出す。
struct MirrorDetector: Sendable {
    private var wrongSince: Double?
    private(set) var shouldFlip = false

    mutating func observe(progress: Double, at t: Double) {
        guard !shouldFlip else { return }
        if progress < -0.7 {
            if let s = wrongSince {
                if t - s >= 1.5 { shouldFlip = true }
            } else {
                wrongSince = t
            }
        } else {
            wrongSince = nil
        }
    }

    mutating func reset() { wrongSince = nil; shouldFlip = false }
}
