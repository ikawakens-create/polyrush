import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/game/board/grid_geometry.dart';

void main() {
  // ─── A. 寸法計算 ─────────────────────────────────────────────────
  group('A. 寸法計算', () {
    // rows=3, cols=4, canvas 400x400, padding=0
    // cellSize = min(400/4, 400/3) = 100
    // boardSize = 400x300, boardOrigin = (0, 50)
    late GridGeometry geo;

    setUp(() {
      geo = GridGeometry.fit(
        boundingBox: (minY: 0, maxY: 2, minX: 0, maxX: 3),
        canvasSize: const Size(400, 400),
      );
    });

    test('cols == 4', () {
      expect(geo.cols, 4, reason: 'maxX-minX+1 = 3-0+1 = 4');
    });

    test('rows == 3', () {
      expect(geo.rows, 3, reason: 'maxY-minY+1 = 2-0+1 = 3');
    });

    test('cellSize == 100', () {
      expect(
        geo.cellSize,
        closeTo(100.0, 1e-10),
        reason: 'min(400/4, 400/3) = min(100, 133.3) = 100',
      );
    });

    test('boardOrigin.dx == 0', () {
      expect(
        geo.boardOrigin.dx,
        closeTo(0.0, 1e-10),
        reason: '盤幅 400 = canvas 幅 400。水平余白ゼロ',
      );
    });

    test('boardOrigin.dy == 50', () {
      expect(
        geo.boardOrigin.dy,
        closeTo(50.0, 1e-10),
        reason: '盤高 300、canvas 高 400。垂直余白 (400-300)/2 = 50',
      );
    });
  });

  // ─── B. 方向ガード（ADR-0006） ────────────────────────────────────
  group('B. 方向ガード (ADR-0006)', () {
    late GridGeometry geo;

    setUp(() {
      geo = GridGeometry.fit(
        boundingBox: (minY: 0, maxY: 3, minX: 0, maxX: 3),
        canvasSize: const Size(400, 400),
      );
    });

    test('y 増 → 下 (dy 増)', () {
      final center00 = geo.cellCenter((0, 0));
      final center10 = geo.cellCenter((1, 0));
      expect(
        center00.dy < center10.dy,
        isTrue,
        reason: 'y=0 のセルは y=1 のセルより上(dy が小さい)でなければならない',
      );
    });

    test('x 増 → 右 (dx 増)', () {
      final center00 = geo.cellCenter((0, 0));
      final center01 = geo.cellCenter((0, 1));
      expect(
        center00.dx < center01.dx,
        isTrue,
        reason: 'x=0 のセルは x=1 のセルより左(dx が小さい)でなければならない',
      );
    });
  });

  // ─── C. 往復一致 ──────────────────────────────────────────────────
  group('C. pixelToCell(cellCenter(c)) == c の往復一致', () {
    test('3x4 盤の全セルで往復一致', () {
      final geo = GridGeometry.fit(
        boundingBox: (minY: 0, maxY: 2, minX: 0, maxX: 3),
        canvasSize: const Size(400, 400),
      );
      for (var row = 0; row < geo.rows; row++) {
        for (var col = 0; col < geo.cols; col++) {
          final cell = (geo.originRow + row, geo.originCol + col);
          final center = geo.cellCenter(cell);
          final result = geo.pixelToCell(center);
          expect(
            result,
            cell,
            reason: 'cell $cell の中心を逆引きした結果が $cell でない (got $result)',
          );
        }
      }
    });

    test('オフセット付き boundingBox でも往復一致', () {
      final geo = GridGeometry.fit(
        boundingBox: (minY: 2, maxY: 4, minX: 1, maxX: 3),
        canvasSize: const Size(300, 300),
      );
      for (var row = 0; row < geo.rows; row++) {
        for (var col = 0; col < geo.cols; col++) {
          final cell = (geo.originRow + row, geo.originCol + col);
          final center = geo.cellCenter(cell);
          final result = geo.pixelToCell(center);
          expect(
            result,
            cell,
            reason: 'cell $cell の中心を逆引きした結果が $cell でない (got $result)',
          );
        }
      }
    });
  });

  // ─── D. 範囲外・境界 ─────────────────────────────────────────────
  group('D. 範囲外・境界', () {
    late GridGeometry geo;

    setUp(() {
      // 4x4 盤、cellSize=100、boardOrigin=(0,0)
      geo = GridGeometry.fit(
        boundingBox: (minY: 0, maxY: 3, minX: 0, maxX: 3),
        canvasSize: const Size(400, 400),
      );
    });

    test('盤の外（左上）は null', () {
      expect(
        geo.pixelToCell(const Offset(-1, -1)),
        isNull,
        reason: '(-1,-1) は盤外',
      );
    });

    test('盤の外（右下）は null', () {
      expect(
        geo.pixelToCell(const Offset(401, 401)),
        isNull,
        reason: '(401,401) は盤外',
      );
    });

    test('盤の左上角 (0,0) は最初のセルに属する', () {
      expect(
        geo.pixelToCell(const Offset(0, 0)),
        (0, 0),
        reason: '(0,0) は cell (0,0) に属す',
      );
    });

    test('右端ちょうど (400.0, 200.0) は null（半開区間）', () {
      expect(
        geo.pixelToCell(const Offset(400.0, 200.0)),
        isNull,
        reason: '右端ちょうどは半開区間のため盤外',
      );
    });

    test('下端ちょうど (200.0, 400.0) は null（半開区間）', () {
      expect(
        geo.pixelToCell(const Offset(200.0, 400.0)),
        isNull,
        reason: '下端ちょうどは半開区間のため盤外',
      );
    });

    test('右端の1px手前は最右列に属する', () {
      expect(
        geo.pixelToCell(const Offset(399.9, 50.0)),
        isNotNull,
        reason: '399.9 は盤内',
      );
    });
  });

  // ─── E. 非正方 boundingBox でも cellSize が一定 ───────────────────
  group('E. 非正方 boundingBox でも cellSize は正方形', () {
    test('縦長 boundingBox (rows=5, cols=2)', () {
      final geo = GridGeometry.fit(
        boundingBox: (minY: 0, maxY: 4, minX: 0, maxX: 1),
        canvasSize: const Size(400, 400),
      );
      final rect00 = geo.cellRect((0, 0));
      final rect11 = geo.cellRect((1, 1));
      expect(
        rect00.width,
        closeTo(rect00.height, 1e-10),
        reason: 'cellRect の幅と高さが等しい（正方形）',
      );
      expect(
        rect11.width,
        closeTo(rect11.height, 1e-10),
        reason: 'どのセルも正方形',
      );
    });

    test('横長 boundingBox (rows=2, cols=5)', () {
      final geo = GridGeometry.fit(
        boundingBox: (minY: 0, maxY: 1, minX: 0, maxX: 4),
        canvasSize: const Size(400, 400),
      );
      final rect = geo.cellRect((0, 0));
      expect(
        rect.width,
        closeTo(rect.height, 1e-10),
        reason: 'cellRect の幅と高さが等しい（正方形）',
      );
    });
  });

  // ─── F. 原点オフセット ────────────────────────────────────────────
  group('F. 原点オフセット', () {
    test('boundingBox minY=2, minX=1 → cell(2,1) が盤の index(0,0) に来る', () {
      final geo = GridGeometry.fit(
        boundingBox: (minY: 2, maxY: 4, minX: 1, maxX: 3),
        canvasSize: const Size(300, 300),
      );

      expect(geo.originRow, 2, reason: 'originRow = minY = 2');
      expect(geo.originCol, 1, reason: 'originCol = minX = 1');

      // cell (2,1) は行インデックス 0, 列インデックス 0 → 盤の左上
      final rect = geo.cellRect((2, 1));
      expect(
        rect.left,
        closeTo(geo.boardOrigin.dx, 1e-10),
        reason: 'cell(2,1) の left は boardOrigin.dx と一致',
      );
      expect(
        rect.top,
        closeTo(geo.boardOrigin.dy, 1e-10),
        reason: 'cell(2,1) の top は boardOrigin.dy と一致',
      );
    });

    test('cell(2,1) の pixelToCell 往復', () {
      final geo = GridGeometry.fit(
        boundingBox: (minY: 2, maxY: 4, minX: 1, maxX: 3),
        canvasSize: const Size(300, 300),
      );
      const topLeftCell = (2, 1);
      final result = geo.pixelToCell(geo.cellCenter(topLeftCell));
      expect(result, topLeftCell, reason: 'cell(2,1) の中心を逆引きして (2,1) が返る');
    });
  });
}
