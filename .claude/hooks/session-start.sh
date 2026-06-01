#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# 1) Install Flutter 3.44.0 (matches CI in .github/workflows/ci.yml)
if [ ! -d /opt/flutter ]; then
  git clone --depth 1 --branch 3.44.0 \
    https://github.com/flutter/flutter.git /opt/flutter
fi

# 2) Ensure flutter / dart are on PATH
ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
ln -sf /opt/flutter/bin/dart    /usr/local/bin/dart

# 3) Warm up the Dart SDK and tool cache
flutter --version  || true
flutter precache --universal || true

# 4) Install pub dependencies if a project manifest is present
if [ -f "${CLAUDE_PROJECT_DIR}/pubspec.yaml" ]; then
  cd "${CLAUDE_PROJECT_DIR}"
  flutter pub get
fi

# 5) Install git pre-push hook so dart format / analyze / test run before every push
GIT_HOOKS_DIR="${CLAUDE_PROJECT_DIR}/.git/hooks"
mkdir -p "${GIT_HOOKS_DIR}"
ln -sf "${CLAUDE_PROJECT_DIR}/.claude/hooks/git-pre-push.sh" \
       "${GIT_HOOKS_DIR}/pre-push"
chmod +x "${GIT_HOOKS_DIR}/pre-push"
