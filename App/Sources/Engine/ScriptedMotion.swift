import Foundation

/// 決まった首の動き（デモの再生・CI の撮影・テストで使う。カメラの代わり）。
/// コースの動きを、ゆっくり届いて保ち、まっすぐへ戻す、の順に並べた「お手本」。
struct ScriptedMotion: Sendable {
    struct Key: Sendable {
        let time: Double
        let pose: HeadPose
    }

    let keys: [Key]

    init(course: Course, size: AngleSize, overshoot: Double = 1.05) {
        var keys: [Key] = [Key(time: 0, pose: .zero), Key(time: StretchSession.countInSeconds, pose: .zero)]
        var t = StretchSession.countInSeconds
        var current = HeadPose.zero
        for (i, m) in course.moves.enumerated() {
            let target = m.target(size) * overshoot
            // 遠い輪へは、ゆっくり（速すぎて風が乱れないように）
            let travel = (target - current).length
            if m.isArc {
                t += max(1.1, travel / 12); keys.append(Key(time: t, pose: target))
                t += m.holdSeconds + 0.5; keys.append(Key(time: t, pose: target))
            } else {
                if current != .zero {
                    t += max(1.6, current.length / 18); keys.append(Key(time: t, pose: .zero))
                }
                t += 2.4; keys.append(Key(time: t, pose: target))
                // 保つ間も、少しだけ揺れる（人の首らしく）
                t += m.holdSeconds / 2 + 0.4; keys.append(Key(time: t, pose: target * 1.02))
                t += m.holdSeconds / 2 + 0.4; keys.append(Key(time: t, pose: target))
            }
            current = target
            let nextIsArc = i + 1 < course.moves.count && course.moves[i + 1].isArc
            if !m.isArc, !nextIsArc {
                t += max(1.6, target.length / 18); keys.append(Key(time: t, pose: .zero))
                current = .zero
            }
        }
        if current != .zero { t += max(1.6, current.length / 18); keys.append(Key(time: t, pose: .zero)) }
        self.keys = keys
    }

    var duration: Double { keys.last?.time ?? 0 }

    /// t 秒の向き（なめらかにつなぐ）
    func pose(at t: Double) -> HeadPose {
        guard let first = keys.first else { return .zero }
        if t <= first.time { return first.pose }
        for i in 1..<keys.count where t <= keys[i].time {
            let a = keys[i - 1], b = keys[i]
            let span = max(0.0001, b.time - a.time)
            let x = (t - a.time) / span
            let s = x * x * (3 - 2 * x)
            return a.pose.mix(b.pose, s)
        }
        return keys.last?.pose ?? .zero
    }

    /// エンジンに通して、途中の状態を作る（撮影用）
    func run(until t: Double, course: Course, size: AngleSize, step: Double = 1.0 / 30) -> StretchSession {
        var s = StretchSession(course: course, size: size)
        var x = 0.0
        while x <= t {
            s.update(pose: pose(at: x), at: x)
            x += step
        }
        return s
    }
}
