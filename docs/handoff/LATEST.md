# Handoff: ⑤b FrameFirstPuzzleGenerator 統合＋切替トグル＋比較計測（システム割当ブランチ claude/frame-first-integration-9jhs54）

- 日付: 2026-07-06
- タスク: ADR-0020 判断1/2/7/8/9 に従い、⑤a で追加した3モジュール
  （FrameGenerator / enumerateDistinctPieceSets / FrameTiler）を使って
  `FrameFirstPuzzleGenerator` を実装し、コンパイル時トグル
  （`puzzle_generator_selector.dart` / `kUseFrameFirstGenerator`）経由で
  play_screen から V3(NonTrivial) 経路と切替できるようにした。既定は
  false（従来の V3 経路）のため本 PR で実挙動は変わらない。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -5
288e705 feat(puzzle): 枠ファースト生成器の新規libモジュール群＋テスト＋ADR（⑤a） (#97)
798c1f3 test(puzzle): 枠ファースト実現可能性 計測CI を追加（ロードマップ④） (#96)
1859403 fix(flip): ダブルタップ判定を待ちなし方式に変更（②.5/③実機フィードバック対応） (#95)
37af9f3 feat(scramble): ③ スクランブル＋forgiveness統合（ADR-0019 完結） (#94)
54fa519 feat(flip): ②.5 反転UI ダブルタップで左右反転（ADR-0019 追補） (#93)
```

`ls lib/domain/puzzle/` で既存 Task 成果物（solver.dart / verified_puzzle_generator.dart /
compact_puzzle_generator_v3.dart / frame_generator.dart / frame_tiler.dart /
piece_set_enumerator.dart ほか）の存在を確認済み。develop はローカルにも fast-forward
済み。その後 `docs/handoff/LATEST.md`（⑤a の申し送り、PR #97）を読み、直近文脈
（⑤a 完了・⑤b で統合＋トグル＋計測を行う方針）を把握した。

**ブランチについて**: 本セッションはシステムにより `claude/frame-first-integration-9jhs54`
ブランチが割当されており、手動命名（指示書指定の `feature/frame-first-integration`）が
できない状態だった。CLAUDE.md の「システム割当ブランチ」例外に従い、このブランチで
作業した。`git merge-base --is-ancestor develop HEAD` で develop 最新（288e705）を
既に含んでいることを確認済み（このブランチは develop の HEAD と同一コミットを
指しており、追加のマージは不要だった）。

## 2. 作成/編集ファイル一覧

新規:
- `lib/domain/puzzle/frame_first_puzzle_generator.dart`
- `lib/domain/puzzle/puzzle_generator_selector.dart`
- `test/unit/domain/puzzle/frame_first_puzzle_generator_test.dart`
- `test/unit/domain/puzzle/frame_first_comparison_report_test.dart`

編集:
- `lib/ui/screens/play/play_screen.dart`（呼び出し口2箇所を `generateSelectedPuzzle(...)`
  に差し替え＋import を `non_trivial_puzzle_generator.dart` → `puzzle_generator_selector.dart`
  に入替。それ以外の行は無変更）
- `docs/handoff/LATEST.md`（本ファイル）
- `docs/handoff/HANDOFF_ROADMAP_solo_v1.md`（⑤ 行の状態を「新規」→「完了」に更新）

## 3. 確定資産の変更なし確認

CLAUDE.md 変更禁止リストのファイル（solver.dart / verified_puzzle_generator.dart /
compact_puzzle_generator(_v2/_v3).dart / non_trivial_puzzle_generator.dart /
puzzle_generator.dart / difficulty.dart / polyomino(_transformer).dart /
puzzle_metrics.dart ほか）には一切触れていない。⑤a の3モジュール
（frame_generator.dart / frame_tiler.dart / piece_set_enumerator.dart）も確定資産として
一切変更していない（読んで API を確認したのみ）。play_screen.dart は指示された
「呼び出し口2箇所の差し替え＋import入替」以外の行は変更していない。

## 4. テスト結果

- `flutter analyze`（プロジェクト全体）: **エラー・警告ゼロ**。info 60件はすべて
  既存パターン踏襲の `avoid_print`（計測レポートの print 出力）・既存の
  `dangling_library_doc_comments`（tray_layout.dart、本タスク対象外）。所要時間 約15秒。
- `dart format`（対象5ファイル）: 3ファイル（`frame_first_puzzle_generator_test.dart` /
  `frame_first_comparison_report_test.dart` / `play_screen.dart`）に整形差分あり
  （改行位置・空行のみ、ロジック変更なし）。適用後は差分なし。
- `flutter test test/unit/domain/puzzle/frame_first_puzzle_generator_test.dart test/unit/domain/puzzle/frame_first_comparison_report_test.dart`:
  **7件 pass / 0 fail**（生成契約テスト difficulty×3 + 決定論1件 + 比較計測レポート
  difficulty×3）。所要時間 約31.5秒。
- `flutter test`（全体）: **694件 pass / 0 fail**（既存687件 → 今回+7件で想定通り）。
  所要時間 約31秒。リグレッションなし。

### 比較計測レポート全文（ADR-0020 判断9・V3 vs frame-first、各20 seeds）

```
===== 比較計測: easy (20 seeds) =====
  [easy] V3(NonTrivial): 成功 20/20 / 充填率 mean=0.717 / separable 65.0% / 生成時間ms mean=4.5 max=42.3 / distinct正準形状 19
  [easy] frame-first   : 成功 20/20 / 充填率 mean=0.829 / separable 85.0% / 生成時間ms mean=3.1 max=18.7 / distinct正準形状 8

===== 比較計測: normal (20 seeds) =====
  [normal] V3(NonTrivial): 成功 20/20 / 充填率 mean=0.671 / separable 0.0% / 生成時間ms mean=3.9 max=15.2 / distinct正準形状 20
  [normal] frame-first   : 成功 20/20 / 充填率 mean=0.897 / separable 0.0% / 生成時間ms mean=40.8 max=149.4 / distinct正準形状 12

===== 比較計測: hard (20 seeds) =====
  [hard] V3(NonTrivial): 成功 20/20 / 充填率 mean=0.715 / separable 0.0% / 生成時間ms mean=4.0 max=15.2 / distinct正準形状 20
  [hard] frame-first   : 成功 20/20 / 充填率 mean=0.896 / separable 0.0% / 生成時間ms mean=507.6 max=3301.9 / distinct正準形状 13
```

観察: frame-first は easy/normal/hard いずれも充填率が V3 より高い（枠を先に
「ずんぐり良形」に絞ってから敷き詰めるため）。easy は separable率も V3(65.0%)より
frame-first(85.0%)の方が高い（non-separableを狙う normal/hard とは逆に、easyは
フィルタなしでそのまま採用するため、枠形状の効果がそのまま出ている）。一方で
生成時間は normal で mean 40.8ms(V3の約10倍)、hard では mean 507.6ms・max 3.3秒
（V3の約100倍以上）と大幅に重い。これは normal/hard で
straightCutSeparable==false のセットが見つからず、枠×セットの全走査
（enumerateDistinctPieceSets の組み合わせ全部 × countSolutions）が末尾まで
毎回実行された上でフォールバック採用しているため（frame-first の separable率が
両難易度とも0.0%）。実機評価前にこの生成コストが許容範囲か Opus 判断が必要。

distinct正準形状数は frame-first の方が V3 より少なめ（easy: 8 vs 19、normal:
12 vs 20、hard: 13 vs 20）。これは枠バリエーションが FrameGenerator の
_carveFrame（貪欲除去）由来であり、⑤a 申し送り済みの「実測28種／理論上限154種」
とも整合する傾向（十分だが理論上限には届いていない）。

## 5. 指示書からの逸脱

なし。4ファイルすべて指示書の内容をそのまま新規作成し、play_screen.dart は
呼び出し口2箇所の差し替え＋import入替のみ。ロジック（探索順・採用条件・
フォールバック方針）は変更していない。コンパイルエラーもなし。ブランチ名は
システム割当ブランチを使用（1章参照、develop最新を含むことを確認済み）。

## 6. PR

未作成。理由: このセッションではコードの作成・テスト・handoff更新までを実施し、
PR作成は含めていない（ユーザー側から作成、または次回セッションで対応）。ブランチ
`claude/frame-first-integration-9jhs54` は develop 最新（288e705）を含んだ状態で
本コミットを積んでいる。

## 7. 次セッションへの申し送り

1. 本 PR は `kUseFrameFirstGenerator = false` のままマージされる想定（挙動不変）。
   実機評価で frame-first に切り替える判断が出たら、
   `lib/domain/puzzle/puzzle_generator_selector.dart` の1行
   （`const bool kUseFrameFirstGenerator = false;`）を true に変えるだけで
   切替できる。将来 runtime 設定（デバッグパネル等）に昇格する場合は
   このファイルが唯一の入口なので改修範囲が小さい。
2. **要検討事項（Opus 判断が必要）**: 比較計測（4章）で判明した通り、
   frame-first は normal/hard で生成コストが V3 の10〜100倍以上重い
   （hard で mean 507.6ms・max 3.3秒/1パズル）。原因は
   straightCutSeparable==false のセットが見つからず、毎回
   enumerateDistinctPieceSets の全候補 × countSolutions を末尾まで
   走査してからフォールバック採用しているため。実機切替前にこの
   コストが許容範囲か、あるいは探索順・枝刈りの見直しが要るかを
   Opus に相談すること（本 PR のスコープ外・ロジック変更禁止だったため
   このまま報告のみ）。
3. distinct正準形状数（枠バリエーション）は frame-first の方が V3 より
   少なめ（4章参照）。⑤a 申し送りの _carveFrame 除去戦略見直しと
   合わせて検討の余地がある。
4. マルチセット化（ロードマップ⑥）は本 PR の frame-first パイプライン
   （enumerateDistinctPieceSets が複数セットを列挙している）を前提に
   設計されており、⑤完了により着手可能な状態になった。
