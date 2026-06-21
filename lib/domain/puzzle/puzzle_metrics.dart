library;

import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';

/// パズル1件の非自明性指標をまとめたイミュータブルデータクラス。
class PuzzleMetrics {
  const PuzzleMetrics({
    required this.rotationalSymmetry90,
    required this.rotationalSymmetry180,
    required this.straightCutSeparable,
    required this.protrusionRatio,
    required this.fillRatio,
    required this.orientationUsageRatio,
    required this.pieceCount,
  });

  /// 90° 回転対称度。正方形枠のときのみ算出。非正方形は null。
  final double? rotationalSymmetry90;

  /// 180° 回転対称度（常に算出）。
  final double rotationalSymmetry180;

  /// 横または縦の一直線カットで分離できるか。
  final bool straightCutSeparable;

  /// 突起（近傍が1以下の枠セル）の割合。
  final double protrusionRatio;

  /// バウンディングボックスに対する枠セル充填率。
  final double fillRatio;

  /// source と異なる orientation を持つブロックの割合（回転・反転使用率）。
  final double orientationUsageRatio;

  /// ピース数。
  final int pieceCount;
}

/// [GeneratedPuzzle] から [PuzzleMetrics] を算出する純粋関数。
///
/// 生成器・ソルバは呼ばない。puzzle を読むだけ。
PuzzleMetrics computePuzzleMetrics(GeneratedPuzzle puzzle) {
  final frame = puzzle.frame;
  final blocks = puzzle.blocks;
  final bb = puzzle.boundingBox;
  final minY = bb.minY;
  final maxY = bb.maxY;
  final minX = bb.minX;
  final maxX = bb.maxX;
  final frameLen = frame.length;

  // ピースごとのセル集合
  final pieceSets = blocks.map((b) => b.cells.toSet()).toList();

  // 対称度計算: 回転変換後のセル集合が、いずれかのピース集合と完全一致する
  // ピースのセル数の総和 / frame.length
  double symmetryScore(Cell Function(Cell) rot) {
    if (frameLen == 0) return 0.0;
    int matchedCells = 0;
    for (final s in pieceSets) {
      final rotated = s.map<Cell>(rot).toSet();
      final matched = pieceSets.any((t) => t.length == rotated.length && t.containsAll(rotated));
      if (matched) matchedCells += s.length;
    }
    return matchedCells / frameLen;
  }

  // 180° 回転: (minY+maxY-y, minX+maxX-x)
  final sym180 = symmetryScore((c) => (minY + maxY - c.$1, minX + maxX - c.$2));

  // 90° 回転: 正方形のみ。rot90(y,x) = (minY + (x - minX), minX + (maxY - y))
  final isSquare = (maxY - minY) == (maxX - minX);
  final double? sym90 = isSquare
      ? symmetryScore((c) => (minY + (c.$2 - minX), minX + (maxY - c.$1)))
      : null;

  // straightCutSeparable: 横（行境界）または縦（列境界）で跨ぐピースがないか
  bool separable = false;

  // 横: 境界 r = minY .. maxY-1
  outer:
  for (int r = minY; r < maxY; r++) {
    // 両側に枠セルがある
    final hasBelow = frame.any((c) => c.$1 <= r);
    final hasAbove = frame.any((c) => c.$1 >= r + 1);
    if (!hasBelow || !hasAbove) continue;
    // 跨ぐピースが0
    for (final b in blocks) {
      final hasLow = b.cells.any((c) => c.$1 <= r);
      final hasHigh = b.cells.any((c) => c.$1 >= r + 1);
      if (hasLow && hasHigh) continue outer;
    }
    separable = true;
    break;
  }

  if (!separable) {
    // 縦: 境界 c = minX .. maxX-1
    outer2:
    for (int col = minX; col < maxX; col++) {
      final hasLeft = frame.any((c) => c.$2 <= col);
      final hasRight = frame.any((c) => c.$2 >= col + 1);
      if (!hasLeft || !hasRight) continue;
      for (final b in blocks) {
        final hasL = b.cells.any((c) => c.$2 <= col);
        final hasR = b.cells.any((c) => c.$2 >= col + 1);
        if (hasL && hasR) continue outer2;
      }
      separable = true;
      break;
    }
  }

  // protrusionRatio: 近傍(4方向)が frame に含まれる数が 1 以下のセルの割合
  const neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)];
  int protrusions = 0;
  for (final c in frame) {
    int cnt = 0;
    for (final d in neighbors) {
      if (frame.contains((c.$1 + d.$1, c.$2 + d.$2))) cnt++;
    }
    if (cnt <= 1) protrusions++;
  }
  final protrusionRatio = frameLen > 0 ? protrusions / frameLen : 0.0;

  // fillRatio
  final bboxArea = (maxY - minY + 1) * (maxX - minX + 1);
  final fillRatio = bboxArea > 0 ? frameLen / bboxArea : 0.0;

  // orientationUsageRatio
  final usedCount = blocks.where((b) => b.orientation != b.source).length;
  final orientationUsageRatio = blocks.isNotEmpty ? usedCount / blocks.length : 0.0;

  return PuzzleMetrics(
    rotationalSymmetry90: sym90,
    rotationalSymmetry180: sym180,
    straightCutSeparable: separable,
    protrusionRatio: protrusionRatio,
    fillRatio: fillRatio,
    orientationUsageRatio: orientationUsageRatio,
    pieceCount: blocks.length,
  );
}
