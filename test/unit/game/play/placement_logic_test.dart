import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/game/play/placement_logic.dart';

void main() {
  // ─── A. translateCells ───────────────────────────────────────────
  group('A. translateCells', () {
    const cells = [(1, 2), (1, 3), (2, 2)];

    test('正の移動', () {
      expect(
        translateCells(cells, 3, 4),
        [(4, 6), (4, 7), (5, 6)],
        reason: 'dy=3, dx=4 を各セルに加算する',
      );
    });

    test('負の移動', () {
      expect(
        translateCells(cells, -1, -2),
        [(0, 0), (0, 1), (1, 0)],
        reason: 'dy=-1, dx=-2 を各セルに加算する',
      );
    });

    test('ゼロ移動', () {
      expect(
        translateCells(cells, 0, 0),
        cells,
        reason: 'dy=0, dx=0 では元と同じ値を返す',
      );
    });
  });

  // ─── B. placedCellsAt ───────────────────────────────────────────
  group('B. placedCellsAt', () {
    test('L 字ピースを (2,3) に配置', () {
      // normalizedCells は (0,0) 基点
      const normalized = [(0, 0), (1, 0), (1, 1)];
      expect(
        placedCellsAt(normalized, (2, 3)),
        [(2, 3), (3, 3), (3, 4)],
        reason: 'origin=(2,3) を加算したグローバル座標になる',
      );
    });

    test('単一セルを (0,0) に配置', () {
      expect(
        placedCellsAt(const [(0, 0)], (0, 0)),
        [(0, 0)],
        reason: '1マスのピースはそのまま origin に来る',
      );
    });
  });

  // ─── C. canPlace ────────────────────────────────────────────────
  group('C. canPlace', () {
    final frame = {(0, 0), (0, 1), (1, 0), (1, 1)};

    test('枠内・未占有 → true', () {
      expect(
        canPlace([(0, 0), (0, 1)], frame, {}),
        isTrue,
        reason: '対象セルがすべて枠内かつ占有なし',
      );
    });

    test('枠外セルを含む → false', () {
      expect(
        canPlace([(0, 0), (2, 0)], frame, {}),
        isFalse,
        reason: '(2,0) は枠に含まれない',
      );
    });

    test('占有済みセルと重複 → false', () {
      expect(
        canPlace([(0, 0), (0, 1)], frame, {(0, 0)}),
        isFalse,
        reason: '(0,0) がすでに占有されている',
      );
    });

    test('隣接するが重複しない → true', () {
      expect(
        canPlace([(1, 0), (1, 1)], frame, {(0, 0), (0, 1)}),
        isTrue,
        reason: '占有セルに隣接していても重複がなければ配置可',
      );
    });
  });

  // ─── D. isComplete ──────────────────────────────────────────────
  group('D. isComplete', () {
    final frame = {(0, 0), (0, 1), (1, 0), (1, 1)};

    test('配置なし（placed なし）→ false', () {
      expect(
        isComplete([], frame),
        isFalse,
        reason: 'ピースが1つも置かれていないので false',
      );
    });

    test('frame の一部だけ埋まっている → false', () {
      expect(
        isComplete(
          [
            [(0, 0), (0, 1)],
          ],
          frame,
        ),
        isFalse,
        reason: '(1,0) と (1,1) が空いている',
      );
    });

    test('frame をちょうど全部埋める複数ピース → true', () {
      expect(
        isComplete(
          [
            [(0, 0), (0, 1)],
            [(1, 0), (1, 1)],
          ],
          frame,
        ),
        isTrue,
        reason: '2 ピースで frame 全体を過不足なく埋める',
      );
    });

    test('frame と同数だが配置がずれて一致しない → false', () {
      expect(
        isComplete(
          [
            [(0, 0), (0, 1), (1, 0), (2, 0)],
          ],
          frame,
        ),
        isFalse,
        reason: '(2,0) が frame に含まれないため不一致',
      );
    });
  });
}
