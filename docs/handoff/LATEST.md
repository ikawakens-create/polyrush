# Handoff: feature/non-triviality-filter

- 日付: 2026-06-21
- タスク: ADR-0018 非自明性フィルタ実装（separable 棄却＆再生成）

## 1. 環境チェック結果

ブランチ: feature/non-triviality-filter（develop から手動作成）。
develop の最新コミット 86ccc4b を含む。
feature/puzzle-metrics ブランチを merge して puzzle_metrics.dart を取り込んだ。

git log --oneline -5 (作業開始時点):
  86ccc4b docs: ADR-0018 非自明性フィルタ (separable 棄却＆再生成) の草案を追加 (#85)
  6e4eeb4 docs: ADR-0017 非自明性メトリクス計測専用層 (PuzzleMetrics) の草案を追加 (#84)
  6187dc5 feat(haptics): プレイ画面に触覚フィードバックを追加 (#83)
  308d8b9 docs: ADR-0016 handoff ファイル方式を導入し CLAUDE.md を更新 (#82)
  6438262 docs: ADR-0015 手触り調整パネルと snapRadius 確定値を記録 (#80)

## 2. 作成ファイル一覧

新規:
  lib/domain/puzzle/non_trivial_puzzle_generator.dart — NonTrivialPuzzleGenerator ラッパー
  test/domain/puzzle/non_trivial_puzzle_generator_test.dart — テスト（unit + レポート）

変更:
  lib/ui/screens/play/play_screen.dart — CompactPuzzleGeneratorV3 → NonTrivialPuzzleGenerator に差し替え（2箇所）
  docs/handoff/LATEST.md — 本ファイル

取り込み済み（feature/puzzle-metrics merge）:
  lib/domain/puzzle/puzzle_metrics.dart — ADR-0017 計測専用層（確定資産・変更なし）
  test/domain/puzzle/puzzle_metrics_test.dart — 既存テスト（変更なし）

## 3. 削除・変更した既存ファイルと理由

play_screen.dart の変更内容（生成呼び出し差し替えのみ）:
- import compact_puzzle_generator_v3.dart → non_trivial_puzzle_generator.dart に変更
- _loadPuzzle() の CompactPuzzleGeneratorV3.generate → NonTrivialPuzzleGenerator.generate
- _goNext() の CompactPuzzleGeneratorV3.generate → NonTrivialPuzzleGenerator.generate
- それ以外のロジックは一切変更なし

## 4. テスト結果

flutter test: 665件すべて pass（14秒）
flutter analyze: error / warning ゼロ（avoid_print info は既存含む）

レポートテスト出力:
  NORMAL separable_rate: フィルタ前 36.0% → フィルタ後 0.0%（フォールバック 0/100）
  HARD   separable_rate: フィルタ前 41.0% → フィルタ後 0.0%（フォールバック 0/100）

## 5. 指示書からの逸脱

なし。システム割当ブランチは使用せず feature/non-triviality-filter を手動作成。

## 6. PR

PR #87: feature/non-triviality-filter → develop

## 7. 次セッションへの申し送り

1. 非自明性メトリクスは計測→較正→組み込みまで一周完了。
   PuzzleMetrics で計測（ADR-0017）、separable を主指標に較正（井川+Opus 目視）、
   NORMAL/HARD で separable 棄却フィルタを適用（ADR-0018）。
   フィルタ後 separable_rate: NORMAL 0% / HARD 0%（seed 1-100 で確認、フォールバック 0件）。

2. 回転・反転の欠如が本物ウボンゴとの最大の差。独立 ADR で要対応（大改修、保護対象に及ぶ）。
   orientationUsageRatio 約0.6（NORMAL 0.675 / HARD 0.650）が根拠データ。
