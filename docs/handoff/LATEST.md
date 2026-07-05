# Handoff: ダブルタップ判定を「待ちなし方式」に変更（システム割当ブランチ claude/polyrush-scramble-forgiveness-sfgqt7）

- 日付: 2026-07-05
- タスク: ②.5/③ の実機フィードバック対応。ダブルタップ（反転）判定を
  「待ちあり方式」（Timer で回転を保留）から「待ちなし方式」（即回転＋
  再タップで回転取消し＋反転）に切り替える。

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -3
37af9f3 feat(scramble): ③ スクランブル＋forgiveness統合（ADR-0019 完結） (#94)
54fa519 feat(flip): ②.5 反転UI ダブルタップで左右反転（ADR-0019 追補） (#93)
a040818 test(puzzle): easy forgiveness 計測CI を追加しロードマップを Fable 確定に更新（②a） (#92)
```

PR #94（③スクランブル）はマージ済み確認済み。

**ブランチの再作成について**: 前タスクで使用したシステム割当ブランチ
`claude/polyrush-scramble-forgiveness-sfgqt7` に対応する PR #94 は
squash マージ済みだった（`git merge-base --is-ancestor <旧ブランチ tip> origin/develop`
が false、develop 側のコミットハッシュが別物）。CLAUDE.md のマージ済みブランチの
取り扱いに従い、同名ブランチを develop 最新（37af9f3）から
`git checkout -B claude/polyrush-scramble-forgiveness-sfgqt7 origin/develop` で
作り直し、その上で本タスクの作業を行った。

## 2. 作成・変更ファイル一覧

- 変更: `lib/game/play/piece_orientation_state.dart`
  （`rotateCcw(index)` を新規追加。`rotate90` を 3 回適用するだけのラップ）
- 変更: `lib/ui/screens/play/piece_tray.dart`
  （Timer による回転保留（`_tapTimer` / `_pendingTapIndex`）を廃止し、
  「即回転＋直前タップとの時刻差でダブルタップ判定」方式に書き換え。
  `_doubleTapMs` を 125 → 300 に変更。ドラッグ開始時の保留解消ロジックを
  タップ記録クリアに簡素化（`_cancelPendingTapForDragStart` →
  `_clearTapRecordForDragStart`）。未使用になった `dart:async` の import を削除）
- 変更: `lib/ui/screens/play/play_screen.dart`
  （`_onFlipPiece` を「rotateCcw で直前の回転を打ち消してから flip する」処理に変更。
  `_applyResult` のセット更新構造には触れていない）
- 変更: `test/game/play/piece_orientation_state_test.dart`
  （`rotateCcw` のテストを2件追加）
- 変更: `docs/adr/0019-piece-rotation-flip.md`
  （待ちなし方式への切替を追補として追加。廃止理由・新方式の仕様・
    既知のトレードオフを記載）
- 変更: `docs/handoff/HANDOFF_ROADMAP_solo_v1.md`
  （⑧ の行に反転モーション演出を追記）
- 変更: `docs/handoff/LATEST.md`（本ファイル）

## 3. 変更した既存ファイルと理由

- `piece_orientation_state.dart`: 指示書通り `rotateCcw` を追加。既存の
  `rotateCw` / `flip` / `fromPuzzle` / `scrambled` はすべて不変更。確定資産
  PolyominoTransformer は不触。
- `piece_tray.dart`: 待ちあり方式は「判定窓を短くすると反転が不安定、長くすると
  回転がもっさりする」ジレンマが実機評価で判明したため、Fable 判断で待ちなし方式
  に切替。Timer 関連の状態（`_tapTimer` / `_pendingTapIndex`）を撤去し、
  「直前タップの index と時刻」のみで判定する構造に単純化した。
  `_doubleTapMs` を 300ms に変更（回転の発火に待ちが無くなったため窓を広げられる）。
- `play_screen.dart`: 待ちなし方式では 1 回目のタップで既に回転が発火済みのため、
  ダブルタップ確定時（`_onFlipPiece`）でその回転を打ち消してから反転する必要が
  生じた。1つの `setState` 内で `rotateCcw` → `flip` の順に適用する形にした。

## 4. テスト結果

- `flutter analyze --no-fatal-infos`: エラー・警告ゼロ。info 52件のみ（既存の
  avoid_print / dangling_library_doc_comments。今回の変更由来の info は0件）。
  所要時間 約7秒。
- `flutter test`: **677 件 pass / 0 fail**（PR #94 時点 675 件 → 今回 +2 件で
  想定通り）。
- `dart format --output=none --set-exit-if-changed`: 変更全ファイルで差分なしを
  確認（初回 `test/game/play/piece_orientation_state_test.dart` に軽微な差分が
  あったため `dart format` を適用し、再チェックでクリーンを確認済み）。

### 新規テスト2件の内容

1. `rotateCcw` の後に `rotateCw` を適用すると元の向きに戻る。
2. `rotateCw → rotateCcw → flip` の結果が `flip` 単独の結果と一致する
   （＝待ちなし方式ダブルタップの実効セマンティクスが「反転のみ」になることの担保）。

既存テスト全件（fromPuzzle 系・rotateCw 系・flip 系・scrambled 系）は
挙動不変で pass。

## 5. 指示書からの逸脱

なし。

## 6. PR

未作成。本セッションはシステムにより `claude/polyrush-scramble-forgiveness-sfgqt7`
ブランチが割当されており、対応する旧 PR（#94）がマージ済みだったため、CLAUDE.md の
マージ済みブランチの取り扱いに従い develop 最新から同名ブランチを作り直して作業した
（詳細は上記「1. 環境チェック結果」参照）。PR 作成・base=develop の設定は
ユーザー（井川さん）側での対応となる。

## 7. 次セッションへの申し送り

1. ダブルタップ（反転）判定は待ちなし方式に切替済み。`_doubleTapMs=300ms`。
   `PieceOrientationState.rotateCcw` を新規追加。
2. 既知のトレードオフ: ダブルタップ時、1 回目のタップの回転が一瞬適用されてから
   反転されて見える（同一フレーム内の setState だが、体感上「一瞬回転→反転」に
   見えることがある）。改善はロードマップ⑧（反転モーション演出）で対応予定
   （ADR-0019 追補に記載済み）。
3. ロードマップの次枠は **④ 枠ファースト計測CI**（HANDOFF_ROADMAP_solo_v1.md §2-2）。
   ランダム枠への敷き詰め可能セット数・所要msの計測テストのみの小PR。着手前に
   同ドキュメントの §2-2・§4 を再読すること。
4. 今回、システム割当ブランチに対応する前回 PR が squash マージ済みだったため
   同名ブランチを develop から作り直した。次回以降も同様のケースでは
   `git merge-base --is-ancestor <ブランチ tip> origin/develop` で
   squash マージ済みかどうかを確認し、該当する場合は
   `git checkout -B <ブランチ名> origin/develop` で作り直すこと。
