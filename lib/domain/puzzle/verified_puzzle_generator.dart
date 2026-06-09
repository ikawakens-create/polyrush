/// 解数検証付きパズル生成層（仕様書 § 4.3.3 / ADR-0008）。
///
/// ## 役割
/// [PuzzleGenerator.construct] でパズルを生成し、[PuzzleSolver.countSolutions]
/// で解の数を検証する。解が 4 通り以上なら「簡単すぎる」として再生成する。
///
/// ## 座標系
/// (y, x) = (row, col)（ADR-0006）。詳細は
/// `docs/adr/0006-polyomino-coordinate-order.md` を参照。
///
/// ## なぜ Result 型を返すのか
/// 仕様書 § 14.2 / ADR-0005 の方針に従い、エラー処理をコンパイラレベルで
/// 強制する。[PuzzleGenerator.construct] は例外を投げるが、このクラスはその
/// 例外を内部で受け止め [Result] に変換する「境界層」として機能する。
/// 詳細は `docs/adr/0008-verified-puzzle-generation.md` を参照。
library;

import 'package:flutter/foundation.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';

/// [VerifiedPuzzleGenerator.generate] が失敗した場合のエラー種別（ADR-0008 判断8）。
enum GenerationError {
  /// [VerifiedPuzzleGenerator.maxVerificationRetries] 回の試行すべてで
  /// [PuzzleGenerator.construct] が [GenerationFailedException] を投げ、
  /// パズルを 1 個も生成できなかった。
  allAttemptsFailed,
}

/// 解数検証済みのパズルと検証メタデータを保持するイミュータブルデータ
/// （ADR-0008 判断7）。
@immutable
class VerifiedPuzzle {
  const VerifiedPuzzle({
    required this.puzzle,
    required this.solutionCount,
    required this.attemptsUsed,
    required this.isFallback,
  });

  /// 採用されたパズル。
  final GeneratedPuzzle puzzle;

  /// 検証で数えた解の数（通常 1〜3; フォールバック時は 4 以上）。
  ///
  /// 仕様書 § 12.2 の分析イベント `puzzle_generated` や
  /// 難易度チューニングのデータ収集に使用する。
  final int solutionCount;

  /// 採用までに要した試行回数（1 以上）。
  final int attemptsUsed;

  /// フォールバックで返したか。
  ///
  /// true の場合、[solutionCount] が 4 以上であり仕様書 § 4.3.3 を満たしていない。
  /// 呼び出し側は警告表示や再生成要求の判断に使用してよい。
  final bool isFallback;
}

/// 解数検証付きパズル生成エンジン（ADR-0008）。
///
/// [PuzzleGenerator.construct] で生成したパズルの解数が 4 通り以上なら
/// 再生成する。インスタンス化禁止。公開 API は [generate] のみ。
class VerifiedPuzzleGenerator {
  VerifiedPuzzleGenerator._();

  /// 検証リトライの上限回数（ADR-0008 判断5）。
  ///
  /// [PuzzleGenerator.construct] 内部の配置リトライ（最大 10 回）とは別物。
  /// 配置リトライは 1 個のパズルを組む途中での詰まり直し回数であり、
  /// こちらは「簡単すぎる」として丸ごと没にする回数を指す。
  static const int maxVerificationRetries = 8;

  /// 解数の採用閾値（ADR-0008 判断3）。
  ///
  /// 解数がこの値未満（1〜3）なら採用。この値が `countSolutions` の `limit`
  /// にも渡されるため、解が 4 つ見つかった時点で探索が打ち切られる。
  static const int _solutionCountThreshold = 4;

  /// 解数を検証しながらパズルを 1 つ生成する（ADR-0008 判断1〜8）。
  ///
  /// - [difficulty]: パズルの難易度。
  /// - [seed]: 乱数シード。同じ引数で呼ぶと常に同じ結果を返す（決定論的）。
  ///
  /// 戻り値:
  /// - [Ok]: 解が 1〜3 通りのパズル（[VerifiedPuzzle.isFallback] == false）、
  ///   または全試行が 4 通り以上だったフォールバック（isFallback == true）。
  /// - [Err]([GenerationError.allAttemptsFailed]): 全試行で
  ///   [PuzzleGenerator.construct] が失敗し、パズルを 1 個も生成できなかった。
  ///
  /// フォールバック時は [VerifiedPuzzle.isFallback] が true になる。
  /// 呼び出し側は必ず [Ok] と [Err] の両方を処理すること。
  static Result<VerifiedPuzzle, GenerationError> generate({
    required Difficulty difficulty,
    required int seed,
    @visibleForTesting
    GeneratedPuzzle Function(Difficulty difficulty, int seed)?
    overrideConstruct,
    @visibleForTesting
    int Function({
      required Set<Cell> frame,
      required List<PolyominoData> shapes,
      required int limit,
    })?
    overrideCountSolutions,
    @visibleForTesting int? overrideMaxRetries,
  }) {
    final maxRetries = overrideMaxRetries ?? maxVerificationRetries;
    final doConstruct =
        overrideConstruct ??
        (Difficulty d, int s) =>
            PuzzleGenerator.construct(difficulty: d, seed: s);
    final doCount =
        overrideCountSolutions ??
        ({
          required Set<Cell> frame,
          required List<PolyominoData> shapes,
          required int limit,
        }) => PuzzleSolver.countSolutions(
          frame: frame,
          shapes: shapes,
          limit: limit,
        );

    GeneratedPuzzle? bestFallbackPuzzle;
    int bestFallbackCount = _solutionCountThreshold;
    bool anyPuzzleGenerated = false;

    for (var i = 0; i < maxRetries; i++) {
      final subSeed = _deriveSubSeed(seed, i);

      GeneratedPuzzle p;
      try {
        p = doConstruct(difficulty, subSeed);
      } on GenerationFailedException {
        // この試行は失敗としてリトライを1回消費し、次へ（ADR-0008 判断5）。
        continue;
      }

      anyPuzzleGenerated = true;

      final shapes = p.blocks.map((b) => b.source).toList();
      final shapeCells = shapes.fold<int>(0, (sum, s) => sum + s.size);
      // 逆算生成法の不変条件: ブロックのセル数合計 == フレームのマス数
      // 不一致はバグ（ADR-0008 判断4）。
      assert(
        shapeCells == p.frame.length,
        'Bug: block cells total ($shapeCells) != frame size (${p.frame.length}). '
        'seed=$subSeed difficulty=$difficulty',
      );

      final count = doCount(
        frame: p.frame,
        shapes: shapes,
        limit: _solutionCountThreshold,
      );

      if (count == 0) {
        // 逆算生成法では理論上発生しない（ADR-0008 判断4）。
        debugPrint(
          'WARNING: VerifiedPuzzleGenerator: solutionCount=0 '
          '(seed=$subSeed, attempt=$i, difficulty=$difficulty). '
          'Reverse-construction guarantees at least 1 solution — this is a bug.',
        );
        continue;
      }

      if (count < _solutionCountThreshold) {
        // 採用: 解が 1〜3 通り（ADR-0008 判断3）。
        return Ok(
          VerifiedPuzzle(
            puzzle: p,
            solutionCount: count,
            attemptsUsed: i + 1,
            isFallback: false,
          ),
        );
      }

      // 却下: 解が 4 通り以上。フォールバック候補として保持（ADR-0008 判断5）。
      if (bestFallbackPuzzle == null || count < bestFallbackCount) {
        bestFallbackCount = count;
        bestFallbackPuzzle = p;
      }
    }

    if (!anyPuzzleGenerated) {
      // 全試行で construct が失敗（ADR-0008 判断5・判断8）。
      return const Err(GenerationError.allAttemptsFailed);
    }

    // 全試行でパズルは生成できたが、すべて解 4 以上（ADR-0008 判断5）。
    debugPrint(
      'WARNING: VerifiedPuzzleGenerator: all $maxRetries attempts produced '
      'solutionCount >= $_solutionCountThreshold. Returning fallback. '
      'difficulty=$difficulty, seed=$seed',
    );
    return Ok(
      VerifiedPuzzle(
        puzzle: bestFallbackPuzzle!,
        solutionCount: bestFallbackCount,
        attemptsUsed: maxRetries,
        isFallback: true,
      ),
    );
  }

  /// 元シードと試行インデックスから決定論的にサブシードを派生させる
  /// （ADR-0008 判断2）。
  ///
  /// - `hashCode` / `Object.hash` は実行間で一貫性が保証されないため使用禁止。
  /// - seed を 16bit ずつ分割して乗算し、中間値を 53bit 以内に収めることで
  ///   Web（JavaScript）環境でも精度を保つ。
  /// - 結果を 32bit マスクすることで符号なし 32bit の値域に限定する。
  static int _deriveSubSeed(int seed, int attempt) {
    const mask = 0xFFFFFFFF;
    final lo = seed & 0xFFFF;
    final hi = (seed >> 16) & 0xFFFF;
    // 各項の最大値: lo*1664525≈109e9, hi*22695477≈1.49e12, attempt*1013904223≈7.1e9
    // 合計 ≈ 1.6e12 < 2^53 (Web 安全範囲)
    return (lo * 1664525 + hi * 22695477 + attempt * 1013904223 + 1) & mask;
  }
}
