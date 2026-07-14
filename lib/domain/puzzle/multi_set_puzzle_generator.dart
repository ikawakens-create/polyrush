import 'dart:math' as math;

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

/// 1つの枠と、その枠を解く相異なる採用セット(variant)の束(ADR-0021)。
///
/// [variants] は各々が同一 [frame] を過不足なく敷く別々のピース構成(source id
/// multiset が相異なる)。length は 1 以上 maxVariants 以下(best-effort)。
/// [canonicalKey] は8二面体正準ID(将来のデイリー枠ID・ADR-0020 判断4/10)。
class MultiSetPuzzle {
  MultiSetPuzzle({
    required this.frame,
    required this.canonicalKey,
    required this.variants,
  });

  final Set<Cell> frame;
  final String canonicalKey;
  final List<VerifiedPuzzle> variants;
}

/// 枠ファースト multi-set 生成器(ADR-0021)。
///
/// [FrameFirstPuzzleGenerator] が「1枠→採用1セット」で early-return するのに対し、
/// 本器は同一枠から採用セットを **最大 [maxVariants] 個まで集めて** 返す(⑥ の核心)。
/// 確定資産(FrameGenerator / enumerateDistinctPieceSets / FrameTiler / solver /
/// metrics)を一切変更せずラップする(B案)。消費側配線は本 PR では扱わない(⑥-c)。
///
/// 方針(ADR-0021):
/// - best-effort: 採用が1つも無い枠(easy/hard の一部・⑥-a計測で min=0 を確認)は
///   次サブシードの枠へ。全試行で採用0なら Err。「ちょうど K 個」は強制しない。
/// - 枠は選び直さない: 単一生成([FrameFirstPuzzleGenerator])と同じ決定論プロセスで
///   枠を得る(easy の枠単調問題・ADR-0020 判断6 を再発させない)。
/// - distinctness = ピース構成(source id multiset)。列挙器が構成の重複を出さないため
///   追加の重複排除は不要(⑥-a計測で「採用数 = distinct構成数」を確認済み)。
/// - normal/hard は非separable(良形)を優先採用、不足時のみ protrusionRatio 昇順で
///   separable を補充(同一枠内・count は遅延評価)。easy はフィルタ対象外(ADR-0018/0020)。
/// - 決定論: [FrameFirstPuzzleGenerator] と同一のサブシード派生でセット走査順を
///   Fisher-Yates シャッフル。同じ (difficulty, seed, maxVariants) は常に同一結果。
///   典型ケース(非separable が存在)では variants.first は単一生成の結果と一致する意図。
class MultiSetPuzzleGenerator {
  MultiSetPuzzleGenerator._();

  /// countSolutions の limit。解数1〜3を採用、4は頭打ち(非採用)。
  static const int _solutionCap = 4;

  /// [difficulty]・[seed] から、同一枠の採用セットを最大 [maxVariants] 個返す。
  static Result<MultiSetPuzzle, CompactPuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
    int maxVariants = 8,
    int maxAttempts = 20,
  }) {
    assert(maxVariants >= 1, 'maxVariants must be >= 1');
    final pool = difficulty.pool;
    final blockCount = difficulty.blockCount;
    final isEasy = difficulty == Difficulty.easy;

    var anyFrameGenerated = false;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final frameSeed = seed + attempt;
      final frame = FrameGenerator.generate(difficulty, frameSeed);
      if (frame == null) continue;
      anyFrameGenerated = true;

      // 確定資産の列挙器は不触。返り値をコピーしてから並べ替える。
      final sets = List<List<PolyominoData>>.of(
        enumerateDistinctPieceSets(pool, blockCount, frame.length),
      );
      _shuffleInPlace(sets, _deriveSubSeed(seed, attempt));

      final accepted = <VerifiedPuzzle>[];
      // normal/hard 用の separable フォールバック候補(count は遅延評価)。
      final fallback =
          <({double prot, List<PolyominoData> set, GeneratedPuzzle puzzle})>[];

      for (final set in sets) {
        if (accepted.length >= maxVariants) break;
        final tiling = FrameTiler.firstTiling(frame, set);
        if (tiling == null) continue; // 敷き詰め不能
        final puzzle = _build(frame, tiling, frameSeed, difficulty);

        if (isEasy) {
          final count = PuzzleSolver.countSolutions(
            frame: frame,
            shapes: set,
            limit: _solutionCap,
          );
          if (count < 1 || count > 3) continue;
          accepted.add(
            VerifiedPuzzle(
              puzzle: puzzle,
              solutionCount: count,
              attemptsUsed: attempt + 1,
              isFallback: false,
            ),
          );
          continue;
        }

        // normal/hard: metrics 先行。非separable のみ countSolutions を掛けて採用。
        final m = computePuzzleMetrics(puzzle);
        if (!m.straightCutSeparable) {
          final count = PuzzleSolver.countSolutions(
            frame: frame,
            shapes: set,
            limit: _solutionCap,
          );
          if (count < 1 || count > 3) continue;
          accepted.add(
            VerifiedPuzzle(
              puzzle: puzzle,
              solutionCount: count,
              attemptsUsed: attempt + 1,
              isFallback: false,
            ),
          );
        } else {
          // separable: count は掛けず protrusion 昇順のフォールバック候補に積む。
          fallback.add((prot: m.protrusionRatio, set: set, puzzle: puzzle));
        }
      }

      // 非separable が maxVariants に満たない場合のみ、protrusion 昇順で補充。
      if (!isEasy && accepted.length < maxVariants && fallback.isNotEmpty) {
        fallback.sort((a, b) => a.prot.compareTo(b.prot));
        for (final fb in fallback) {
          if (accepted.length >= maxVariants) break;
          final count = PuzzleSolver.countSolutions(
            frame: frame,
            shapes: fb.set,
            limit: _solutionCap,
          );
          if (count < 1 || count > 3) continue;
          accepted.add(
            VerifiedPuzzle(
              puzzle: fb.puzzle,
              solutionCount: count,
              attemptsUsed: attempt + 1,
              isFallback: false,
            ),
          );
        }
      }

      if (accepted.isNotEmpty) {
        return Ok(
          MultiSetPuzzle(
            frame: frame,
            canonicalKey: FrameGenerator.canonicalKey(frame),
            variants: accepted,
          ),
        );
      }
      // この枠は採用0 → 次サブシードの枠へ(best-effort)。
    }

    return anyFrameGenerated
        ? const Err(CompactPuzzleError.qualityNotMet)
        : const Err(CompactPuzzleError.generationFailed);
  }

  /// セットリストを [subSeed] 由来で Fisher-Yates シャッフル(in-place・決定論)。
  static void _shuffleInPlace(List<List<PolyominoData>> xs, int subSeed) {
    final rng = math.Random(subSeed);
    for (var i = xs.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = xs[i];
      xs[i] = xs[j];
      xs[j] = t;
    }
  }

  /// FrameFirstPuzzleGenerator._deriveSubSeed と同一の 32bit LCG(決定論の整合性)。
  static int _deriveSubSeed(int seed, int attempt) {
    const mask = 0xFFFFFFFF;
    final lo = seed & 0xFFFF;
    final hi = (seed >> 16) & 0xFFFF;
    return (lo * 1664525 + hi * 22695477 + attempt * 1013904223 + 1) & mask;
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
