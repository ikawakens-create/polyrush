#!/bin/bash
# Pre-push checks – mirrors CI (.github/workflows/ci.yml) with Flutter 3.44.0
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

if [ ! -f "${REPO_ROOT}/pubspec.yaml" ]; then
  echo "No pubspec.yaml found, skipping Flutter pre-push checks."
  exit 0
fi

cd "${REPO_ROOT}"

echo "==> dart format (check only)"
dart format --output=none --set-exit-if-changed .

echo "==> flutter analyze"
flutter analyze --no-fatal-infos

echo "==> flutter test"
flutter test
