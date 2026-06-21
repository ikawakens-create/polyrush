import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

String _ascii(Set<Cell> frame) {
  final minY = frame.map((c) => c.$1).reduce(min);
  final maxY = frame.map((c) => c.$1).reduce(max);
  final minX = frame.map((c) => c.$2).reduce(min);
  final maxX = frame.map((c) => c.$2).reduce(max);
  final sb = StringBuffer();
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      sb.write(frame.contains((y, x)) ? '#' : '.');
    }
    sb.write('\n');
  }
  return sb.toString();
}

void main() {
  test('診断: 枠ASCII + 解数 (easy/normal/hard, seed 1..6)', () {
    for (final d in [Difficulty.easy, Difficulty.normal, Difficulty.hard]) {
      for (var seed = 1; seed <= 6; seed++) {
        final r = NonTrivialPuzzleGenerator.generate(difficulty: d, seed: seed);
        switch (r) {
          case Ok(:final value):
            final p = value.puzzle;
            final shapes = p.blocks.map((b) => b.source).toList();
            final count = PuzzleSolver.countSolutions(
              frame: p.frame,
              shapes: shapes,
              limit: 5,
            );
            final sizes = p.blocks
                .map((b) => b.orientation.cells.length)
                .join('+');
            // ignore: avoid_print
            print(
              '=== $d seed=$seed frame=${p.frame.length} '
              'pieces=$sizes solutions(<=5)=$count ===',
            );
            // ignore: avoid_print
            print(_ascii(p.frame));
          case Err(:final error):
            // ignore: avoid_print
            print('=== $d seed=$seed GEN-FAIL: $error ===');
        }
      }
    }
  });

  test('診断: easy seed=1 の解（絶対座標, color順=red,blue,green,purple）', () {
    final r = NonTrivialPuzzleGenerator.generate(
      difficulty: Difficulty.easy,
      seed: 1,
    );
    switch (r) {
      case Ok(:final value):
        final p = value.puzzle;
        // ignore: avoid_print
        print('FRAME(${p.frame.length}):');
        // ignore: avoid_print
        print(_ascii(p.frame));
        for (var i = 0; i < p.blocks.length; i++) {
          final cells = p.blocks[i].cells.toList()
            ..sort(
              (a, c) =>
                  a.$1 != c.$1 ? a.$1.compareTo(c.$1) : a.$2.compareTo(c.$2),
            );
          // ignore: avoid_print
          print('piece[$i] 絶対cells=$cells');
        }
      case Err():
    }
  });
}
