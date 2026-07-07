# Handoff: frame-first 生成器の本番有効化（kUseFrameFirstGenerator = true）

- 日付: 2026-07-07
- タスク: ⑤c（PR #99）マージ済み・Fable 承認を受け、`puzzle_generator_selector.dart` の
  トグル `kUseFrameFirstGenerator` を `false` → `true` に変更（1行のみ）。
  これにより本番の生成経路が V3(NonTrivial) から frame-first（ADR-0020）に切り替わる。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -5
d72bf0d perf(puzzle): frame-first セット走査シャッフル＋firstTiling先行で高速化（⑤c） (#99)
eaef44c feat(puzzle): FrameFirstPuzzleGenerator統合＋切替トグル＋比較計測（⑤b） (#98)
288e705 feat(puzzle): 枠ファースト生成器の新規libモジュール群＋テスト＋ADR（⑤a） (#97)
798c1f3 test(puzzle): 枠ファースト実現可能性 計測CI を追加（ロードマップ④） (#96)
1859403 fix(flip): ダブルタップ判定を待ちなし方式に変更（②.5/③実機フィードバック対応） (#95)
```

直近コミットに「⑤c frame-first セット走査シャッフル…」(#99) のマージを確認。
`ls lib/domain/puzzle/` で既存 Task 成果ファイル（solver.dart / verified_puzzle_generator.dart /
compact_puzzle_generator_v3.dart / frame_first_puzzle_generator.dart ほか）の存在を確認済み。
その後 `docs/handoff/LATEST.md`（⑤c の申し送り）を読み、直近文脈（hard の性能改善は
目標未達だが Fable が実機評価優先で本番トグル true 化を承認済み、という状態）を把握した。

### ブランチについて（システム割当ブランチ・例外適用）

本セッションは Code Web のシステムにより `claude/enable-frame-first-generator-jhffku`
ブランチが強制割当され、手動命名（`feature/enable-frame-first` 等）が不可能だったため、
CLAUDE.md の「システム割当ブランチ」例外を適用してこのブランチのまま作業した。

- 作業前に `git merge-base --is-ancestor d72bf0d(developの最新) HEAD` で、このブランチが
  develop の最新コミットを含む（=develop と同一コミット、fast-forward 不要）ことを確認済み。
- PR は base=develop で作成（main は使用していない）。

## 2. 作成/変更ファイル一覧

変更（指示どおり1ファイル・1行のみ）:
- `lib/domain/puzzle/puzzle_generator_selector.dart`
  - `const bool kUseFrameFirstGenerator = false;` → `= true;`
  - dartdoc コメント・他コードは無変更。

- `docs/handoff/LATEST.md`（本ファイル・本タスクの申し送り更新）

## 3. 削除/変更した既存ファイル

上記以外の既存ファイルへの変更なし。CLAUDE.md 変更禁止リストの各ファイル
（compact_puzzle_generator_v2/v3.dart、solver.dart、verified_puzzle_generator.dart ほか）
には一切触れていない。

## 4. テスト結果

- `flutter analyze`（プロジェクト全体）: **エラー・警告ゼロ**。info 60件は⑤c 時点と
  同一のパターン（`avoid_print`（計測レポート系テストの print）・`tray_layout.dart` の
  `dangling_library_doc_comments`、いずれも本タスク対象外・既知）。所要時間 約13秒。
- `flutter test`（全体）: **694件 pass / 0 fail**。所要時間 約62秒
  （テストランナー内部タイマー表示は 00:41、シェル `time` 実測 real 1m2.161s）。
  生成器が frame-first に切り替わったことによる既存テストの落ちは無し
  （`kUseFrameFirstGenerator` / `generateSelectedPuzzle` を直接参照するテストは
  存在せず、個々の生成器テストは各生成器を直接呼んでいるため今回のトグル変更の
  影響を受けない構成だった）。
- 比較計測レポート（`frame_first_comparison_report_test.dart`、参考値・本タスクでの
  変更対象ではない）: hard は mean=306.0ms/max=2179.0ms で、⑤c 完了時点
  （mean=285.2ms/max=2017.0ms）と同水準（マシン負荷による揺らぎの範囲内）。

## 5. 指示書からの逸脱

- ブランチ: 指示書は `feature/enable-frame-first` を手動作成する指示だったが、
  本セッションはシステム割当ブランチ `claude/enable-frame-first-generator-jhffku` を
  強制され手動命名不可だったため、CLAUDE.md のシステム割当ブランチ例外を適用し
  このブランチで作業した（上記「1. 環境チェック結果」参照）。develop 最新コミットを
  含むことは作業前に確認済み。
- それ以外の逸脱なし。変更したのはトグル1行のみ。

## 6. PR

作成予定（本セッションの直後）。base=develop、Squash merge 前提。

## 7. 次セッションへの申し送り

【実機評価チェックリスト（井川さんが APK で確認）】

a. 各難易度（easy/normal/hard）で「次へ」を10回以上連打し、引っかかりの有無を確認
b. 特に hard。ローカル計測の2〜5倍遅くなる前提で体感を見る（生成中の一瞬の固まり）
c. 枠の形が「ずんぐり良形」になったか（細長い枠が消えたか）を主観評価
d. 同じ枠・同じパズルの再登場が減ったかを主観評価

判定基準（Fable 確定）: アルゴリズム速度ではなく「『次へ』タップ時に引っかかりを
感じないこと」。引っかかりが出た場合の第一候補対策は「次パズルのプリフェッチ
（現パズル解答中に裏で次を生成）」。その場合は別 PR で設計に入る。
