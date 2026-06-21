import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';

String _solutionAscii(GeneratedPuzzle p) {
  final cellToBlock = <Cell, int>{};
  for (var i = 0; i < p.blocks.length; i++) {
    for (final c in p.blocks[i].cells) {
      cellToBlock[c] = i;
    }
  }
  final ys = p.frame.map((c) => c.$1);
  final xs = p.frame.map((c) => c.$2);
  final minY = ys.reduce(min);
  final maxY = ys.reduce(max);
  final minX = xs.reduce(min);
  final maxX = xs.reduce(max);
  final sb = StringBuffer();
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final b = cellToBlock[(y, x)];
      sb.write(b == null ? '.' : b.toString());
    }
    sb.write('\n');
  }
  return sb.toString();
}

void main() {
  test('診断: 解ASCII + 枠/ピース内訳 (easy & normal, seed 1..10)', () {
    for (final d in [Difficulty.easy, Difficulty.normal]) {
      for (var seed = 1; seed <= 10; seed++) {
        final r = NonTrivialPuzzleGenerator.generate(difficulty: d, seed: seed);
        switch (r) {
          case Ok(:final value):
            final p = value.puzzle;
            final sizes = p.blocks.map((b) => b.cells.length).join('+');
            final sum = p.blocks.fold<int>(0, (s, b) => s + b.cells.length);
            // ignore: avoid_print
            print('=== $d seed=$seed  frame=${p.frame.length}  '
                'pieces=$sizes=$sum  (0=赤 1=青 2=緑 3=紫) ===');
            // ignore: avoid_print
            print(_solutionAscii(p));
          case Err(:final error):
            // ignore: avoid_print
            print('=== $d seed=$seed GEN-FAIL: $error ===');
        }
      }
    }
  });
}
