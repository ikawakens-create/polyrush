# Handoff: chore/solution-ascii-diagnostic

- 日付: 2026-06-21
- タスク: 解ASCII + 枠/ピース内訳ダンプ 診断テスト追加

## 1. 環境チェック結果

ブランチ: chore/solution-ascii-diagnostic（develop から手動作成）。
develop の最新コミット d9c3630 を含む。

git log --oneline -3 (作業開始時点):
  d9c3630 docs: ADR-0019 ピースの回転・反転と初期向きランダム化の草案を追加 (#88)
  19745c7 Feature/non triviality filter (#87)
  de9f2d6 Feature/puzzle metrics (#86)

## 2. 作成ファイル一覧

新規:
  test/domain/puzzle/solution_ascii_diagnostic_test.dart — 診断専用テスト（診断のみ・常に pass）

変更:
  docs/handoff/LATEST.md — 本ファイル

lib/ 以下は一切変更なし。

## 3. 削除・変更した既存ファイルと理由

なし。

## 4. テスト結果

flutter analyze: error / warning ゼロ（avoid_print info は既存含む・pre-push hook 通過）
flutter test (診断テスト単体): 1件 pass（00:00）

テスト print 出力（easy seed 1-10 / normal seed 1-10、全文）:

=== Difficulty.easy seed=1  frame=11  pieces=3+4+4=11  (0=赤 1=青 2=緑 3=紫) ===
.1..
.11.
.01.
.00.
2222

=== Difficulty.easy seed=2  frame=11  pieces=4+4+3=11  (0=赤 1=青 2=緑 3=紫) ===
2.
22
0.
00
10
11
1.

=== Difficulty.easy seed=3  frame=11  pieces=4+3+4=11  (0=赤 1=青 2=緑 3=紫) ===
0..
0.2
022
012
11.

=== Difficulty.easy seed=4  frame=11  pieces=4+4+3=11  (0=赤 1=青 2=緑 3=紫) ===
222
11.
11.
0..
00.
0..

=== Difficulty.easy seed=5  frame=10  pieces=3+3+4=10  (0=赤 1=青 2=緑 3=紫) ===
1.2
122
102
00.

=== Difficulty.easy seed=6  frame=11  pieces=4+4+3=11  (0=赤 1=青 2=緑 3=紫) ===
0222
0111
001.

=== Difficulty.easy seed=7  frame=11  pieces=3+4+4=11  (0=赤 1=青 2=緑 3=紫) ===
22..
20..
2011
.011

=== Difficulty.easy seed=8  frame=12  pieces=4+4+4=12  (0=赤 1=青 2=緑 3=紫) ===
.1..
111.
.00.
.00.
2222

=== Difficulty.easy seed=9  frame=11  pieces=4+4+3=11  (0=赤 1=青 2=緑 3=紫) ===
.1..
.11.
0122
0002

=== Difficulty.easy seed=10  frame=11  pieces=4+4+3=11  (0=赤 1=青 2=緑 3=紫) ===
..112
..112
00002

=== Difficulty.normal seed=1  frame=18  pieces=5+5+4+4=18  (0=赤 1=青 2=緑 3=紫) ===
.1111.
310000
33220.
3.22..

=== Difficulty.normal seed=2  frame=17  pieces=4+4+4+5=17  (0=赤 1=青 2=緑 3=紫) ===
...22
...02
..002
.310.
.311.
3331.

=== Difficulty.normal seed=3  frame=17  pieces=4+4+4+5=17  (0=赤 1=青 2=緑 3=紫) ===
...22
...02
..002
.310.
.311.
3331.

=== Difficulty.normal seed=4  frame=18  pieces=4+5+4+5=18  (0=赤 1=青 2=緑 3=紫) ===
12222
1113.
.013.
.0033
.0..3

=== Difficulty.normal seed=5  frame=18  pieces=5+4+4+5=18  (0=赤 1=青 2=緑 3=紫) ===
333332
...022
110002
.110..

=== Difficulty.normal seed=6  frame=19  pieces=5+5+4+5=19  (0=赤 1=青 2=緑 3=紫) ===
2110000
22110..
2.313..
..333..

=== Difficulty.normal seed=7  frame=19  pieces=5+5+4+5=19  (0=赤 1=青 2=緑 3=紫) ===
2110000
22110..
2.313..
..333..

=== Difficulty.normal seed=8  frame=19  pieces=5+5+4+5=19  (0=赤 1=青 2=緑 3=紫) ===
2110000
22110..
2.313..
..333..

=== Difficulty.normal seed=9  frame=19  pieces=5+5+4+5=19  (0=赤 1=青 2=緑 3=紫) ===
..3..
22333
2213.
11110
.0000

=== Difficulty.normal seed=10  frame=18  pieces=5+5+4+4=18  (0=赤 1=青 2=緑 3=紫) ===
2....
2.333
2.103
21100
1100.

## 5. 指示書からの逸脱

システム割当ブランチではなく、chore/solution-ascii-diagnostic を develop から手動作成。
指示書のブランチ名通り。

## 6. PR

なし（§5 指示：「PR は作らない」）。

## 7. 次セッションへの申し送り

1. 診断テスト（solution_ascii_diagnostic_test.dart）は chore/solution-ascii-diagnostic
   ブランチに push 済み。PR は作っていない。Opus がこの出力を確認後、
   次のタスクを判断する想定。

2. easy の観察:
   - easy seed=1,8: 縦長レイアウト。seed=8 は frame=12 と最大。
   - easy seed=2: 非常に縦長（7行×2列）。極端に細い形状。
   - easy seed=5: frame=10 と最小（3+3+4）。

3. normal の観察:
   - normal seed=2 と seed=3 が完全に同一解（seed多様性の問題あり）。
   - normal seed=6,7,8 も完全に同一解（3 seeds が同一）。
   - 回転・反転が無いため同一向きパターンが重複しやすい。ADR-0019 実装が急務。

4. 回転 PR #89（feature/rotation-prototype）はまだマージ待ち。
   本タスクの診断結果を Opus に渡し、回転実装方針の最終確認へ。
