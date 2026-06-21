import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

List<Cell> _norm(List<Cell> cells) {
  final minY = cells.map((c) => c.$1).reduce(min);
  final minX = cells.map((c) => c.$2).reduce(min);
  final out = cells.map((c) => (c.$1 - minY, c.$2 - minX)).toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return out;
}

void main() {
  test('診断: orientation(トレイ表示) == cells(実配置) か', () {
    final bad = <String>[];
    for (final d in [Difficulty.easy, Difficulty.normal, Difficulty.hard]) {
      for (var seed = 1; seed <= 20; seed++) {
        final r = NonTrivialPuzzleGenerator.generate(difficulty: d, seed: seed);
        VerifiedPuzzle? vp;
        switch (r) {
          case Ok(:final value):
            vp = value;
          case Err():
        }
        if (vp == null) continue;
        final p = vp.puzzle;
        for (var i = 0; i < p.blocks.length; i++) {
          final b = p.blocks[i];
          final ori = _norm(b.orientation.cells);
          final cel = _norm(b.cells);
          if (ori.toString() != cel.toString()) {
            final line = '[MISMATCH $d seed=$seed piece=$i] '
                'orientation=$ori  cells=$cel  src.size=${b.source.size}';
            // ignore: avoid_print
            print(line);
            bad.add(line);
          }
        }
      }
    }
    // ignore: avoid_print
    print('=== orientation != cells の件数: ${bad.length} ===');
    expect(
      bad,
      isEmpty,
      reason: 'トレイ表示形状と実配置形状が違うピースがある（上のMISMATCHログ参照）',
    );
  });

  test('診断: easy/normal/hard seed=1 形状ダンプ', () {
    for (final d in [Difficulty.easy, Difficulty.normal, Difficulty.hard]) {
      final r = NonTrivialPuzzleGenerator.generate(difficulty: d, seed: 1);
      switch (r) {
        case Ok(:final value):
          final p = value.puzzle;
          // ignore: avoid_print
          print('--- $d seed=1 frame(${p.frame.length}) ---');
          for (var i = 0; i < p.blocks.length; i++) {
            final b = p.blocks[i];
            // ignore: avoid_print
            print('piece[$i] orientation=${_norm(b.orientation.cells)} '
                'cells=${_norm(b.cells)} source=${_norm(b.source.cells)}');
          }
        case Err(:final error):
          // ignore: avoid_print
          print('$d seed=1 GEN-FAIL: $error');
      }
    }
  });
}
