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

    /// （周波数, 始まり秒, 長さ秒, 大きさ）
    private static func notes(_ k: Kind) -> [(Double, Double, Double, Float)] {
        switch k {
        case .enter: [(659.25, 0, 0.5, 0.18)]                                  // E5
        case .complete: [(783.99, 0, 0.6, 0.16), (1046.5, 0.12, 0.8, 0.14)]  // G5 → C6
        case .gust: [(196.0, 0, 0.35, 0.10)]                                   // G3 ひくく
        case .finish: [(523.25, 0, 0.9, 0.14), (659.25, 0.16, 0.9, 0.13), (783.99, 0.32, 1.1, 0.13), (1046.5, 0.5, 1.4, 0.12)]
        case .tick: [(880, 0, 0.12, 0.08)]
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
            for i in 0..<n where s0 + i < Int(frames) {
                let t = Double(i) / sr
                // やわらかい立ち上がりと、長い減衰（ベルのような音）
                let env = min(1, t / 0.012) * exp(-t * 4.2 / len)
                let v = sin(2 * .pi * f * t) + 0.25 * sin(2 * .pi * f * 2 * t)
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
