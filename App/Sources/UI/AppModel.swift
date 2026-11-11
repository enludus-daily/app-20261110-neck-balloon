import Foundation
import Observation
import QuartzCore
import SwiftUI
import UserNotifications

/// アプリ全体の状態。保存は端末の中（UserDefaults）だけ
@MainActor
@Observable
final class AppModel {
    enum Route: Equatable { case home, play, result }
    enum Sheet: String, Identifiable { case courses, records, settings, pro, permission; var id: String { rawValue } }

    var progress: Progress { didSet { save() } }
    var route: Route = .home
    var sheet: Sheet?
    private(set) var play: PlayModel?
    private(set) var lastSummary: SessionSummary?
    private(set) var lastCourse: Course?
    /// 撮影用：画面の言語を切り替える（-screenshotScene en-…）
    var forcedLocale: Locale?
    /// 撮影・デモの間は保存しない
    @ObservationIgnored var persist = true
    var reminderDenied = false
    /// カメラを断られたあとに、遊ぼうとしていたコース
    @ObservationIgnored var pendingCourse: Course?

    let store: PurchaseStore
    static let saveKey = "neckballoon.progress.v1"

    init() {
        let bundle = Bundle.main.bundleIdentifier ?? "com.enludus.daily.003"
        let pro = ProductID.pro(bundleID: bundle)
        store = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
        applyFeel()
    }

    var isPro: Bool { store.entitlements.isPro }
    var today: String { DayKey.key(Date()) }
    var todayOrdinal: Int { DayKey.ordinal(today) ?? 0 }
    var todayCourse: Course { CourseLibrary.today(dayOrdinal: todayOrdinal, isPro: isPro) }
    var playedToday: Bool { progress.didPlay(today) }

    func onLaunch() async {
        await store.load()
    }

    private func save() {
        guard persist, let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.saveKey)
    }

    func applyFeel() {
        Haptics.enabled = progress.settings.haptics
        Chimes.shared.enabled = progress.settings.sound
    }

    // MARK: 遊ぶ

    func canPlay(_ c: Course) -> Bool { !c.isPro || isPro || !progress.usedProTrial }

    func start(_ course: Course) {
        if course.isPro, !isPro {
            guard !progress.usedProTrial else { sheet = .pro; return }
            progress.usedProTrial = true
        }
        let input = progress.settings.input
        if input == .camera {
            switch CameraPoseSource.authorization {
            case .denied, .restricted:
                pendingCourse = course
                sheet = .permission
                return
            default: break
            }
        }
        sheet = nil
        let source: HeadPoseSource
        switch input {
        case .camera: source = CameraPoseSource()
        case .tilt: source = MotionPoseSource()
        case .touch: source = TouchPoseSource()
        }
        let model = PlayModel(course: course, settings: progress.settings, source: source)
        model.onFinish = { [weak self] s in self?.finish(s, course: course) }
        model.onMirrorFlip = { [weak self] in self?.progress.settings.mirror.toggle() }
        play = model
        lastSummary = nil
        route = .play
        model.begin()
    }

    func startToday() { start(todayCourse) }

    /// カメラの許可がないとき：ほかの入力に切り替えて続ける
    func switchInput(_ mode: InputMode) {
        progress.settings.input = mode
        sheet = nil
        if let c = pendingCourse {
            pendingCourse = nil
            start(c)
        }
    }

    func quit() {
        play?.stop()
        play = nil
        route = .home
    }

    func finish(_ s: SessionSummary, course: Course) {
        play?.stop()
        if persist { progress.record(s) }
        lastSummary = s
        lastCourse = course
        route = .result
        play = nil
        // 課金の画面は、2 回目を遊び終えた直後に 1 回だけ（価値を感じたあと）
        if persist, !isPro, !progress.hasSeenPaywall, progress.totalPlays >= 2 {
            progress.hasSeenPaywall = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                if self.route == .result, self.sheet == nil { self.sheet = .pro }
            }
        }
    }

    func playAgain() {
        if let c = lastCourse { start(c) }
    }

    // MARK: お知らせ

    func setDailyReminder(_ hour: Int?) async {
        progress.settings.dailyReminderHour = hour
        await rescheduleReminders()
    }

    func setWorkReminder(_ w: WorkReminder?) async {
        progress.settings.workReminder = isPro ? w : nil
        await rescheduleReminders()
    }

    func rescheduleReminders() async {
        let s = progress.settings
        let ok = await Reminder.schedule(daily: s.dailyReminderHour, work: isPro ? s.workReminder : nil)
        reminderDenied = !ok && (s.dailyReminderHour != nil || s.workReminder != nil)
    }

    // MARK: 撮影とデモ

    /// 見本のデータ：16 日遊んで、今日は 17 日目。首の範囲が少しずつ広がっている
    static func sampleProgress(today: String) -> Progress {
        var p = Progress()
        p.hasOnboarded = true
        p.hasSeenPaywall = true
        guard let t = DayKey.ordinal(today) else { return p }
        let skipped: Set<Int> = [9, 13, 20]
        for i in 1...22 where !skipped.contains(i) {
            let key = DayKey.key(ordinal: t - i)
            let grow = Double(22 - i) / 22
            let r = NeckRange(tiltRight: 24 + 9 * grow, tiltLeft: 22 + 10 * grow, up: 14 + 5 * grow, down: 20 + 6 * grow,
                              turnRight: 30 + 12 * grow, turnLeft: 28 + 13 * grow)
            let course = CourseLibrary.free[i % CourseLibrary.free.count]
            p.record(SessionSummary(date: key, courseID: course.id, score: 62 + (i * 7) % 33, range: r,
                                    stretches: course.stretchCount, perfect: 2 + i % 4, fastSeconds: Double(i % 3)))
        }
        return p
    }

    func applyScreenshotScene(_ raw: String) {
        persist = false
        var scene = raw
        if scene.hasPrefix("en-") {
            forcedLocale = Locale(identifier: "en_US")
            scene.removeFirst(3)
        } else {
            // シミュレータは英語なので、名前に en- がない場面は日本語で撮る
            forcedLocale = Locale(identifier: "ja_JP")
        }
        progress = Self.sampleProgress(today: today)
        switch scene {
        case "home": break
        case "play":
            let c = CourseLibrary.free[3]
            let motion = ScriptedMotion(course: c, size: .small)
            // 2 つ目の動き（左に倒す）を輪の中で保っている途中
            let session = motion.run(until: 16.2, course: c, size: .small)
            play = PlayModel(frozen: session)
            route = .play
        case "result":
            let c = CourseLibrary.free[3]
            let motion = ScriptedMotion(course: c, size: .small)
            let s = motion.run(until: motion.duration + 0.5, course: c, size: .small)
            finish(s.summary(date: today), course: c)
            sheet = nil
        case "courses": sheet = .courses
        case "records": sheet = .records
        case "settings": sheet = .settings
        case "pro": sheet = .pro
        case "permission":
            pendingCourse = todayCourse
            sheet = .permission
        case "onboarding": progress.hasOnboarded = false
        default: break
        }
    }

    /// -demo：人の操作なしで 15〜20 秒。ホーム → 今日のコース（首を倒して輪へ）→ 結果
    func runDemo() {
        persist = false
        progress = Self.sampleProgress(today: today)
        let c = CourseLibrary.free[0]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            let motion = ScriptedMotion(course: c, size: .small)
            let model = PlayModel(course: c, settings: progress.settings, source: ScriptedPoseSource(motion: motion))
            model.onFinish = { [weak self] s in self?.finish(s, course: c) }
            play = model
            route = .play
            model.begin()
            try? await Task.sleep(for: .seconds(13))
            guard route == .play else { return }
            let s = motion.run(until: motion.duration + 0.5, course: c, size: .small)
            finish(s.summary(date: today), course: c)
        }
    }
}

/// プレイ中の状態。頭の向きを受け取り、エンジンに通し、手応え（音・振動）を出す
@MainActor
@Observable
final class PlayModel {
    private(set) var session: StretchSession
    private(set) var sourceStatus: PoseSourceStatus = .idle
    private(set) var now: Double = 0
    /// 最後に輪に入った時刻（輪が少しふくらむ）
    private(set) var enteredAt: Double = -10
    /// 最後に動きを終えた時刻（輪がはじける）
    private(set) var completedAt: Double = -10
    private(set) var gustAt: Double = -10
    private(set) var flippedNotice = false
    let frozen: Bool
    let input: InputMode

    @ObservationIgnored var onFinish: ((SessionSummary) -> Void)?
    @ObservationIgnored var onMirrorFlip: (() -> Void)?
    @ObservationIgnored private let source: HeadPoseSource?
    @ObservationIgnored private var smoother = PoseSmoother()
    @ObservationIgnored private var mirror: Bool
    @ObservationIgnored private var neutralSum = HeadPose.zero
    @ObservationIgnored private var neutralCount = 0
    @ObservationIgnored private var neutral = HeadPose.zero
    @ObservationIgnored private var detector = MirrorDetector()
    @ObservationIgnored private var finished = false
    /// 最後に向きが届いた時刻
    @ObservationIgnored private var lastPoseAt: Double?
    /// 顔の見失いに気づくための時計（カメラのときだけ）
    @ObservationIgnored private var lostTimer: Timer?
    /// これだけ向きが届かなければ、顔を見失ったとみなす（秒）
    static let lostAfter = 0.3

    init(course: Course, settings: Settings, source: HeadPoseSource) {
        session = StretchSession(course: course, size: settings.size, leniency: settings.leniency)
        self.source = source
        mirror = settings.mirror
        input = settings.input
        frozen = false
    }

    /// 撮影用：止まった絵
    init(frozen session: StretchSession) {
        self.session = session
        source = nil
        mirror = false
        input = .camera
        frozen = true
        sourceStatus = .running
        now = 100
    }

    var touchSource: TouchPoseSource? { source as? TouchPoseSource }

    func begin() {
        guard let source else { return }
        source.onPose = { [weak self] pose, t in self?.ingest(pose, at: t) }
        source.start()
        sourceStatus = source.status
        Haptics.prepare()
        if input == .camera {
            // ARKit・Vision は顔を見失うと向きを送らなくなる。時間だけはエンジンに進めてもらう
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkLost() }
            }
            RunLoop.main.add(timer, forMode: .common)
            lostTimer = timer
        }
    }

    func stop() {
        lostTimer?.invalidate()
        lostTimer = nil
        source?.stop()
        source?.onPose = nil
    }

    /// 顔を見失ったまま案内を出すとき（見失いが長い・目標から遠いところで見失った）
    var showFaceBack: Bool { input == .camera && !frozen && session.needsFaceBack }

    private func checkLost() {
        guard !finished, let source else { return }
        let t = CACurrentMediaTime()
        let lost = source.status == .lost || (lastPoseAt.map { t - $0 > Self.lostAfter } ?? false)
        guard lost else { return }
        now = t
        sourceStatus = source.status
        let before = session
        session.updateLost(at: t)
        smoother.reset()
        react(before: before, at: t)
    }

    /// 指のモード：画面の上の指の位置（中心からのずれ、半径 1 で輪）を向きにする
    func touch(x: Double, y: Double) {
        guard let t = touchSource, let m = session.move else { return }
        let d = m.screenDirection
        let along = max(-0.3, min(1.3, x * d.x + y * d.y))
        t.current = m.target(session.size) * along
    }

    func touchEnded() { touchSource?.current = .zero }

    private func ingest(_ raw: HeadPose, at t: Double) {
        guard !finished else { return }
        now = t
        lastPoseAt = t
        sourceStatus = source?.status ?? .idle
        var p = mirror ? raw.mirrored : raw
        let before = session
        // 数えている間の後半で、まっすぐの向きを覚える（カメラ・傾けのとき）
        if session.phase == .countIn, input != .touch {
            if session.countdown(at: t) < 2.2 {
                neutralSum = neutralSum + p
                neutralCount += 1
                neutral = neutralSum * (1 / Double(neutralCount))
            }
        }
        if input != .touch { p = p - neutral }
        let smooth = smoother.push(p)
        session.update(pose: smooth, at: t)

        // 左右が逆の端末に気づいたら、入れ替える
        if input == .camera, session.phase == .reaching, let m = session.move,
           m == .tiltRight || m == .tiltLeft || m == .turnRight || m == .turnLeft {
            detector.observe(progress: session.progress, at: t)
            if detector.shouldFlip {
                mirror.toggle()
                neutral = neutral.mirrored
                smoother.reset()
                detector.reset()
                flippedNotice = true
                onMirrorFlip?()
            }
        }

        react(before: before, at: t)
    }

    /// 手応え（音・振動）と、終わったときの知らせ
    private func react(before: StretchSession, at t: Double) {
        if before.phase != .holding, session.phase == .holding {
            enteredAt = t
            Haptics.enter()
            Chimes.shared.play(.enter)
        }
        if session.index > before.index {
            completedAt = t
            if session.phase != .finished {
                Haptics.complete()
                Chimes.shared.play(.complete)
            }
        }
        if session.speed > StretchSession.fastSpeed, before.speed <= StretchSession.fastSpeed, t - gustAt > 2 {
            gustAt = t
            Haptics.gust()
            Chimes.shared.play(.gust)
        }
        if before.phase == .countIn, session.phase == .reaching {
            Chimes.shared.play(.tick)
        }
        if session.isFinished {
            finished = true
            Haptics.finish()
            Chimes.shared.play(.finish)
            onFinish?(session.summary(date: DayKey.key(Date())))
        }
    }
}
