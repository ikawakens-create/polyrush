library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';

/// 配置済みピースを表すイミュータブルデータ。
///
/// [source] は pool から選んだ正規化済みの [PolyominoData]（カノニカル形）。
/// [cells] はグリッド上の絶対座標（`source.cells` のカノニカル形とは異なる）。
class PlacedBlock {
  PlacedBlock({
    required this.source,
    required List<Cell> cells,
  }) : cells = List.unmodifiable(cells);

  final PolyominoData source;
  final List<Cell> cells;
}

/// 1回の生成結果を保持するイミュータブルデータ。
class GeneratedPuzzle {
  GeneratedPuzzle({
    required Set<Cell> frame,
    required this.boundingBox,
    required List<PlacedBlock> blocks,
    required this.seed,
    required this.difficulty,
  })  : frame = Set.unmodifiable(frame),
        blocks = List.unmodifiable(blocks);

  /// 全ブロックの和集合（パズル枠）。
  final Set<Cell> frame;

  /// frame の外接矩形。ADR-0006 に従い (minY, maxY, minX, maxX) の順。
  final ({int minY, int maxY, int minX, int maxX}) boundingBox;

  /// 配置されたブロックのリスト（配置順）。
  final List<PlacedBlock> blocks;

  final int seed;
  final Difficulty difficulty;
}

/// 配置候補が枯渇した場合にスローされる例外。
class GenerationFailedException implements Exception {
  const GenerationFailedException(this.message);
  final String message;

  @override
  String toString() => 'GenerationFailedException: $message';
}

/// 逆算生成法によるパズル枠の自動生成エンジン。
class PuzzleGenerator {
  PuzzleGenerator._();

  /// 逆算生成法で1つのパズルを構築する（仕様書 § 4.3.2）。
  ///
  /// Throws [GenerationFailedException] 配置候補が枯渇した場合。
  ///
  /// [overridePool] [overrideBlockCount] [overrideMaxAttempts] はテスト専用。
  static GeneratedPuzzle construct({
    required Difficulty difficulty,
    required int seed,
    @visibleForTesting List<PolyominoData>? overridePool,
    @visibleForTesting int? overrideBlockCount,
    @visibleForTesting int? overrideMaxAttempts,
  }) {
    final random = Random(seed);
    final pool = overridePool ?? difficulty.pool;
    final blockCount = overrideBlockCount ?? difficulty.blockCount;
    final maxAttempts = overrideMaxAttempts ?? 10;

    final placedCells = <Cell>{};
    final blocks = <PlacedBlock>[];

    // § 4.3.2: 最初の1個目を原点付近に置く（向きはランダム）。
    final firstPiece = pool[random.nextInt(pool.length)];
    final firstOrientations =
        PolyominoTransformer.allUniqueOrientations(firstPiece).toList();
    final firstOriented =
        firstOrientations[random.nextInt(firstOrientations.length)];
    final firstCells = List<Cell>.from(firstOriented.cells);
    placedCells.addAll(firstCells);
    blocks.add(PlacedBlock(source: firstPiece, cells: firstCells));

    // § 4.3.2: for i = 2 to N。
    for (var i = 1; i < blockCount; i++) {
      var placed = false;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final piece = pool[random.nextInt(pool.length)];
        final orientations =
            PolyominoTransformer.allUniqueOrientations(piece).toList();
        final oriented = orientations[random.nextInt(orientations.length)];
        final candidates = listPlacementCandidates(oriented, placedCells);
        if (candidates.isNotEmpty) {
          final chosen = candidates[random.nextInt(candidates.length)];
          placedCells.addAll(chosen);
          blocks.add(PlacedBlock(source: piece, cells: chosen));
          placed = true;
          break;
        }
      }
      if (!placed) {
        throw GenerationFailedException(
          'Failed to place block ${i + 1} of $blockCount '
          'after $maxAttempts attempts (seed=$seed)',
        );
      }
    }

    final minY = placedCells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY = placedCells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final minX = placedCells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX = placedCells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);

    return GeneratedPuzzle(
      frame: placedCells,
      boundingBox: (minY: minY, maxY: maxY, minX: minX, maxX: maxX),
      blocks: blocks,
      seed: seed,
      difficulty: difficulty,
    );
  }

  /// セル a と b が辺隣接するか判定する（対角線・同一セルは false）。
  @visibleForTesting
  static bool isAdjacent(Cell a, Cell b) =>
      (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs() == 1;

  /// [placedCells] の境界マス（配置済みセルでなく、かつ辺隣接するマス）を返す。
  @visibleForTesting
  static Set<Cell> listBoundaryCells(Set<Cell> placedCells) {
    final boundary = <Cell>{};
    for (final cell in placedCells) {
      for (final neighbor in _neighbors(cell)) {
        if (!placedCells.contains(neighbor)) boundary.add(neighbor);
      }
    }
    return boundary;
  }

  /// [oriented] を [placedCells] に対して配置できる候補を全列挙する。
  ///
  /// 各候補は (A) 重複なし、(B) 少なくとも1辺隣接 の両条件を満たす。
  /// 同じセル集合が複数の (境界マス, ピースセル) 組から生成される場合は重複除去する。
  @visibleForTesting
  static List<List<Cell>> listPlacementCandidates(
    PolyominoData oriented,
    Set<Cell> placedCells,
  ) {
    final boundary = listBoundaryCells(placedCells);
    final seen = <String>{};
    final result = <List<Cell>>[];

    for (final g in boundary) {
      for (final p in oriented.cells) {
        final dy = g.$1 - p.$1;
        final dx = g.$2 - p.$2;
        final translated = oriented.cells
            .map((c) => (c.$1 + dy, c.$2 + dx))
            .toList()
          ..sort(
            (a, b) =>
                a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
          );

        // (A) 既配置セルと重なっていない
        if (translated.any((c) => placedCells.contains(c))) continue;

        // (B) 少なくとも1辺隣接（g が境界マスなので常に成立するが明示チェック）
        if (!translated.any(
          (c) =>
              placedCells.contains((c.$1 - 1, c.$2)) ||
              placedCells.contains((c.$1 + 1, c.$2)) ||
              placedCells.contains((c.$1, c.$2 - 1)) ||
              placedCells.contains((c.$1, c.$2 + 1)),
        )) {
          continue;
        }

        final key = translated.toString();
        if (seen.add(key)) result.add(translated);
      }
    }

    return result;
  }

  static List<Cell> _neighbors(Cell cell) => [
        (cell.$1 - 1, cell.$2),
        (cell.$1 + 1, cell.$2),
        (cell.$1, cell.$2 - 1),
        (cell.$1, cell.$2 + 1),
      ];
}
