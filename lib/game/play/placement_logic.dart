import 'package:polyrush/domain/puzzle/polyomino.dart';

List<Cell> translateCells(List<Cell> cells, int dy, int dx) =>
    cells.map((c) => (c.$1 + dy, c.$2 + dx)).toList();

List<Cell> placedCellsAt(List<Cell> normalizedCells, Cell origin) =>
    translateCells(normalizedCells, origin.$1, origin.$2);

bool canPlace(List<Cell> cells, Set<Cell> frame, Set<Cell> occupied) =>
    cells.every((c) => frame.contains(c) && !occupied.contains(c));
