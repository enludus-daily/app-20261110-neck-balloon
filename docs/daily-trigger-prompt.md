# 毎日の予約実行のプロンプト（正本）

予約実行（毎日 22:00 JST、毎回新しいセッション）に渡す文。変えたらここも直す。

予約実行の設定（claude.ai で本人が作成、2026-11-03）：リポジトリは enludus-daily/daily-ideas だけ。コネクタはなし。環境は daily-apps。

---

enludus-daily の毎日のアプリ作りを行う。（正本: https://github.com/enludus-daily/daily-app-template/blob/main/docs/daily-trigger-prompt.md ）

1. enludus-daily/daily-ideas は最初から付いている。ほかに付けてよいのは、手順で作ったその日のアプリのリポジトリだけ（add_repo で付ける）。daily-app-template は付けずに `git clone --depth 1 https://github.com/enludus-daily/daily-app-template` で読む。Vault（personal-knowledge）・個人のリポジトリ・daily-actions は付けない。daily-actions とアプリのワークフローの daily-actions の SHA は変えない。
2. daily-app-template の `CLAUDE.md` と `docs/daily-runbook.md` を読み、その手順どおりに進める。CLAUDE.md の「してはいけないこと」「上限と止まる条件」を必ず守る。
3. 目標は、課題を1つ選び → 小さな SwiftUI アプリを作り → CI を通し → TestFlight に上げ → `docs/app-store.md` を埋めて提出の直前まで整えること。審査への提出と App プライバシーの申告はしない。
4. push の前は必ず pre-push の検査（`scripts/preflight-push.sh`）を通す。`--no-verify` は使わない。
5. コミットの作者は本人にする（runbook の 6 の 3）。本人の希望により、コミットメッセージの末尾に `Co-Authored-By:` や `Claude-Session:` などの行を付けない。
6. 同じ失敗が 2 回続いたら、上限に達したら、署名・権限のエラーが出たら、直すのをやめる。daily-ideas の今日の Issue に `needs-human` を付けて状況を書き、終える。
7. その日のアプリのリポジトリを add_repo で付けられなかったら、作業をやめて、daily-ideas の今日の Issue に `needs-human` を付け、理由を書いて終える。
8. 最後に、runbook の「終わりの報告」の形で、今日の Issue にコメントする。
