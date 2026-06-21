# Handoff: feature/rotation-prototype

- 日付: 2026-06-21
- タスク: ADR-0019 最小プロト（トレイのタップで 90 度回転）

## 1. 環境チェック結果

ブランチ: feature/rotation-prototype（develop から手動作成）。
develop の最新コミット d9c3630 を含む。

git log --oneline -3 (作業開始時点):
  d9c3630 docs: ADR-0019 ピースの回転・反転と初期向きランダム化の草案を追加 (#88)
  19745c7 Feature/non triviality filter (#87)
  de9f2d6 Feature/puzzle metrics (#86)

## 2. 作成ファイル一覧

新規:
  lib/game/play/piece_orientation_state.dart — ピースごとの向き管理（ADR-0019）
  test/game/play/piece_orientation_state_test.dart — テスト（2件）

変更:
  lib/ui/screens/play/piece_tray.dart — PiecePainter を PolyominoData 受け取りに変更、onTapPiece/orientationOf 追加
  lib/ui/screens/play/play_screen.dart — _orientations 状態・_orientationOf・_onTapPiece 追加、PieceTray/浮きピース等に結線
  docs/handoff/LATEST.md — 本ファイル

## 3. 削除・変更した既存ファイルと理由

piece_tray.dart の変更内容:
- PiecePainter のフィールドを PlacedBlock → PolyominoData に変更（描画は向きだけで十分）
- PieceTray に orientationOf(int) と onTapPiece(int) コールバックを追加
- _pieceDrawWidth / _pieceDrawHeight / _cellCentersInContent を widget.orientationOf(i) 経由に変更
- _onPointerUp に「ほぼ動かなかった = タップ → 回転」を追加

play_screen.dart の変更内容:
- import piece_orientation_state.dart 追加
- _orientations フィールド追加（PieceOrientationState?）
- _loadPuzzle() で _orientations を初期化
- _orientationOf() / _onTapPiece() メソッド追加
- _updateGhost() の cells 取得を _orientationOf 経由に変更
- _floatingPieceOffset() の引数を PlacedBlock → PolyominoData に変更
- _buildFloatingPiece() で orientation を _orientationOf 経由に取得
- PieceTray に orientationOf と onTapPiece を渡す

## 4. テスト結果

flutter test: 667件すべて pass（新規2件含む、約15秒）
flutter analyze --no-fatal-infos: error / warning ゼロ（avoid_print info は既存ファイルのみ）

新規テスト:
  - fromPuzzle は各ピースを解の向きで初期化する ✓
  - rotateCw を 4 回適用すると元の向きに戻る ✓

## 5. 指示書からの逸脱

なし。システム割当ブランチは使用せず feature/rotation-prototype を手動作成。

## 6. PR

PR 作成済み（push 後に作成予定）。
base=develop, compare=feature/rotation-prototype。

## 7. 次セッションへの申し送り

1. 今回追加したプロト（ADR-0019 最小プロト）でトレイのタップ回転が動く。
   初期向きは解の向きのまま（ランダム化未実装）。

2. 次 PR の作業内容（ADR-0019 続き）:
   - 初期向きランダム化（PieceOrientationState.fromPuzzleShuffle() など）
   - 反転（PolyominoTransformer.flipH or flipV）の追加
   - K 判定（1手回転で一致する向きをスキップ or ハイライト）
   これらはすべて PieceOrientationState に追加する形で実装する。

3. 確定資産として今回変更してよかったファイル:
   - piece_tray.dart と play_screen.dart のみ（指示書どおり）
   今後 CLAUDE.md の「既存ファイル変更ポリシー」に追加するかは Opus 判断。
