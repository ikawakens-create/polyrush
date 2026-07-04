import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';

/// プレイ中のピースごとの「現在の向き」を保持する薄い層（ADR-0019）。
///
/// 確定資産（PolyominoTransformer / PlacedBlock）はラップして使うだけ。
/// プロト段階では初期向きを解の向き（block.orientation）に合わせ、
/// タップによる 90 度回転のみを提供する。
/// 初期向きランダム化・反転・K 判定は次 PR で本クラスに追加する。
class PieceOrientationState {
  PieceOrientationState.fromPuzzle(GeneratedPuzzle puzzle)
    : _orientations = [for (final b in puzzle.blocks) b.orientation];

  final List<PolyominoData> _orientations;

  /// 保持しているピース数。
  int get length => _orientations.length;

  /// ピース [index] の現在の向き。
  PolyominoData orientationOf(int index) => _orientations[index];

  /// ピース [index] を時計回りに 90 度回転する（結果は正規化済み）。
  void rotateCw(int index) {
    _orientations[index] = PolyominoTransformer.rotate90(_orientations[index]);
  }
}
