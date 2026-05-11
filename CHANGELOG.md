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

### Changed

- デフォルトブランチを develop に変更
