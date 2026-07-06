import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/frame_tiler.dart';
import 'package:polyrush/domain/puzzle/piece_set_enumerator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:polyrush/domain/puzzle/solver.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// 枠ファースト生成器(ADR-0020 判断1/2/7/8)。
///
/// パイプライン: FrameGenerator(良い枠を先に生成) → enumerateDistinctPieceSets
/// (重複なしセット列挙) → PuzzleSolver.countSolutions(解数1〜3を採用判定) →
/// FrameTiler.firstTiling(1解を materialize) → VerifiedPuzzle 組み立て。
///
/// API は [NonTrivialPuzzleGenerator] と同形(同じ Result 契約)。play_screen は
/// puzzle_generator_selector 経由で本生成器と V3 経路を切り替える(判断1)。
///
/// - (seed, attempt) の決定論的試行(seed+attempt)・リトライ上限・フォールバックなし
///   (isFallback は常に false。採用は解数1〜3のみ)を V3 系から踏襲(判断8)。
/// - normal/hard は straightCutSeparable==false を優先、無ければ protrusionRatio 最小
///   (ADR-0018 と同一挙動。判断7)。easy はフィルタ対象外。
/// - セット走査は決定論的順序で最初の合格セットを確定(早期確定。判断2 手順3)。
class FrameFirstPuzzleGenerator {
  FrameFirstPuzzleGenerator._();

  /// countSolutions の limit。解数1〜3を採用、4は頭打ち(非採用)。
  static const int _solutionCap = 4;

  static Result<VerifiedPuzzle, CompactPuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
    int maxAttempts = 20,
  }) {
    final pool = difficulty.pool;
    final blockCount = difficulty.blockCount;
    final isEasy = difficulty == Difficulty.easy;

    var anyFrameGenerated = false;
    // normal/hard 用: 非separableが得られない枠向けの protrusion最小フォールバック候補。
    GeneratedPuzzle? bestPuzzle;
    var bestCount = 0;
    var bestAttempt = 0;
    var bestProt = double.infinity;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final frameSeed = seed + attempt;
      final frame = FrameGenerator.generate(difficulty, frameSeed);
      if (frame == null) continue;
      anyFrameGenerated = true;

      final sets = enumerateDistinctPieceSets(pool, blockCount, frame.length);
      for (final set in sets) {
        final count = PuzzleSolver.countSolutions(
          frame: frame,
          shapes: set,
          limit: _solutionCap,
        );
        if (count < 1 || count > 3) continue; // 採用基準(1〜3)

        final tiling = FrameTiler.firstTiling(frame, set);
        if (tiling == null) continue; // 判断2b により count>=1 なら通常来ない
        final puzzle = _build(frame, tiling, frameSeed, difficulty);

        if (isEasy) {
          // easy はフィルタ対象外。最初の合格セットを即採用。
          return Ok(
            VerifiedPuzzle(
              puzzle: puzzle,
              solutionCount: count,
              attemptsUsed: attempt + 1,
              isFallback: false,
            ),
          );
        }

        // normal/hard: straightCutSeparable==false を優先(ADR-0018 と同一挙動)。
        final m = computePuzzleMetrics(puzzle);
        if (!m.straightCutSeparable) {
          return Ok(
            VerifiedPuzzle(
              puzzle: puzzle,
              solutionCount: count,
              attemptsUsed: attempt + 1,
              isFallback: false,
            ),
          );
        }
        if (m.protrusionRatio < bestProt) {
          bestProt = m.protrusionRatio;
          bestPuzzle = puzzle;
          bestCount = count;
          bestAttempt = attempt + 1;
        }
      }
    }

    // 非separableが得られなかった場合は protrusion最小をフォールバック採用(判断7)。
    // 解数は常に1〜3なので isFallback は false(判断8)。
    if (bestPuzzle != null) {
      return Ok(
        VerifiedPuzzle(
          puzzle: bestPuzzle,
          solutionCount: bestCount,
          attemptsUsed: bestAttempt,
          isFallback: false,
        ),
      );
    }
    return anyFrameGenerated
        ? const Err(CompactPuzzleError.qualityNotMet)
        : const Err(CompactPuzzleError.generationFailed);
  }

  static GeneratedPuzzle _build(
    Set<Cell> frame,
    List<PlacedBlock> blocks,
    int seed,
    Difficulty difficulty,
  ) {
    var minY = frame.first.$1, maxY = frame.first.$1;
    var minX = frame.first.$2, maxX = frame.first.$2;
    for (final c in frame) {
      if (c.$1 < minY) minY = c.$1;
      if (c.$1 > maxY) maxY = c.$1;
      if (c.$2 < minX) minX = c.$2;
      if (c.$2 > maxX) maxX = c.$2;
    }
    return GeneratedPuzzle(
      frame: frame,
      boundingBox: (minY: minY, maxY: maxY, minX: minX, maxX: maxX),
      blocks: blocks,
      seed: seed,
      difficulty: difficulty,
    );
  }
}
