import Foundation
import Testing
@testable import NeckBalloon

/// 決まった動き（関数）をエンジンに 30 回/秒で流す
private func drive(_ course: Course, size: AngleSize = .small, leniency: Leniency = .loose, until limit: Double = 400, pose: (Double) -> HeadPose) -> StretchSession {
    var s = StretchSession(course: course, size: size, leniency: leniency)
    var t = 0.0
    while t <= limit, !s.isFinished {
        s.update(pose: pose(t), at: t)
        t += 1.0 / 30
    }
    return s
}

/// カメラの代わり：nil の時刻は顔を見失った（向きが届かない）として流す
private func driveCamera(_ course: Course, size: AngleSize = .small, leniency: Leniency = .loose, until limit: Double = 400,
                         pose: (Double) -> HeadPose?) -> StretchSession {
    var s = StretchSession(course: course, size: size, leniency: leniency)
    var t = 0.0
    while t <= limit, !s.isFinished {
        if let p = pose(t) { s.update(pose: p, at: t) } else { s.updateLost(at: t) }
        t += 1.0 / 30
    }
    return s
}

/// 本物のカメラに近い見え方：目標の `seeUpTo` 倍より大きく動くと、顔を見失う
private func camera(_ motion: ScriptedMotion, course: Course, size: AngleSize = .small, seeUpTo: Double) -> (Double) -> HeadPose? {
    let limits = course.moves.map { $0.target(size).length * seeUpTo }
    let reach = limits.min() ?? 0
    return { t in
        let p = motion.pose(at: t)
        return p.length > reach ? nil : p
    }
}

private func one(_ moves: [Move]) -> Course {
    Course(id: "t", title: Phrase("t", "t"), note: Phrase("", ""), sky: .noon, moves: moves, isPro: false)
}

/// 数え 3 秒をまっすぐで過ごしてから、決まった時刻まで流す
private func afterCountIn(_ s: inout StretchSession, from t: inout Double) {
    while t < StretchSession.countInSeconds + 0.1 { s.update(pose: .zero, at: t); t += 1.0 / 30 }
}

/// 速い動き：0.25 秒で一気に届き、6 秒止まり、0.25 秒で戻る
private func jerky(_ course: Course, size: AngleSize = .small) -> (Double) -> HeadPose {
    var keys: [(Double, HeadPose)] = [(0, .zero), (StretchSession.countInSeconds, .zero)]
    var t = StretchSession.countInSeconds
    for m in course.moves {
        let target = m.target(size) * 1.05
        t += 0.25; keys.append((t, target))
        t += 6; keys.append((t, target))
        t += 0.25; keys.append((t, .zero))
        t += 0.5; keys.append((t, .zero))
    }
    return { x in
        for i in 1..<keys.count where x <= keys[i].0 {
            let a = keys[i - 1], b = keys[i]
            return a.1.mix(b.1, (x - a.0) / max(0.0001, b.0 - a.0))
        }
        return .zero
    }
}

struct HeadPoseTests {
    @Test func measureAlongTheTarget() {
        let target = HeadPose(yaw: 0, pitch: 0, roll: 20)
        let r = StretchSession.measure(HeadPose(yaw: 0, pitch: 0, roll: 10), toward: target)
        #expect(abs(r.along - 0.5) < 1e-9)
        #expect(r.off < 1e-9)
    }

    @Test func oppositeDirectionIsNegative() {
        let r = StretchSession.measure(HeadPose(yaw: 0, pitch: 0, roll: -20), toward: HeadPose(yaw: 0, pitch: 0, roll: 20))
        #expect(r.along < -0.9)
    }

    @Test func offAxisIsMeasured() {
        let r = StretchSession.measure(HeadPose(yaw: 0, pitch: 10, roll: 20), toward: HeadPose(yaw: 0, pitch: 0, roll: 20))
        #expect(abs(r.along - 1) < 1e-9)
        #expect(abs(r.off - 0.5) < 1e-9)
    }

    @Test func mirroredSwapsLeftAndRightOnly() {
        let p = HeadPose(yaw: 10, pitch: 5, roll: -8).mirrored
        #expect(p == HeadPose(yaw: -10, pitch: 5, roll: 8))
    }
}

struct StretchSessionTests {
    let course = CourseLibrary.free[3]  // 昼休みの 1 分（6 方向）

    @Test func waitsForTheCountIn() {
        var s = StretchSession(course: course, size: .small)
        s.update(pose: .zero, at: 0)
        s.update(pose: course.moves[0].target(.small), at: 2.0)
        #expect(s.phase == .countIn)
        s.update(pose: .zero, at: 3.1)
        #expect(s.phase == .reaching)
    }

    @Test func slowAndWideFinishesCalm() {
        let motion = ScriptedMotion(course: course, size: .small)
        let s = drive(course) { motion.pose(at: $0) }
        #expect(s.isFinished)
        #expect(s.results.allSatisfy { !$0.timedOut })
        #expect(s.results.allSatisfy { $0.held >= $0.holdTarget })
        #expect(s.score >= 90)
        #expect(s.summary(date: "2026-11-10").grade == .calm)
    }

    @Test func fastMovesScoreLowerThanSlowOnes() {
        let motion = ScriptedMotion(course: course, size: .small)
        let slow = drive(course) { motion.pose(at: $0) }
        let fast = drive(course, pose: jerky(course))
        #expect(fast.isFinished)
        #expect(fast.results.reduce(0) { $0 + $1.fastSeconds } > 0)
        #expect(fast.score < slow.score)
    }

    @Test func standingStillTimesOutWithALowScore() {
        let one = Course(id: "t", title: Phrase("t", "t"), note: Phrase("", ""), sky: .noon, moves: [.tiltRight, .tiltLeft], isPro: false)
        let s = drive(one, until: 60) { _ in .zero }
        #expect(s.isFinished)
        #expect(s.results.allSatisfy { $0.timedOut })
        #expect(s.score <= 30)
    }

    @Test func holdingDoesNotCountWhileMovingFast() {
        let one = Course(id: "t", title: Phrase("t", "t"), note: Phrase("", ""), sky: .noon, moves: [.tiltRight], isPro: false)
        var s = StretchSession(course: one, size: .small)
        let target = Move.tiltRight.target(.small)
        var t = 0.0
        while t < 3.2 { s.update(pose: .zero, at: t); t += 1.0 / 30 }
        // 輪の中で、上下に激しく揺らし続ける
        var k = 0
        while t < 9 {
            let shake = HeadPose(yaw: 0, pitch: k % 2 == 0 ? 6 : -6, roll: 0)
            s.update(pose: target + shake, at: t)
            t += 1.0 / 30; k += 1
        }
        #expect(s.results[0].fastSeconds > 3)
        #expect(s.results[0].held < 1)
    }

    @Test func rangeRecordsTheWidestAngles() {
        let motion = ScriptedMotion(course: course, size: .small)
        let s = drive(course) { motion.pose(at: $0) }
        #expect(s.range.tiltRight >= 22)
        #expect(s.range.tiltLeft >= 22)
        #expect(s.range.down >= 12)
        #expect(s.range.turnRight >= 20)
    }

    @Test func circlesFlowWithoutReturningToCenter() {
        let c = CourseLibrary.course(id: "two-circles")!
        let motion = ScriptedMotion(course: c, size: .small)
        let s = drive(c) { motion.pose(at: $0) }
        #expect(s.isFinished)
        #expect(s.results.allSatisfy { !$0.timedOut })
    }

    @Test(arguments: AngleSize.allCases, Leniency.allCases)
    func everyCourseCanBeFinishedAtEverySize(size: AngleSize, leniency: Leniency) {
        for c in CourseLibrary.all {
            let motion = ScriptedMotion(course: c, size: size, leniency: leniency)
            let s = drive(c, size: size, leniency: leniency) { motion.pose(at: $0) }
            #expect(s.isFinished, "\(c.id) \(size) \(leniency)")
            #expect(s.score >= 90, "\(c.id) \(size) \(leniency) \(s.score)")
        }
    }

    @Test func scriptedRunStopsInTheMiddleForScreenshots() {
        let motion = ScriptedMotion(course: course, size: .small)
        let s = motion.run(until: 16.2, course: course, size: .small)
        #expect(!s.isFinished)
        #expect(s.index >= 1)
    }
}

/// 本人の実機の意見（2026-11-11）への直し：見失い・行きすぎ・短いぶれで、点が不当に下がらないこと
struct LenientJudgingTests {
    @Test func defaultIsLooseWithAShortHold() {
        #expect(Settings().leniency == .loose)
        #expect(Move.chinDown.holdSeconds(.loose) == 3)
        #expect(Move.chinDown.holdSeconds(.normal) == 4)
        #expect(Leniency.loose.enterZone < Leniency.normal.enterZone)
        #expect(Leniency.loose.wobbleGrace >= 0.5 && Leniency.normal.wobbleGrace >= 0.5)
    }

    @Test func targetsStayInsideWhatTheCameraCanRead() {
        // 横を向くは 20° 前後、あごを引くは −12° 前後（それより大きい分は見失いの扱いで受け止める）
        #expect(abs(Move.turnRight.baseTarget.yaw) <= 22)
        #expect(abs(Move.turnLeft.baseTarget.yaw) <= 22)
        for m in Move.allCases {
            #expect(m.baseTarget.pitch >= -12.5, "\(m)")
            #expect(abs(m.baseTarget.yaw) <= 22, "\(m)")
        }
    }

    @Test func cuesMatchTheSmallerMovement() {
        for m in Move.allCases {
            #expect(!m.cue.ja.contains("肩ごし"), "\(m)")
            #expect(!m.cue.en.lowercased().contains("over your"), "\(m)")
        }
        for c in CourseLibrary.all {
            #expect(!c.note.ja.contains("肩ごし") && !c.title.ja.contains("ふり向"), "\(c.id)")
        }
    }

    /// あごを引くと顔が見えなくなる：目標の 0.8 倍まで読めて、その先は見失ったまま
    @Test(arguments: Leniency.allCases)
    func losingTheFaceNearTheTargetCountsAsAGoodStretch(leniency: Leniency) {
        let c = one([.chinDown])
        let target = Move.chinDown.target(.small)
        let s = driveCamera(c, leniency: leniency, until: 30) { t in
            if t < 3 { return .zero }
            let x = min(1, (t - 3) / 2.5)
            let p = target * (1.3 * x)
            return p.length > target.length * 0.8 ? nil : p
        }
        #expect(s.results[0].maxProgress >= 1)
        #expect(!s.results[0].timedOut)
        // 見失ったまま、顔を戻さなくても保ちきれる
        #expect(s.isFinished)
        #expect(s.score >= 90, "\(s.score)")
    }

    @Test func aLongLossAsksForTheFaceBackWithoutTimingOut() {
        let c = one([.turnRight])
        var s = StretchSession(course: c, size: .small, leniency: .loose)
        var t = 0.0
        afterCountIn(&s, from: &t)
        // 目標から遠いところ（0.2 倍）で見失い、40 秒もどらない
        s.update(pose: Move.turnRight.target(.small) * 0.2, at: t)
        while t < 45 { s.updateLost(at: t); t += 1.0 / 30 }
        #expect(s.needsFaceBack)
        #expect(s.results[0].held == 0)
        #expect(!s.results[0].timedOut)
        #expect(s.phase == .reaching)
        // 顔が戻れば、そのまま続けられる
        let target = Move.turnRight.target(.small)
        while t < 52, !s.isFinished { s.update(pose: target, at: t); t += 1.0 / 30 }
        #expect(!s.needsFaceBack)
        #expect(s.isFinished)
    }

    @Test func aBriefLossNearTheTargetDoesNotAskForTheFace() {
        let c = one([.turnRight])
        var s = StretchSession(course: c, size: .small, leniency: .loose)
        var t = 0.0
        afterCountIn(&s, from: &t)
        s.update(pose: Move.turnRight.target(.small) * 0.9, at: t)
        let lostAt = t
        while t < lostAt + 1.5 { s.updateLost(at: t); t += 1.0 / 30 }
        #expect(s.isLost)
        #expect(!s.needsFaceBack)
        #expect(s.phase == .holding)
    }

    @Test(arguments: [1.5, 2.0, 2.5])
    func goingPastTheTargetStillCounts(overshoot: Double) {
        let c = one([.turnRight, .turnLeft, .tiltRight, .lookUp])
        let motion = ScriptedMotion(course: c, size: .small, overshoot: overshoot)
        let s = drive(c) { motion.pose(at: $0) }
        #expect(s.isFinished)
        #expect(s.results.allSatisfy { !$0.timedOut })
        #expect(s.score >= 90, "\(overshoot) \(s.score)")
    }

    @Test func goingPastWithSomeWobbleOffAxisStillCounts() {
        let c = one([.turnRight])
        let target = Move.turnRight.target(.small)
        // 目標の 1.8 倍まで向き、首が少し傾く（ずれ 10°）
        let s = drive(c, until: 30) { t in
            if t < 3 { return .zero }
            let x = min(1, (t - 3) / 2.5)
            return (target * 1.8 + HeadPose(yaw: 0, pitch: -6, roll: 8)) * x
        }
        #expect(s.isFinished)
        #expect(s.score >= 90, "\(s.score)")
    }

    /// 本物のカメラのように、目標の 1.15 倍より先は見えない。大きく伸ばす人ほど見失うが、点は下がらない
    @Test(arguments: Leniency.allCases)
    func aCameraThatLosesBigMovesDoesNotLowerTheScore(leniency: Leniency) {
        let c = CourseLibrary.course(id: "look-back-bird")!
        let seen = drive(c, leniency: leniency) { ScriptedMotion(course: c, size: .small, leniency: leniency).pose(at: $0) }
        let motion = ScriptedMotion(course: c, size: .small, overshoot: 1.5, leniency: leniency)
        let s = driveCamera(c, leniency: leniency, pose: camera(motion, course: c, seeUpTo: 1.15))
        #expect(s.isFinished)
        #expect(s.results.allSatisfy { !$0.timedOut })
        #expect(s.score >= 90, "\(leniency) \(s.score)")
        #expect(s.score >= seen.score - 5)
    }

    @Test(arguments: Leniency.allCases)
    func shortWobblesDoNotBreakTheHold(leniency: Leniency) {
        let c = one([.tiltRight])
        let target = Move.tiltRight.target(.small)
        var s = StretchSession(course: c, size: .small, leniency: leniency)
        var t = 0.0
        afterCountIn(&s, from: &t)
        // ゆっくり輪へ
        let start = t
        while t < start + 2.5 { s.update(pose: target * ((t - start) / 2.5), at: t); t += 1.0 / 30 }
        var dropped = 0
        var prev = s.phase
        // 1 秒ごとに 0.4 秒だけ、輪の外（0.3 倍）へ落ちる
        while t < start + 20, !s.isFinished {
            let inDip = (t - start).truncatingRemainder(dividingBy: 1.0) < 0.4
            s.update(pose: inDip ? target * 0.3 : target, at: t)
            if prev == .holding, s.phase == .reaching { dropped += 1 }
            prev = s.phase
            t += 1.0 / 30
        }
        #expect(dropped == 0)
        #expect(s.isFinished)
        #expect(t < start + 2.5 + leniency.holdSeconds + 1.5)
    }

    @Test func aLongDipLeavesTheRing() {
        let c = one([.tiltRight])
        let target = Move.tiltRight.target(.small)
        var s = StretchSession(course: c, size: .small, leniency: .loose)
        var t = 0.0
        afterCountIn(&s, from: &t)
        while t < 6 { s.update(pose: target * min(1, (t - 3) / 2), at: t); t += 1.0 / 30 }
        #expect(s.phase == .holding)
        let dipStart = t
        while t < dipStart + 1.2 { s.update(pose: .zero, at: t); t += 1.0 / 30 }
        #expect(s.phase == .reaching)
    }

    @Test func comingBackAfterALossIsNotCountedAsFast() {
        let c = one([.chinDown, .lookUp])
        let target = Move.chinDown.target(.small)
        var s = StretchSession(course: c, size: .small, leniency: .loose)
        var t = 0.0
        afterCountIn(&s, from: &t)
        let start = t
        while t < start + 2.5 { s.update(pose: target * ((t - start) / 2.5), at: t); t += 1.0 / 30 }
        let lostAt = t
        while t < lostAt + 1.0 { s.updateLost(at: t); t += 1.0 / 30 }
        // 顔が見えたときは、見失う前と離れた向き（行きすぎていた）
        s.update(pose: target * 1.9, at: t)
        t += 1.0 / 30
        s.update(pose: target * 1.9, at: t)
        #expect(s.results[0].fastSeconds == 0)
        #expect(s.speed < StretchSession.fastSpeed)
    }

    @Test func oldSaveDataWithoutLeniencyStillLoads() throws {
        let old = #"{"input":"camera","size":"medium","sound":false,"haptics":true,"mirror":true,"dailyReminderHour":9}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(old.utf8))
        #expect(s.leniency == .loose)
        #expect(s.size == .medium)
        #expect(s.sound == false)
        #expect(s.mirror)
        #expect(s.dailyReminderHour == 9)
        var n = s
        n.leniency = .normal
        #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(n)) == n)
    }
}

struct GradeTests {
    @Test(arguments: [(95, Grade.calm), (90, .calm), (80, .gentle), (60, .breezy), (20, .gusty)])
    func gradeFromScore(score: Int, grade: Grade) {
        #expect(Grade(score: score) == grade)
    }
}

struct MirrorDetectorTests {
    @Test func flipsAfterHoldingTheOppositeWay() {
        var d = MirrorDetector()
        d.observe(progress: -0.9, at: 0)
        d.observe(progress: -0.9, at: 1.0)
        #expect(!d.shouldFlip)
        d.observe(progress: -0.9, at: 1.6)
        #expect(d.shouldFlip)
    }

    @Test func aBriefWrongMoveDoesNotFlip() {
        var d = MirrorDetector()
        d.observe(progress: -0.9, at: 0)
        d.observe(progress: 0.2, at: 1.0)
        d.observe(progress: -0.9, at: 1.2)
        d.observe(progress: -0.9, at: 2.0)
        #expect(!d.shouldFlip)
    }
}

struct CourseLibraryTests {
    @Test func eightFreeAndSixteenPro() {
        #expect(CourseLibrary.free.count == 8)
        #expect(CourseLibrary.all.filter { $0.isPro }.count == 16)
        #expect(Set(CourseLibrary.all.map { $0.id }).count == CourseLibrary.all.count)
    }

    @Test func everyCourseIsAboutAMinuteOrTwo() {
        for c in CourseLibrary.all {
            #expect((20...150).contains(c.estimatedSeconds()), "\(c.id) \(c.estimatedSeconds())")
            #expect(!c.title.en.isEmpty && !c.note.en.isEmpty)
        }
    }

    @Test func todayRotatesThroughFreeCourses() {
        let ids = (0..<8).map { CourseLibrary.today(dayOrdinal: 9000 + $0, isPro: false).id }
        #expect(Set(ids).count == 8)
        #expect(!CourseLibrary.today(dayOrdinal: 9000, isPro: false).isPro)
    }

    @Test func screenDirectionsAreUnitLength() {
        for m in Move.allCases {
            let d = m.screenDirection
            #expect(abs((d.x * d.x + d.y * d.y).squareRoot() - 1) < 1e-6)
        }
        #expect(Move.tiltRight.screenDirection.x > 0.99)
        #expect(Move.chinDown.screenDirection.y < -0.99)
    }
}

struct ProgressTests {
    func summary(_ date: String, score: Int = 80, tilt: Double = 20) -> SessionSummary {
        SessionSummary(date: date, courseID: "first-sky", score: score,
                       range: NeckRange(tiltRight: tilt, tiltLeft: tilt, up: 10, down: 15, turnRight: 25, turnLeft: 25),
                       stretches: 4, perfect: 1, fastSeconds: 0)
    }

    @Test func dayKeyOrdinalRoundTrips() {
        let o = DayKey.ordinal("2026-11-10")
        #expect(o != nil)
        #expect(DayKey.key(ordinal: o!) == "2026-11-10")
        #expect(DayKey.ordinal("2026-11-11")! - o! == 1)
        #expect(DayKey.ordinal("2027-01-01")! - DayKey.ordinal("2026-12-31")! == 1)
    }

    @Test func streakCountsUntilYesterdayWithoutBlaming() {
        var p = Progress()
        p.record(summary("2026-11-07"))
        p.record(summary("2026-11-08"))
        p.record(summary("2026-11-09"))
        #expect(p.streak(today: "2026-11-10") == 3)
        p.record(summary("2026-11-10"))
        #expect(p.streak(today: "2026-11-10") == 4)
        #expect(p.streak(today: "2026-11-12") == 0)
    }

    @Test func recordKeepsTheBestOfTheDay() {
        var p = Progress()
        p.record(summary("2026-11-10", score: 70, tilt: 18))
        p.record(summary("2026-11-10", score: 92, tilt: 25))
        p.record(summary("2026-11-10", score: 60, tilt: 20))
        let d = p.days["2026-11-10"]
        #expect(d?.plays == 3)
        #expect(d?.bestScore == 92)
        #expect(d?.range.tiltRight == 25)
        #expect(p.totalPlays == 3)
        #expect(p.totalDays == 1)
    }

    @Test func weeklyRangeIsOldestFirst() {
        var p = Progress()
        p.record(summary("2026-11-10", tilt: 30))
        p.record(summary("2026-11-01", tilt: 10))
        let w = p.weeklyTilt(weeks: 3, today: "2026-11-10")
        #expect(w.count == 3)
        #expect(w[2] > w[1])
    }

    @Test func progressSurvivesEncoding() throws {
        var p = Progress()
        p.record(summary("2026-11-10"))
        p.settings.workReminder = WorkReminder()
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(Progress.self, from: data) == p)
    }

    @Test func workReminderStaysUnderTheSystemLimit() {
        let w = WorkReminder()
        #expect(w.slots.count == 5 * 9)
        let all = WorkReminder(startHour: 0, endHour: 23, weekdays: Set(1...7))
        #expect(all.slots.count <= 60)
        #expect(WorkReminder(startHour: 18, endHour: 10, weekdays: [2]).slots.isEmpty)
    }

    @MainActor
    @Test func sampleDataLooksLikeAFewWeeks() {
        let p = AppModel.sampleProgress(today: "2026-11-10")
        #expect(p.totalDays >= 15)
        #expect(p.hasOnboarded)
    }
}
