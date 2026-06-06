/// 噛み合い優先のコンパクト枠生成エンジン（ADR-0010）。
///
/// ## 役割
/// [PuzzleGenerator.listPlacementCandidates] で候補を全列挙し、
/// 接触辺数が最大の候補を優先して選ぶことでコンパクトな枠を生成する。
/// [PuzzleSolver.countSolutions] と [isFrameSimplyConnected] を
/// 自前で呼んで解数・単連結性を検証する。
/// [PuzzleGenerator.construct] も [VerifiedPuzzleGenerator] も呼ばない独立生成器。
///
/// ## 座標系
/// `(y, x) = (row, col)`（ADR-0006）。
/// 詳細は `docs/adr/0006-polyomino-coordinate-order.md` を参照。
///
/// ## 解数検証ロジックの重複について
/// [PuzzleSolver.countSolutions] を limit=4 で呼ぶロジックは ADR-0008 と
/// 一部重複するが、[VerifiedPuzzleGenerator] を呼ばない独立実装であるため
/// 意図的に許容している（ADR-0010 判断3）。
library;

// listPlacementCandidates は @visibleForTesting だが、ADR-0010 では
// 本番の生成部品として意図的に利用している。将来 puzzle_generator 側で
// 正式公開へ格上げする（宿題）。それまでの暫定として警告を抑制する。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// [CompactPuzzleGenerator.generate] が失敗した場合のエラー種別（ADR-0010 判断7）。
enum CompactPuzzleError {
  /// 全試行で枠の生成自体に失敗（配置候補枯渇）。
  generationFailed,

  /// 枠は生成できたが、全試行で解数過多または穴ありだった。
  qualityNotMet,
}

/// 接触辺数が最大の配置を優先してコンパクトな枠を生成するエンジン（ADR-0010）。
///
/// [PuzzleGenerator.listPlacementCandidates]・[PuzzleSolver.countSolutions]・
/// [isFrameSimplyConnected] を組み合わせて自前で
/// 「生成 → 解数検証 → 穴検証」を行う。確定資産は一切変更しない。
///
/// インスタンス化禁止。公開 API は [generate] のみ。
class CompactPuzzleGenerator {
  CompactPuzzleGenerator._();

  /// 検証リトライの上限回数（ADR-0010 判断6）。
  static const int maxCompactRetries = 8;

  static const int _solutionCountThreshold = 4;

  /// 噛み合い優先で枠を生成し、解数・単連結性を検証して返す（ADR-0010）。
  ///
  /// - [difficulty]: パズルの難易度。
  /// - [seed]: 乱数シード。同じ引数で呼ぶと常に同じ結果を返す（決定論的）。
  ///
  /// 戻り値:
  /// - [Ok]: 解が 1〜3 通りかつ単連結の [VerifiedPuzzle]。
  ///   [VerifiedPuzzle.isFallback] は Compact では常に false。
  /// - [Err]([CompactPuzzleError.generationFailed]): 全試行で枠生成が失敗。
  /// - [Err]([CompactPuzzleError.qualityNotMet]):
  ///   枠は生成できたが、全試行で品質基準（解数 1〜3 かつ単連結）を満たさなかった。
  ///
  /// 解数検証ロジックは ADR-0008 と重複するが、意図的に許容している
  /// （ADR-0010 判断3）。
  static Result<VerifiedPuzzle, CompactPuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
  }) {
    var anyFrameBuilt = false;

    for (var attempt = 0; attempt < maxCompactRetries; attempt++) {
      final subSeed = _deriveSubSeed(seed, attempt);
      final puzzle = _buildCompactFrame(difficulty, subSeed);

      if (puzzle == null) continue;
      anyFrameBuilt = true;

      final shapes = puzzle.blocks.map((b) => b.source).toList();
      final count = PuzzleSolver.countSolutions(
        frame: puzzle.frame,
        shapes: shapes,
        limit: _solutionCountThreshold,
      );

      if (count == 0) {
        // 逆算生成法では理論上発生しない（ADR-0008 判断4 と同様）。
        debugPrint(
          'WARNING: CompactPuzzleGenerator: solutionCount=0 '
          '(seed=$subSeed, attempt=$attempt, difficulty=$difficulty). '
          'Reverse-construction guarantees at least 1 solution — this is a bug.',
        );
        continue;
      }

      if (count >= _solutionCountThreshold) continue;

      if (!isFrameSimplyConnected(puzzle.frame)) continue;

      return Ok(
        VerifiedPuzzle(
          puzzle: puzzle,
          solutionCount: count,
          attemptsUsed: attempt + 1,
          isFallback: false,
        ),
      );
    }

    if (!anyFrameBuilt) {
      return const Err(CompactPuzzleError.generationFailed);
    }
    return const Err(CompactPuzzleError.qualityNotMet);
  }

  /// [_buildCompactFrame] の [visibleForTesting] 公開ラッパー。
  @visibleForTesting
  static GeneratedPuzzle? buildCompactFrame(
    Difficulty difficulty,
    int seed,
  ) =>
      _buildCompactFrame(difficulty, seed);

  /// 接触辺数最大優先で枠を1個組む（ADR-0010 判断2）。
  ///
  /// 配置候補が10回以内に見つからない場合は null を返す。
  static GeneratedPuzzle? _buildCompactFrame(Difficulty difficulty, int seed) {
    final random = Random(seed);
    final pool = difficulty.pool;

    final orientationCache = <String, List<PolyominoData>>{};
    List<PolyominoData> orientationsOf(PolyominoData piece) =>
        orientationCache.putIfAbsent(
          piece.id,
          () => PolyominoTransformer.allUniqueOrientations(piece).toList(),
        );

    final placedCells = <Cell>{};
    final blocks = <PlacedBlock>[];

    // 1個目は construct と同じ（接触相手がないので接触辺数の概念がない）。
    final firstPiece = pool[random.nextInt(pool.length)];
    final firstOrientations = orientationsOf(firstPiece);
    final firstOriented =
        firstOrientations[random.nextInt(firstOrientations.length)];
    final firstCells = List<Cell>.from(firstOriented.cells)
      ..sort(
        (a, b) =>
            a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    placedCells.addAll(firstCells);
    blocks.add(
      PlacedBlock(
        source: firstPiece,
        orientation: firstOriented,
        cells: firstCells,
      ),
    );

    final blockCount = difficulty.blockCount;
    for (var i = 1; i < blockCount; i++) {
      var placed = false;
      for (var attempt = 0; attempt < 10; attempt++) {
        final piece = pool[random.nextInt(pool.length)];
        final orientations = orientationsOf(piece);
        final oriented = orientations[random.nextInt(orientations.length)];
        final candidates =
            PuzzleGenerator.listPlacementCandidates(oriented, placedCells);

        if (candidates.isEmpty) continue;

        // 接触辺数最大の候補を選ぶ（ADR-0010 判断2）。同点はランダム。
        final contactCounts = candidates
            .map((c) => _countContactEdges(c, placedCells))
            .toList();
        final maxContact = contactCounts.reduce((a, b) => a > b ? a : b);
        final best = [
          for (var j = 0; j < candidates.length; j++)
            if (contactCounts[j] == maxContact) candidates[j],
        ];

        final chosen = best[random.nextInt(best.length)];
        placedCells.addAll(chosen);
        blocks.add(
          PlacedBlock(source: piece, orientation: oriented, cells: chosen),
        );
        placed = true;
        break;
      }
      if (!placed) return null;
    }

    final minY =
        placedCells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY =
        placedCells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final minX =
        placedCells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX =
        placedCells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);

    return GeneratedPuzzle(
      frame: placedCells,
      boundingBox: (minY: minY, maxY: maxY, minX: minX, maxX: maxX),
      blocks: blocks,
      seed: seed,
      difficulty: difficulty,
    );
  }

  /// [_countContactEdges] の [visibleForTesting] 公開ラッパー。
  @visibleForTesting
  static int countContactEdges(
    List<Cell> candidate,
    Set<Cell> placedCells,
  ) =>
      _countContactEdges(candidate, placedCells);

  /// 配置候補と既配置セルの接触辺数を数える（ADR-0010 判断2）。
  ///
  /// candidate の各セルの4近傍が placedCells に含まれる場合にカウントする。
  /// candidate 内のセル同士の隣接は数えない（既配置との接触辺のみ）。
  static int _countContactEdges(
    List<Cell> candidate,
    Set<Cell> placedCells,
  ) {
    var count = 0;
    for (final c in candidate) {
      if (placedCells.contains((c.$1 - 1, c.$2))) count++;
      if (placedCells.contains((c.$1 + 1, c.$2))) count++;
      if (placedCells.contains((c.$1, c.$2 - 1))) count++;
      if (placedCells.contains((c.$1, c.$2 + 1))) count++;
    }
    return count;
  }

  /// 元シードと試行インデックスから決定論的にサブシードを派生させる。
  ///
  /// ADR-0008 § サブシード派生と同系。hashCode は使わない。
  static int _deriveSubSeed(int seed, int attempt) {
    const mask = 0xFFFFFFFF;
    final lo = seed & 0xFFFF;
    final hi = (seed >> 16) & 0xFFFF;
    return (lo * 1664525 + hi * 22695477 + attempt * 1013904223 + 1) & mask;
  }
}
