import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v3.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NonTrivialPuzzleGenerator', () {
    group('NORMAL: non-separable を返す', () {
      const seeds = [1, 2, 3, 5, 7, 10, 42, 100];
      for (final seed in seeds) {
        test('seed=$seed', () {
          final r = NonTrivialPuzzleGenerator.generate(
            difficulty: Difficulty.normal,
            seed: seed,
          );
          expect(r, isA<Ok>(), reason: 'seed=$seed must return Ok');
          final vp = (r as Ok).value;
          final m = computePuzzleMetrics(vp.puzzle);
          expect(
            m.straightCutSeparable,
            isFalse,
            reason: 'seed=$seed NORMAL must be non-separable',
          );
        });
      }
    });

    group('HARD: non-separable を返す', () {
      const seeds = [1, 2, 3, 5, 7, 10, 42, 100];
      for (final seed in seeds) {
        test('seed=$seed', () {
          final r = NonTrivialPuzzleGenerator.generate(
            difficulty: Difficulty.hard,
            seed: seed,
          );
          expect(r, isA<Ok>(), reason: 'seed=$seed must return Ok');
          final vp = (r as Ok).value;
          final m = computePuzzleMetrics(vp.puzzle);
          expect(
            m.straightCutSeparable,
            isFalse,
            reason: 'seed=$seed HARD must be non-separable',
          );
        });
      }
    });

    group('EASY 素通し: V3 と同一パズルを返す', () {
      const seeds = [1, 42, 999];
      for (final seed in seeds) {
        test('seed=$seed', () {
          final rNt = NonTrivialPuzzleGenerator.generate(
            difficulty: Difficulty.easy,
            seed: seed,
          );
          final rV3 = CompactPuzzleGeneratorV3.generate(
            difficulty: Difficulty.easy,
            seed: seed,
          );
          expect(
            rNt,
            isA<Ok>(),
            reason: 'NonTrivial easy seed=$seed must be Ok',
          );
          expect(rV3, isA<Ok>(), reason: 'V3 easy seed=$seed must be Ok');
          final vpNt = (rNt as Ok).value;
          final vpV3 = (rV3 as Ok).value;
          expect(
            vpNt.puzzle.frame,
            equals(vpV3.puzzle.frame),
            reason: 'frame must match seed=$seed',
          );
          expect(
            vpNt.puzzle.blocks.map((b) => b.cells).toList(),
            equals(vpV3.puzzle.blocks.map((b) => b.cells).toList()),
            reason: 'blocks must match seed=$seed',
          );
        });
      }
    });

    group('常に Ok を返す (easy/normal/hard × seed 1..30)', () {
      for (final d in Difficulty.values) {
        for (int seed = 1; seed <= 30; seed++) {
          test('${d.name} seed=$seed', () {
            final r = NonTrivialPuzzleGenerator.generate(
              difficulty: d,
              seed: seed,
            );
            expect(r, isA<Ok>(), reason: '${d.name} seed=$seed must return Ok');
            final vp = (r as Ok).value;
            expect(
              vp.puzzle.frame,
              isNotEmpty,
              reason: '${d.name} seed=$seed frame must be non-empty',
            );
          });
        }
      }
    });

    group('レポートテスト: フィルタ前後 separable_rate', () {
      test('NORMAL seed 1..100', () {
        int separableAfter = 0;
        int fallbackCount = 0;
        int total = 0;

        for (int seed = 1; seed <= 100; seed++) {
          final r = NonTrivialPuzzleGenerator.generate(
            difficulty: Difficulty.normal,
            seed: seed,
          );
          expect(r, isA<Ok>(), reason: 'NORMAL seed=$seed must be Ok');
          total++;
          final vp = (r as Ok).value;
          final m = computePuzzleMetrics(vp.puzzle);
          if (m.straightCutSeparable) {
            separableAfter++;
            fallbackCount++;
          }
        }

        final rateAfter = separableAfter / total;
        // ADR-0017 計測値（フィルタ前）
        const rateBefore = 0.36;

        print('');
        print('=== NORMAL separable_rate レポート ===');
        print('  フィルタ前 (ADR-0017): ${(rateBefore * 100).toStringAsFixed(1)}%');
        print('  フィルタ後           : ${(rateAfter * 100).toStringAsFixed(1)}%');
        print('  フォールバック件数   : $fallbackCount / $total');
        print('');
      }, tags: ['report']);

      test('HARD seed 1..100', () {
        int separableAfter = 0;
        int fallbackCount = 0;
        int total = 0;

        for (int seed = 1; seed <= 100; seed++) {
          final r = NonTrivialPuzzleGenerator.generate(
            difficulty: Difficulty.hard,
            seed: seed,
          );
          expect(r, isA<Ok>(), reason: 'HARD seed=$seed must be Ok');
          total++;
          final vp = (r as Ok).value;
          final m = computePuzzleMetrics(vp.puzzle);
          if (m.straightCutSeparable) {
            separableAfter++;
            fallbackCount++;
          }
        }

        final rateAfter = separableAfter / total;
        const rateBefore = 0.41;

        print('');
        print('=== HARD separable_rate レポート ===');
        print('  フィルタ前 (ADR-0017): ${(rateBefore * 100).toStringAsFixed(1)}%');
        print('  フィルタ後           : ${(rateAfter * 100).toStringAsFixed(1)}%');
        print('  フォールバック件数   : $fallbackCount / $total');
        print('');
      }, tags: ['report']);
    });
  });
}
