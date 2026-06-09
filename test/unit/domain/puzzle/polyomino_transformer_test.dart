// ─────────────────────────────────────────────────────────────────────────────
// 手計算例（事前確認）
//
// kL3 cells = [(0,0), (0,1), (1,0)]  H=2, W=2
//
//   元の形:       rotate90 後:
//   ##            ##
//   #.            .#
//
// rotate90  : (y,x)→(x,H-1-y)=(x,1-y)
//   (0,0)→(0,1), (0,1)→(1,1), (1,0)→(0,0)  → 正規化後: [(0,0),(0,1),(1,1)]
//
// rotate180 : (y,x)→(H-1-y,W-1-x)=(1-y,1-x)
//   (0,0)→(1,1), (0,1)→(1,0), (1,0)→(0,1)  → 正規化後: [(0,1),(1,0),(1,1)]
//
// flipHorizontal: (y,x)→(y,W-1-x)=(y,1-x)
//   (0,0)→(0,1), (0,1)→(0,0), (1,0)→(1,1)  → 正規化後: [(0,0),(0,1),(1,1)]
//   ※ rotate90 と同じ形になる（L-Tromino は反転が 90度回転と同値）
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';

void main() {
  // ─── 1. normalize ──────────────────────────────────────────────────────
  group('normalize', () {
    test('既に正規化済みのポリオミノは変化しない', () {
      final result = PolyominoTransformer.normalize(kI3);
      expect(result.cells, kI3.cells);
      expect(result.id, kI3.id);
    });

    test('minY が 0 でない場合は上にシフトされる', () {
      const shifted = PolyominoData(
        id: 'I3',
        size: 3,
        cells: [(2, 0), (2, 1), (2, 2)],
      );
      final result = PolyominoTransformer.normalize(shifted);
      final minY = result.cells
          .map((c) => c.$1)
          .reduce((a, b) => a < b ? a : b);
      expect(minY, 0);
    });

    test('minX が 0 でない場合は左にシフトされる', () {
      const shifted = PolyominoData(
        id: 'I3',
        size: 3,
        cells: [(0, 3), (0, 4), (0, 5)],
      );
      final result = PolyominoTransformer.normalize(shifted);
      final minX = result.cells
          .map((c) => c.$2)
          .reduce((a, b) => a < b ? a : b);
      expect(minX, 0);
    });

    test('セルは (y昇順, x昇順) にソートされる', () {
      const unordered = PolyominoData(
        id: 'L3',
        size: 3,
        cells: [(1, 0), (0, 1), (0, 0)],
      );
      final result = PolyominoTransformer.normalize(unordered);
      expect(result.cells, [(0, 0), (0, 1), (1, 0)]);
    });

    test('全19種: normalize 後 minY == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.normalize(p);
        final minY = result.cells
            .map((c) => c.$1)
            .reduce((a, b) => a < b ? a : b);
        expect(minY, 0, reason: '${p.id}: minY=$minY');
      }
    });

    test('全19種: normalize 後 minX == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.normalize(p);
        final minX = result.cells
            .map((c) => c.$2)
            .reduce((a, b) => a < b ? a : b);
        expect(minX, 0, reason: '${p.id}: minX=$minX');
      }
    });

    test('全19種: normalize 後 cells は (y昇順, x昇順)', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.normalize(p);
        for (var i = 0; i < result.cells.length - 1; i++) {
          final (y0, x0) = result.cells[i];
          final (y1, x1) = result.cells[i + 1];
          final ordered = (y0 < y1) || (y0 == y1 && x0 < x1);
          expect(ordered, isTrue, reason: '${p.id}: index $i not in order');
        }
      }
    });

    test('id が引き継がれる', () {
      final result = PolyominoTransformer.normalize(kT4);
      expect(result.id, kT4.id);
    });

    test('size が引き継がれる', () {
      final result = PolyominoTransformer.normalize(kT4);
      expect(result.size, kT4.size);
    });
  });

  // ─── 2. rotate90 ─────────────────────────────────────────────────────
  group('rotate90', () {
    test('L3 手計算: rotate90 = [(0,0),(0,1),(1,1)]', () {
      final result = PolyominoTransformer.rotate90(kL3);
      expect(result.cells, [(0, 0), (0, 1), (1, 1)]);
    });

    test('I5 (横5マス) → 縦5マス', () {
      final result = PolyominoTransformer.rotate90(kI5);
      expect(result.cells, [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]);
    });

    test('回転後 minY == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.rotate90(p);
        final minY = result.cells
            .map((c) => c.$1)
            .reduce((a, b) => a < b ? a : b);
        expect(minY, 0, reason: '${p.id}: minY=$minY');
      }
    });

    test('回転後 minX == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.rotate90(p);
        final minX = result.cells
            .map((c) => c.$2)
            .reduce((a, b) => a < b ? a : b);
        expect(minX, 0, reason: '${p.id}: minX=$minX');
      }
    });

    test('id が引き継がれる', () {
      final result = PolyominoTransformer.rotate90(kT4);
      expect(result.id, kT4.id);
    });

    test('cells.length が変わらない', () {
      for (final p in kAllPolyominoes) {
        expect(
          PolyominoTransformer.rotate90(p).cells.length,
          p.cells.length,
          reason: p.id,
        );
      }
    });

    test('X5 (十字型) は rotate90 で形が変わらない', () {
      final result = PolyominoTransformer.rotate90(kX5);
      expect(result.cells, kX5.cells);
    });

    test('O4 は rotate90 で形が変わらない', () {
      final result = PolyominoTransformer.rotate90(kO4);
      expect(result.cells, kO4.cells);
    });
  });

  // ─── 3. rotate180 ────────────────────────────────────────────────────
  group('rotate180', () {
    test('L3 手計算: rotate180 = [(0,1),(1,0),(1,1)]', () {
      final result = PolyominoTransformer.rotate180(kL3);
      expect(result.cells, [(0, 1), (1, 0), (1, 1)]);
    });

    test('rotate90 を2回適用した結果と等しい', () {
      for (final p in kAllPolyominoes) {
        final via180 = PolyominoTransformer.rotate180(p);
        final via90x2 = PolyominoTransformer.rotate90(
          PolyominoTransformer.rotate90(p),
        );
        expect(
          via180.cells,
          via90x2.cells,
          reason: '${p.id}: rotate180 != rotate90×2',
        );
      }
    });

    test('rotate180 後 minY == 0 かつ minX == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.rotate180(p);
        final minY = result.cells
            .map((c) => c.$1)
            .reduce((a, b) => a < b ? a : b);
        final minX = result.cells
            .map((c) => c.$2)
            .reduce((a, b) => a < b ? a : b);
        expect(minY, 0, reason: '${p.id}: minY=$minY');
        expect(minX, 0, reason: '${p.id}: minX=$minX');
      }
    });

    test('I5: rotate180 で元の形に戻る', () {
      final result = PolyominoTransformer.rotate180(kI5);
      expect(result.cells, kI5.cells);
    });

    test('X5: rotate180 で元の形に戻る', () {
      final result = PolyominoTransformer.rotate180(kX5);
      expect(result.cells, kX5.cells);
    });
  });

  // ─── 4. rotate270 ────────────────────────────────────────────────────
  group('rotate270', () {
    test('rotate90 を3回適用した結果と等しい', () {
      for (final p in kAllPolyominoes) {
        final via270 = PolyominoTransformer.rotate270(p);
        final via90x3 = PolyominoTransformer.rotate90(
          PolyominoTransformer.rotate90(PolyominoTransformer.rotate90(p)),
        );
        expect(
          via270.cells,
          via90x3.cells,
          reason: '${p.id}: rotate270 != rotate90×3',
        );
      }
    });

    test('rotate270 後 minY == 0 かつ minX == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.rotate270(p);
        final minY = result.cells
            .map((c) => c.$1)
            .reduce((a, b) => a < b ? a : b);
        final minX = result.cells
            .map((c) => c.$2)
            .reduce((a, b) => a < b ? a : b);
        expect(minY, 0, reason: '${p.id}: minY=$minY');
        expect(minX, 0, reason: '${p.id}: minX=$minX');
      }
    });

    test('I5: rotate270 は縦5マス', () {
      final result = PolyominoTransformer.rotate270(kI5);
      expect(result.cells, [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]);
    });
  });

  // ─── 5. rotate×4 周回テスト ──────────────────────────────────────
  group('rotate90 × 4 = 元に戻る', () {
    test('T4: rotate90 ×4 で元に戻る', () {
      var current = kT4;
      for (var i = 0; i < 4; i++) {
        current = PolyominoTransformer.rotate90(current);
      }
      expect(current.cells, kT4.cells);
    });

    test('全19種: rotate90 ×4 で元に戻る', () {
      for (final p in kAllPolyominoes) {
        var current = p;
        for (var i = 0; i < 4; i++) {
          current = PolyominoTransformer.rotate90(current);
        }
        expect(
          current.cells,
          p.cells,
          reason: '${p.id}: 4 rotations did not return to original',
        );
      }
    });
  });

  // ─── 6. flipHorizontal ───────────────────────────────────────────────
  group('flipHorizontal', () {
    test('L3 手計算: flipH = [(0,0),(0,1),(1,1)] (rotate90 と同形)', () {
      final result = PolyominoTransformer.flipHorizontal(kL3);
      expect(result.cells, [(0, 0), (0, 1), (1, 1)]);
    });

    test('flipH を2回適用すると元に戻る', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.flipHorizontal(
          PolyominoTransformer.flipHorizontal(p),
        );
        expect(result.cells, p.cells, reason: '${p.id}: flipH×2 != original');
      }
    });

    test('flipH 後 minY == 0 かつ minX == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.flipHorizontal(p);
        final minY = result.cells
            .map((c) => c.$1)
            .reduce((a, b) => a < b ? a : b);
        final minX = result.cells
            .map((c) => c.$2)
            .reduce((a, b) => a < b ? a : b);
        expect(minY, 0, reason: '${p.id}: minY=$minY');
        expect(minX, 0, reason: '${p.id}: minX=$minX');
      }
    });

    test('I5: flipH で形が変わらない', () {
      final result = PolyominoTransformer.flipHorizontal(kI5);
      expect(result.cells, kI5.cells);
    });

    test('X5: flipH で形が変わらない', () {
      final result = PolyominoTransformer.flipHorizontal(kX5);
      expect(result.cells, kX5.cells);
    });

    test('O4: flipH で形が変わらない', () {
      final result = PolyominoTransformer.flipHorizontal(kO4);
      expect(result.cells, kO4.cells);
    });

    test('cells.length が変わらない', () {
      for (final p in kAllPolyominoes) {
        expect(
          PolyominoTransformer.flipHorizontal(p).cells.length,
          p.cells.length,
          reason: p.id,
        );
      }
    });

    test('id が引き継がれる', () {
      expect(PolyominoTransformer.flipHorizontal(kL4).id, kL4.id);
    });
  });

  // ─── 7. flipVertical ────────────────────────────────────────────────
  group('flipVertical', () {
    test('flipV を2回適用すると元に戻る', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.flipVertical(
          PolyominoTransformer.flipVertical(p),
        );
        expect(result.cells, p.cells, reason: '${p.id}: flipV×2 != original');
      }
    });

    test('flipV 後 minY == 0 かつ minX == 0', () {
      for (final p in kAllPolyominoes) {
        final result = PolyominoTransformer.flipVertical(p);
        final minY = result.cells
            .map((c) => c.$1)
            .reduce((a, b) => a < b ? a : b);
        final minX = result.cells
            .map((c) => c.$2)
            .reduce((a, b) => a < b ? a : b);
        expect(minY, 0, reason: '${p.id}: minY=$minY');
        expect(minX, 0, reason: '${p.id}: minX=$minX');
      }
    });

    test('I3: flipV で形が変わらない', () {
      final result = PolyominoTransformer.flipVertical(kI3);
      expect(result.cells, kI3.cells);
    });

    test('I5: flipV で形が変わらない', () {
      final result = PolyominoTransformer.flipVertical(kI5);
      expect(result.cells, kI5.cells);
    });

    test('cells.length が変わらない', () {
      for (final p in kAllPolyominoes) {
        expect(
          PolyominoTransformer.flipVertical(p).cells.length,
          p.cells.length,
          reason: p.id,
        );
      }
    });
  });

  // ─── 8. 1マスのモノミノ相当（エッジケース）──────────────────────
  group('1マスのモノミノ相当', () {
    const mono = PolyominoData(id: 'mono', size: 1, cells: [(0, 0)]);

    test('normalize は変化しない', () {
      expect(PolyominoTransformer.normalize(mono).cells, [(0, 0)]);
    });

    test('rotate90 は変化しない', () {
      expect(PolyominoTransformer.rotate90(mono).cells, [(0, 0)]);
    });

    test('rotate180 は変化しない', () {
      expect(PolyominoTransformer.rotate180(mono).cells, [(0, 0)]);
    });

    test('rotate270 は変化しない', () {
      expect(PolyominoTransformer.rotate270(mono).cells, [(0, 0)]);
    });

    test('flipHorizontal は変化しない', () {
      expect(PolyominoTransformer.flipHorizontal(mono).cells, [(0, 0)]);
    });

    test('flipVertical は変化しない', () {
      expect(PolyominoTransformer.flipVertical(mono).cells, [(0, 0)]);
    });

    test('allUniqueOrientations は1要素', () {
      expect(PolyominoTransformer.allUniqueOrientations(mono).length, 1);
    });

    test('areEquivalent(mono, mono) == true', () {
      expect(PolyominoTransformer.areEquivalent(mono, mono), isTrue);
    });
  });

  // ─── 9. 空ポリオミノの assert ─────────────────────────────────────
  group('空ポリオミノは AssertionError を投げる（debug ビルドのみ）', () {
    const empty = PolyominoData(id: 'empty', size: 0, cells: []);

    test('normalize: AssertionError', () {
      expect(
        () => PolyominoTransformer.normalize(empty),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rotate90: AssertionError', () {
      expect(
        () => PolyominoTransformer.rotate90(empty),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rotate180: AssertionError', () {
      expect(
        () => PolyominoTransformer.rotate180(empty),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rotate270: AssertionError', () {
      expect(
        () => PolyominoTransformer.rotate270(empty),
        throwsA(isA<AssertionError>()),
      );
    });

    test('flipHorizontal: AssertionError', () {
      expect(
        () => PolyominoTransformer.flipHorizontal(empty),
        throwsA(isA<AssertionError>()),
      );
    });

    test('flipVertical: AssertionError', () {
      expect(
        () => PolyominoTransformer.flipVertical(empty),
        throwsA(isA<AssertionError>()),
      );
    });

    test('areEquivalent(empty, ...): AssertionError', () {
      const mono = PolyominoData(id: 'mono', size: 1, cells: [(0, 0)]);
      expect(
        () => PolyominoTransformer.areEquivalent(empty, mono),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allUniqueOrientations: AssertionError', () {
      expect(
        () => PolyominoTransformer.allUniqueOrientations(empty),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ─── 10. allUniqueOrientations: サイズ検証 ──────────────────────
  group('allUniqueOrientations: ユニーク向き数', () {
    // Task 1 の PolyominoData.id に合わせたマップ
    // 合計 88 ユニーク向き
    const expectedOrientations = <String, int>{
      // トロミノ (2種)
      'I3': 2,
      'L3': 4,
      // テトロミノ (5種)
      'I4': 2,
      'O4': 1,
      'T4': 4,
      'L4': 8,
      'S4': 4,
      // ペントミノ (12種)
      'F5': 8,
      'I5': 2,
      'L5': 8,
      'N5': 8,
      'P5': 8,
      'T5': 4,
      'U5': 4,
      'V5': 4,
      'W5': 4,
      'X5': 1,
      'Y5': 8,
      'Z5': 4,
    };

    for (final p in kAllPolyominoes) {
      test('${p.id}: unique orientations == ${expectedOrientations[p.id]}', () {
        final count = PolyominoTransformer.allUniqueOrientations(p).length;
        expect(
          count,
          expectedOrientations[p.id],
          reason: '${p.id}: expected ${expectedOrientations[p.id]}, got $count',
        );
      });
    }

    test('全19種の合計ユニーク向き数は 88', () {
      final total = kAllPolyominoes
          .map((p) => PolyominoTransformer.allUniqueOrientations(p).length)
          .reduce((a, b) => a + b);
      expect(total, 88);
    });
  });

  // ─── 11. allUniqueOrientations: 中身の整合性 ────────────────────
  group('allUniqueOrientations: 中身の整合性', () {
    test('全要素が正規化済み（minY==0 かつ minX==0）', () {
      for (final p in kAllPolyominoes) {
        for (final q in PolyominoTransformer.allUniqueOrientations(p)) {
          final minY = q.cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
          final minX = q.cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
          expect(minY, 0, reason: '${p.id} orientation: minY=$minY');
          expect(minX, 0, reason: '${p.id} orientation: minX=$minX');
        }
      }
    });

    test('p 自身と同値な要素を必ず1つ含む', () {
      for (final p in kAllPolyominoes) {
        final orientations = PolyominoTransformer.allUniqueOrientations(p);
        expect(
          orientations.any((q) => PolyominoTransformer.areEquivalent(p, q)),
          isTrue,
          reason: '${p.id}: no equivalent orientation found',
        );
      }
    });

    test('任意の2要素は areEquivalent で同値', () {
      for (final p in kAllPolyominoes) {
        final orientations = PolyominoTransformer.allUniqueOrientations(
          p,
        ).toList();
        for (var i = 0; i < orientations.length; i++) {
          for (var j = i + 1; j < orientations.length; j++) {
            expect(
              PolyominoTransformer.areEquivalent(
                orientations[i],
                orientations[j],
              ),
              isTrue,
              reason: '${p.id}: orientation $i and $j are not equivalent',
            );
          }
        }
      }
    });

    test('要素同士の cells リストは全て異なる', () {
      for (final p in kAllPolyominoes) {
        final orientations = PolyominoTransformer.allUniqueOrientations(
          p,
        ).toList();
        final keys = orientations.map((q) => q.cells.toString()).toList();
        expect(
          keys.toSet().length,
          keys.length,
          reason: '${p.id}: duplicate cells in orientations',
        );
      }
    });
  });

  // ─── 12. areEquivalent ──────────────────────────────────────────────
  group('areEquivalent', () {
    test('同じ向きの同じピースは true', () {
      expect(PolyominoTransformer.areEquivalent(kT4, kT4), isTrue);
    });

    test('I5 横向きと縦向きは true', () {
      final vertical = PolyominoTransformer.rotate90(kI5);
      expect(PolyominoTransformer.areEquivalent(kI5, vertical), isTrue);
    });

    test('L4 と rotate90(L4) は true', () {
      expect(
        PolyominoTransformer.areEquivalent(
          kL4,
          PolyominoTransformer.rotate90(kL4),
        ),
        isTrue,
      );
    });

    test('L3 と flipH(L3) は true（鏡像で一致）', () {
      expect(
        PolyominoTransformer.areEquivalent(
          kL3,
          PolyominoTransformer.flipHorizontal(kL3),
        ),
        isTrue,
      );
    });

    test('T5 と L5 は false（異なる形状）', () {
      expect(PolyominoTransformer.areEquivalent(kT5, kL5), isFalse);
    });

    test('I4 と O4 は false', () {
      expect(PolyominoTransformer.areEquivalent(kI4, kO4), isFalse);
    });

    // 反射律: areEquivalent(p, p) == true
    test('反射律: 全19種で areEquivalent(p, p) == true', () {
      for (final p in kAllPolyominoes) {
        expect(
          PolyominoTransformer.areEquivalent(p, p),
          isTrue,
          reason: '${p.id}: areEquivalent(p,p) is false',
        );
      }
    });

    // 対称律: areEquivalent(a, b) == areEquivalent(b, a)
    test('対称律: areEquivalent(a,b) == areEquivalent(b,a)', () {
      for (var i = 0; i < kAllPolyominoes.length; i++) {
        for (var j = i + 1; j < kAllPolyominoes.length; j++) {
          final a = kAllPolyominoes[i];
          final b = kAllPolyominoes[j];
          expect(
            PolyominoTransformer.areEquivalent(a, b),
            PolyominoTransformer.areEquivalent(b, a),
            reason: '${a.id} vs ${b.id}: symmetry violated',
          );
        }
      }
    });

    // 推移律: areEquivalent(a,b) && areEquivalent(b,c) ⇒ areEquivalent(a,c)
    test('推移律: 全19種の回転バリアント間で推移的', () {
      for (final p in kAllPolyominoes) {
        final q = PolyominoTransformer.rotate90(p);
        final r = PolyominoTransformer.rotate180(p);
        // p≡q かつ q≡r ⇒ p≡r
        if (PolyominoTransformer.areEquivalent(p, q) &&
            PolyominoTransformer.areEquivalent(q, r)) {
          expect(
            PolyominoTransformer.areEquivalent(p, r),
            isTrue,
            reason: '${p.id}: transitivity violated',
          );
        }
      }
    });

    // 網羅性: 19×19 マトリクスで対角線のみ true
    test('網羅性: 異なる種類はすべて areEquivalent == false', () {
      for (var i = 0; i < kAllPolyominoes.length; i++) {
        for (var j = 0; j < kAllPolyominoes.length; j++) {
          final a = kAllPolyominoes[i];
          final b = kAllPolyominoes[j];
          final expected = (i == j);
          expect(
            PolyominoTransformer.areEquivalent(a, b),
            expected,
            reason: '${a.id} vs ${b.id}: expected areEquivalent=$expected',
          );
        }
      }
    });
  });
}
