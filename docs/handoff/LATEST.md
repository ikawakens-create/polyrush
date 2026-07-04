# Handoff: feature/piece-flip（システム割当ブランチ claude/piece-flip-double-tap-19e9vp で実施）

- 日付: 2026-07-04
- タスク: ロードマップ ②.5「反転UI」実装（案A: ダブルタップで反転）

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -3
a040818 test(puzzle): easy forgiveness 計測CI を追加しロードマップを Fable 確定に更新（②a） (#92)
b8ecc08 refactor(play): _applyResult で _result と _orientations をセット更新（PR #89 リグレッション対策） (#91)
88e1cff feat(rotation): ADR-0019 最小プロト トレイのタップで 90 度回転 (#89)

$ git branch -a
  claude/piece-flip-double-tap-19e9vp
* develop
  remotes/origin/chore/frame-ascii-diagnostic
  remotes/origin/chore/shape-desync-diagnostic
  remotes/origin/chore/solution-ascii-diagnostic
  remotes/origin/claude/flutter-setup-prechecks-GCioU
  remotes/origin/claude/handoff-workflow-docs-irczim
  remotes/origin/claude/piece-flip-double-tap-19e9vp
  remotes/origin/claude/puzzle-inspector-tool-5TahP
  remotes/origin/develop
  remotes/origin/main
  remotes/origin/test/next-orientation-sync

$ ls lib/game/play/ lib/ui/screens/play/ test/game/play/
lib/game/play/: confetti_physics.dart feel_config.dart piece_orientation_state.dart
                placement_logic.dart play_haptics.dart
lib/ui/screens/play/: board_preview_screen.dart confetti_overlay.dart piece_tray.dart
                       play_screen.dart tray_layout.dart
test/game/play/: piece_orientation_state_test.dart
```

期待通り。develop の直近コミットは a040818、既存 Task 成果ファイルも存在確認済み。

システム割当ブランチ `claude/piece-flip-double-tap-19e9vp` が develop 最新（a040818）を
`git merge-base --is-ancestor` で含んでいることを確認済み（マージ不要）。
CLAUDE.md の「例外: システム割当ブランチ」規定に従い、このブランチ上で作業した。

## 2. 作成・変更ファイル一覧

- 変更: lib/game/play/piece_orientation_state.dart（flip(index) を追加）
- 変更: lib/ui/screens/play/piece_tray.dart（ダブルタップ手動判定 _handleTap を追加、
  onFlipPiece コールバックを追加）
- 変更: lib/ui/screens/play/play_screen.dart（_onFlipPiece 配線）
- 変更: test/game/play/piece_orientation_state_test.dart（flip テストを1件追加）
- 変更: docs/adr/0019-piece-rotation-flip.md（末尾に追補セクションを追記）
- 変更: docs/handoff/LATEST.md（本ファイル）

## 3. 変更した既存ファイルと理由

- piece_orientation_state.dart: 指示書通り flip(index) を追加。
  PolyominoTransformer.flipHorizontal を呼ぶだけのラップで、確定資産である
  PolyominoTransformer 自体には一切触れていない。
- piece_tray.dart: トレイのタップ検出が自前 Listener のため onDoubleTap が
  使えず、指示書通り Timer によるダブルタップ手動判定（_handleTap）を追加。
- play_screen.dart: _onFlipPiece を追加し PieceTray に配線。_result /
  _orientations や _applyResult には一切触れていない。
- 変更禁止ファイル（polyomino.dart / polyomino_transformer.dart /
  puzzle_generator.dart / solver.dart / compact_puzzle_generator_v2/v3.dart /
  placement_logic.dart / confetti_physics.dart / tray_layout.dart 等）は
  いずれも未変更。

## 4. テスト結果

- `flutter analyze --no-fatal-infos`: エラー・警告ゼロ。info 52件のみ
  （既存の avoid_print / dangling_library_doc_comments。今回の変更由来の
  info は0件）。所要時間 約12.8秒。
- `flutter test`: 671 件 pass / 0 fail（#92 時点 670 件 → 今回 +1 件で
  想定通り 671 件）。
- `flutter test test/game/play/piece_orientation_state_test.dart` 単独実行:
  3 件 pass（fromPuzzle / rotateCw / flip の3テストすべて pass。
  新規追加の「flip を 2 回適用すると元の向きに戻る」を含む）。
- `dart format --output=none --set-exit-if-changed` で変更4ファイルとも
  フォーマット差分なしを確認。

## 5. 指示書からの逸脱

なし。ただしブランチについては下記6を参照(システム割当ブランチの例外を適用)。

## 6. PR

未作成。本セッションはシステムにより `claude/piece-flip-double-tap-19e9vp`
ブランチが強制割当されており、`feature/piece-flip` への手動チェックアウトが
できない環境だったため、CLAUDE.md の「例外: システム割当ブランチ」規定に従い、
develop の最新コミット（a040818）を含むことを確認した上でこのブランチ上で
作業した。PR 作成・base=develop の設定はユーザー（井川さん）側での対応となる。

## 7. 次セッションへの申し送り

1. ②.5（反転UI・ダブルタップ案A）完了。シングルタップ=回転／ダブルタップ=反転
   （_doubleTapMs=250ms の手動判定）。ADR-0019 に追補セクションを追記済み。
2. easy には反転を配らない（回転のみ）方針を維持。反転が必要になるのは主に
   ③ スクランブル導入後の normal/hard。
3. ③ でスクランブル（初期向きランダム化）を実装する際は、必ず解の向き
   （block.orientation）を基準にした回転を配ること。ソース基準で回すと、
   解が反転向きのパズルで「easy は回転のみで必ず解ける」が崩れる
   （ADR-0019 追補に記載済み）。
4. ダブルタップの待ち時間（250ms）は実機の手触り次第で調整・見直しの余地あり
   （ADR-0019 追補に既知トレードオフとして記載）。
