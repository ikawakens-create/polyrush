# Handoff: ⑤c frame-first 性能改善（セット走査順シャッフル＋firstTiling先行）

- 日付: 2026-07-07
- タスク: ADR-0020 の frame-first 生成器（⑤b で統合済み）について、判断9 の実生成計測で
  判明した hard mean 507ms・max 3.3s（V3 は 4ms）の性能課題を、2段構えの改善で緩和した。
  同じ (difficulty, seed) なら結果は決定論的のまま。
  - Step1 `shuffleSets`: `enumerateDistinctPieceSets` の結果を (seed, attempt) 由来のサブ
    シードで Fisher-Yates シャッフルしてから走査（採用セットが列挙順の後方に固まる偏りを解消）。
  - Step2 `tilingFirst`: 走査を `firstTiling` 先行にし、非 separable のときだけ重い
    `countSolutions` を掛ける（separable セットには課さない）。
  - 両スイッチとも既定 `true`（本番＝最終形）。`false` は判断9 の A/B/C 比較計測専用。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -5
eaef44c feat(puzzle): FrameFirstPuzzleGenerator統合＋切替トグル＋比較計測（⑤b） (#98)
288e705 feat(puzzle): 枠ファースト生成器の新規libモジュール群＋テスト＋ADR（⑤a） (#97)
798c1f3 test(puzzle): 枠ファースト実現可能性 計測CI を追加（ロードマップ④） (#96)
1859403 fix(flip): ダブルタップ判定を待ちなし方式に変更（②.5/③実機フィードバック対応） (#95)
37af9f3 feat(scramble): ③ スクランブル＋forgiveness統合（ADR-0019 完結） (#94)
```

`ls lib/domain/puzzle/` で `frame_first_puzzle_generator.dart` ほか既存 Task 成果ファイル
（solver.dart / verified_puzzle_generator.dart / compact_puzzle_generator_v3.dart /
frame_generator.dart / frame_tiler.dart / piece_set_enumerator.dart ほか）の存在を確認済み。
develop はローカルにも fast-forward 済み（288e705 → eaef44c、⑤b の #98 を含む）。
その後 `docs/handoff/LATEST.md`（⑤b の申し送り）を読み、直近文脈（⑤b 完了・normal/hard の
生成コストが重い問題が要検討事項として残っている状態）を把握した。

ブランチは指示通り `git checkout -b feature/frame-first-perf` で develop から手動作成
（システム割当は発生しなかった）。

## 2. 作成/変更ファイル一覧

変更（全文差し替え・指示書どおり2ファイルのみ）:
- `lib/domain/puzzle/frame_first_puzzle_generator.dart`
- `test/unit/domain/puzzle/frame_first_comparison_report_test.dart`
- `docs/handoff/LATEST.md`（本ファイル・本タスクの申し送り更新）

## 3. 削除/変更した既存ファイル

上記以外の既存ファイルへの変更なし。CLAUDE.md 変更禁止リスト・⑤a 確定資産
（piece_set_enumerator.dart / frame_tiler.dart / frame_generator.dart / solver.dart /
puzzle_metrics.dart / compact_puzzle_generator*.dart / puzzle_generator_selector.dart
（`kUseFrameFirstGenerator=false` 不変）ほか）には一切触れていない。

## 4. テスト結果

- `flutter analyze`（プロジェクト全体）: **エラー・警告ゼロ**。info 60件はすべて既存パターン
  踏襲の `avoid_print`（計測レポートの print）・既存の `dangling_library_doc_comments`
  （tray_layout.dart、本タスク対象外）。所要時間 約14秒。
- `dart format`（対象2ファイル）: `frame_first_puzzle_generator.dart` は差分なし。
  `frame_first_comparison_report_test.dart` は `expect(...)` の改行位置のみ整形差分あり
  （ロジック変更なし）。適用後は差分なし。
- `flutter test test/unit/domain/puzzle/frame_first_puzzle_generator_test.dart`:
  **4件 pass / 0 fail**（生成契約テスト difficulty×3 + 決定論1件）。既定を最終形(C)に
  変えても既存の性質ベーステストはそのまま通過。
- `flutter test test/unit/domain/puzzle/frame_first_comparison_report_test.dart`:
  **3件 pass / 0 fail**（difficulty×3 の比較レポート）。所要時間 約22秒。
- `flutter test`（全体）: **694件 pass / 0 fail**（⑤b と同数・リグレッションなし）。
  所要時間 約37秒。

### 比較計測レポート全文（V3 / A(⑤b現状) / B(Step1のみ) / C(Step1+2最終)、各20 seeds）

```
===== 比較計測: easy (20 seeds) =====
  [easy] V3(NonTrivial)      : 成功 20/20 / 充填率 mean=0.717 / separable 65.0% / 生成時間ms mean=2.6 max=20.3 / distinct正準形状 19
  [easy] frameFirst A(5b現状) : 成功 20/20 / 充填率 mean=0.829 / separable 85.0% / 生成時間ms mean=2.6 max=11.1 / distinct正準形状 8
  [easy] frameFirst B(Step1)  : 成功 20/20 / 充填率 mean=0.829 / separable 55.0% / 生成時間ms mean=1.5 max=4.4 / distinct正準形状 8
  [easy] frameFirst C(最終)   : 成功 20/20 / 充填率 mean=0.829 / separable 55.0% / 生成時間ms mean=1.2 max=2.8 / distinct正準形状 8

===== 比較計測: normal (20 seeds) =====
  [normal] V3(NonTrivial)      : 成功 20/20 / 充填率 mean=0.671 / separable 0.0% / 生成時間ms mean=2.6 max=6.3 / distinct正準形状 20
  [normal] frameFirst A(5b現状) : 成功 20/20 / 充填率 mean=0.897 / separable 0.0% / 生成時間ms mean=31.7 max=115.9 / distinct正準形状 12
  [normal] frameFirst B(Step1)  : 成功 20/20 / 充填率 mean=0.897 / separable 0.0% / 生成時間ms mean=3.7 max=11.4 / distinct正準形状 12
  [normal] frameFirst C(最終)   : 成功 20/20 / 充填率 mean=0.897 / separable 0.0% / 生成時間ms mean=3.2 max=9.4 / distinct正準形状 12

===== 比較計測: hard (20 seeds) =====
  [hard] V3(NonTrivial)      : 成功 20/20 / 充填率 mean=0.715 / separable 0.0% / 生成時間ms mean=3.7 max=15.0 / distinct正準形状 20
  [hard] frameFirst A(5b現状) : 成功 20/20 / 充填率 mean=0.896 / separable 0.0% / 生成時間ms mean=420.9 max=2777.4 / distinct正準形状 13
  [hard] frameFirst B(Step1)  : 成功 20/20 / 充填率 mean=0.896 / separable 0.0% / 生成時間ms mean=379.1 max=2759.2 / distinct正準形状 13
  [hard] frameFirst C(最終)   : 成功 20/20 / 充填率 mean=0.896 / separable 0.0% / 生成時間ms mean=285.2 max=2017.0 / distinct正準形状 13
```

観察: easy/normal では Step1(B)・Step1+2(C) とも顕著に速くなった（normal: A mean31.7ms→
C mean3.2ms、V3とほぼ同等）。easy は separable率が A(85.0%)からB/C(55.0%)へ下がっている
点に注意（シャッフルにより「たまたま先頭にあった高separable率セット」に依存しなくなり、
easyの母集団本来の分布に近づいたためと考えられる。easyはフィルタ対象外なので生成成功率・
充填率には影響なし）。

hard は改善したが目標未達: mean 420.9ms(A)→285.2ms(C)、max 2777.4ms(A)→2017.0ms(C)。
指示書の目標（mean<=100ms・max<=500ms）には届いていない。hard は separable率が
A/B/C 全て0.0%のままで、non-separableなセットが（このマシンのこの20seed母集団では）
一つも見つからず、毎回 tilingFirst でも全セットを走査してから protrusion最小の
フォールバックを採用している。シャッフル(Step1)は「早期に非separableへ当たる」ことを
狙った改善だが、非separableな候補自体が存在しない/稀な枠では効果が薄く、tilingFirst
(Step2)による countSolutions 呼び出し削減の効果（A→B, B→Cの差）のみが効いている形。

## 5. 指示書からの逸脱

なし。変更したのは指示された2ファイルのみ（全文差し替え）。⑤a/⑤b確定資産・
puzzle_generator_selector.dart のトグルは無変更。

## 6. PR

未作成。理由: このセッションではコード変更・テスト実行・handoff更新までを実施し、
PR作成はユーザー側のリクエストが必要なため待機。ブランチ `feature/frame-first-perf` は
develop 最新（eaef44c）から作成済みでコミット可能な状態。

## 7. 次セッションへの申し送り

1. hard の C が目標（mean<=100ms/max<=500ms）を満たすかは井川が GitHub CI ログで
   最終確認し、Fable レビューに回す。本セッションのローカル計測では目標未達
   （mean 285.2ms・max 2017.0ms）だが、CI マシンでの数値は変動しうるため最終判断は
   CI ログを優先すること。
2. 目標達成なら次は本番トグル `kUseFrameFirstGenerator` の true 化＋実機評価の
   小PR（別PR）。未達なら、hard で non-separable セットが実質見つからない構造的な
   理由（枠形状 or セット候補の性質）自体の見直しが必要か、Fable/Opus に相談すること。
3. ADR-0020 判断2 手順3 は「決定論的列挙順で最初の合格」から「決定論的シャッフル順で
   最初の合格＋firstTiling先行」へ更新されたため、ADR-0020 への追補（1段落）は
   Fable 承認後に別 docs PR で行う。
