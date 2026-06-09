#!/bin/bash
# push 前に CI と同等のチェック（dart format / analyze / test）を走らせる。
# 注意: チェックが失敗しても push はブロックしない（警告のみ）。
#       最終的な合否判定は CI（GitHub Actions）が行う。これは初心者運用で
#       「push できない」事故を避けるための意図的な設計判断。
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

if [ ! -f "${REPO_ROOT}/pubspec.yaml" ]; then
  echo "[pre-push] pubspec.yaml が無いため Flutter チェックをスキップします。"
  exit 0
fi

cd "${REPO_ROOT}"

WARN=0

echo "==> [pre-push] dart format (check only)"
dart format --output=none --set-exit-if-changed . || { echo "[pre-push] 警告: 未フォーマットのファイルがあります。"; WARN=1; }

echo "==> [pre-push] flutter analyze"
flutter analyze --no-fatal-infos || { echo "[pre-push] 警告: analyze で問題が見つかりました。"; WARN=1; }

echo "==> [pre-push] flutter test"
flutter test || { echo "[pre-push] 警告: テストが失敗しました。"; WARN=1; }

if [ "${WARN}" -ne 0 ]; then
  echo "[pre-push] 警告ありで push を続行します（最終判定は CI）。"
fi

exit 0
