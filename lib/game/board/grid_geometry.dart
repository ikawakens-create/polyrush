import 'dart:math';
import 'dart:ui';

import 'package:polyrush/domain/puzzle/polyomino.dart';

/// 盤面のピクセル座標計算を担うイミュータブルなクラス。
///
/// 座標系は `(y, x) = (row, col)` (ADR-0006)。
/// y が増える方向 = 下、x が増える方向 = 右。
/// [Cell] の `$1` = y (行)、`$2` = x (列)。
class GridGeometry {
  const GridGeometry._({
    required this.cols,
    required this.rows,
    required this.originRow,
    required this.originCol,
    required this.cellSize,
    required this.boardOrigin,
    required this.canvasSize,
  });

  /// 盤の列数。
  final int cols;

  /// 盤の行数。
  final int rows;

  /// boundingBox の minY（セル y 座標 → 行インデックス変換の基点）。
  final int originRow;

  /// boundingBox の minX（セル x 座標 → 列インデックス変換の基点）。
  final int originCol;

  /// 1マスのピクセル辺長（正方形）。
  final double cellSize;

  /// 盤の左上が canvas 内に来るピクセル位置（中央寄せ）。
  final Offset boardOrigin;

  /// canvas の寸法。
  final Size canvasSize;

  /// boundingBox と canvasSize からジオメトリを計算するファクトリ。
  ///
  /// [padding] を四辺から差し引いた使用可能領域に盤を収め、中央に配置する。
  factory GridGeometry.fit({
    required ({int minY, int maxY, int minX, int maxX}) boundingBox,
    required Size canvasSize,
    double padding = 0,
  }) {
    final cols = boundingBox.maxX - boundingBox.minX + 1;
    final rows = boundingBox.maxY - boundingBox.minY + 1;

    final availWidth = canvasSize.width - padding * 2;
    final availHeight = canvasSize.height - padding * 2;

    final cellSize = min(availWidth / cols, availHeight / rows);

    final boardWidth = cellSize * cols;
    final boardHeight = cellSize * rows;

    final boardOrigin = Offset(
      padding + (availWidth - boardWidth) / 2,
      padding + (availHeight - boardHeight) / 2,
    );

    return GridGeometry._(
      cols: cols,
      rows: rows,
      originRow: boundingBox.minY,
      originCol: boundingBox.minX,
      cellSize: cellSize,
      boardOrigin: boardOrigin,
      canvasSize: canvasSize,
    );
  }

  /// セルが占める矩形を返す。
  ///
  /// [cell] の `$1` = y (行)、`$2` = x (列)。
  /// y → top、x → left に対応する（ADR-0006）。
  Rect cellRect(Cell cell) {
    final colIndex = cell.$2 - originCol;
    final rowIndex = cell.$1 - originRow;
    final left = boardOrigin.dx + colIndex * cellSize;
    final top = boardOrigin.dy + rowIndex * cellSize;
    return Rect.fromLTWH(left, top, cellSize, cellSize);
  }

  /// セルの中心ピクセル座標を返す。
  Offset cellCenter(Cell cell) => cellRect(cell).center;

  /// ピクセル座標からセルを逆引きする。盤外なら null。
  ///
  /// 右端・下端は半開区間（境界ピクセルは次セルまたは盤外に所属）。
  Cell? pixelToCell(Offset p) {
    final colIndex = ((p.dx - boardOrigin.dx) / cellSize).floor();
    final rowIndex = ((p.dy - boardOrigin.dy) / cellSize).floor();

    if (colIndex < 0 || colIndex >= cols) return null;
    if (rowIndex < 0 || rowIndex >= rows) return null;

    return (originRow + rowIndex, originCol + colIndex);
  }
}
