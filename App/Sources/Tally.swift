// 画面から切り離した、テストできる処理の例。その日のアプリで置き換える。
struct Tally: Equatable, Sendable {
    static let maximum = 9_999

    private(set) var count: Int

    init(count: Int = 0) {
        self.count = min(max(count, 0), Self.maximum)
    }

    mutating func increment() {
        count = min(count + 1, Self.maximum)
    }

    mutating func reset() {
        count = 0
    }
}
