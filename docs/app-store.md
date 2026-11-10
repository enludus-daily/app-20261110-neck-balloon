# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.___ |
| アプリ名 | （毎日のセッションが決める。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/__REPO__/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/__REPO__/blob/main/PRIVACY.md |
| 年齢区分の答え | （暴力・ギャンブル・Web 閲覧・生成 AI などの有無。API では入れないので本人が入力） |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：
- 既存のアプリとの意味のある違い：
- 長く使える価値（4.2）：
- 他社の名前・商標・見た目を使っていないか：
- Apple Intelligence を使う場合、使えない端末での動き：

## 収益の道筋（本人が選ぶ）

- 候補：なし / 投げ銭（StoreKit 2）/ 買い切り（StoreKit 2）/ 広告（AdMob。公開後に AdMob の登録・審査・app-ads.txt・プライバシー申告の変更が要る）
- 理由：

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
