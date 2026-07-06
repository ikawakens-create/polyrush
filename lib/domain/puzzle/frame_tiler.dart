import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';

/// 枠ファースト生成器(ADR-0020 判断2・A案)の配置 materialize 部。
///
/// 採用セット(解数1〜3のピース集合)を枠へ実際に敷いた **最初の1解** を返す。
/// PuzzleSolver.countSolutions は解「数」しか返さないため、配置(PlacedBlock)を組むには
/// 本モジュールが必要。数え上げは行わず最初の1解で early exit する「縮小版」。
///
/// 決定論(判断2 条件a): pivot＝最小空セル (y,x)、ピースは [pieces] の順、向きは
/// 正準キー昇順で走査する。同じ枠＋セットなら常に同じ tiling を返す。
class FrameTiler {
  FrameTiler._();

  /// [frame] を [pieces](重複なし・セル数合計＝枠セル数を前提)で敷いた最初の1解を返す。
  /// 敷き詰め不能なら null。返る各 PlacedBlock は source/orientation/絶対cells を持つ。
  static List<PlacedBlock>? firstTiling(
    Set<Cell> frame,
    List<PolyominoData> pieces,
  ) {
    final empty = Set<Cell>.of(frame);
    final used = List<bool>.filled(pieces.length, false);

    // 各ピースの全ユニーク向きを正準キー昇順に固定(決定論)。
    final orientedByIndex = <List<PolyominoData>>[];
    for (final p in pieces) {
      final oris = PolyominoTransformer.allUniqueOrientations(p).toList()
        ..sort((a, b) => _cellsKey(a.cells).compareTo(_cellsKey(b.cells)));
      orientedByIndex.add(oris);
    }

    final result = <PlacedBlock>[];

    bool backtrack() {
      if (empty.isEmpty) return true;
      final pivot = _minCell(empty);
      for (var i = 0; i < pieces.length; i++) {
        if (used[i]) continue;
        for (final ori in orientedByIndex[i]) {
          final mn = _minCell(ori.cells);
          final dy = pivot.$1 - mn.$1;
          final dx = pivot.$2 - mn.$2;
          final placed = <Cell>[];
          var fits = true;
          for (final c in ori.cells) {
            final q = (c.$1 + dy, c.$2 + dx);
            if (!empty.contains(q)) {
              fits = false;
              break;
            }
            placed.add(q);
          }
          if (!fits) continue;
          for (final q in placed) {
            empty.remove(q);
          }
          used[i] = true;
          result.add(
            PlacedBlock(source: pieces[i], orientation: ori, cells: placed),
          );
          if (backtrack()) return true;
          result.removeLast();
          used[i] = false;
          for (final q in placed) {
            empty.add(q);
          }
        }
      }
      return false;
    }

    return backtrack() ? result : null;
  }

  /// 辞書順(y,x)で最小のセル。
  static Cell _minCell(Iterable<Cell> cells) {
    Cell? best;
    for (final c in cells) {
      if (best == null ||
          c.$1 < best.$1 ||
          (c.$1 == best.$1 && c.$2 < best.$2)) {
        best = c;
      }
    }
    return best!;
  }

  static String _cellsKey(List<Cell> cells) {
    final l = cells.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return l.map((c) => '${c.$1},${c.$2}').join(';');
  }
}
