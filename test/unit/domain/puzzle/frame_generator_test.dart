import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';

const List<Cell> _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

bool _connected(Set<Cell> cells) {
  if (cells.isEmpty) return false;
  final seen = <Cell>{cells.first};
  final stack = <Cell>[cells.first];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    for (final d in _dirs) {
      final nb = (c.$1 + d.$1, c.$2 + d.$2);
      if (cells.contains(nb) && seen.add(nb)) stack.add(nb);
    }
  }
  return seen.length == cells.length;
}

({int h, int w, int minY, int minX}) _bbox(Set<Cell> cells) {
  var minY = cells.first.$1, maxY = cells.first.$1;
  var minX = cells.first.$2, maxX = cells.first.$2;
  for (final c in cells) {
    if (c.$1 < minY) minY = c.$1;
    if (c.$1 > maxY) maxY = c.$1;
    if (c.$2 < minX) minX = c.$2;
    if (c.$2 > maxX) maxX = c.$2;
  }
  return (h: maxY - minY + 1, w: maxX - minX + 1, minY: minY, minX: minX);
}

bool _hasHole(Set<Cell> cells) {
  final bb = _bbox(cells);
  final norm = cells.map((c) => (c.$1 - bb.minY, c.$2 - bb.minX)).toSet();
  final bg = <Cell>{};
  for (var y = 0; y < bb.h; y++) {
    for (var x = 0; x < bb.w; x++) {
      if (!norm.contains((y, x))) bg.add((y, x));
    }
  }
  if (bg.isEmpty) return false;
  final seen = <Cell>{};
  final stack = <Cell>[];
  for (final c in bg) {
    if (c.$1 == 0 || c.$1 == bb.h - 1 || c.$2 == 0 || c.$2 == bb.w - 1) {
      if (seen.add(c)) stack.add(c);
    }
  }
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    for (final d in _dirs) {
      final nb = (c.$1 + d.$1, c.$2 + d.$2);
      if (bg.contains(nb) && seen.add(nb)) stack.add(nb);
    }
  }
  return seen.length != bg.length;
}

void main() {
  group('FrameGenerator 枠不変条件', () {
    for (final d in Difficulty.values) {
      test('${d.name}: 生成枠が制約(単連結・穴なし・セル数・充填率・アスペクト)を満たす', () {
        expect(
          FrameGenerator.validBoxNs(d),
          isNotEmpty,
          reason: '${d.name}: 制約充足枠が存在すること',
        );
        final lo = FrameGenerator.fillLowerBound(d);
        var generated = 0;
        for (var i = 0; i < 20; i++) {
          final f = FrameGenerator.generate(d, 4000 * (d.index + 1) + i);
          if (f == null) continue;
          generated++;
          final n = f.length;
          expect(
            n,
            inInclusiveRange(d.minTotalCells, d.maxTotalCells),
            reason: '${d.name}: セル数が難易度帯内',
          );
          expect(_connected(f), isTrue, reason: '${d.name}: 単連結');
          expect(_hasHole(f), isFalse, reason: '${d.name}: 穴なし');
          final bb = _bbox(f);
          final aspect = bb.h > bb.w ? bb.h / bb.w : bb.w / bb.h;
          expect(
            aspect,
            lessThanOrEqualTo(FrameGenerator.kAspectMax + 1e-9),
            reason: '${d.name}: アスペクト≤1.6',
          );
          final fill = n / (bb.h * bb.w);
          expect(
            fill,
            greaterThanOrEqualTo(lo - 1e-9),
            reason: '${d.name}: 充填率下限',
          );
          expect(
            fill,
            lessThanOrEqualTo(FrameGenerator.kFillMax + 1e-9),
            reason: '${d.name}: 充填率上限',
          );
        }
        expect(generated, greaterThan(0), reason: '${d.name}: 1つ以上生成できる');
      });
    }
  });

  // ADR-0020 判断6: easy 下限0.75 による枠バリエーション改善の計測。
  // 理論上限は distinct 正準形状 154種(下限0.85 では 3種)。実測が何種届くかを報告する。
  group('easy 枠バリエーション計測(判断6)', () {
    test('easy: 200シードの distinct 正準形状数を計測しレポート', () {
      const seeds = 200;
      final shapes = <String>{};
      var generated = 0;
      for (var i = 0; i < seeds; i++) {
        final f = FrameGenerator.generate(Difficulty.easy, 900000 + i);
        if (f == null) continue;
        generated++;
        shapes.add(FrameGenerator.canonicalKey(f));
      }
      print('');
      print('===== easy 枠バリエーション(判断6・下限0.75) =====');
      print(
        '生成 $generated / $seeds シード, distinct 正準形状 ${shapes.length} 種 '
        '(下限0.85時の理論値=3種, 下限0.75の理論上限=154種)',
      );
      // 下限0.85(従来)の理論値3種より確実に増えていること。
      expect(
        shapes.length,
        greaterThan(3),
        reason: 'easy 下限0.75 で正準形状が3種(従来)より増えること',
      );
    });
  });
}
