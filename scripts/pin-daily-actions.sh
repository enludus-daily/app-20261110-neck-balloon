#!/usr/bin/env bash
# 呼び出し用ワークフローの daily-actions の版（40 桁の SHA）を書き換える。整備用のセッションか本人が使う。
# その SHA で daily-actions の自己 CI が成功していることを確かめてから書き換える。
#
# 使い方: scripts/pin-daily-actions.sh <40桁の SHA> [説明（既定: 今日の日付）]
set -euo pipefail

sha="${1:-}"; note="${2:-$(TZ=Asia/Tokyo date +%F)}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "40 桁の SHA を渡してください: '$sha'" >&2; exit 2; }
[[ "$note" =~ ^[A-Za-z0-9\ ._:/-]{1,60}$ ]] || { echo "説明は英数字と ._:/- だけ、60 文字以内" >&2; exit 2; }

if [ "${SKIP_CI_CHECK:-0}" != 1 ]; then
  result=$(gh api "repos/enludus-daily/daily-actions/actions/workflows/ci.yml/runs?head_sha=$sha&status=completed&per_page=5" \
    --jq '[.workflow_runs[] | .conclusion] | if index("success") then "success" else (.[0] // "none") end')
  [ "$result" = success ] || { echo "その SHA で daily-actions の自己 CI が成功していません（$result）" >&2; exit 1; }
fi

root=$(git rev-parse --show-toplevel); cd "$root"
for f in .github/workflows/ci.yml .github/workflows/testflight.yml .github/workflows/asc.yml; do
  [ -f "$f" ] || continue
  sed -i.bak -E \
    -e "s#(uses: enludus-daily/daily-actions/\.github/workflows/[a-z-]+\.yml)@[0-9a-f]{40}( \# daily-actions .*)?\$#\1@$sha \# daily-actions $note#" \
    -e "s#(actions-sha: )[0-9a-f]{40}#\1$sha#" "$f"
  rm -f "$f.bak"
  [ "$(grep -c "$sha" "$f")" -eq 2 ] || { echo "$f の書き換えに失敗しました（SHA が 2 か所にない）" >&2; exit 1; }
done
echo "daily-actions を $sha（$note）に固定しました"
