#!/bin/bash
set -euo pipefail

# Code Web（リモート）環境でのみ実行する。ローカルでは何もしない。
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# 1) Flutter 3.44.0 を導入（CI .github/workflows/ci.yml と同じ版）
if [ ! -d /opt/flutter ]; then
  git clone --depth 1 --branch 3.44.0 \
    https://github.com/flutter/flutter.git /opt/flutter
fi

# 2) flutter / dart を PATH に通す
ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
ln -sf /opt/flutter/bin/dart    /usr/local/bin/dart

# 3) SDK とツールキャッシュを温める
flutter --version || true
flutter precache --universal || true

# 4) プロジェクトに pubspec.yaml があれば依存を取得
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "${CLAUDE_PROJECT_DIR}/pubspec.yaml" ]; then
  cd "${CLAUDE_PROJECT_DIR}"
  flutter pub get || true
fi

# 5) push 前チェック用フックをインストール
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}/.git" ]; then
  GIT_HOOKS_DIR="${CLAUDE_PROJECT_DIR}/.git/hooks"
  mkdir -p "${GIT_HOOKS_DIR}"
  ln -sf "${CLAUDE_PROJECT_DIR}/.claude/hooks/git-pre-push.sh" \
         "${GIT_HOOKS_DIR}/pre-push"
  chmod +x "${GIT_HOOKS_DIR}/pre-push"
fi
