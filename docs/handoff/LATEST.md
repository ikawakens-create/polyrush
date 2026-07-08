⑤完了: frame-first 本番稼働(kUseFrameFirstGenerator=true, PR #99/#100)・枠品質実機確認済み(細長枠解消/同一パズル再登場解消)・hard は数値目標取り下げ実機体感基準へ置換・プリフェッチPRは温存。⑥開始: 本PRで multi-set 実現可能性の計測CIを追加(測ってから組み込む原則)。

# Handoff: multi-set 実現可能性 計測CI 追加(⑥-a)

- 日付: 2026-07-08
- タスク: ⑥-a。実パイプラインの採用ルール(solutionCount in 1..3、normal/hard は
  非separable を良形とみなす)を通した後、1枠から実際に出題できる「異なる採用
  セット」がいくつ取れるかを計測するレポートテストを新規追加。⑥ multi-set 化
  (1枠に対して複数のピースセットを対応させ出題バリエーションを増やす構想)の
  前提を、数字で裏取りする目的。lib 側の変更は無し(新規テスト1ファイル＋本
  handoff の上書きのみ)。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
Fast-forward, develop は 032df22 まで更新済み
$ git log --oneline -5
032df22 feat(puzzle): frame-first 生成器を本番有効化(トグル true 化) (#100)
d72bf0d perf(puzzle): frame-first セット走査シャッフル＋firstTiling先行で高速化(⑤c) (#99)
eaef44c feat(puzzle): FrameFirstPuzzleGenerator統合＋切替トグル＋比較計測(⑤b) (#98)
288e705 feat(puzzle): 枠ファースト生成器の新規libモジュール群＋テスト＋ADR(⑤a) (#97)
798c1f3 test(puzzle): 枠ファースト実現可能性 計測CI を追加(ロードマップ④) (#96)
$ ls lib/domain/puzzle/
README.md  compact_puzzle_generator.dart  compact_puzzle_generator_v2.dart
compact_puzzle_generator_v3.dart  difficulty.dart  frame_connectivity.dart
frame_first_puzzle_generator.dart  frame_generator.dart  frame_tiler.dart
non_trivial_puzzle_generator.dart  piece_set_enumerator.dart
playable_puzzle_generator.dart  polyomino.dart  polyomino_transformer.dart
puzzle_generator.dart  puzzle_generator_selector.dart  puzzle_metrics.dart
solver.dart  verified_puzzle_generator.dart
```

直近コミットに⑤系(#96〜#100)のマージ履歴を確認。`lib/domain/puzzle/` 配下に
既存 Task 成果ファイル(solver.dart / verified_puzzle_generator.dart /
compact_puzzle_generator_v3.dart / frame_first_puzzle_generator.dart ほか)の
存在を確認済み。期待どおりの結果だったため作業続行。

### ブランチについて(システム割当ブランチ・例外適用)

本セッションは開始時点で `claude/multiset-feasibility-ci-7k3lxz` ブランチが
システムにより既に割当・チェックアウト可能な状態になっており、手動命名
(`feature/frame-first-multiset-measure`)への変更ができなかったため、
CLAUDE.md の「システム割当ブランチ」例外を適用してこのブランチで作業した。

- 作業前に `git merge-base --is-ancestor develop HEAD` で、このブランチが
  develop の最新コミット(032df22)を含む(develop と同一コミットから分岐、
  fast-forward 不要)ことを確認済み。
- PR は base=develop で作成(main は使用しない)。

## 2. 作成/変更ファイル一覧

新規:
- `test/unit/domain/puzzle/frame_first_multiset_report_test.dart`
  - 指示書の全文どおりに追加。ただし CI 起動の注意に従い、既存の
    `frame_first_comparison_report_test.dart` を確認したところ
    `@Tags(['slow'])` 指定が無く通常レーンで走る構成だったため、本ファイルも
    それに合わせて指示書にあった `@Tags(['slow'])` 行と `library;` 行を
    削除し、通常レーンで実行される形にした(逸脱として下記5に明記)。

変更:
- `docs/handoff/LATEST.md`(本ファイル・本タスクの申し送り更新。指定どおり
  LATEST.md を上書き、新規ファイルは作成していない)

## 3. 削除/変更した既存ファイル

上記以外の既存ファイルへの変更なし。CLAUDE.md 変更禁止リストの各ファイル
(solver.dart / v3 / frame_generator.dart / frame_tiler.dart /
piece_set_enumerator.dart / frame_first_puzzle_generator.dart ほか)には
一切触れていない。

## 4. テスト結果

- 新規テスト単体実行 `flutter test test/unit/domain/puzzle/frame_first_multiset_report_test.dart`:
  **1件 pass / 0 fail**。内部タイマー表示 00:42(elapsed 42805 ms)、シェル
  `time` 実測 real 1m8.038s(flutter起動オーバーヘッド込み)。3分の目安を
  超えなかったため、seedCounts(easy 50 / normal 40 / hard 30)は指示書の
  ままとし、引き下げは行っていない。
- 全体 `flutter test`: **695件 pass / 0 fail**。所要時間 実測 real 0m57.941s
  (内部タイマー 00:54)。既存694件(⑤c時点)+本タスクの新規1件で695件と整合。
  リグレッションなし。
- `flutter analyze`(プロジェクト全体): **エラー・警告ゼロ**。info 60件は
  ⑤c/⑤d 時点と同一パターン(既存レポート系テストの `avoid_print` など)。
  本タスクの新規ファイルは `print` 呼び出しに `// ignore: avoid_print` を
  指示書どおり付けているため info 増加ゼロ(60件のまま)。所要時間 約9.6秒
  (`time` 実測 real 13.160s)。

### レポートの print 出力全文

```
=== ⑥ multi-set feasibility report (real pipeline rules) ===
--- easy (seeds=50 framesGenerated=50 distinctFrames=16) ---
tileable   sets/frame : mean=5.0 median=3.0 min=0 max=14
accepted   sets/frame : mean=4.3 median=3.0 min=0 max=12
distinct set-sigs/frm : mean=4.3 median=3.0 min=0 max=12
distinct tiling-sigs  : mean=4.3 median=3.0 min=0 max=12
--- normal (seeds=40 framesGenerated=40 distinctFrames=12) ---
tileable   sets/frame : mean=119.6 median=125.0 min=29 max=259
accepted   sets/frame : mean=88.2 median=72.0 min=20 max=213
accepted&nonSep/frame : mean=60.0 median=39.0 min=13 max=164
distinct set-sigs/frm : mean=88.2 median=72.0 min=20 max=213
distinct tiling-sigs  : mean=88.2 median=72.0 min=20 max=213
--- hard (seeds=30 framesGenerated=30 distinctFrames=14) ---
tileable   sets/frame : mean=321.8 median=294.0 min=39 max=755
accepted   sets/frame : mean=106.7 median=107.0 min=0 max=315
accepted&nonSep/frame : mean=65.2 median=56.0 min=0 max=169
distinct set-sigs/frm : mean=106.7 median=107.0 min=0 max=315
distinct tiling-sigs  : mean=106.7 median=107.0 min=0 max=315
(elapsed 42805 ms)
```

判定(テスト内の assert): normal の少なくとも1枠で distinct 採用構成数の
最大値が2以上であることを確認(`maxDistinctAccepted[normal] = 213 >= 2`)。
easy でも一部の枠(distinct set-sigs max=12)で複数構成が取れており、hard も
同様(max=315)。3難易度とも multi-set 実現可能性は数値上裏付けられた形。

## 5. 指示書からの逸脱

- 指示書原文の新規テストファイルには冒頭に `@Tags(['slow'])` と `library;`
  の2行があったが、■タグ／CI起動の注意 の指示に従い既存の
  `frame_first_comparison_report_test.dart` を確認したところ `@Tags` 指定
  なしで通常レーンに乗る構成だったため、揃える目的でこの2行を削除した。
  (指示書内の「既存が slow タグ無しなら本ファイルの @Tags(['slow']) 行を
  削除して通常レーンに合わせる」との条件分岐に該当する対応。)
- seedCounts の引き下げは実施していない(単体実行が3分を超えなかったため)。
- ブランチ: 指示書は `feature/frame-first-multiset-measure` を develop から
  手動作成する指示だったが、セッション開始時点でシステムが
  `claude/multiset-feasibility-ci-7k3lxz` を既に割当てており手動命名不可
  だったため、CLAUDE.md のシステム割当ブランチ例外を適用しこのブランチで
  作業した(上記「1. 環境チェック結果」参照)。develop 最新コミットを含む
  ことは作業前に確認済み。
- それ以外の逸脱なし。

## 6. PR

作成予定(本セッションの直後)。base=develop。

## 7. 次セッションへの申し送り

- 本タスクは計測のみで lib 側の実装(multi-set 化本体)には着手していない。
  次タスク(⑥-b 想定)では、本レポートの数値(normal/hard で1枠あたり
  distinct 採用構成が二桁〜三桁オーダーで取れる)を前提に、実際に
  「1枠→複数セットの中から選ぶ」仕組みを frame-first 系のどの層に足すかを
  Opus と設計する必要がある。既存の確定資産(frame_first_puzzle_generator.dart
  など)は改造禁止のため、新層を追加する形で設計すること。
- 計測に使った採用ルール(solutionCount in 1..3、normal/hard で
  straightCutSeparable=false を優先)は現行本番ロジックの理解に基づく近似。
  本番の採用ルールと完全一致しているかは要確認(次タスクで frame-first
  本体の採用フィルタ実装を再確認した上で、必要ならレポートのルールを
  追随させる)。
- easy の accepted 平均が低め(mean=4.3)なので、easy で multi-set 化した
  場合の出題バリエーション上限が normal/hard より小さくなる点は留意。
