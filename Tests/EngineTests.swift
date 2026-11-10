import Foundation
import Testing
@testable import NeckBalloon

/// 決まった動き（関数）をエンジンに 30 回/秒で流す
private func drive(_ course: Course, size: AngleSize = .small, until limit: Double = 400, pose: (Double) -> HeadPose) -> StretchSession {
    var s = StretchSession(course: course, size: size)
    var t = 0.0
    while t <= limit, !s.isFinished {
        s.update(pose: pose(t), at: t)
        t += 1.0 / 30
    }
    return s
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
        #expect(s.results.allSatisfy { $0.held >= $0.move.holdSeconds })
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
        #expect(s.results.allSatisfy(\.timedOut))
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
        #expect(s.range.down >= 20)
        #expect(s.range.turnRight >= 28)
    }

    @Test func circlesFlowWithoutReturningToCenter() {
        let c = CourseLibrary.course(id: "two-circles")!
        let motion = ScriptedMotion(course: c, size: .small)
        let s = drive(c) { motion.pose(at: $0) }
        #expect(s.isFinished)
        #expect(s.results.allSatisfy { !$0.timedOut })
    }

    @Test(arguments: AngleSize.allCases)
    func everyCourseCanBeFinishedAtEverySize(size: AngleSize) {
        for c in CourseLibrary.all {
            let motion = ScriptedMotion(course: c, size: size)
            let s = drive(c, size: size) { motion.pose(at: $0) }
            #expect(s.isFinished, "\(c.id) \(size)")
            #expect(s.score >= 80, "\(c.id) \(size) \(s.score)")
        }
    }

    @Test func scriptedRunStopsInTheMiddleForScreenshots() {
        let motion = ScriptedMotion(course: course, size: .small)
        let s = motion.run(until: 16.2, course: course, size: .small)
        #expect(!s.isFinished)
        #expect(s.index >= 1)
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
        #expect(CourseLibrary.all.filter(\.isPro).count == 16)
        #expect(Set(CourseLibrary.all.map(\.id)).count == CourseLibrary.all.count)
    }

    @Test func everyCourseIsAboutAMinuteOrTwo() {
        for c in CourseLibrary.all {
            #expect((25...150).contains(c.estimatedSeconds), "\(c.id) \(c.estimatedSeconds)")
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
