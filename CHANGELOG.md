# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Phase 0 GitHub セットアップ完了（2026-05-11）
  - リポジトリ初期化（Private、MIT、Flutter .gitignore）
  - docs/SPECIFICATION.md v1.5 配置
  - docs/adr/0001-flutter-flame-selection.md 配置
  - README.md / CHANGELOG.md 整備
  - .github/PULL_REQUEST_TEMPLATE.md 配置
  - .github/ISSUE_TEMPLATE/{bug,feature}.md 配置
  - .github/workflows/ci.yml 骨組み配置
  - ブランチ運用確立（main=リリース、develop=開発統合）
  - Claude Code Web 環境 polyrush-flutter セットアップ
  - 自動削除設定有効化
- `docs/SPECIFICATION.md` v1.5 を追加（要件定義および基本設計書）
- リポジトリ初期化（README.md、CHANGELOG.md、ADR-0001）
- Phase 0 完全完了（2026-05-15）
  - Flutter プロジェクト初期化（com.nallamanam.polyrush、Android only）
  - 依存関係追加：flame, flutter_riverpod, isar, firebase_core/auth/crashlytics, flame_audio, intl
  - クリーンアーキテクチャ風フォルダ構成（lib/{core,data,domain,game,ui,network,l10n}、test/{unit,widget,golden}）
  - 各フォルダに責務記載の README.md 配置
  - Firebase プロジェクト polyrush-bc19f 作成（Spark プラン）
  - Firebase Authentication 有効化（匿名 + Google）
  - Firebase Crashlytics 有効化
  - Firebase Analytics 有効化
  - lib/firebase_options.dart 生成、lib/main.dart で Firebase 初期化
  - GitHub Actions CI ワークフローが全 PR で緑実行
  - ブランチ保護ルールに Required status checks (flutter ジョブ) を追加
    （※ 個人 Free アカウントの Private リポジトリのため Not enforced、Pro 化で自動有効化）

### Status

- Phase 0 完了、Phase 1（パズル生成エンジン）開始可能

### Changed

- デフォルトブランチを develop に変更
