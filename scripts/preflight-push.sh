#!/usr/bin/env bash
# push の前の検査（.githooks/pre-push から呼ばれる）。通らなければ push しない。
#   1. 1日（JST）の push の上限
#   2. 秘密情報・個人情報の検査（scripts/scan-sensitive.sh。正本は daily-actions/scan/）
# --no-verify で飛ばさないこと（CLAUDE.md）。
set -euo pipefail

root=$(git rev-parse --show-toplevel)
max="${DAILY_MAX_PUSHES:-40}"
state="${DAILY_STATE_DIR:-$HOME/.daily-apps}"
today=$(TZ=Asia/Tokyo date +%Y-%m-%d)
counter="$state/pushes-$today"
mkdir -p "$state"
used=$(cat "$counter" 2>/dev/null || echo 0)
if [ "$used" -ge "$max" ]; then
  echo "preflight: 今日（JST $today）の push の上限 $max 回に達しました。止めて本人に戻してください。" >&2
  exit 1
fi

# pre-push は標準入力で「<local ref> <local sha> <remote ref> <remote sha>」を受け取る
zero=0000000000000000000000000000000000000000
ranges=()
while read -r _lref lsha _rref rsha; do
  [ "$lsha" = "$zero" ] && continue          # 削除の push
  if [ "$rsha" = "$zero" ]; then ranges+=("$lsha"); else ranges+=("$rsha..$lsha"); fi
done
[ ${#ranges[@]} -eq 0 ] && ranges=("")       # 手で実行したとき: 全履歴

for range in "${ranges[@]}"; do
  echo "preflight: scan ${range:-(全履歴)}"
  bash "$root/scripts/scan-sensitive.sh" "$root" "$range"
done

echo $((used + 1)) > "$counter"
echo "preflight: OK（今日の push $((used + 1))/$max）"
