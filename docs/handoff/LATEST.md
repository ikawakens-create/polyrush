# Handoff: ④ 枠ファースト計測CI 追加＋重複ピース列挙バグ修正（PR #96 / システム割当ブランチ claude/frame-first-measure-lub6je）

- 日付: 2026-07-05
- タスク: ロードマップ ④「枠ファースト計測CI」。ADR-0020(枠ファースト生成器)候補の
  実現可能性を判断するための計測専用テストを、挙動不変・新規ファイル追加のみで導入。
  その後、PR #96 レビューで判明した計測前提のバグ（後述）を同ブランチに追加修正。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -5
1859403 fix(flip): ダブルタップ判定を待ちなし方式に変更（②.5/③実機フィードバック対応） (#95)
37af9f3 feat(scramble): ③ スクランブル＋forgiveness統合（ADR-0019 完結） (#94)
54fa519 feat(flip): ②.5 反転UI ダブルタップで左右反転（ADR-0019 追補） (#93)
a040818 test(puzzle): easy forgiveness 計測CI を追加しロードマップを Fable 確定に更新（②a） (#92)
b8ecc08 refactor(play): _applyResult で _result と _orientations をセット更新（PR #89 リグレッション対策） (#91)
```

`ls lib/domain/puzzle/` で既存 Task 成果物（solver.dart / verified_puzzle_generator.dart
ほか）の存在を確認済み。develop はローカルにも fast-forward 済み。

**ブランチについて**: 本セッションはシステムにより `claude/frame-first-measure-lub6je`
ブランチが割当されており、手動命名（指示書指定の `feature/frame-first-measure`）が
できない状態だった。CLAUDE.md の「システム割当ブランチ」例外に従い、このブランチで
作業した。`git merge-base --is-ancestor develop HEAD` で develop 最新（1859403）を
既に含んでいることを確認済み（前タスクのケースと異なり、作り直しは不要だった）。
本追加修正も同じブランチ・同じ PR #96 に対して行った。

## 2. 作成・変更ファイル一覧

- 新規: `test/unit/domain/puzzle/frame_first_feasibility_report_test.dart`
  （指示書の内容をそのまま新規作成。ただし「5. 指示書からの逸脱」に記載の
  1点のみ初回セッションで修正。今回の追加修正で `_enumerateSets` を再修正）
- 変更: `docs/handoff/LATEST.md`（本ファイル）

## 3. 削除/変更した既存ファイル

なし。CLAUDE.md 変更禁止リスト（solver.dart / verified_puzzle_generator.dart 等）には
一切触れていない。lib/ 配下への追加もなし（枠生成ロジックはテスト内ヘルパーとして実装、
指示書どおり）。

## 4. テスト結果（今回の追加修正後・最新）

- `flutter analyze --no-fatal-infos test/unit/domain/puzzle/frame_first_feasibility_report_test.dart`:
  エラー・警告ゼロ。info 2件のみ（`avoid_print`。レポート出力の `print` 呼び出しに対する
  既存パターン踏襲の指摘で、他の計測テストと同様のため許容）。所要時間 約12秒。
- `dart format --output=none --set-exit-if-changed`: 差分なし（クリーン）。
- `flutter test test/unit/domain/puzzle/frame_first_feasibility_report_test.dart`:
  **3 件 pass / 0 fail**（easy/normal/hard 各1テスト）。所要時間 約5秒
  （重複ピース除去により候補数が減り、初回セッションの約13秒から短縮）。
  全難易度で打ち切り(truncation) 0 件。
- `flutter test`（全体）: **680 件 pass / 0 fail**（既存677件 → 今回+3件で想定通り、
  件数は初回セッションと同じ）。所要時間 約23秒。リグレッションなし。

### レポート出力全文（Fable 判定用・重複ピース除去後の最新値）

```
===== 枠ファースト計測: easy =====
制約充足 (h,w,n) 候補: [(3, 4, 11)]
枠生成: 成功 10 / 要求 10 (打ち切り 0) / distinct形状 4 / N種 [11]
候補セット数/枠: mean=20 min=20.0 max=20.0  (= candidateSet × countSolutions の総当たり規模)
--- Fable 判定用メトリクス ---
[1] 敷き詰め可能セット/枠: mean=14.0 (完了枠 n=10)
[2] 探索時間/枠(ms): min=4 mean=15 max=38
[3] 解数1〜3(採用基準内)の割合: 120 / 140 = 85.7%

===== 枠ファースト計測: normal =====
制約充足 (h,w,n) 候補: [(4, 5, 17), (4, 5, 18), (4, 5, 19)]
枠生成: 成功 5 / 要求 5 (打ち切り 0) / distinct形状 5 / N種 [17, 18, 19]
候補セット数/枠: mean=816 min=120.0 max=1100.0  (= candidateSet × countSolutions の総当たり規模)
--- Fable 判定用メトリクス ---
[1] 敷き詰め可能セット/枠: mean=205.8 (完了枠 n=5)
[2] 探索時間/枠(ms): min=46 mean=436 max=707
[3] 解数1〜3(採用基準内)の割合: 847 / 1029 = 82.3%

===== 枠ファースト計測: hard =====
制約充足 (h,w,n) 候補: [(4, 6, 21), (4, 6, 22), (5, 5, 22), (5, 5, 23)]
枠生成: 成功 3 / 要求 3 (打ち切り 0) / distinct形状 3 / N種 [22]
候補セット数/枠: mean=660 min=660.0 max=660.0  (= candidateSet × countSolutions の総当たり規模)
--- Fable 判定用メトリクス ---
[1] 敷き詰め可能セット/枠: mean=335.7 (完了枠 n=3)
[2] 探索時間/枠(ms): min=729 mean=1071 max=1315
[3] 解数1〜3(採用基準内)の割合: 519 / 1007 = 51.5%
```

（初回セッションのレポート値は git 履歴（本ファイルの旧版）で参照可能。重複ピース
除去により候補セット数・敷き詰め可能セット数・探索時間はいずれも減少し、採用基準内
比率は微増〜微減している。傾向自体（easy > normal > hard の順で採用基準内比率が
下がる）は変わらない。）

## 5. 指示書からの逸脱・追加修正

### 初回セッション（新規ファイル作成時）

- 指示書原文の `_mean` / `_minL` / `_maxL` は引数を `List<num>` として宣言していたが、
  すべての呼び出し元は `List<double>`（`.map((e) => e.toDouble()).toList()` または
  `frameMs`）を渡していた。Dart の `reduce` はレシーバの実行時型に対して厳密に
  コールバック型を検証するため、`List<num>` として宣言された関数に `List<double>`
  の実体を渡すと `xs.reduce((a, b) => a + b)` のクロージャ型（`num Function(num,num)`
  として推論される）が `List<double>` の `reduce` が要求する
  `double Function(double,double)` のサブタイプにならず、実行時に
  `type '(num, num) => num' is not a subtype of type '(double, double) => double'`
  で即座に fail していた（3グループ全て）。
  修正: 3関数の引数型を `List<num>` → `List<double>`、戻り値型を `num` → `double`
  （`_minL`/`_maxL`）に変更。呼び出し側・ロジック・出力フォーマットは無変更。

### 今回の追加修正（PR #96 レビュー指摘対応）

- `_enumerateSets` が `rec(i, count - 1, ...)`（同一インデックス再利用可）で
  再帰していたため、同一ピースの重複使用を許すマルチセット列挙になっていた。
  現行ゲームルール（V3 の `usedSourceIds`）は1タスク内でピース重複を禁止しており
  （実物ウボンゴも1タスク内は全異種）、計測がルール上ありえないセットを含む状態
  だった。
  修正: `rec(i, count - 1, ...)` → `rec(i + 1, count - 1, ...)` に変更し、
  重複なし（全ピース異種の組み合わせ）の列挙に修正。あわせて関数 doc コメントを
  「重複ありマルチセット」から「重複なし組み合わせ（V3 の usedSourceIds と同じ
  ルール。実物ウボンゴも1タスク内は全異種）」に更新。
  枠生成ロジック・ソルバ呼び出し・レポート出力フォーマット等、他の部分は無変更。
  修正後、候補セット数・敷き詰め可能セット数・探索時間はいずれも減少（上記
  「4. テスト結果」の最新レポート参照）。lib/ 配下は一切触れていない。

その他の逸脱なし。ブランチ名についてはシステム割当ブランチ使用（1章参照）。

## 6. PR

作成済み: https://github.com/ikawakens-create/polyrush/pull/96
（base=develop。今回の追加修正は同 PR の同ブランチに push 済み、PR は自動更新される）

## 7. 次セッションへの申し送り

1. ④の計測結果（上記「4. テスト結果」の最新レポート）を Fable に渡し、⑤（ADR-0020＋
   枠ファースト生成器の正式実装）へ進めるかの Go/NoGo 判断を仰ぐこと。
   **重複ピース除去後の最新値を使うこと**（旧値は git 履歴のみに残る）。
2. 参考情報（Fable 判断用の要点・最新値ベース）:
   - easy: 候補20セット中mean 14個が敷き詰め可能（70%）、探索は数十ms/枠。
   - normal: 候補平均816セット中mean 205.8個が敷き詰め可能、探索平均436ms/枠、
     最大707ms。打ち切りなし。
   - hard: 候補660セット中mean 335.7個が敷き詰め可能、探索平均1071ms/枠、
     最大1315ms。打ち切りなし（時間予算12000msに対し大幅に余裕あり）。
   - 全難易度で「候補セット総当たり」自体は破綻せず完走した。重複ピース除去に
     より候補数・探索時間ともに縮小し、hard も1秒程度/枠に収まっている。
   - 解数1〜3の採用基準内比率は easy 85.7%／normal 82.3％／hard 51.5%と
     難易度が上がるほど下がる傾向は変わらない（hard は解数4以上に頭打ちする
     候補が相対的に多い）。
3. 枠生成ヘルパー（`_carveFrame` 等）はテスト内実装であり、⑤での正式実装時の
   参考実装という位置づけ（指示書どおり lib/ 配下には置いていない）。
4. 今回のバグ2件（`List<num>` reduce の型不整合、重複ピース列挙）はいずれも
   指示書に含まれる新規コード側の問題であり、既存資産には無関係。
   `_enumerateSets` のように「ピース集合」を扱うヘルパーを今後書く際は、
   V3 の `usedSourceIds`（重複禁止）ルールを前提にすることを推奨。
