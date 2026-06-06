import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v2.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

// CI で旧 Compact と新 V2 の平均充填率を並べて計測する（ADR-0012 判断5）。
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
      test('旧Compactと新V2の充填率比較・V2 correctness（seed=1..$kSeedSamples）', () {
        var oldFill = 0.0;
        var oldOk = 0;
        var newFill = 0.0;
        var newOk = 0;
        var newErr = 0;
        final errDetails = <String>[];

        for (var seed = 1; seed <= kSeedSamples; seed++) {
          // 旧 Compact
          final oldResult = CompactPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: seed,
          );
          if (oldResult is Ok<VerifiedPuzzle, CompactPuzzleError>) {
            oldFill += _fillRate(oldResult.value.puzzle);
            oldOk++;
          }

          // 新 V2
          final newResult = CompactPuzzleGeneratorV2.generate(
            difficulty: difficulty,
            seed: seed,
          );
          if (newResult is Ok<VerifiedPuzzle, CompactPuzzleError>) {
            newFill += _fillRate(newResult.value.puzzle);
            newOk++;
            final vp = newResult.value;
            expect(
              vp.solutionCount,
              inInclusiveRange(1, 3),
              reason: '${difficulty.name}/seed=$seed: solutionCount は 1〜3',
            );
            expect(
              vp.isFallback,
              isFalse,
              reason: '${difficulty.name}/seed=$seed: V2 はフォールバックしない（常に false）',
            );
            expect(
              isFrameSimplyConnected(vp.puzzle.frame),
              isTrue,
              reason: '${difficulty.name}/seed=$seed: 枠が単連結であること（穴なし）',
            );
            final ids =
                vp.puzzle.blocks.map((b) => b.source.id).toList();
            expect(
              ids.toSet().length,
              equals(ids.length),
              reason: '${difficulty.name}/seed=$seed: blocks 内の source.id がすべて異なること（重複なし）',
            );
          } else {
            newErr++;
            final err = (newResult as Err<VerifiedPuzzle, CompactPuzzleError>).error;
            errDetails.add('${difficulty.name}/seed=$seed: $err');
          }
        }

        final oldAvg = oldOk > 0 ? oldFill / oldOk : 0.0;
        final newAvg = newOk > 0 ? newFill / newOk : 0.0;
        // ignore: avoid_print
        print(
          '${difficulty.name} : N=$kSeedSamples'
          ' | OLD avg fill=${oldAvg.toStringAsFixed(2)} (ok=$oldOk)'
          ' | NEW avg fill=${newAvg.toStringAsFixed(2)} (ok=$newOk)'
          ' | NEW Err=$newErr',
        );

        expect(
          newErr,
          equals(0),
          reason: 'maxCompactRetries=8 でリトライ予算が足りること。'
              '失敗seed: $errDetails',
        );
      });
    });
  }
}
