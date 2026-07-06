# Handoff: ⑤a 枠ファースト生成器 新規libモジュール群＋テスト＋ADR（システム割当ブランチ claude/frame-first-lib-modules-rnnqy4）

- 日付: 2026-07-06
- タスク: ADR-0020（枠ファースト生成器）の正式実装のうち ⑤a。新規 lib モジュール群
  （FrameGenerator / enumerateDistinctPieceSets / FrameTiler）とそのテスト、および
  本 ADR ドキュメントを、挙動不変・新規ファイル追加のみで導入。アプリ配線は含まない
  （play_screen 等の統合・トグルは次PR ⑤b）。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -5
798c1f3 test(puzzle): 枠ファースト実現可能性 計測CI を追加（ロードマップ④） (#96)
1859403 fix(flip): ダブルタップ判定を待ちなし方式に変更（②.5/③実機フィードバック対応） (#95)
37af9f3 feat(scramble): ③ スクランブル＋forgiveness統合（ADR-0019 完結） (#94)
54fa519 feat(flip): ②.5 反転UI ダブルタップで左右反転（ADR-0019 追補） (#93)
a040818 test(puzzle): easy forgiveness 計測CI を追加しロードマップを Fable 確定に更新（②a） (#92)
```

`ls lib/domain/puzzle/` で既存 Task 成果物（solver.dart / verified_puzzle_generator.dart /
compact_puzzle_generator_v3.dart ほか）の存在を確認済み。develop はローカルにも
fast-forward 済み。その後 `docs/handoff/LATEST.md`（④の申し送り、PR #96）を読み、
直近文脈（⑤ を Go 判定・⑤a/⑤b 分割方針）を把握した。

**ブランチについて**: 本セッションはシステムにより `claude/frame-first-lib-modules-rnnqy4`
ブランチが割当されており、手動命名（指示書指定の `feature/frame-first-modules`）が
できない状態だった。CLAUDE.md の「システム割当ブランチ」例外に従い、このブランチで
作業した。`git merge-base --is-ancestor origin/develop origin/claude/frame-first-lib-modules-rnnqy4`
で develop 最新（798c1f3）を既に含んでいることを確認済み（このブランチは develop の
HEAD と同一コミットを指しており、追加のマージは不要だった）。

## 2. 作成ファイル一覧（すべて新規）

- `docs/adr/0020-frame-first-generator.md`（ADR本体。指示書の内容をそのまま新規作成）
- `lib/domain/puzzle/frame_generator.dart`（枠生成部。FrameGenerator）
- `lib/domain/puzzle/piece_set_enumerator.dart`（ピースセット列挙部。enumerateDistinctPieceSets）
- `lib/domain/puzzle/frame_tiler.dart`（配置 materialize 部。FrameTiler）
- `test/unit/domain/puzzle/frame_generator_test.dart`
- `test/unit/domain/puzzle/frame_tiler_test.dart`

## 3. 削除/変更した既存ファイル

`docs/handoff/LATEST.md`（本ファイル）のみ。CLAUDE.md 変更禁止リストのファイル
（solver.dart / verified_puzzle_generator.dart / compact_puzzle_generator_v3.dart /
non_trivial_puzzle_generator.dart ほか）には一切触れていない。アプリ配線
（play_screen.dart 等）も変更していない。

## 4. テスト結果

- `flutter analyze --no-fatal-infos`（対象5ファイル）: **エラー・警告ゼロ**。info 3件
  （`frame_generator_test.dart` の `print` 呼び出しに対する `avoid_print` 指摘。PR #96 の
  既存パターンを踏襲したレポート出力のためのもので許容）。所要時間 約17秒。
- `dart format`（対象5ファイル）: 3ファイルに整形差分あり（改行位置のみ、ロジック変更なし）。
  適用後は差分なし。
- `flutter test test/unit/domain/puzzle/frame_generator_test.dart test/unit/domain/puzzle/frame_tiler_test.dart`:
  **7件 pass / 0 fail**（FrameGenerator 3件 + easyバリエーション計測1件 + FrameTiler 3件）。
  所要時間 約2秒。
- `flutter test`（全体）: **687件 pass / 0 fail**（既存680件 → 今回+7件で想定通り）。
  所要時間 約25秒（real 29.5秒）。リグレッションなし。

### easy 枠バリエーションレポート全文（ADR-0020 判断6 計測要件）

```
===== easy 枠バリエーション(判断6・下限0.75) =====
生成 200 / 200 シード, distinct 正準形状 28 種 (下限0.85時の理論値=3種, 下限0.75の理論上限=154種)
```

実測28種は下限0.85時の理論値3種を大きく上回るが、理論上限154種には届いていない
（`FrameGenerator._carveFrame` の除去手順が「隣接数最小のセルをランダム選択」という
貪欲法であり、全彫り方を厳密列挙していないため。理論上限は全列挙時の値）。テストの
期待値（3種より多いこと）は満たしている。⑤bの効果測定・実機評価で必要ならシード数を
増やす、または除去手順の多様化を検討する余地がある（今回は指示書どおりロジック不変）。

## 5. 指示書からの逸脱

なし。6ファイルすべて指示書の内容をそのまま新規作成し、ロジック（探索・列挙・充填率式）は
変更していない。コンパイルエラーもなし。ブランチ名についてはシステム割当ブランチ使用
（1章参照）。

## 6. PR

未作成。理由: このセッションではコードの作成・テスト・handoff更新までを実施し、PR作成は
含めていない（後続でユーザー側から作成、または次回セッションで対応）。ブランチ
`claude/frame-first-lib-modules-rnnqy4` は develop 最新（798c1f3）を含んだ状態で本コミットを
積んでいる。

## 7. 次セッションへの申し送り（⑤b: 生成器統合＋トグル＋効果測定）

1. 今回追加した3モジュール（FrameGenerator / enumerateDistinctPieceSets / FrameTiler）を
   使って、ADR-0020 判断1/2/7/8 に従い `lib/domain/puzzle/frame_first_puzzle_generator.dart`
   （新規）を実装する。公開APIは
   `Result<VerifiedPuzzle, CompactPuzzleError> generate({required Difficulty, required int seed})`
   で V3/NonTrivial と揃える。
2. パイプライン: 枠生成(FrameGenerator) → セット列挙(enumerateDistinctPieceSets) →
   採用判定(countSolutions, 解数1〜3。normal/hardはcomputePuzzleMetricsでstraightCutSeparable
   優先→protrusionRatio最小フォールバック、ADR-0018と同一挙動) → 配置materialize(FrameTiler)。
3. play_screen.dart（2箇所）にコンパイル時constトグル（例 `kUseFrameFirstGenerator`）を追加し、
   既定は当面 V3(NonTrivial) 経路のままとする。V3系ファイルは変更禁止のため、切替は
   play_screen側の呼び出し分岐のみで行うこと。
4. 判断9の効果測定（V3(NonTrivial) と frame-first を並べたCI計測: 充填率・
   straightCutSeparable率・生成成功率・実生成時間・1枠あたり採用可能セット数）を
   新規テストとして追加すること。
5. FrameGenerator.canonicalKey は将来のデイリー配布用の安定枠IDとして設計済み
   （判断4・判断10）だが、⑤bでは未使用。統合時に必要なら流用可。
6. easy枠バリエーションの実測値（28種、理論上限154種）は「4. テスト結果」参照。
   実機評価でバリエーション不足を感じた場合、_carveFrame の除去戦略見直しは
   別途Opus/Fableに相談すること（今回のスコープ外・ロジック変更禁止だった）。
