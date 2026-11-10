import Foundation
import UserNotifications

/// お知らせ（自分で設定でオンにしたときだけ。端末の中で予約し、外に送らない）
enum Reminder {
    static let dailyID = "neck-balloon.daily"
    static let workPrefix = "neck-balloon.work."

    /// 予約をすべて作り直す。許可がなければ false
    @MainActor
    static func schedule(daily hour: Int?, work: WorkReminder?) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0 == dailyID || $0.hasPrefix(workPrefix) })
        guard hour != nil || work != nil else { return true }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        let ja = Locale.current.isJapanese

        if let hour {
            let content = UNMutableNotificationContent()
            content.title = ja ? "今日の 1 分" : "Today's minute"
            content.body = ja ? "風船が待っています。首をゆっくり、1 分だけ。" : "Your balloon is waiting. One slow minute for your neck."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger))
        }
        if let work {
            for slot in work.slots {
                let content = UNMutableNotificationContent()
                content.title = ja ? "ひと息、1 分" : "One-minute break"
                content.body = ja ? "画面から目を上げて、首をゆっくり倒しましょう。" : "Look up from the screen and slowly tilt your head."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: slot.hour, minute: 0, weekday: slot.weekday), repeats: true)
                try? await center.add(UNNotificationRequest(identifier: "\(workPrefix)\(slot.weekday)-\(slot.hour)", content: content, trigger: trigger))
            }
        }
        return true
    }
}
