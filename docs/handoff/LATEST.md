# Handoff: feature/puzzle-metrics

- 日付: 2026-06-21
- タスク: ADR-0017 PuzzleMetrics 計測専用層の実装

## 1. 環境チェック結果

ブランチ: feature/puzzle-metrics（develop から手動命名）。
develop の最新コミット 6e4eeb4 を含むことを確認済み。

git log --oneline -5 (作業開始時点):
  6e4eeb4 docs: ADR-0017 非自明性メトリクス計測専用層 (PuzzleMetrics) の草案を追加 (#84)
  6187dc5 feat(haptics): プレイ画面に触覚フィードバックを追加 (#83)
  308d8b9 docs: ADR-0016 handoff ファイル方式を導入し CLAUDE.md を更新 (#82)
  6438262 docs: ADR-0015 手触り調整パネルと snapRadius 確定値を記録 (#80)
  d82dfd8 feat(feel): snapRadius のデフォルト値を 0.5 から 0.71 に引き上げ (#79)

ls lib/domain/puzzle/:
  README.md compact_puzzle_generator.dart compact_puzzle_generator_v2.dart
  compact_puzzle_generator_v3.dart difficulty.dart frame_connectivity.dart
  playable_puzzle_generator.dart polyomino.dart polyomino_transformer.dart
  puzzle_generator.dart puzzle_metrics.dart solver.dart
  verified_puzzle_generator.dart

## 2. 作成ファイル一覧

新規:
  lib/domain/puzzle/puzzle_metrics.dart — PuzzleMetrics クラス + computePuzzleMetrics 関数
  test/domain/puzzle/puzzle_metrics_test.dart — ユニットテスト (9件) + レポートテスト (1件)

変更:
  docs/handoff/LATEST.md — 本ファイル

## 3. 削除・変更した既存ファイルと理由

なし（新規ファイル追加のみ。確定資産は未変更）。

## 4. テスト結果

flutter analyze: error ゼロ（info: avoid_print はテストファイルのみ）
flutter test: 554件すべて pass（既存 544件 + 新規 10件）

## 5. 指示書からの逸脱

- ブランチ名: feature/puzzle-metrics（システム割当ではなく手動命名）
- orientationUsageRatio テストの `blockSame` で、当初 id が異なる PolyominoData を
  使ったため == が false になり test が 1件 fail した。
  source に同じインスタンスを orientation にも渡す形に修正して解決。

## 6. PR

作成予定（develop base）

## 7. レポート出力サマリ

EASY (n=100): sym180=0.013, sym90(非null)=0.000, sym90_null=82%, sep=64%, prot=0.135, fill=0.730, ori=0.567, pieces=3
NORMAL(n=100): sym180=0.002, sym90(非null)=0.000, sym90_null=87%, sep=36%, prot=0.116, fill=0.681, ori=0.675, pieces=4
HARD (n=100): sym180=0.005, sym90(非null)=0.032, sym90_null=89%, sep=41%, prot=0.096, fill=0.683, ori=0.650, pieces=5

## 8. 次セッションへの申し送り

1. 非自明性メトリクスは計測のみ実装済み。次は CI レポートを井川+Opus が目視較正し、
   PR#2 で生成フィルタへ組み込む。
2. 回転・反転の欠如が本物ウボンゴとの最大の差。現行ゲームに回転・反転操作が無く、
   ピースは解の向きのまま手渡される。独立 ADR で要対応（大改修、保護対象に及ぶ）。
