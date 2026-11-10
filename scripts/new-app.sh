#!/usr/bin/env bash
# テンプレートから作ったリポジトリを、その日のアプリの名前と枠（Bundle ID）に書き換える。1回だけ実行する。
#
# 使い方: scripts/new-app.sh --name WaterLog --display "みずログ" --slot 003
#   --name    Swift の型名・スキーム名になる英字（大文字始まり、2〜30文字）
#   --display ホーム画面に出る名前（App Store の名前は提出前に本人が決める）
#   --slot    daily-ideas/slots.json で確保した枠（001〜999）→ com.enludus.daily.<slot>
set -euo pipefail

name="" display="" slot=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --display) display="$2"; shift 2 ;;
    --slot) slot="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$name" =~ ^[A-Z][A-Za-z0-9]{1,29}$ ]] || { echo "--name は大文字で始まる英数字 2〜30 文字: '$name'" >&2; exit 2; }
[[ "$slot" =~ ^[0-9]{3}$ ]] || { echo "--slot は 3 桁: '$slot'" >&2; exit 2; }
[ -n "$display" ] || { echo "--display が要ります" >&2; exit 2; }
[[ "$display" != *'"'* && "$display" != *'\'* && "$display" != *'|'* ]] || { echo "--display に \" \\ | は使えません" >&2; exit 2; }

root=$(git rev-parse --show-toplevel); cd "$root"
grep -q 'name: DailyApp' project.yml || { echo "すでに書き換え済みです（project.yml に DailyApp がない）" >&2; exit 1; }

bundle="com.enludus.daily.$slot"
# 表示名だけ先に置き換える（後の DailyApp の一括置換に巻き込まれないように）
sed -i.bak "s|CFBundleDisplayName: DailyApp|CFBundleDisplayName: \"$display\"|" project.yml
sed -i.bak "s|com\.enludus\.daily\.template|$bundle|g" project.yml docs/products.json
for f in project.yml App/Sources/*.swift Tests/*.swift .github/workflows/ci.yml .github/workflows/testflight.yml; do
  sed -i.bak "s/DailyApp/$name/g" "$f"
done
find . -name '*.bak' -not -path './.git/*' -delete
# リポジトリ名と表示名を、提出用の情報・プライバシーポリシーに入れる
repo=$(basename -s .git "$(git config --get remote.origin.url 2>/dev/null || echo "$root")")
for f in docs/app-store.json docs/app-store.md PRIVACY.md; do
  [ -f "$f" ] || continue
  sed -i.bak -e "s|__REPO__|$repo|g" -e "s|__APP_NAME__|$display|g" "$f"
done
find . -name '*.bak' -not -path './.git/*' -delete
git mv App/Sources/DailyAppApp.swift "App/Sources/${name}App.swift"
git mv Tests/DailyAppTests.swift "Tests/${name}Tests.swift"

git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/*.sh

echo "書き換えました: スキーム $name / Bundle ID $bundle / 表示名 $display"
echo "次: README.md・docs/app-store.json・docs/app-store.md・PRIVACY.md を、その日のアプリの内容に書き換える"
