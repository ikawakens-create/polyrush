⑥-c完了: A2方式で multi-set を消費側へ配線(kUseMultiSetGenerator=true)。generateSelectedPuzzle の
契約・play_screen は不変のまま、内部で1枠→複数 variant を取得し seed から決定論的に1つ選ぶ。
実機評価で A2 の体感(似た枠でも別パズルに感じるか)を確認予定。A1(枠内巡回)は未実装・open。

# Handoff: multi-set 消費側配線(⑥-c・A2方式・トグル切替)

- 日付: 2026-07-14
- タスク: ⑥-c。既存の唯一の入口 `generateSelectedPuzzle(difficulty, seed) ->
  Result<VerifiedPuzzle, ...>` のシグネチャ・戻り値契約を変えずに、内部で
  `MultiSetPuzzleGenerator`(⑥-b・確定資産)を使う配線を追加した(A2方式)。
  `play_screen.dart` は無変更。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
Already up to date(develop は 48df239 まで)
$ git log --oneline -5
48df239 feat(puzzle): multi-set 生成 capability を追加(B案・ラップ)＋ADR-0021(⑥-b) (#102)
deb6eb3 test(puzzle): multi-set 実現可能性 計測CI を追加(⑥-a) (#101)
032df22 feat(puzzle): frame-first 生成器を本番有効化(トグル true 化) (#100)
d72bf0d perf(puzzle): frame-first セット走査シャッフル＋firstTiling先行で高速化(⑤c) (#99)
eaef44c feat(puzzle): FrameFirstPuzzleGenerator統合＋切替トグル＋比較計測(⑤b) (#98)
$ ls lib/domain/puzzle/
README.md  compact_puzzle_generator.dart  compact_puzzle_generator_v2.dart
compact_puzzle_generator_v3.dart  difficulty.dart  frame_connectivity.dart
frame_first_puzzle_generator.dart  frame_generator.dart  frame_tiler.dart
multi_set_puzzle_generator.dart  non_trivial_puzzle_generator.dart
piece_set_enumerator.dart  playable_puzzle_generator.dart  polyomino.dart
polyomino_transformer.dart  puzzle_generator.dart puzzle_generator_selector.dart
puzzle_metrics.dart  solver.dart  verified_puzzle_generator.dart
```

直近コミットに⑤〜⑥-b系(#96〜#102)のマージ履歴を確認。`lib/domain/puzzle/`
配下に既存 Task 成果ファイル(multi_set_puzzle_generator.dart ほか)の存在を
確認済み。期待どおりの結果だったため作業続行。

### ブランチについて(システム割当ブランチ・例外適用)

本セッションは開始時点で `claude/multi-set-consumer-a2-cmrnp4` ブランチが
システムにより既に割当・チェックアウト可能な状態になっており(harness の
「Git Development Branch Requirements」でこのブランチが指定され「別ブランチ
へ push しない」旨も明記されていた)、指示書どおりの手動命名
(`feature/multi-set-consumer-a2`)への変更が実質不可能だったため、CLAUDE.md
の「システム割当ブランチ」例外を適用してこのブランチで作業した。

- 作業前に `git merge-base --is-ancestor 48df239 HEAD` で、このブランチが
  develop の最新コミット(48df239)を含む(develop と完全同一コミット・差分
  ゼロ)ことを確認済み。
- PR は base=develop で作成する。

## 2. 作成/変更ファイル一覧

新規:
- `test/unit/domain/puzzle/multi_set_consumer_test.dart`
  — 指示書の全文どおりに追加。通常レーン(`@Tags(['slow'])` なし)。

変更:
- `lib/domain/puzzle/puzzle_generator_selector.dart`
  — 指示書の全文どおりに置換。`kUseMultiSetGenerator`(既定 true)・
    `kMultiSetMaxVariants`(6)を追加し、`generateSelectedPuzzle` 内で
    multi-set 経路 → seed 決定論選択(`_pickVariant`)→ frame-first/V3 の
    3経路選択にした。シグネチャ・戻り値契約は変更なし。
- `docs/handoff/LATEST.md`
  — 本ファイル(上書き)。

## 3. 削除/変更した既存ファイル

上記2ファイル以外への変更なし。CLAUDE.md 変更禁止リストの各ファイル
(multi_set_puzzle_generator.dart / frame_first_puzzle_generator.dart /
frame_generator.dart / frame_tiler.dart / piece_set_enumerator.dart ほか)
には一切触れていない。`play_screen.dart` も無変更(指示書の肝の条件を確認
済み: `generateSelectedPuzzle(difficulty: ..., seed: ...)` の呼び出し2箇所
のみで、シグネチャ変更なしのため無改変で成立)。

## 4. テスト結果

- 新規テスト単体実行
  `flutter test test/unit/domain/puzzle/multi_set_consumer_test.dart`:
  **8件 pass / 0 fail**。所要時間 実測 real 約25秒(内部タイマー 00:25)。
- play_screen 系テスト単体実行
  `flutter test test/widget/play/play_screen_test.dart
  test/widget/play/play_screen_orientation_sync_test.dart`:
  **13件 pass / 0 fail**(既存契約に対する非破壊を確認)。
- 全体 `flutter test`: **719件 pass / 0 fail**。所要時間 実測 real
  2m18.189s(内部タイマー 01:58)。既存711件(⑥-b時点)+本タスクの新規8件で
  719件と整合。リグレッションなし。
- `flutter analyze`(プロジェクト全体): **エラー・警告ゼロ**(61 issues は
  すべて既存パターンの info。⑥-b時点と同数・同種)。

## 5. 指示書からの逸脱

- ブランチ: 指示書は `feature/multi-set-consumer-a2` を develop から手動
  作成する指示だったが、セッション開始時点で harness が
  `claude/multi-set-consumer-a2-cmrnp4` を既に割当てており、かつ「別ブラ
  ンチへ push しない」という harness 側の明示指示と競合したため、
  CLAUDE.md のシステム割当ブランチ例外を適用しこのブランチで作業した
  (上記「1. 環境チェック結果」参照)。develop 最新コミットを含む(完全一致)
  ことは作業前に確認済み。
- それ以外の逸脱なし。play_screen.dart への変更は発生していない。

## 6. PR

作成予定(本セッションの直後)。base=develop。

## 7. 次セッションへの申し送り

- 本タスクは A2方式(seed 決定論選択)の配線のみ。A1方式(同一枠を「次へ」
  で巡回する消費モデル)は未実装・未確定のまま open(ADR-0021 判断6 の
  残課題)。
- `kUseMultiSetGenerator` トグルは既定 true。実機評価で体感(似た枠でも
  別パズルに感じるか)が芳しくない場合は false に戻せば ⑤ の frame-first
  単一経路(トグル `kUseFrameFirstGenerator`)にフォールバックする。
- `kMultiSetMaxVariants = 6` は暫定値(⑥-a 計測の中央値を踏まえた控えめな
  上限)。実機評価の結果次第で調整対象。
- `_pickVariant` の撹拌定数(`2654435761`, Knuth 乗数)は「隣接 seed が同じ
  index に偏らない」ための簡易ハッシュ。厳密な統計的性質は未検証(小規模
  な `test/unit/domain/puzzle/multi_set_consumer_test.dart` の「散らばり」
  テストのみで担保)。
- 次タスクでは実機評価のうえ、A1/A2 のどちらを最終方式とするか(または
  両方を選択可能にするか)を Opus と確定し、ADR-0021 を追補すること。
