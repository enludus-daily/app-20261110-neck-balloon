import Foundation

/// 日付の鍵（"2026-11-10"）。端末の暦の日付で数える
enum DayKey {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 日の通し番号（2000-01-01 からの日数）。並びと差を計算するため
    static func ordinal(_ key: String) -> Int? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let d = cal.date(from: c), let base = cal.date(from: DateComponents(year: 2000, month: 1, day: 1)) else { return nil }
        return cal.dateComponents([.day], from: base, to: d).day
    }

    static func key(ordinal: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let base = cal.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        let d = cal.date(byAdding: .day, value: ordinal, to: base) ?? base
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// 1 日の記録
struct DayRecord: Equatable, Sendable, Codable {
    var plays = 0
    var bestScore = 0
    var range = NeckRange()
    var courses: [String] = []
}

/// 設定
struct Settings: Equatable, Sendable, Codable {
    var input: InputMode = .camera
    var size: AngleSize = .small
    var sound = true
    var haptics = true
    /// 前面カメラの左右を入れ替える
    var mirror = false
    /// 毎日のお知らせ（時。nil で切）
    var dailyReminderHour: Int?
    /// Pro：仕事中の 1 時間ごと（平日）
    var workReminder: WorkReminder?
}

/// 仕事中の「1 時間ごとの 1 分」（Pro）
struct WorkReminder: Equatable, Sendable, Codable {
    var startHour = 10
    var endHour = 18
    /// 1 = 日曜 … 7 = 土曜（Calendar の weekday）
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    /// 予約する（曜日, 時）の並び。iOS の予約の上限（64）を超えない
    var slots: [(weekday: Int, hour: Int)] {
        guard startHour <= endHour else { return [] }
        var out: [(weekday: Int, hour: Int)] = []
        for w in weekdays.sorted() {
            for h in startHour...endHour { out.append((weekday: w, hour: h)) }
        }
        return Array(out.prefix(60))
    }
}

/// 端末の中に残すもの（UserDefaults に JSON で 1 つ）
struct Progress: Equatable, Sendable, Codable {
    var hasOnboarded = false
    var days: [String: DayRecord] = [:]
    var settings = Settings()
    var hasSeenPaywall = false
    /// Pro のコースを 1 回だけ試した
    var usedProTrial = false
    var history: [SessionSummary] = []

    mutating func record(_ s: SessionSummary) {
        var d = days[s.date] ?? DayRecord()
        d.plays += 1
        d.bestScore = max(d.bestScore, s.score)
        d.range = d.range.merged(s.range)
        if !d.courses.contains(s.courseID) { d.courses.append(s.courseID) }
        days[s.date] = d
        history.append(s)
        if history.count > 400 { history.removeFirst(history.count - 400) }
    }

    var totalPlays: Int { days.values.reduce(0) { $0 + $1.plays } }
    var totalDays: Int { days.count }

    func didPlay(_ key: String) -> Bool { (days[key]?.plays ?? 0) > 0 }

    /// 続けた日数。今日まだでも、きのうまで続いていれば数える（責めない）
    func streak(today: String) -> Int {
        guard let t = DayKey.ordinal(today) else { return 0 }
        var o = didPlay(today) ? t : t - 1
        var n = 0
        while didPlay(DayKey.key(ordinal: o)) { n += 1; o -= 1 }
        return n
    }

    /// 直近 n 日（古い順）
    func lastDays(_ n: Int, today: String) -> [(key: String, record: DayRecord?)] {
        guard let t = DayKey.ordinal(today) else { return [] }
        return (0..<n).reversed().map { i in
            let k = DayKey.key(ordinal: t - i)
            return (k, days[k])
        }
    }

    /// 期間のいちばん広い範囲
    func range(lastDays n: Int, today: String) -> NeckRange {
        lastDays(n, today: today).reduce(NeckRange()) { $0.merged($1.record?.range ?? NeckRange()) }
    }

    /// 週ごとの範囲の平均（古い順。Pro のグラフ）
    func weeklyTilt(weeks: Int, today: String) -> [Double] {
        guard let t = DayKey.ordinal(today) else { return [] }
        return (0..<weeks).reversed().map { w in
            let ranges = (0..<7).compactMap { days[DayKey.key(ordinal: t - w * 7 - $0)]?.range }
            guard !ranges.isEmpty else { return 0 }
            return ranges.reduce(0) { $0 + $1.tilt + $1.turn + $1.nod } / Double(ranges.count)
        }
    }
}
