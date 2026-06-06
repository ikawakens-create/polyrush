/// 重み付きスコア選択によるコンパクト枠生成エンジン（ADR-0013）。
///
/// ## 役割
/// [CompactPuzzleGeneratorV2] の性質をそのまま引き継ぎつつ、候補選択の規則だけを
/// 重み付きスコア最大化に変えた新生成器（ADR-0013 判断1）。
/// 関連 ADR: 0008 / 0009 / 0010 / 0011 / 0012。
///
/// ## V2 からの唯一の違い（ADR-0013 判断2）
/// V2 は「接触辺数が最大の候補に絞り、その中で外接矩形面積が最小、なお同点なら乱数」
/// という段階式（lexicographic）だった。V3 は各候補を
///   score(candidate) = contactEdges(candidate) - kBboxPenaltyLambda * bboxAreaAfter(candidate)
/// という1つの点数で評価し、最大の候補を選ぶ（同点なら乱数）。
///
/// これにより「接触辺数が最大でなくても、外への広がりが十分小さければ選ばれる」ため、
/// V2 のタイブレーク（同点時のみ作用）より広い場面でコンパクト化が効く。
///
/// ## 引き継ぐ性質（V2 / Compact と同一）
/// - 同形 source の重複回避（配置済み source.id を Set で追跡）（ADR-0011）
/// - 解数検証: countSolutions(limit:4) で 1〜3 を採用、4以上は再生成（ADR-0008/0010）
/// - 穴検証: isFrameSimplyConnected で単連結を確認（ADR-0009/0010）
/// - (seed, attempt) からの決定論的サブシード派生（ADR-0008）
/// - 検証リトライ上限: [maxCompactRetries] = 16
/// - フォールバックなし（常に isFallback == false）
///
/// ## 座標系
/// `(y, x) = (row, col)`（ADR-0006）。
library;

// listPlacementCandidates は @visibleForTesting だが、ADR-0010/0012/0013 では
// 本番の生成部品として意図的に利用している。警告を抑制する。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// 外接矩形ペナルティの重み係数（ADR-0013 判断2・判断3）。
///
/// score = contactEdges - kBboxPenaltyLambda * bboxAreaAfter の LAMBDA 値。
/// 大きくするほどコンパクト寄り（長方形寄り）になり、小さくするほど V2 寄りになる。
///
/// ADR-0013 判断2。値は CI の充填率測定で決めた暫定値であり、
/// 測定結果しだいで別 ADR で再調整しうる。
const double kBboxPenaltyLambda = 0.5;

/// 重み付きスコア選択によるコンパクト枠生成エンジン（ADR-0013）。
///
/// [CompactPuzzleGeneratorV2] と同一の性質を持ちつつ、候補選択を段階式から
/// 重み付きスコア最大化に変えた生成器（ADR-0013 判断2）。
///
/// インスタンス化禁止。公開 API は [generate] のみ。
class CompactPuzzleGeneratorV3 {
  CompactPuzzleGeneratorV3._();

  /// 検証リトライの上限回数（ADR-0010/0013 判断4）。
  static const int maxCompactRetries = 16;

  static const int _solutionCountThreshold = 4;

  /// 重み付きスコア選択で枠を生成し、解数・単連結性を検証して返す（ADR-0013）。
  ///
  /// - [difficulty]: パズルの難易度。
  /// - [seed]: 乱数シード。同じ引数で呼ぶと常に同じ結果を返す（決定論的）。
  ///
  /// 戻り値:
  /// - [Ok]: 解が 1〜3 通りかつ単連結の [VerifiedPuzzle]。
  ///   [VerifiedPuzzle.isFallback] は V3 では常に false（ADR-0013 判断4）。
  /// - [Err]([CompactPuzzleError.generationFailed]): 全試行で枠生成が失敗。
  /// - [Err]([CompactPuzzleError.qualityNotMet]):
  ///   枠は生成できたが、全試行で品質基準（解数 1〜3 かつ単連結）を満たさなかった。
  ///
  /// 解数検証ロジックは ADR-0008/0010/0013 判断4 と同一。
  static Result<VerifiedPuzzle, CompactPuzzleError> generate({
    required Difficulty difficulty,
    required int seed,
  }) {
    var anyFrameBuilt = false;

    for (var attempt = 0; attempt < maxCompactRetries; attempt++) {
      final subSeed = _deriveSubSeed(seed, attempt);
      final puzzle = _buildFrameV3(difficulty, subSeed);

      if (puzzle == null) continue;
      anyFrameBuilt = true;

      final shapes = puzzle.blocks.map((b) => b.source).toList();
      final count = PuzzleSolver.countSolutions(
        frame: puzzle.frame,
        shapes: shapes,
        limit: _solutionCountThreshold,
      );

      if (count == 0) {
        debugPrint(
          'WARNING: CompactPuzzleGeneratorV3: solutionCount=0 '
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

  /// 重み付きスコア最大化で枠を1個組む（ADR-0013 判断2）。
  ///
  /// 配置候補が10回以内に見つからない場合は null を返す。
  static GeneratedPuzzle? _buildFrameV3(Difficulty difficulty, int seed) {
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

    // 1個目は V2 と同じ（接触相手がないので score の概念がない）。
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

    final usedSourceIds = <String>{firstPiece.id};

    final blockCount = difficulty.blockCount;
    for (var i = 1; i < blockCount; i++) {
      final availablePool =
          pool.where((p) => !usedSourceIds.contains(p.id)).toList();
      var placed = false;
      for (var attempt = 0; attempt < 10; attempt++) {
        if (availablePool.isEmpty) break;
        final piece = availablePool[random.nextInt(availablePool.length)];
        final orientations = orientationsOf(piece);
        final oriented = orientations[random.nextInt(orientations.length)];
        final candidates =
            PuzzleGenerator.listPlacementCandidates(oriented, placedCells);

        if (candidates.isEmpty) continue;

        // 重み付きスコア = contactEdges - kBboxPenaltyLambda * bboxAreaAfter
        // で各候補を評価し、最大スコアの候補に絞る（ADR-0013 判断2）。
        final scores = candidates
            .map(
              (c) =>
                  _countContactEdges(c, placedCells) -
                  kBboxPenaltyLambda * _bboxAreaAfterPlacement(c, placedCells),
            )
            .toList();
        final maxScore = scores.reduce((a, b) => a > b ? a : b);
        final best = [
          for (var j = 0; j < candidates.length; j++)
            if (scores[j] == maxScore) candidates[j],
        ];

        // 同点なら乱数で1つ選ぶ（決定論性維持）。
        final chosen = best[random.nextInt(best.length)];
        placedCells.addAll(chosen);
        blocks.add(
          PlacedBlock(source: piece, orientation: oriented, cells: chosen),
        );
        usedSourceIds.add(piece.id);
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

  /// 候補を配置したときの枠（既配置 ∪ 候補）の外接矩形面積を返す（ADR-0013 判断2）。
  static int _bboxAreaAfterPlacement(
    List<Cell> candidate,
    Set<Cell> placedCells,
  ) {
    var minY = candidate[0].$1;
    var maxY = candidate[0].$1;
    var minX = candidate[0].$2;
    var maxX = candidate[0].$2;
    for (final c in candidate) {
      if (c.$1 < minY) minY = c.$1;
      if (c.$1 > maxY) maxY = c.$1;
      if (c.$2 < minX) minX = c.$2;
      if (c.$2 > maxX) maxX = c.$2;
    }
    for (final c in placedCells) {
      if (c.$1 < minY) minY = c.$1;
      if (c.$1 > maxY) maxY = c.$1;
      if (c.$2 < minX) minX = c.$2;
      if (c.$2 > maxX) maxX = c.$2;
    }
    return (maxX - minX + 1) * (maxY - minY + 1);
  }

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
  /// ADR-0008 § サブシード派生と同系の 32bit LCG（乗数1664525・加数1013904223・
  /// 法2^32）。hashCode は使わない（ADR-0008/0010/0012/0013 判断4）。
  static int _deriveSubSeed(int seed, int attempt) {
    const mask = 0xFFFFFFFF;
    final lo = seed & 0xFFFF;
    final hi = (seed >> 16) & 0xFFFF;
    return (lo * 1664525 + hi * 22695477 + attempt * 1013904223 + 1) & mask;
  }
}
