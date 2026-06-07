import 'package:polyrush/domain/puzzle/polyomino.dart';

List<Cell> translateCells(List<Cell> cells, int dy, int dx) =>
    cells.map((c) => (c.$1 + dy, c.$2 + dx)).toList();

List<Cell> placedCellsAt(List<Cell> normalizedCells, Cell origin) =>
    translateCells(normalizedCells, origin.$1, origin.$2);

bool canPlace(List<Cell> cells, Set<Cell> frame, Set<Cell> occupied) =>
    cells.every((c) => frame.contains(c) && !occupied.contains(c));

/// 配置済みピース全体が枠を過不足なく埋めているか判定する純粋関数。
///
/// [placedPieces] の全セルの和集合が [frame] と完全一致すれば true。
bool isComplete(List<List<Cell>> placedPieces, Set<Cell> frame) {
  final allCells = placedPieces.expand((p) => p).toSet();
  return allCells.length == frame.length && allCells.containsAll(frame);
}
