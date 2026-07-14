⑦-pre完了: ピース変形アニメを追加（回転=180ms 平面回転 / 反転=260ms Y軸カード裏返し＋中間で
陰影）。UI層(piece_tray.dart)に閉じて実装し、ドメイン・play_screen・当たり判定は不変。
ADR-0019 待ちなし方式との競合は反転時に回転アニメをキャンセルして回避。鏡像バグ回避のため
t>=0.5 で angle=π*t-π ＋ 描画内容を反転後へ差し替える方式を採用。タイミング定数は実機体感で調整予定。

# Handoff: ピース変形アニメーション（⑦-pre・回転=平面回転／反転=Y軸カード裏返し）

- 日付: 2026-07-14
- タスク: ⑦-pre。ピースのトレイタップ時の見た目を「回転＝平面内でくるっと回る」
  「反転＝Y軸まわりのカード裏返し」に分離し、どちらの操作が起きたかが見た目だけで
  判別できるようにする。ドメイン（PieceOrientationState）・play_screen.dart・
  当たり判定ロジックは無変更。UI層 `lib/ui/screens/play/piece_tray.dart` 内に
  閉じたレイヤーとして実装した（B案の精神）。

## 1. 環境チェック結果

```
$ git fetch origin
$ git checkout develop && git pull origin develop
Updating 48df239..e9044f0 (fast-forward)
$ git log --oneline -5
e9044f0 feat(puzzle): multi-set 消費側配線(A2方式・トグル切替)(⑥-c) (#103)
48df239 feat(puzzle): multi-set 生成 capability を追加(B案・ラップ)＋ADR-0021（⑥-b） (#102)
deb6eb3 test(puzzle): multi-set 実現可能性 計測CI を追加(⑥-a) (#101)
032df22 feat(puzzle): frame-first 生成器を本番有効化（トグル true 化） (#100)
d72bf0d perf(puzzle): frame-first セット走査シャッフル＋firstTiling先行で高速化（⑤c） (#99)
$ ls lib/domain/puzzle/
README.md  compact_puzzle_generator.dart  compact_puzzle_generator_v2.dart
compact_puzzle_generator_v3.dart  difficulty.dart  frame_connectivity.dart
frame_first_puzzle_generator.dart  frame_generator.dart  frame_tiler.dart
multi_set_puzzle_generator.dart  non_trivial_puzzle_generator.dart
piece_set_enumerator.dart  playable_puzzle_generator.dart  polyomino.dart
polyomino_transformer.dart  puzzle_generator.dart  puzzle_generator_selector.dart
puzzle_metrics.dart  solver.dart  verified_puzzle_generator.dart
```

develop が #103（multi-set 消費側配線）まで進んでいることを確認。
`lib/domain/puzzle/` 配下に既存 Task 成果ファイル一式の存在を確認済み。
期待どおりの結果だったため作業続行。

### ブランチについて（システム割当ブランチ・例外適用）

本セッションは開始時点で `claude/piece-transform-animation-juy319` ブランチが
システムにより既に割当・チェックアウト可能な状態になっており、指示書どおりの
手動命名（`feature/piece-transform-animation`）への変更が実質不可能だったため、
CLAUDE.md の「システム割当ブランチ」例外を適用してこのブランチで作業した。

- 作業前に `git merge-base --is-ancestor e9044f0 HEAD` で、このブランチが
  develop の最新コミット（e9044f0）を含む（develop と完全同一コミット・
  差分ゼロ）ことを確認済み。
- PR は base=develop で作成する。

## 2. 作成/変更ファイル一覧

新規:
- `test/widget/play/piece_tray_animation_test.dart`
  — 指示書のテスト要件（6項目）を満たす widget テスト。PieceTray を
    play_screen 相当のロジック（rotateCw / rotateCcw+flip）で駆動する
    最小ハーネス（`_Harness`）を同ファイル内に用意。

変更:
- `lib/ui/screens/play/piece_tray.dart`
  — アニメ層を追加。詳細は「3. 実装の要点」参照。
- `docs/handoff/LATEST.md`
  — 本ファイル（上書き）。

## 3. 削除/変更した既存ファイル・実装の要点

`lib/domain/puzzle/` 配下（確定資産）・`lib/game/play/piece_orientation_state.dart`・
`lib/ui/screens/play/play_screen.dart` は一切変更していない。変更は
`lib/ui/screens/play/piece_tray.dart` のみ。

- `_PieceTrayState` に `with TickerProviderStateMixin` を付与し、
  ピースごとに回転用・反転用の `AnimationController` を
  `Map<int, AnimationController>` で保持（遅延生成、`dispose()` で全破棄、
  `didUpdateWidget` でパズル差し替え時に破棄・再初期化）。
- `_handleTap` で、1回目のタップ（回転）発火時に「反転前の形」
  （＝回転適用前の `widget.orientationOf(i)`）を `_flipBeforeOrientation` に
  確保してから `widget.onTapPiece` を呼ぶ。2回目のタップ（反転）発火時は
  この確保済みの値を「反転前」として使う（ADR-0019 待ちなし方式では、
  2回目のタップ時点の `orientationOf` は既に回転後の値になっているため、
  そのまま使うと「回転後の形→反転後の形」という誤った遷移になってしまう。
  これは指示書に明記された落とし穴（要件A）で、実装時に見つけて回避した）。
- 反転発火時は進行中の回転アニメを即座に `value=1.0` へスナップ（中間状態を
  残さず破棄）してから反転アニメを開始する。逆に回転発火時も反転アニメを
  同様にスナップする（相互排他）。
- 回転アニメ: `Transform.rotate`（`alignment: Alignment.center` 明示）で
  -90°→0°（`Curves.easeOutCubic`、180ms）。描画内容は常に
  `widget.orientationOf(i)`（新しい向き）。
- 反転アニメ: `Transform` + `Matrix4`（`setEntry(3,2,0.001)` で perspective、
  `rotateY`）で 260ms・`Curves.easeInOut`。鏡像バグ回避のため、進捗 t が
  0.5 未満は「反転前」の形・angle=π*t、0.5 以上は「反転後」の形
  （`widget.orientationOf(i)`）・angle=π*t-π を描画。t に応じた
  `shade = 1.0 - 0.35*sin(π*t)` を `PiecePainter` に渡し、
  `Color.lerp(baseColor, Colors.black, 1-shade)` で暗さを表現。
- レイアウト（`AnimatedSize`・`Padding`・hitboxPad・当たり判定計算）は無変更。
  `CustomPaint` の `size` は常に現在の `orientationOf(i)` 基準で、
  アニメの進行状況に左右されない（要件B）。
- ドラッグ開始時（`_onPointerMove` の掴み分岐）に `_snapAnimationsToEnd` を
  追加し、進行中のアニメを即座に終了状態へスナップしてからドラッグに入る
  （要件C）。ポインタ処理・座標計算自体は無変更。
- `PiecePainter` に `shade`（既定 1.0）パラメータを追加し、`shouldRepaint`
  にも比較を追加。
- タイミング・強度定数（`_rotateAnimMs=180`, `_flipAnimMs=260`,
  `_flipShadeDepth=0.35`）はファイル冒頭に `const` で切り出し済み。

## 4. テスト結果

- 新規テスト単体実行
  `flutter test test/widget/play/piece_tray_animation_test.dart`:
  **6件 pass / 0 fail**。所要時間 実測 real 約29秒。
- play 系 widget テスト
  `flutter test test/widget/play/`:
  **18件 pass / 0 fail**（既存 play_screen 系 12件 + 新規 6件、
  リグレッションなし）。実測 real 約8.6秒。
- 全体 `flutter test`: **725件 pass / 0 fail**。所要時間 実測 real
  2m02.759s。既存719件（⑥-c時点）+ 本タスクの新規6件で725件と整合。
  リグレッションなし。
- `flutter analyze`（プロジェクト全体）: **エラー・警告ゼロ**（62 issues は
  すべて既存パターンの info。変更ファイル2件を個別に
  `flutter analyze lib/ui/screens/play/piece_tray.dart
  test/widget/play/piece_tray_animation_test.dart` した結果は
  「No issues found!」）。
- `dart format` 適用済み（`piece_tray.dart` / `piece_tray_animation_test.dart`）。

## 5. 指示書からの逸脱

- ブランチ: 指示書は `feature/piece-transform-animation` を develop から
  手動作成する指示だったが、セッション開始時点で harness が
  `claude/piece-transform-animation-juy319` を既に割当てていたため、
  CLAUDE.md のシステム割当ブランチ例外を適用しこのブランチで作業した
  （上記「1. 環境チェック結果」参照）。develop 最新コミットを含む
  （完全一致）ことは作業前に確認済み。
- 反転前の形のキャッシュ方式について: 指示書は「didUpdateWidget 等で更新」
  という実装例を示していたが、待ちなし方式（ADR-0019）では2回目のタップ
  到達時点で既に1回目の回転がドメイン状態に反映済みのため、単純に
  「直近ビルド時の orientationOf」をキャッシュする方式では、フレーム
  タイミング次第で「反転前」が誤って回転後の値になりうると判断した。
  そのため「1回目のタップ（ミューテーション前）の時点で明示的に確保する」
  方式を採用した。指示書が意図した効果（反転前の形を正しく保持する）は
  達成しているが、実装手段は指示書の例と異なる。テスト
  `piece_tray_animation_test.dart` の「反転アニメの中間では〜」テストで
  この点を検証済み。
- それ以外の逸脱なし。ドメイン・play_screen・当たり判定コードへの変更は
  発生していない。

## 6. PR

作成予定（本セッションの直後）。base=develop。

## 7. 次セッションへの申し送り

- タイミング定数（`_rotateAnimMs=180` / `_flipAnimMs=260` /
  `_flipShadeDepth=0.35`）は実機体感での調整対象。すべて
  `piece_tray.dart` 冒頭の `const` に切り出し済みなのでその場で調整できる。
- 反転アニメの「反転前の形」は 1 回目のタップ時点でキャッシュする方式
  （上記「5. 指示書からの逸脱」参照）。ADR-0019 待ちなし方式を変更する
  場合はこのキャッシュ方式の妥当性を再確認すること。
- 回転アニメは新しい形の bounding box をそのまま -90°→0° で回すため、
  非正方形ピース（例: 直線系）では回転中に描画がレイアウト枠から
  はみ出て見える可能性がある（Transform は描画のみでクリップしないため）。
  指示書の要件B（レイアウト不変・Transformは描画のみ）どおりの意図的な
  トレードオフだが、実機評価ではみ出しが気になる場合は要検討。
