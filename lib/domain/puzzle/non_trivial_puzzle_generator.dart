/// 非自明性フィルタ付きパズル生成ラッパー（ADR-0018）。
///
/// [CompactPuzzleGeneratorV3] のラッパー。NORMAL/HARD では straightCutSeparable が
/// false のパズルを優先して返す。EASY はフィルタ対象外でそのまま返す。
library;

import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v3.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// 非自明性フィルタ付きパズル生成器（ADR-0018）。
///
/// インスタンス化禁止。公開 API は [generate] のみ。
class NonTrivialPuzzleGenerator {
  NonTrivialPuzzleGenerator._();

  /// パズルを生成して返す。
  ///
  /// - [difficulty] が [Difficulty.easy] の場合はフィルタなし
  ///   ([CompactPuzzleGeneratorV3.generate] の結果をそのまま返す)。
  /// - [Difficulty.normal] / [Difficulty.hard] では [maxAttempts] 回以内に
  ///   straightCutSeparable == false のパズルを探し、最初に見つかったものを返す。
  ///   全試行で non-separable が得られなかった場合は protrusionRatio 最小の候補を返す。
  ///   1件も生成できなかった稀ケースのみ [Err] を返す。
  ///
  /// [seed] を基点として seed+0, seed+1, ... seed+maxAttempts-1 を順に試行する。
  static Result<VerifiedPuzzle, CompactPuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
    int maxAttempts = 20,
  }) {
    if (difficulty == Difficulty.easy) {
      return CompactPuzzleGeneratorV3.generate(
        difficulty: difficulty,
        seed: seed,
      );
    }

    VerifiedPuzzle? best;
    double bestProt = double.infinity;
    CompactPuzzleError? lastErr;

    for (int i = 0; i < maxAttempts; i++) {
      final r = CompactPuzzleGeneratorV3.generate(
        difficulty: difficulty,
        seed: seed + i,
      );
      if (r is Err<VerifiedPuzzle, CompactPuzzleError>) {
        lastErr = r.error;
        continue;
      }
      final vp = (r as Ok<VerifiedPuzzle, CompactPuzzleError>).value;
      final m = computePuzzleMetrics(vp.puzzle);
      if (!m.straightCutSeparable) return Ok(vp);
      final prot = m.protrusionRatio;
      if (prot < bestProt) {
        best = vp;
        bestProt = prot;
      }
    }

    if (best != null) return Ok(best);
    return Err(lastErr ?? CompactPuzzleError.generationFailed);
  }
}
