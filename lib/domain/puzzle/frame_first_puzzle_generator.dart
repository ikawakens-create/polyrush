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

/// 枠ファースト生成器(ADR-0020 判断1/2/7/8 + ⑤c 性能改善)。
///
/// パイプライン: FrameGenerator(良い枠を先に生成) → enumerateDistinctPieceSets
/// (重複なしセット列挙) → [⑤c Step1: 走査順を決定論シャッフル] → 走査
/// ([⑤c Step2: firstTiling 先行]) → VerifiedPuzzle 組み立て。
///
/// ⑤c の2改善(既定 ON。同じ seed なら結果は決定論的):
/// - Step1 [shuffleSets]: enumerateDistinctPieceSets の結果を (seed, attempt) 由来の
///   サブシードで Fisher-Yates シャッフルしてから走査する。採用セットが決定論的列挙順の
///   後方に固まり、届くまで大量の countSolutions を呼ぶ問題(判断9 で hard mean 507ms/
///   max 3.3s)を解消する。加えて「同じ枠→常に同じセット」という品質の偏りも解消する。
/// - Step2 [tilingFirst]: 走査を firstTiling 先行にする。firstTiling(1解 early exit・軽い)
///   → metrics(separable 判定) を先に行い、非 separable のときだけ重い countSolutions で
///   解数1〜3を確認する。separable セットには countSolutions を掛けない(採用しないため)。
///   これにより高コストな countSolutions の呼び出し回数が激減する。
///
/// [shuffleSets]/[tilingFirst] は既定 true(本番=最終形)。false は判断9 の比較計測が
/// (A)⑤b現状=(false,false) (B)Step1のみ=(true,false) (C)最終=(true,true) を1テストで
/// 並べるための計測専用スイッチであり、本番経路(puzzle_generator_selector)は既定で呼ぶ。
///
/// API は [NonTrivialPuzzleGenerator] と同形。(seed, attempt) の決定論的試行・フォール
/// バックなし(isFallback は常に false・採用は解数1〜3のみ)を V3 系から踏襲(判断8)。
/// normal/hard は straightCutSeparable==false を優先、無ければ protrusionRatio 最小
/// (ADR-0018 と同一挙動・判断7)。easy はフィルタ対象外。
class FrameFirstPuzzleGenerator {
  FrameFirstPuzzleGenerator._();

  /// countSolutions の limit。解数1〜3を採用、4は頭打ち(非採用)。
  static const int _solutionCap = 4;

  static Result<VerifiedPuzzle, CompactPuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
    int maxAttempts = 20,
    bool shuffleSets = true,
    bool tilingFirst = true,
  }) {
    final pool = difficulty.pool;
    final blockCount = difficulty.blockCount;
    final isEasy = difficulty == Difficulty.easy;

    var anyFrameGenerated = false;

    // フォールバック候補(normal/hard・非separableが得られない枠向け・判断7)。
    // count-first 経路は count 確定済みで保持。tiling-first 経路は count 未計算で保持し、
    // 全滅時に遅延で countSolutions を掛けて解数1〜3を確認する(計測では発生しない稀パス)。
    GeneratedPuzzle? bestPuzzle;
    List<PolyominoData>? bestSet;
    var bestCount = 0; // 0 = 未計算マーカー(tiling-first のフォールバック候補)
    var bestAttempt = 0;
    var bestProt = double.infinity;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final frameSeed = seed + attempt;
      final frame = FrameGenerator.generate(difficulty, frameSeed);
      if (frame == null) continue;
      anyFrameGenerated = true;

      // ⑤a 確定資産の列挙器は不触。返り値をコピーしてから並べ替える。
      final sets = List<List<PolyominoData>>.of(
        enumerateDistinctPieceSets(pool, blockCount, frame.length),
      );
      if (shuffleSets) {
        _shuffleInPlace(sets, _deriveSubSeed(seed, attempt));
      }

      for (final set in sets) {
        if (tilingFirst) {
          // ---- Step2: firstTiling 先行 ----
          final tiling = FrameTiler.firstTiling(frame, set);
          if (tiling == null) continue; // 敷き詰め不能
          final puzzle = _build(frame, tiling, frameSeed, difficulty);

          if (isEasy) {
            // easy は separable フィルタ対象外。解数1〜3を確認して即採用。
            final count = PuzzleSolver.countSolutions(
              frame: frame,
              shapes: set,
              limit: _solutionCap,
            );
            if (count < 1 || count > 3) continue;
            return Ok(
              VerifiedPuzzle(
                puzzle: puzzle,
                solutionCount: count,
                attemptsUsed: attempt + 1,
                isFallback: false,
              ),
            );
          }

          final m = computePuzzleMetrics(puzzle);
          if (!m.straightCutSeparable) {
            // 非separable のときだけ countSolutions を掛ける。
            final count = PuzzleSolver.countSolutions(
              frame: frame,
              shapes: set,
              limit: _solutionCap,
            );
            if (count < 1 || count > 3) continue;
            return Ok(
              VerifiedPuzzle(
                puzzle: puzzle,
                solutionCount: count,
                attemptsUsed: attempt + 1,
                isFallback: false,
              ),
            );
          }
          // separable: countSolutions は掛けず、protrusion 最小をフォールバック候補に
          // 記録する(count 未計算)。
          if (m.protrusionRatio < bestProt) {
            bestProt = m.protrusionRatio;
            bestPuzzle = puzzle;
            bestSet = set;
            bestAttempt = attempt + 1;
            bestCount = 0; // 未計算マーカー
          }
        } else {
          // ---- ⑤b現状: countSolutions 先行(計測 A/B 用) ----
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
            return Ok(
              VerifiedPuzzle(
                puzzle: puzzle,
                solutionCount: count,
                attemptsUsed: attempt + 1,
                isFallback: false,
              ),
            );
          }

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
            bestSet = set;
            bestCount = count;
            bestAttempt = attempt + 1;
          }
        }
      }
    }

    // フォールバック採用(判断7)。解数は常に1〜3なので isFallback は false(判断8)。
    if (bestPuzzle != null) {
      var count = bestCount;
      if (count == 0) {
        // tiling-first 経路の未計算候補: 遅延で解数1〜3を確認(稀パス・計測では0回)。
        count = PuzzleSolver.countSolutions(
          frame: bestPuzzle.frame,
          shapes: bestSet!,
          limit: _solutionCap,
        );
        if (count < 1 || count > 3) {
          // 遅延確認で採用基準を外した稀ケース。品質未達として扱う。
          return const Err(CompactPuzzleError.qualityNotMet);
        }
      }
      return Ok(
        VerifiedPuzzle(
          puzzle: bestPuzzle,
          solutionCount: count,
          attemptsUsed: bestAttempt,
          isFallback: false,
        ),
      );
    }

    return anyFrameGenerated
        ? const Err(CompactPuzzleError.qualityNotMet)
        : const Err(CompactPuzzleError.generationFailed);
  }

  /// セットリストを [subSeed] 由来で Fisher-Yates シャッフル(in-place)。決定論的。
  static void _shuffleInPlace(List<List<PolyominoData>> xs, int subSeed) {
    final rng = math.Random(subSeed);
    for (var i = xs.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = xs[i];
      xs[i] = xs[j];
      xs[j] = t;
    }
  }

  /// ADR-0008 § サブシード派生と同系の 32bit LCG(乗数1664525・加数1013904223・法2^32)。
  /// hashCode は使わない。⑤a 確定資産の列挙器を触らないため本クラス内に同型の小関数を持つ
  /// (V3 の _deriveSubSeed と同一。dartdoc で出自を明記)。
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
