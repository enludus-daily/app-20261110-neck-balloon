import AVFoundation
import UIKit

/// 振動（弱め。デスクで静かに）。手応えの表は README にある
@MainActor
enum Haptics {
    static var enabled = true
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let notice = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() { soft.prepare(); light.prepare(); notice.prepare() }
    static func select() { if enabled { selection.selectionChanged() } }
    /// 輪に入った
    static func enter() { if enabled { soft.impactOccurred(intensity: 0.6) } }
    /// 輪が満ちた
    static func complete() { if enabled { light.impactOccurred(intensity: 0.8) } }
    /// 風が乱れた（速すぎ）
    static func gust() { if enabled { notice.notificationOccurred(.warning) } }
    /// コースを終えた
    static func finish() { if enabled { notice.notificationOccurred(.success) } }
}

/// 小さな音（その場で作るやわらかい音。外の音源は使わない）。消音スイッチに従い、ほかの音と混ぜる
@MainActor
final class Chimes {
    static let shared = Chimes()
    var enabled = true
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var buffers: [Kind: AVAudioPCMBuffer] = [:]
    private var ready = false

    enum Kind: CaseIterable { case enter, complete, gust, finish, tick }

    private init() {}

    private func setUp() -> Bool {
        if ready { return true }
        guard let format else { return false }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.5
            try engine.start()
        } catch {
            return false
        }
        for k in Kind.allCases { buffers[k] = Self.render(Self.notes(k), format: format) }
        ready = true
        return true
    }

    /// （周波数, 始まり秒, 長さ秒, 大きさ）。周波数 0 は「風の音」（やわらかいノイズ）
    /// 絵本の夜空に合わせて、オルゴールのような音（ペンタトニック）。失敗は低い音ではなく、ふっと吹く風
    private static func notes(_ k: Kind) -> [(Double, Double, Double, Float)] {
        switch k {
        case .enter: [(880.0, 0, 0.7, 0.13)]                                    // A5 ひとつ
        case .complete: [(1318.5, 0, 0.7, 0.11), (1760.0, 0.1, 0.9, 0.10)]    // E6 → A6（星がひとつ灯る）
        case .gust: [(0, 0, 0.45, 0.10)]                                        // 風
        case .finish: [(1760.0, 0, 1.0, 0.09), (1318.5, 0.14, 1.0, 0.09), (1174.7, 0.28, 1.0, 0.09),
                       (880.0, 0.42, 1.2, 0.10), (1318.5, 0.62, 1.6, 0.08)]     // 星が降るように下りて、最後に一つ上
        case .tick: [(1174.7, 0, 0.18, 0.07)]
        }
    }

    private static func render(_ notes: [(Double, Double, Double, Float)], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let total = notes.map { $0.1 + $0.2 }.max() ?? 0.1
        let frames = AVAudioFrameCount(total * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let ch = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        for i in 0..<Int(frames) { ch[i] = 0 }
        for (f, start, len, amp) in notes {
            let s0 = Int(start * sr), n = Int(len * sr)
            if f == 0 {
                // 風：ノイズを 2 回ならして（低い音だけ残す）、ふくらんでしぼむ形に
                var seed: UInt32 = 12345
                var lp1: Double = 0, lp2: Double = 0
                for i in 0..<n where s0 + i < Int(frames) {
                    seed = seed &* 1_664_525 &+ 1_013_904_223
                    let white = Double(seed >> 9) / Double(1 << 23) * 2 - 1
                    lp1 += (white - lp1) * 0.06
                    lp2 += (lp1 - lp2) * 0.06
                    let t = Double(i) / Double(n)
                    let env = sin(.pi * t) * sin(.pi * t)
                    ch[s0 + i] += Float(lp2 * env * 6) * amp
                }
                continue
            }
            for i in 0..<n where s0 + i < Int(frames) {
                let t = Double(i) / sr
                // オルゴール：速い立ち上がり、長い減衰、高い倍音（少しずれた倍音で金属の小さな櫛の音）
                let env = min(1, t / 0.004) * exp(-t * 5.0 / len)
                let v = sin(2 * .pi * f * t) + 0.3 * sin(2 * .pi * f * 3.01 * t) * exp(-t * 9) + 0.12 * sin(2 * .pi * f * 5.4 * t) * exp(-t * 18)
                ch[s0 + i] += Float(v * env) * amp
            }
        }
        return buf
    }

    func play(_ k: Kind) {
        guard enabled, setUp(), let b = buffers[k] else { return }
        player.scheduleBuffer(b, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
