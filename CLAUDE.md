# CLAUDE.md（enludus-daily のアプリ）

このリポジトリは、enludus-daily で毎日1本作る iOS アプリ（SwiftUI）の1つ。**public**。
手順は `docs/daily-runbook.md`、開発の考え方は `.claude/skills/`（dev-lifecycle / dev-judgment / dev-workflow）、**題材は `idea-fusion`（悩み × エンタメ / エンタメ × エンタメ）、画面の参考は `ui-reference`（StudyReel と流行りのアプリ）、画面と中身と課金の基準は `app-quality-bar`**（見た目は StudyReel のトーン、ゲームの手応えと中身の厚さは五十音マインスイーパー。届かなければ完成にしない）。

## スキルの読み替え（このリポジトリでは、ここが優先）

- **監督の指示（daily-ideas の `director` ラベルの Issue）が、手順書・スキルより優先する**（本人が指揮を任せた。2026-11-09）。下の「してはいけないこと」「上限と止まる条件」はいつも最優先。
- **Vault（personal-knowledge）は使わない。** セッションに付けない方針。スキルの「Vault を読む・更新する」は飛ばし、報告には「Vault: 対象外（daily のセッションには付けない）」と書く。
- **付けてよいリポジトリは2つだけ：** `enludus-daily/daily-ideas` と、その日のアプリのリポジトリ。個人のリポジトリ・`daily-actions`・`daily-app-template` は付けない（テンプレートは public の `git clone` で読むだけ）。
- **daily-actions（CI・上限のガード・検査）は直さない。** 直すのは本人が始める整備用のセッションか、本人がそのセッションで明示的に許したときだけ。アプリのワークフローの `@<SHA>` と `actions-sha` も、同じ条件でだけ変える（`scripts/pin-daily-actions.sh` を使い、その SHA で daily-actions の自己 CI が通っていることを確かめる）。
- **dev-lifecycle 4 のあとで本人に戻す、は省く。** 「課題を探して作り、TestFlight まで出す」ことは本人が前もって承認している（2026-11-03）。ただし下の「止まる条件」に当たったら止める。
- **アプリ名は AI が決めてよい**（本人の許可 2026-11-04）。
- **App Store Connect の設定は、`.github/workflows/asc.yml` と TestFlight の配信（daily-actions の asc。上限のガード付き）を通して変えてよい**（本人の許可 2026-11-04）：内部テストのグループと配信、アプリ名・サブタイトル・カテゴリ・説明・キーワード・URL・宣伝文、提出用のバージョンとビルドの選択、**App 内課金の商品と価格**（`asc.yml` の `products`。本人の許可 2026-11-05。買い切りと自動更新サブスクだけ）。
- **このアプリ（くびふうせん）の審査への提出を AI が行ってよい**（本人の許可 2026-11-11）。ただし `asc.yml`（daily-actions の asc。上限のガード付き）を通してだけ。今の asc に提出の命令はないので、命令ができるまでは出せない（daily-actions に足すのは、本人が始める整備用のセッションで）。App プライバシーの申告・年齢区分は、今までどおり本人が行う。
- **main への直接 push を許す**（1人で作る毎日のアプリのため）。ただし push の前に必ず `scripts/preflight-push.sh` を通す（pre-push フック）。

## してはいけないこと

- 審査への提出（このアプリだけは上の許可のとおり asc.yml を通してよい）、App プライバシーの申告、年齢区分・アプリ本体の価格・配信地域の変更（本人が行う）。App 内課金の商品の削除・審査への提出も本人。App Store Connect の設定を asc.yml / TestFlight の配信以外の方法で変えること
- `git push --no-verify`、フック・検査・上限の無効化、ワークフローの daily-actions の SHA の変更やガードを通らない CI の追加、`DAILY_GUARD_DISABLED` などの Variables / Secrets の変更
- daily-actions・テンプレート・ほかのアプリのリポジトリへの push
- 秘密情報・個人情報をコード・Issue・ログ・コミットメッセージに書くこと
- 外部の依存（SwiftPM のパッケージ）を足すこと。要るなら止めて本人に戻す
- サーバー・ログイン・広告・トラッキング・解析 SDK・個人データの収集。消耗型の App 内課金（ジェム・コインなど。サーバーなしでは残高を守れない）。データは端末の中だけ（プライバシーの申告を「収集なし」に保つため）
- 標準の HTTPS 以外の暗号の実装（輸出規制の申告が変わる。`ITSAppUsesNonExemptEncryption` は NO のまま）

## コミットの作者

コミットの作者は**本人**にする（本人の希望。2026-11-03）。リポジトリを作ったときの最初のコミット（作者がトークンの持ち主＝本人）から名前とメールアドレスを取り、そのリポジトリの git に設定する（`docs/daily-runbook.md` の 6 の 3）。ほかの名前・アドレスは使わない（検査の許可リストにないので CI が止まる）。

## 上限と止まる条件

| | 上限 | どこで守るか |
|---|---|---|
| アプリのリポジトリへの push | 1日 40 回（セッション全体） | `scripts/preflight-push.sh`（pre-push フック） |
| CI の実行 | 1日 40 回、連続 3 回失敗で停止 | daily-actions（SHA 固定）の guard |
| TestFlight へのアップロード | 1日 10 回、連続 2 回失敗で停止 | daily-actions（SHA 固定）の guard |
| App Store Connect の設定（asc.yml） | 1日 20 回、連続 3 回失敗で停止 | daily-actions（SHA 固定）の guard |
| アプリのリポジトリの作成 | 1日 2 回、連続 2 回失敗で停止 | daily-ideas の `create-app-repo.yml`（作成は Actions だけが行う） |

上限は 2026-11-04 に本人の判断で引き上げた（本人がアプリごとに意見を出し、そのたびに直して TestFlight に出すため）。

次のどれかに当たったら、**直すのをやめて**、daily-ideas の今日の Issue に `needs-human` を付けて、状況（何を試したか・エラーの要点・次に本人が見るもの）を書いて終える。
- 同じ失敗（エラーの要点が同じ）が **2 回** 続いた
- 上限に達した（guard の `DAILY_LIMIT` / `CONSECUTIVE_FAILURES`）
- 署名・証明書・App Store Connect の権限のエラー（`docs/signing.md` は daily-actions にある）
- 空いている枠（`daily-ideas/slots.json`）がない
- 検査（scan）が検出し、誤検出かどうか自分で決めきれない

## ビルドとテスト

Linux のセッションでは Xcode が使えない。ビルドとテストは GitHub Actions（`.github/workflows/ci.yml` → daily-actions の再利用ワークフロー。40 桁の SHA で固定）。
- push → CI の結果を `gh api repos/enludus-daily/<repo>/actions/runs` で確かめる。失敗したらログを読んで直す
- テストは振る舞いを書く（`Tests/`、Swift Testing）。画面から処理を切り離してテストできる形にする
- 手元でできる確認：`scripts/scan-sensitive.sh .`、`python3 scripts/tone-check.py`（色のトーン）、`python3 scripts/shot-check.py <screenshots のフォルダ>`（黒い丸・まっ黒な画面）、`python3 -c "import yaml; yaml.safe_load(open('project.yml'))"`

## 状態の言葉

「CI 通過（run の URL）」「TestFlight にアップロードした（ビルド番号）」「処理状況は未確認」を区別して書く。実行していない確認を通ったことにしない。
