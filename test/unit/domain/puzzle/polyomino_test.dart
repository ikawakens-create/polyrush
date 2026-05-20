import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';

void main() {
  // ─── 1. 種類数 ─────────────────────────────────────────────────────
  group('種類数', () {
    test('トロミノは2種', () {
      expect(kTrominoes.length, 2);
    });

    test('テトロミノは5種', () {
      expect(kTetrominoes.length, 5);
    });

    test('ペントミノは12種', () {
      expect(kPentominoes.length, 12);
    });

    test('全種合計は19種', () {
      expect(kAllPolyominoes.length, 19);
    });
  });

  // ─── 2. セル数（size と cells.length の一致） ─────────────────────
  group('セル数', () {
    for (final p in kAllPolyominoes) {
      test('${p.id}: cells.length == size (${p.size})', () {
        expect(
          p.cells.length,
          p.size,
          reason: '${p.id}: cells.length=${p.cells.length} != size=${p.size}',
        );
      });
    }
  });

  // ─── 3. カノニカル形の正規化（左上が原点） ────────────────────────
  group('カノニカル形の正規化', () {
    for (final p in kAllPolyominoes) {
      test('${p.id}: 最小 row == 0', () {
        final minRow = p.cells.map((c) => c.$1).reduce(min);
        expect(minRow, 0, reason: '${p.id}: min row=$minRow, expected 0');
      });

      test('${p.id}: 最小 col == 0', () {
        final minCol = p.cells.map((c) => c.$2).reduce(min);
        expect(minCol, 0, reason: '${p.id}: min col=$minCol, expected 0');
      });
    }
  });

  // ─── 4. 連結性（BFS） ────────────────────────────────────────────
  group('連結性', () {
    for (final p in kAllPolyominoes) {
      test('${p.id}: 全セルが辺で連結している', () {
        expect(
          _isConnected(p.cells),
          isTrue,
          reason: '${p.id}: cells are not fully connected',
        );
      });
    }
  });

  // ─── 5. ID の一意性 ───────────────────────────────────────────────
  group('ID の一意性', () {
    test('全19種の ID に重複がない', () {
      final ids = kAllPolyominoes.map((p) => p.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'Duplicate IDs: ${_findDuplicates(ids)}',
      );
    });
  });

  // ─── 6. row-major 順の確認 ────────────────────────────────────────
  group('cells の並び順（row-major）', () {
    for (final p in kAllPolyominoes) {
      test('${p.id}: row 昇順、同 row 内は col 昇順', () {
        for (var i = 0; i < p.cells.length - 1; i++) {
          final (y0, x0) = p.cells[i];
          final (y1, x1) = p.cells[i + 1];
          final isRowMajor = (y0 < y1) || (y0 == y1 && x0 < x1);
          expect(
            isRowMajor,
            isTrue,
            reason:
                '${p.id}: index $i=(${p.cells[i]}) is not before index ${i + 1}=(${p.cells[i + 1]}) in row-major order',
          );
        }
      });
    }
  });

  // ─── 7. 個別形状のスモークテスト ─────────────────────────────────
  group('個別形状', () {
    test('I3: 直線3セル', () {
      expect(kI3.cells, [(0, 0), (0, 1), (0, 2)]);
    });

    test('O4: 2×2 の正方形', () {
      expect(kO4.cells, [(0, 0), (0, 1), (1, 0), (1, 1)]);
    });

    test('X5: 十字型は (1,1) を中心に上下左右', () {
      expect(kX5.cells, [(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)]);
    });

    test('L4: L字テトロミノ', () {
      expect(kL4.cells, [(0, 0), (0, 1), (1, 0), (2, 0)]);
    });

    test('I5: 直線5セル', () {
      expect(kI5.cells, [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]);
    });
  });

  // ─── 8. Free Polyomino 正当性 ─────────────────────────────────
  group('Free Polyomino 正当性', () {
    void check(List<PolyominoData> ps, String name) {
      final keys = ps.map((p) => _canonicalKey(p.cells)).toList();
      expect(
        keys.toSet().length,
        keys.length,
        reason:
            '$name: 回転・反転で重複する形が含まれています。'
            '重複キー: ${_findDuplicateStrings(keys)}',
      );
    }

    test('トロミノ内に回転・反転で重複する形が無い', () {
      check(kTrominoes, 'トロミノ');
    });
    test('テトロミノ内に回転・反転で重複する形が無い', () {
      check(kTetrominoes, 'テトロミノ');
    });
    test('ペントミノ内に回転・反転で重複する形が無い', () {
      check(kPentominoes, 'ペントミノ');
    });
  });

  // ─── 9. PolyominoData equality ────────────────────────────────
  group('PolyominoData equality', () {
    test('同じ内容のインスタンスは等値', () {
      const a = PolyominoData(
        id: 'I4',
        size: 4,
        cells: [(0, 0), (0, 1), (0, 2), (0, 3)],
      );
      const b = PolyominoData(
        id: 'I4',
        size: 4,
        cells: [(0, 0), (0, 1), (0, 2), (0, 3)],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('id が異なれば非等値', () {
      const a = PolyominoData(id: 'I4', size: 4, cells: [(0, 0)]);
      const b = PolyominoData(id: 'L4', size: 4, cells: [(0, 0)]);
      expect(a, isNot(equals(b)));
    });

    test('cells 順が異なれば非等値', () {
      const a = PolyominoData(id: 'X', size: 2, cells: [(0, 0), (0, 1)]);
      const b = PolyominoData(id: 'X', size: 2, cells: [(0, 1), (0, 0)]);
      expect(a, isNot(equals(b)));
    });
  });
}

// ─── テストヘルパー ───────────────────────────────────────────────────

/// BFS で全セルが辺連結かどうかを検証する。
///
/// 「各セルに隣接セルがある」だけでは、独立した2つの固まりを見逃す可能性があるため、
/// 最初のセルから到達可能なセル数 == cells.length を確認する。
bool _isConnected(List<Cell> cells) {
  if (cells.isEmpty) return true;
  final cellSet = cells.toSet();
  final visited = <Cell>{};
  final queue = Queue<Cell>()..add(cells.first);
  while (queue.isNotEmpty) {
    final (y, x) = queue.removeFirst();
    if (!visited.add((y, x))) continue;
    for (final neighbor in [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]) {
      if (cellSet.contains(neighbor) && !visited.contains(neighbor)) {
        queue.add(neighbor);
      }
    }
  }
  return visited.length == cells.length;
}

/// デバッグ用：重複 ID を列挙する。
List<String> _findDuplicates(List<String> ids) {
  final seen = <String>{};
  return ids.where((id) => !seen.add(id)).toList();
}

/// 4回転 × 2反転 = 8通りのバリアントを正規化し、
/// 辞書順最小のものを Free Polyomino の正規キーとして返す。
String _canonicalKey(List<Cell> cells) {
  List<Cell> normalize(List<Cell> cs) {
    final minY = cs.map((c) => c.$1).reduce(min);
    final minX = cs.map((c) => c.$2).reduce(min);
    final shifted = cs.map((c) => (c.$1 - minY, c.$2 - minX)).toList();
    shifted.sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
    );
    return shifted;
  }

  List<Cell> rotate90(List<Cell> cs) => cs.map((c) => (c.$2, -c.$1)).toList();
  List<Cell> reflectX(List<Cell> cs) => cs.map((c) => (c.$1, -c.$2)).toList();

  final variants = <String>[];
  var current = cells;
  for (var i = 0; i < 4; i++) {
    variants.add(normalize(current).toString());
    variants.add(normalize(reflectX(current)).toString());
    current = rotate90(current);
  }
  variants.sort();
  return variants.first;
}

List<String> _findDuplicateStrings(List<String> xs) {
  final seen = <String>{};
  return xs.where((x) => !seen.add(x)).toList();
}
