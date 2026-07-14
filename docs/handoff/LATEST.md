⑥-b完了: MultiSetPuzzleGenerator を新規追加(B案・確定資産不変)。1枠→最大K個の相異なる採用セット(variant)を best-effort で返す capability。消費側配線(⑥-c)は未着手＝消費モデルは実機評価で確定(open)。ADR-0021 起草・frame-first系4ファイル＋新ファイルを frozen登録。

# Handoff: multi-set 生成 capability の追加(⑥-b・B案・ラップ)＋ADR-0021

- 日付: 2026-07-09
- タスク: ⑥-b。既存の確定資産(FrameGenerator / enumerateDistinctPieceSets /
  FrameTiler / PuzzleSolver.countSolutions / computePuzzleMetrics)を一切変更
  せず、新規ファイル `MultiSetPuzzleGenerator` でラップし、1枠から相異なる
  採用セット(variant)を最大K個 best-effort で返す capability を追加。
  消費側配線(⑥-c)は本タスクのスコープ外(open のまま)。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
Fast-forward、develop は deb6eb3 まで更新済み
$ git log --oneline -5
deb6eb3 test(puzzle): multi-set 実現可能性 計測CI を追加(⑥-a) (#101)
032df22 feat(puzzle): frame-first 生成器を本番有効化(トグル true 化) (#100)
d72bf0d perf(puzzle): frame-first セット走査シャッフル＋firstTiling先行で高速化(⑤c) (#99)
eaef44c feat(puzzle): FrameFirstPuzzleGenerator統合＋切替トグル＋比較計測(⑤b) (#98)
288e705 feat(puzzle): 枠ファースト生成器の新規libモジュール群＋テスト＋ADR(⑤a) (#97)
$ ls lib/domain/puzzle/
README.md  compact_puzzle_generator.dart  compact_puzzle_generator_v2.dart
compact_puzzle_generator_v3.dart  difficulty.dart  frame_connectivity.dart
frame_first_puzzle_generator.dart  frame_generator.dart  frame_tiler.dart
non_trivial_puzzle_generator.dart  piece_set_enumerator.dart
playable_puzzle_generator.dart  polyomino.dart  polyomino_transformer.dart
puzzle_generator.dart  puzzle_generator_selector.dart  puzzle_metrics.dart
solver.dart  verified_puzzle_generator.dart
```

直近コミットに⑤〜⑥-a系(#96〜#101)のマージ履歴を確認。`lib/domain/puzzle/`
配下に既存 Task 成果ファイル(solver.dart / verified_puzzle_generator.dart /
compact_puzzle_generator_v3.dart / frame_first_puzzle_generator.dart ほか)
の存在を確認済み。期待どおりの結果だったため作業続行。

### ブランチについて(システム割当ブランチ・例外適用)

本セッションは開始時点で `claude/multi-set-puzzle-generator-26l545` ブランチ
がシステムにより既に割当・チェックアウト可能な状態になっており(harness の
「Git Development Branch Requirements」でこのブランチが指定され「別ブランチ
へ push しない」旨も明記されていた)、指示書どおりの手動命名
(`feature/multi-set-generator`)への変更が実質不可能だったため、CLAUDE.md の
「システム割当ブランチ」例外を適用してこのブランチで作業した。

- 作業前に `git merge-base --is-ancestor develop HEAD` で、このブランチが
  develop の最新コミット(deb6eb3)を含む(develop と完全同一コミット・差分
  ゼロ)ことを確認済み。
- PR は base=develop で作成する。

## 2. 作成/変更ファイル一覧

新規:
- `lib/domain/puzzle/multi_set_puzzle_generator.dart`
  — 指示書の全文どおりに追加。既存 API のみを利用するラップ実装(B案)。
- `test/unit/domain/puzzle/multi_set_puzzle_generator_test.dart`
  — 指示書の全文どおりに追加。通常レーン(`@Tags(['slow'])` なし)。
- `docs/adr/0021-multi-set-generator.md`
  — 指示書の全文どおりに追加。

変更:
- `CLAUDE.md`
  — 「既存ファイル変更ポリシー」リストへ、`lib/game/play/placement_logic.dart`
    行の直前に frame-first 系4ファイル＋本タスクの新規ファイルの計5行を
    指示書どおりに追記。既存行は変更していない。
- `docs/handoff/LATEST.md`
  — 本ファイル(上書き)。

## 3. 削除/変更した既存ファイル

上記以外の既存ファイルへの変更なし。CLAUDE.md 変更禁止リストの各ファイル
(solver.dart / v3 / frame_generator.dart / frame_tiler.dart /
piece_set_enumerator.dart / frame_first_puzzle_generator.dart ほか)には
一切触れていない。ラップ可能だったため、B案からの逸脱(確定資産の改変)は
発生しなかった。

## 4. テスト結果

- 新規テスト単体実行
  `flutter test test/unit/domain/puzzle/multi_set_puzzle_generator_test.dart`:
  **16件 pass / 0 fail**。所要時間 実測 real 約30秒(内部タイマー 00:30)。
- 全体 `flutter test`: **711件 pass / 0 fail**。所要時間 実測 real 1m31.283s
  (内部タイマー 01:10)。既存695件(⑥-a時点)+本タスクの新規16件で711件と
  整合。リグレッションなし。
- `flutter analyze`(プロジェクト全体): **エラー・警告ゼロ**(61 issues は
  すべて既存パターンの info。`avoid_print` の既存テスト群、および本タスクの
  新規テスト内ヘルパー `math_max` に対する
  `non_constant_identifier_names` info が1件追加。エラー・警告は0件)。

## 5. 指示書からの逸脱

- ブランチ: 指示書は `feature/multi-set-generator` を develop から手動作成
  する指示だったが、セッション開始時点で harness が
  `claude/multi-set-puzzle-generator-26l545` を既に割当てており、かつ
  「別ブランチへ push しない」という harness 側の明示指示と競合したため、
  CLAUDE.md のシステム割当ブランチ例外を適用しこのブランチで作業した
  (上記「1. 環境チェック結果」参照)。develop 最新コミットを含む(完全一致)
  ことは作業前に確認済み。
- それ以外の逸脱なし。ラップ不能(確定資産の改変が必要)と判明した箇所は
  無かったため、作業停止・ユーザー報告は発生していない。

## 6. PR

作成予定(本セッションの直後)。base=develop。

## 7. 次セッションへの申し送り

- 本タスクは capability の追加のみ。消費側配線(⑥-c: play_screen 等から
  `MultiSetPuzzleGenerator` をどう呼ぶか・「同じ枠を巡回」か「1構成を
  ランダム出題」か等の消費モデル)は未着手・未確定(ADR-0021 判断6 = open)。
  次タスクでは実機評価のうえ消費モデルを Opus と確定し、ADR-0021 を追補
  すること。
- `MultiSetPuzzleGenerator` の採用判定ロジック(非separable優先・
  protrusionRatio 昇順フォールバック)は `FrameFirstPuzzleGenerator` と
  一部重複している(ADR-0021 判断1・B案の許容範囲)。将来、生成層を一本化
  する際の棚卸し対象(ADR-0013 判断7 と合わせて検討)。
- frame-first 系4ファイル(frame_generator / frame_tiler /
  piece_set_enumerator / frame_first_puzzle_generator)および本タスクの
  新規ファイルを CLAUDE.md の変更禁止リストへ登録済み。以後これらへの改良
  は新層を足す形で行うこと。
