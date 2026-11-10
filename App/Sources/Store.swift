import Foundation
import Observation
import StoreKit

// App 内課金（StoreKit 2・サーバーなし）。その日のアプリで、商品の並びと Pro の中身を決める。
// 基準は .claude/skills/app-quality-bar/references/money.md。商品は docs/products.json と同じ ID にする。

/// 商品 ID の決まり。Bundle ID から作るので、new-app.sh で名前が変わっても合う。
enum ProductID {
    static func pro(bundleID: String) -> String { bundleID + ".pro" }
    static func pack(_ name: String, bundleID: String) -> String { bundleID + ".pack." + name }
    static func yearly(bundleID: String) -> String { bundleID + ".sub.yearly" }
    static func monthly(bundleID: String) -> String { bundleID + ".sub.monthly" }
}

/// 権利の判定（画面から切り離して、テストできる形にする）
struct Entitlements: Equatable, Sendable {
    /// 持っていれば Pro になる商品（買い切りの Pro、サブスク）
    let proProductIDs: Set<String>
    private(set) var owned: Set<String> = []

    var isPro: Bool { !owned.isDisjoint(with: proProductIDs) }

    func owns(_ productID: String) -> Bool { isPro || owned.contains(productID) }

    mutating func replace(with productIDs: Set<String>) { owned = productIDs }
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased, cancelled, pending, failed
}

/// StoreKit とのやりとり。画面はこれの状態だけを見る。
@MainActor
@Observable
final class PurchaseStore {
    enum LoadState: Equatable { case idle, loading, ready, unavailable }

    private(set) var products: [Product] = []
    private(set) var entitlements: Entitlements
    private(set) var loadState: LoadState = .idle
    let productIDs: [String]
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(productIDs: [String], proProductIDs: Set<String>) {
        self.productIDs = productIDs
        self.entitlements = Entitlements(proProductIDs: proProductIDs)
        // 返金・家族共有・ほかの端末での購入など、アプリの外で起きた変化を受け取る
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
    }

    func load() async {
        loadState = .loading
        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { $0.price < $1.price }
            loadState = loaded.isEmpty ? .unavailable : .ready
        } catch {
            loadState = .unavailable
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owned = Set<String>()
        // currentEntitlements は、返金されたもの・期限切れのサブスクを含まない
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result { owned.insert(transaction.productID) }
        }
        entitlements.replace(with: owned)
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .success(.unverified):
                return .failed
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// 「購入を復元」。審査でも求められる
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
