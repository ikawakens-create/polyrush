# Handoff: ③ スクランブル＋forgiveness統合（システム割当ブランチ claude/polyrush-scramble-forgiveness-sfgqt7）

- 日付: 2026-07-04
- タスク: ロードマップ ③「スクランブル実装＋forgiveness統合」（ADR-0019 完結）

## 1. 環境チェック結果

```
$ git fetch origin && git checkout develop && git pull origin develop
$ git log --oneline -5
54fa519 feat(flip): ②.5 反転UI ダブルタップで左右反転（ADR-0019 追補） (#93)
a040818 test(puzzle): easy forgiveness 計測CI を追加しロードマップを Fable 確定に更新（②a） (#92)
b8ecc08 refactor(play): _applyResult で _result と _orientations をセット更新（PR #89 リグレッション対策） (#91)
88e1cff feat(rotation): ADR-0019 最小プロト トレイのタップで 90 度回転 (#89)
d9c3630 docs: ADR-0019 ピースの回転・反転と初期向きランダム化の草案を追加 (#88)

$ ls lib/domain/puzzle/
README.md  compact_puzzle_generator.dart  compact_puzzle_generator_v2.dart
compact_puzzle_generator_v3.dart  difficulty.dart  frame_connectivity.dart
non_trivial_puzzle_generator.dart  playable_puzzle_generator.dart
polyomino.dart  polyomino_transformer.dart  puzzle_generator.dart
puzzle_metrics.dart  solver.dart  verified_puzzle_generator.dart
```

PR #93（反転UI）はマージ済み確認済み。develop の直近コミットも既存 Task 成果ファイルも
期待通り存在。

システム割当ブランチ `claude/polyrush-scramble-forgiveness-sfgqt7` が develop 最新
（54fa519）と同一コミットであることを `git merge-base --is-ancestor` で確認済み
（マージ不要）。CLAUDE.md の「例外: システム割当ブランチ」規定に従い、このブランチ上で
作業した。

## 2. 作成・変更ファイル一覧

- 変更: `lib/game/play/piece_orientation_state.dart`
  （新規名前付きコンストラクタ `PieceOrientationState.scrambled(puzzle, difficulty)` を
  追加。既存 `fromPuzzle` は挙動不変のまま残置）
- 変更: `lib/ui/screens/play/play_screen.dart`
  （`_applyResult` 内の初期化呼び出しを `fromPuzzle` → `scrambled(value.puzzle, _difficulty)`
  に差し替え。加えて `debugOrientationsInSyncWithResult()` の同期判定を、スクランブル
  導入に伴い「解の向きと完全一致」から「同じピース(source)の有効な向きになっているか
  （PolyominoTransformer.areEquivalent）」に更新）
- 変更: `lib/ui/screens/play/piece_tray.dart`
  （`_doubleTapMs` を 250 → 125 に変更。実機評価による調整である旨をコメントに追記）
- 新規: `test/game/play/piece_orientation_state_scrambled_test.dart`
  （決定論・easy 回転限定・easy floor・normal/hard cap の4テスト）
- 変更: `docs/adr/0019-piece-rotation-flip.md`
  （③ 追補セクションを追記。Status を Accepted に更新。未決事項4件をすべて
  「決定済み」に更新）
- 変更: `docs/handoff/HANDOFF_ROADMAP_solo_v1.md`
  （ロードマップ表の ③ 行を「待機」→「完了」に更新）
- 変更: `docs/handoff/LATEST.md`（本ファイル）

## 3. 変更した既存ファイルと理由

- `piece_orientation_state.dart`: 指示書通り、生成器側ではなく本ファイルにスクランブル
  ロジックを実装（B案・既存 API 不変更）。floor/cap 判定・候補向き構築はすべて
  private static ヘルパー（`_floorCapFor` / `_candidatesFor` / `_buildScrambled`）に
  切り出した。確定資産（PolyominoTransformer 等）は一切変更していない。
- `play_screen.dart`: `_applyResult` の更新構造（PR #91）は崩していない。
  `_result` / `_orientations` を個別に代入するコードは書いていない。
  `debugOrientationsInSyncWithResult()` はテスト専用ヘルパーだが、スクランブル導入で
  「ロード直後は解の向きと完全一致する」という前提が崩れるため、判定基準を
  「同じピースの有効な向きか」に更新する必要があった（指示書に明記はなかったが、
  この変更なしでは既存の widget リグレッションテストが破綻するため対応した）。
- `piece_tray.dart`: 指示書通り `_doubleTapMs` を 125ms に変更。

## 4. テスト結果

- `flutter analyze --no-fatal-infos`: エラー・警告ゼロ。info 52件のみ（既存の
  avoid_print / dangling_library_doc_comments。今回の変更由来の info は0件）。
  所要時間 約14.6秒。
- `flutter test`: **675 件 pass / 0 fail**（#93 時点 671 件 → 今回 +4 件で想定通り）。
  所要時間 約19〜23秒。
- `dart format --output=none --set-exit-if-changed` で変更全ファイルのフォーマット差分
  なしを確認（初回 `piece_orientation_state.dart` に軽微な差分があったため
  `dart format` を適用し、再チェックでクリーンを確認済み）。

### 新規テスト4件の内容

1. 決定論: 同じ puzzle から2回 `scrambled` を作ると全ピースの向きが一致する
   （easy/normal/hard × seed 1..5）。
2. easy 回転限定: easy で配られた各向きが `block.orientation` の回転セット
   （rotate90 0〜3回）に含まれる（反転向きが混ざらない）ことを seed 1..30 で確認。
3. easy floor: 非対称ピース（対称ピースを除く）のうち解の向きと一致するのが
   ちょうど1個であることを seed 1..30 で確認。
4. normal/hard cap: 非対称ピースの解の向き一致数が2以下であることを
   normal/hard × seed 1..30 で確認。

## 5. 指示書からの逸脱

- なし。ただし「4. テスト結果」に記載の通り、`debugOrientationsInSyncWithResult()` の
  判定基準変更は指示書に明記されていなかったが、スクランブル導入の直接の帰結として
  必要だったため実施した。

## 6. PR

未作成。本セッションはシステムにより `claude/polyrush-scramble-forgiveness-sfgqt7`
ブランチが強制割当されており、CLAUDE.md の「例外: システム割当ブランチ」規定に従い、
develop 最新（54fa519）と同一であることを確認した上でこのブランチ上で作業した。
PR 作成・base=develop の設定はユーザー（井川さん）側での対応となる。

## 7. 次セッションへの申し送り

1. ③「スクランブル＋forgiveness統合」完了。ADR-0019 の未決事項はすべて決定済みとなり、
   ADR-0019 は完結（Status: Accepted）。
2. floor/cap 最終値: easy floor=1/cap=1、normal/hard floor=0/cap=2。対称ピース
   （O4・X5）は除外。easy は回転のみ配布、normal/hard は反転込み全向き。
3. `_doubleTapMs` は 125ms に短縮済み（実機評価による）。さらに詰める場合は
   FeelConfig への昇格を検討。
4. ロードマップの次枠は **④ 枠ファースト計測CI**（HANDOFF_ROADMAP_solo_v1.md §2-2）。
   ランダム枠への敷き詰め可能セット数・所要msの計測テストのみの小PR。着手前に
   同ドキュメントの §2-2・§4 を再読すること。
5. `debugOrientationsInSyncWithResult()` の判定基準を変更したため、今後
   play_screen.dart の初期化ロジックを触る際はこのヘルパーの意味（「同じピースの
   有効な向きか」であり「解の向きと一致するか」ではない）に注意すること。
