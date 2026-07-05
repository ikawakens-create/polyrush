# Handoff: ④ 枠ファースト計測CI 追加（システム割当ブランチ claude/frame-first-measure-lub6je）

- 日付: 2026-07-05
- タスク: ロードマップ ④「枠ファースト計測CI」。ADR-0020(枠ファースト生成器)候補の
  実現可能性を判断するための計測専用テストを、挙動不変・新規ファイル追加のみで導入。

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

## 2. 作成・変更ファイル一覧

- 新規: `test/unit/domain/puzzle/frame_first_feasibility_report_test.dart`
  （指示書の内容をそのまま新規作成。ただし下記「5. 指示書からの逸脱」に記載の
  1点のみ修正）
- 変更: `docs/handoff/LATEST.md`（本ファイル）

## 3. 削除/変更した既存ファイル

なし。CLAUDE.md 変更禁止リスト（solver.dart / verified_puzzle_generator.dart 等）には
一切触れていない。lib/ 配下への追加もなし（枠生成ロジックはテスト内ヘルパーとして実装、
指示書どおり）。

## 4. テスト結果

- `flutter analyze --no-fatal-infos test/unit/domain/puzzle/frame_first_feasibility_report_test.dart`:
  エラー・警告ゼロ。info 2件のみ（`avoid_print`。レポート出力の `print` 呼び出しに対する
  既存パターン踏襲の指摘で、他の計測テストと同様のため許容）。所要時間 約11秒。
- `dart format --output=none --set-exit-if-changed`: 新規ファイルに軽微な差分があったため
  `dart format` を適用し、再チェックでクリーンを確認済み。
- `flutter test test/unit/domain/puzzle/frame_first_feasibility_report_test.dart`:
  **3 件 pass / 0 fail**（easy/normal/hard 各1テスト）。所要時間 約13秒。
  全難易度で打ち切り(truncation) 0 件。
- `flutter test`（全体）: **680 件 pass / 0 fail**（既存677件 → 今回+3件で想定通り）。
  所要時間 約26秒。リグレッションなし。

### レポート出力全文（Fable 判定用）

```
===== 枠ファースト計測: easy =====
制約充足 (h,w,n) 候補: [(3, 4, 11)]
枠生成: 成功 10 / 要求 10 (打ち切り 0) / distinct形状 4 / N種 [11]
候補セット数/枠: mean=30 min=30.0 max=30.0  (= candidateSet × countSolutions の総当たり規模)
--- Fable 判定用メトリクス ---
[1] 敷き詰め可能セット/枠: mean=18.0 (完了枠 n=10)
[2] 探索時間/枠(ms): min=6 mean=14 max=39
[3] 解数1〜3(採用基準内)の割合: 160 / 180 = 88.9%

===== 枠ファースト計測: normal =====
制約充足 (h,w,n) 候補: [(4, 5, 17), (4, 5, 18), (4, 5, 19)]
枠生成: 成功 5 / 要求 5 (打ち切り 0) / distinct形状 5 / N種 [17, 18, 19]
候補セット数/枠: mean=1410 min=420.0 max=1820.0  (= candidateSet × countSolutions の総当たり規模)
--- Fable 判定用メトリクス ---
[1] 敷き詰め可能セット/枠: mean=325.2 (完了枠 n=5)
[2] 探索時間/枠(ms): min=119 mean=619 max=968
[3] 解数1〜3(採用基準内)の割合: 1324 / 1626 = 81.4%

===== 枠ファースト計測: hard =====
制約充足 (h,w,n) 候補: [(4, 6, 21), (4, 6, 22), (5, 5, 22), (5, 5, 23)]
枠生成: 成功 3 / 要求 3 (打ち切り 0) / distinct形状 3 / N種 [22]
候補セット数/枠: mean=2730 min=2730.0 max=2730.0  (= candidateSet × countSolutions の総当たり規模)
--- Fable 判定用メトリクス ---
[1] 敷き詰め可能セット/枠: mean=1068.0 (完了枠 n=3)
[2] 探索時間/枠(ms): min=2267 mean=3226 max=3908
[3] 解数1〜3(採用基準内)の割合: 1753 / 3204 = 54.7%
```

## 5. 指示書からの逸脱

1点のみ、実行不能なバグの修正:

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
  枠生成ロジック・列挙ロジック・ソルバ呼び出し等、計測の中身に関わる部分は
  指示書のまま一切変更していない。

その他の逸脱なし。ブランチ名についてはシステム割当ブランチ使用（1章参照）。

## 6. PR

未作成。本セッションはシステムにより `claude/frame-first-measure-lub6je` ブランチが
割当されており、develop 最新を既に含んでいたためそのまま作業した。PR 作成・
base=develop の設定はユーザー（井川さん）側での対応となる。

## 7. 次セッションへの申し送り

1. ④の計測結果（上記レポート全文）を Fable に渡し、⑤（ADR-0020＋枠ファースト
   生成器の正式実装）へ進めるかの Go/NoGo 判断を仰ぐこと。
2. 参考情報（Fable 判断用の要点）:
   - easy: 候補30セット中mean 18個が敷き詰め可能（60%）、探索は数十ms/枠。
   - normal: 候補平均1410セット中mean 325個が敷き詰め可能、探索平均619ms/枠、
     最大968ms。打ち切りなし。
   - hard: 候補2730セット中mean 1068個が敷き詰め可能、探索平均3226ms/枠、
     最大3908ms。打ち切りなし（時間予算12000msに対し余裕あり）。
   - 全難易度で「候補セット総当たり」自体は破綻せず完走した。ただし hard は
     1枠あたり3〜4秒かかっており、⑤で「枠生成→複数枠試行」のループを組む場合は
     この所要時間が実装方式（何枠試すか、リアルタイム生成か事前生成か）に効いてくる
     点に留意。
   - 解数1〜3の採用基準内比率は easy 88.9%／normal 81.4%／hard 54.7%と難易度が
     上がるほど下がる（hard は解数4以上に頭打ちする候補が相対的に多い）。
3. 枠生成ヘルパー（`_carveFrame` 等）はテスト内実装であり、⑤での正式実装時の
   参考实装という位置づけ（指示書どおり lib/ 配下には置いていない）。
4. 今回のバグ（`List<num>` reduce の型不整合）は指示書に含まれる新規コード側の
   問題であり、既存資産には無関係。今後同種のヘルパー関数を書く際は、
   `List<num>` を経由する集計関数は避け、呼び出し側の実際の型（`List<double>` /
   `List<int>` 等）に合わせて宣言することを推奨。
