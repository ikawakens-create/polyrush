import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_first_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

String _serializePuzzle(VerifiedPuzzle vp) {
  final blocks = vp.puzzle.blocks.map((b) {
    final cs = b.cells.toList()
      ..sort((a, c) => a.$1 != c.$1 ? a.$1 - c.$1 : a.$2 - c.$2);
    return '${b.source.id}:${cs.map((c) => '${c.$1},${c.$2}').join('/')}';
  }).toList()..sort();
  return '${vp.solutionCount}|${blocks.join('|')}';
}

void main() {
  group('FrameFirstPuzzleGenerator 生成契約', () {
    for (final d in Difficulty.values) {
      test('${d.name}: Ok・解数1〜3・isFallback false・枠を過不足なく被覆・全異種', () {
        var okCount = 0;
        for (var i = 0; i < 10; i++) {
          final r = FrameFirstPuzzleGenerator.generate(
            difficulty: d,
            seed: 300000 * (d.index + 1) + i,
          );
          expect(
            r,
            isA<Ok<VerifiedPuzzle, CompactPuzzleError>>(),
            reason: '${d.name}: 生成が成功すること',
          );
          final vp = (r as Ok<VerifiedPuzzle, CompactPuzzleError>).value;
          okCount++;

          expect(
            vp.solutionCount,
            inInclusiveRange(1, 3),
            reason: '${d.name}: 解数が採用基準1〜3',
          );
          expect(vp.isFallback, isFalse, reason: '${d.name}: フォールバックなし(判断8)');
          expect(vp.attemptsUsed, greaterThanOrEqualTo(1));

          final p = vp.puzzle;
          expect(
            p.blocks.length,
            d.blockCount,
            reason: '${d.name}: ピース数が blockCount',
          );
          // 全異種(重複ピースなし・判断5)
          final ids = p.blocks.map((b) => b.source.id).toSet();
          expect(ids.length, p.blocks.length, reason: '${d.name}: 全ピースが異種');
          // 被覆: ブロック和 == 枠、重複なし
          final covered = <Cell>{};
          for (final b in p.blocks) {
            covered.addAll(b.cells);
          }
          expect(
            covered.length,
            p.blocks.fold<int>(0, (a, b) => a + b.cells.length),
            reason: '${d.name}: ブロック間で重複なし',
          );
          expect(
            covered,
            equals(p.frame),
            reason: '${d.name}: ブロック和が枠と一致(過不足なし)',
          );
          expect(p.difficulty, d);
        }
        expect(okCount, 10, reason: '${d.name}: 10シードすべて生成できること');
      });
    }

    test('決定論: 同じ (difficulty, seed) は同一パズルを返す', () {
      for (final d in Difficulty.values) {
        final seed = 777000 + d.index;
        final r1 = FrameFirstPuzzleGenerator.generate(
          difficulty: d,
          seed: seed,
        );
        final r2 = FrameFirstPuzzleGenerator.generate(
          difficulty: d,
          seed: seed,
        );
        expect(r1, isA<Ok<VerifiedPuzzle, CompactPuzzleError>>());
        expect(r2, isA<Ok<VerifiedPuzzle, CompactPuzzleError>>());
        final v1 = (r1 as Ok<VerifiedPuzzle, CompactPuzzleError>).value;
        final v2 = (r2 as Ok<VerifiedPuzzle, CompactPuzzleError>).value;
        expect(
          _serializePuzzle(v2),
          _serializePuzzle(v1),
          reason: '${d.name}: 同一入力で同一出力(決定論)',
        );
      }
    });
  });
}
