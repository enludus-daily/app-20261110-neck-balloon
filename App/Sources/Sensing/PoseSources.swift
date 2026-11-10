import ARKit
import AVFoundation
import CoreMotion
import Foundation
import QuartzCore
import Vision

// 顔の向きは端末の中だけで計算する。映像は保存も送信もしない（フレームを受け取ったらその場で向きだけ取り出して捨てる）。

/// 決まった動きを流す（テスト・CI の撮影・デモの再生）
@MainActor
final class ScriptedPoseSource: HeadPoseSource {
    var onPose: ((HeadPose, Double) -> Void)?
    private(set) var status: PoseSourceStatus = .idle
    let motion: ScriptedMotion
    private var timer: Timer?
    private var started: Double = 0

    init(motion: ScriptedMotion) { self.motion = motion }

    func start() {
        status = .running
        started = CACurrentMediaTime()
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = CACurrentMediaTime()
        onPose?(motion.pose(at: now - started), now)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        status = .idle
    }
}

/// 指でなぞる（カメラを使わない人のため）。画面の側から向きを入れる
@MainActor
final class TouchPoseSource: HeadPoseSource {
    var onPose: ((HeadPose, Double) -> Void)?
    private(set) var status: PoseSourceStatus = .idle
    private var timer: Timer?
    /// 画面から入る、今の向き
    var current: HeadPose = .zero

    func start() {
        status = .running
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onPose?(self.current, CACurrentMediaTime())
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        status = .idle
        current = .zero
    }
}

/// 端末を両手で持って傾ける（CoreMotion）。始めたときの姿勢を 0 にする
@MainActor
final class MotionPoseSource: HeadPoseSource {
    var onPose: ((HeadPose, Double) -> Void)?
    private(set) var status: PoseSourceStatus = .idle
    private let manager = CMMotionManager()
    private var reference: CMAttitude?

    func start() {
        guard manager.isDeviceMotionAvailable else { status = .unavailable; return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30
        status = .running
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            MainActor.assumeIsolated {
                guard let self, let motion else { return }
                let att = motion.attitude
                if self.reference == nil { self.reference = att.copy() as? CMAttitude }
                if let r = self.reference { att.multiply(byInverseOf: r) }
                let d = 180 / Double.pi
                // 端末を右へ傾ける＝首を右へ倒す、手前へ倒す＝あごを引く、右へ回す＝右を向く
                let pose = HeadPose(yaw: -att.yaw * d, pitch: -att.pitch * d, roll: att.roll * d)
                self.onPose?(pose, CACurrentMediaTime())
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        status = .idle
    }
}

/// 前面カメラで顔の向きを読む。TrueDepth のある端末は ARKit の顔の追跡、ない端末は Vision。
@MainActor
final class CameraPoseSource: NSObject, HeadPoseSource {
    var onPose: ((HeadPose, Double) -> Void)?
    private(set) var status: PoseSourceStatus = .idle
    private var arSession: ARSession?
    private var vision: VisionFaceReader?

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start() {
        switch Self.authorization {
        case .authorized: break
        case .notDetermined:
            Task { @MainActor in
                if await Self.requestAccess() { self.start() } else { self.status = .denied }
            }
            return
        default:
            status = .denied
            return
        }
        if ARFaceTrackingConfiguration.isSupported {
            let s = ARSession()
            s.delegate = self
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = false
            s.run(config, options: [.resetTracking, .removeExistingAnchors])
            arSession = s
            status = .running
        } else {
            let reader = VisionFaceReader { [weak self] pose in
                Task { @MainActor in
                    guard let self else { return }
                    if let pose {
                        self.status = .running
                        self.onPose?(pose, CACurrentMediaTime())
                    } else {
                        self.status = .lost
                    }
                }
            }
            if reader.start() {
                vision = reader
                status = .running
            } else {
                status = .unavailable
            }
        }
    }

    func stop() {
        arSession?.pause()
        arSession = nil
        vision?.stop()
        vision = nil
        status = .idle
    }

    /// 顔のアンカーの向き（行列）から、ヨー・ピッチ・ロールを取り出す
    nonisolated static func pose(from m: simd_float4x4) -> HeadPose {
        let forward = SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z)
        let up = SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z)
        let d = 180 / Double.pi
        let yaw = Double(atan2(forward.x, forward.z)) * d
        let pitch = Double(asin(max(-1, min(1, forward.y)))) * d
        let roll = Double(atan2(-up.x, up.y)) * d
        return HeadPose(yaw: yaw, pitch: pitch, roll: roll)
    }
}

extension CameraPoseSource: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        let tracked = face.isTracked
        let pose = Self.pose(from: face.transform)
        Task { @MainActor in
            if tracked {
                self.status = .running
                self.onPose?(pose, CACurrentMediaTime())
            } else {
                self.status = .lost
            }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in self.status = .unavailable }
    }
}

/// TrueDepth のない端末：前面カメラの映像から Vision で顔の向きを読む（映像は残さない）
final class VisionFaceReader: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "face-reader")
    private let handler: (HeadPose?) -> Void
    private var frame = 0

    init(handler: @escaping (HeadPose?) -> Void) {
        self.handler = handler
    }

    func start() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .low
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return false }
        session.addOutput(output)
        if let c = output.connection(with: .video) {
            if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        }
        session.commitConfiguration()
        let s = session
        queue.async { s.startRunning() }
        return true
    }

    func stop() {
        let s = session
        queue.async { s.stopRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frame += 1
        guard frame % 2 == 0 else { return }  // 15 回/秒で十分
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let h = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .upMirrored, options: [:])
        try? h.perform([request])
        guard let face = request.results?.first else { handler(nil); return }
        let d = 180 / Double.pi
        let pose = HeadPose(yaw: (face.yaw?.doubleValue ?? 0) * d,
                            pitch: (face.pitch?.doubleValue ?? 0) * d,
                            roll: -(face.roll?.doubleValue ?? 0) * d)
        handler(pose)
    }
}
