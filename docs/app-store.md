# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.003（使い回しの枠。前のアプリ：app-20261105-koyomi-haiku） |
| アプリ名 | くびふうせん：首のストレッチゲーム（en-US：Neck Balloon: Stretch Game） |
| サポート URL | https://github.com/enludus-daily/app-20261110-neck-balloon/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261110-neck-balloon/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」（暴力・性的表現・ギャンブル・Web 閲覧・ユーザー生成コンテンツ・生成 AI・医療情報の提供なし）→ 4+ の想定。ただし「医療または治療に関する情報」は「なし」（ストレッチの案内だけで、診断や治療を言わない）。API では入れないので本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・壁紙・単純なタイマー・占いではない。首の向きを読んで採点するストレッチのゲーム（24 コース・記録・3 つの入力）
- 既存のアプリとの意味のある違い：首を動かすゲーム（NeckFitPlay・Tilt!・Head Games）は「素早く避ける・捕まえる」反射のアーケード。こちらは「ゆっくり大きく保つほど高得点」の採点、デスクで 1 分のコース、首の動いた範囲の記録、カメラなしの代わり
- 長く使える価値（4.2）：日ごとに変わる 1 分のコースと、首の動いた範囲が週ごとに広がる記録
- 他社の名前・商標・見た目を使っていないか：使っていない（絵はすべて自作の Shape / Canvas。SF Symbols は標準の使い方だけ）
- Apple Intelligence を使う場合、使えない端末での動き：使わない
- 1.4.1（健康・医療）：医療の約束をしない。「治る」「改善」と書かず、「医療機器ではありません」「痛いときはやめる」を画面と説明文に書いた。角度は「めやす」
- 5.1.2(vi)（ARKit の顔のデータ）：顔の追跡で得た頭の向きを、ゲームの操作にだけ使う。保存・送信・第三者への提供なし。プライバシーポリシーに明記（PRIVACY.md）。審査のメモにも書く
- 2.5.x：カメラの許可の文（NSCameraUsageDescription）に用途を書いた。許可しなくても傾け・指で遊べる

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro ¥480（`com.enludus.daily.003.pro`、StoreKit 2、ファミリー共有）。asc.yml の products で App Store Connect に作る
- 理由と比べた表：README の「課金」（勝算の表）

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。カメラの映像は端末の中で角度を取り出して捨てる。開発者は何も受け取らない＝「収集」に当たらない）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] App 内課金 Pro を、このバージョンといっしょに審査に出す（初めての App 内課金）
- [ ] 審査のメモに「カメラは顔の向き（角度）を読むためだけ。保存・送信なし。カメラなしでも 設定 > 遊び方 > 傾ける／指 で遊べる」と書く
- [ ] 審査に提出する
