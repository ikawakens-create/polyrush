import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v2.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v3.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

// CI で V2 と V3 の平均充填率を並べて計測する（ADR-0013 判断5）。
// @Tags(['slow']) は付けない（PR の CI で実行され数値が出るようにする）。

/// 充填率 = frame のセル数 / (外接矩形の幅 × 高さ)
double _fillRate(GeneratedPuzzle puzzle) {
  final bb = puzzle.boundingBox;
  final area = (bb.maxX - bb.minX + 1) * (bb.maxY - bb.minY + 1);
  return puzzle.frame.length / area;
}

const kSeedSamples = 300;

void main() {
  for (final difficulty in Difficulty.values) {
    group(difficulty.name, () {
      test('V2とV3の充填率比較・V3 correctness（seed=1..$kSeedSamples）', () {
        var v2Fill = 0.0;
        var v2Ok = 0;
        var v3Fill = 0.0;
        var v3Ok = 0;
        var v3Err = 0;
        final errDetails = <String>[];

        for (var seed = 1; seed <= kSeedSamples; seed++) {
          // V2
          final v2Result = CompactPuzzleGeneratorV2.generate(
            difficulty: difficulty,
            seed: seed,
          );
          if (v2Result is Ok<VerifiedPuzzle, CompactPuzzleError>) {
            v2Fill += _fillRate(v2Result.value.puzzle);
            v2Ok++;
          }

          // V3
          final v3Result = CompactPuzzleGeneratorV3.generate(
            difficulty: difficulty,
            seed: seed,
          );
          if (v3Result is Ok<VerifiedPuzzle, CompactPuzzleError>) {
            v3Fill += _fillRate(v3Result.value.puzzle);
            v3Ok++;
            final vp = v3Result.value;
            expect(
              vp.solutionCount,
              inInclusiveRange(1, 3),
              reason: '${difficulty.name}/seed=$seed: solutionCount は 1〜3',
            );
            expect(
              vp.isFallback,
              isFalse,
              reason: '${difficulty.name}/seed=$seed: V3 はフォールバックしない（常に false）',
            );
            expect(
              isFrameSimplyConnected(vp.puzzle.frame),
              isTrue,
              reason: '${difficulty.name}/seed=$seed: 枠が単連結であること（穴なし）',
            );
            final ids = vp.puzzle.blocks.map((b) => b.source.id).toList();
            expect(
              ids.toSet().length,
              equals(ids.length),
              reason:
                  '${difficulty.name}/seed=$seed: blocks 内の source.id がすべて異なること（重複なし）',
            );
          } else {
            v3Err++;
            final err =
                (v3Result as Err<VerifiedPuzzle, CompactPuzzleError>).error;
            errDetails.add('${difficulty.name}/seed=$seed: $err');
          }
        }

        final v2Avg = v2Ok > 0 ? v2Fill / v2Ok : 0.0;
        final v3Avg = v3Ok > 0 ? v3Fill / v3Ok : 0.0;
        // ignore: avoid_print
        print(
          '${difficulty.name} : N=$kSeedSamples'
          ' | V2 avg fill=${v2Avg.toStringAsFixed(2)} (ok=$v2Ok)'
          ' | V3 avg fill=${v3Avg.toStringAsFixed(2)} (ok=$v3Ok)'
          ' | V3 Err=$v3Err',
        );

        expect(
          v3Err,
          equals(0),
          reason:
              'maxCompactRetries=8 でリトライ予算が足りること。'
              '失敗seed: $errDetails',
        );
      });
    });
  }
}
