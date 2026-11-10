# daily-app-template

enludus-daily で毎日作る iOS アプリ（SwiftUI）のテンプレート。テンプレートから作ったリポジトリでは、この README をそのアプリの説明に書き換える。

## 中身

| パス | 役割 |
|---|---|
| `project.yml` | XcodeGen の spec。`.xcodeproj` はコミットしない |
| `App/Sources/`, `Tests/` | ひな形のアプリとテスト（Swift Testing） |
| `App/Resources/` | アイコン、アクセントカラー、`PrivacyInfo.xcprivacy` |
| `.github/workflows/ci.yml` | push / PR で daily-actions の `ios-ci.yml` を呼ぶ（40 桁の SHA で固定） |
| `.github/workflows/testflight.yml` | 手動（workflow_dispatch）で `ios-testflight.yml` を呼ぶ（アップロードのあと内部テストに配信） |
| `.github/workflows/asc.yml` | 手動で `ios-asc.yml` を呼ぶ（App Store Connect に名前・説明などを入れる / 最新ビルドを配信） |
| `docs/app-store.json`, `PRIVACY.md` | App Store Connect に入れる情報、プライバシーポリシー |
| `scripts/pin-daily-actions.sh` | daily-actions の SHA を書き換える（整備用のセッションか本人だけ。自己 CI の成功を確かめる） |
| `scripts/new-app.sh` | 名前・表示名・枠（Bundle ID）に書き換える |
| `scripts/preflight-push.sh`, `.githooks/pre-push` | push の前の検査（秘密・個人情報）と1日の上限 |
| `scripts/scan-sensitive.sh` | 検査の複製（正本は daily-actions/scan/。違うと CI が警告） |
| `scripts/make-icon.py` | アイコンを作る（Pillow） |
| `.claude/skills/` | dev-lifecycle / dev-judgment / dev-workflow（naki0227/useful-map から取得） |
| `CLAUDE.md`, `docs/daily-runbook.md` | 毎日のセッションの決まりと手順 |
| `docs/app-store.md` | 審査の危険・本人がすることの記録 |

## 手元（Mac）で開く

```sh
brew install xcodegen   # CI は 2.46.0 で固定
xcodegen generate
open DailyApp.xcodeproj
```

## 版

- Xcode 27.1（ランナー `xcode-27`。GitHub では Preview 扱い）、iOS 18.0 以降、iPhone だけ（iPhone Duo の内側の画面にも合わせる）、Swift 6
- スキルの取得元：`naki0227/personal-knowledge`（Vault、private）の `templates/repo-bootstrap/.claude/skills/` を、本人の整備用セッションで写す（2026-11-05 に app-quality-bar を追加）
