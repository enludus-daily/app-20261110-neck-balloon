import UIKit
import StoreKit
import SwiftUI

/// Pro（買い切り）。値段は StoreKit の displayPrice を出す。押し付けない：閉じるをはっきり置く
struct ProView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: LocalizedStringKey?

    var body: some View {
        ZStack {
            // Pro は夜の空：星と月の下に、風船がいくつも浮かぶ
            SkyBackdrop(sky: .night, drift: 0.2)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.16)))
                                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
                        }
                        .accessibilityLabel(Text("閉じる"))
                    }
                    HStack(alignment: .bottom, spacing: 14) {
                        Balloon(tilt: .degrees(-6), glow: 1).frame(height: 96)
                        Balloon(tilt: .degrees(8), glow: 0.4).frame(height: 70)
                        Balloon(tilt: .degrees(-2), glow: 0.7).frame(height: 54)
                    }
                    .frame(maxWidth: .infinity)
                    Text(verbatim: "Neck Balloon Pro").font(Theme.text(13, .heavy)).kerning(0.6).foregroundStyle(Theme.gold)
                    Text("首の 1 分を、毎日ちがう空で。").font(Theme.display(30, .heavy)).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 14) {
                        feature("cloud.sun.fill", "24 コースすべて", "ななめ・回す・夜と星など、Pro の 16 コース。毎日の 1 分が全コースから選ばれます。")
                        feature("chart.xyaxis.line", "1 年の記録と週ごとのグラフ", "首の動いた角度が、週ごとにどう広がったかを見られます。")
                        feature("bell.fill", "仕事中、1 時間ごとの 1 分", "平日の 10〜18 時に、ひと息のお知らせ。")
                        feature("heart.fill", "広告なし・ずっと使える", "1 回の購入で、ファミリー共有にも対応。")
                    }
                    .padding(18)
                    .background(PaperBack(seed: 21, radius: Theme.rMedium))

                    if app.isPro {
                        Label("Pro を使っています", systemImage: "checkmark.seal")
                            .font(Theme.text(15, .bold)).foregroundStyle(Theme.gold)
                    } else if let product = app.store.products.first {
                        Button {
                            Task {
                                busy = true
                                let r = await app.store.purchase(product)
                                busy = false
                                switch r {
                                case .purchased: dismiss()
                                case .pending: message = "購入の承認を待っています"
                                case .failed: message = "購入できませんでした。時間をおいて、もう一度お試しください"
                                case .cancelled: break
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Pro にする")
                                Text(verbatim: product.displayPrice).font(Theme.display(17, .heavy))
                            }
                        }
                        .buttonStyle(PillButtonStyle())
                        .disabled(busy)
                        Text("買い切り。サブスクリプションではありません。").font(Theme.text(12, .medium)).foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text(app.store.loadState == .loading ? LocalizedStringKey("読み込んでいます…") : LocalizedStringKey("いまは購入できません。通信を確かめて、あとでもう一度開いてください"))
                            .font(Theme.text(13, .medium)).foregroundStyle(.white.opacity(0.85))
                        Button { Task { await app.store.load() } } label: { Text("もう一度読み込む") }
                            .buttonStyle(LineButtonStyle())
                    }
                    if let message {
                        Text(message).font(Theme.text(13, .bold)).foregroundStyle(Theme.gold)
                    }
                    Button {
                        Task {
                            busy = true
                            await app.store.restore()
                            busy = false
                            message = app.isPro ? LocalizedStringKey("復元しました") : LocalizedStringKey("復元できる購入が見つかりませんでした")
                        }
                    } label: { Text("購入を復元") }
                    .font(Theme.text(14, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(22)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.skyTime, .night)
        .task { if app.store.products.isEmpty { await app.store.load() } }
    }

    private func feature(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.balloonDeep)
                .frame(width: 32, height: 32).background(Circle().fill(Theme.balloonLight.opacity(0.7)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.display(16, .heavy)).foregroundStyle(Theme.ink)
                Text(detail).font(Theme.text(13)).foregroundStyle(Theme.ink.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// カメラの許可がないとき
struct PermissionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.skyTime) private var sky

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Caption("カメラ")
            Text("カメラの許可がありません").font(Theme.display(26, .heavy)).foregroundStyle(Theme.ink)
            Text("顔の向きを読むためだけにカメラを使います（映像は保存も送信もしません）。許可しなくても、iPhone を傾けるか、指でなぞって同じコースを遊べます。")
                .font(Theme.text(15)).foregroundStyle(Theme.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Balloon(tilt: .degrees(-10)).frame(height: 80)
                Image(systemName: "arrow.left.and.right").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.palette(sky).washDeep)
                CloudRing(fill: 0.6).frame(width: 70)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            Button { app.switchInput(.tilt) } label: { Text("傾けて遊ぶ") }.buttonStyle(PillButtonStyle())
            Button { app.switchInput(.touch) } label: { Text("指で遊ぶ") }.buttonStyle(LineButtonStyle(onPaper: true))
            Button("設定でカメラを許可する") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(Theme.text(14, .bold))
            .foregroundStyle(Theme.palette(sky).washDeep)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .background(PaperBack(seed: 31, radius: Theme.rLarge))
        .padding(20)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SkyBackdrop(sky: sky, drift: 0.6))
        .presentationDetents([.large])
    }
}
