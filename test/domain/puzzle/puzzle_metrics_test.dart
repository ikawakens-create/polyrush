import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v3.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';

// ダミー PolyominoData ヘルパー
PolyominoData _poly(String id, List<Cell> cells) =>
    PolyominoData(id: id, size: cells.length, cells: cells);

// PlacedBlock ヘルパー（source == orientation = non-rotated）
PlacedBlock _block(List<Cell> cells) {
  final p = _poly('X${cells.length}', cells);
  return PlacedBlock(source: p, orientation: p, cells: cells);
}

// PlacedBlock ヘルパー（orientation != source）
PlacedBlock _blockRotated(List<Cell> srcCells, List<Cell> oriCells, List<Cell> placed) {
  final src = _poly('X${srcCells.length}', srcCells);
  final ori = _poly('X${oriCells.length}', oriCells);
  return PlacedBlock(source: src, orientation: ori, cells: placed);
}

GeneratedPuzzle _puzzle(List<PlacedBlock> blocks, {int minY = 0, int maxY = 3, int minX = 0, int maxX = 3}) {
  final frame = <Cell>{};
  for (final b in blocks) {
    frame.addAll(b.cells);
  }
  return GeneratedPuzzle(
    frame: frame,
    boundingBox: (minY: minY, maxY: maxY, minX: minX, maxX: maxX),
    blocks: blocks,
    seed: 0,
    difficulty: Difficulty.easy,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // (A) ユニットテスト
  // -------------------------------------------------------------------------
  group('PuzzleMetrics unit tests', () {
    // 風車フィクスチャ（4x4, 4ピース）
    // A: (0,0),(1,0),(1,1),(2,0)
    // B: (0,1),(0,2),(0,3),(1,2)
    // C: (1,3),(2,2),(2,3),(3,3)
    // D: (2,1),(3,0),(3,1),(3,2)
    final pinwheel = _puzzle([
      _block([(0, 0), (1, 0), (1, 1), (2, 0)]),
      _block([(0, 1), (0, 2), (0, 3), (1, 2)]),
      _block([(1, 3), (2, 2), (2, 3), (3, 3)]),
      _block([(2, 1), (3, 0), (3, 1), (3, 2)]),
    ]);

    test('pinwheel: rotationalSymmetry180 == 1.0', () {
      final m = computePuzzleMetrics(pinwheel);
      expect(m.rotationalSymmetry180, closeTo(1.0, 0.001),
          reason: '風車は 180° 回転で各ピースが別のピースに重なる');
    });

    test('pinwheel: rotationalSymmetry90 == 1.0', () {
      final m = computePuzzleMetrics(pinwheel);
      expect(m.rotationalSymmetry90, isNotNull,
          reason: '4x4 は正方形なので sym90 は非 null');
      expect(m.rotationalSymmetry90!, closeTo(1.0, 0.001),
          reason: '風車は 90° 回転でも各ピースが別のピースに重なる');
    });

    test('pinwheel: straightCutSeparable == false', () {
      final m = computePuzzleMetrics(pinwheel);
      expect(m.straightCutSeparable, isFalse,
          reason: '風車はいずれの直線カットでも跨ぐピースが生じる');
    });

    test('pinwheel: pieceCount == 4', () {
      final m = computePuzzleMetrics(pinwheel);
      expect(m.pieceCount, equals(4));
    });

    // 横棒フィクスチャ（各行が1ピース）
    // P: (0,0),(0,1),(0,2),(0,3)
    // Q: (1,0),(1,1),(1,2),(1,3)
    // R: (2,0),(2,1),(2,2),(2,3)
    // S: (3,0),(3,1),(3,2),(3,3)
    final stripes = _puzzle([
      _block([(0, 0), (0, 1), (0, 2), (0, 3)]),
      _block([(1, 0), (1, 1), (1, 2), (1, 3)]),
      _block([(2, 0), (2, 1), (2, 2), (2, 3)]),
      _block([(3, 0), (3, 1), (3, 2), (3, 3)]),
    ]);

    test('stripes: rotationalSymmetry180 == 1.0', () {
      final m = computePuzzleMetrics(stripes);
      expect(m.rotationalSymmetry180, closeTo(1.0, 0.001),
          reason: '横棒も 180° ではピース同士が入れ替わって一致する');
    });

    test('stripes: rotationalSymmetry90 == 0.0', () {
      final m = computePuzzleMetrics(stripes);
      expect(m.rotationalSymmetry90, isNotNull,
          reason: '4x4 は正方形');
      expect(m.rotationalSymmetry90!, closeTo(0.0, 0.001),
          reason: '横棒を 90° 回転すると縦棒になり、いずれの横棒ピースとも不一致');
    });

    test('stripes: straightCutSeparable == true', () {
      final m = computePuzzleMetrics(stripes);
      expect(m.straightCutSeparable, isTrue,
          reason: '行境界がすべてカット可能');
    });

    test('stripes: pieceCount == 4', () {
      final m = computePuzzleMetrics(stripes);
      expect(m.pieceCount, equals(4));
    });

    // orientationUsageRatio のテスト
    // 2ブロック中1ブロックが orientation != source
    test('orientationUsageRatio: 0.5 when half blocks use non-source orientation', () {
      final srcA = _poly('A4', [(0, 0), (0, 1), (1, 0), (1, 1)]);
      // orientation に同じインスタンスを使う → source == orientation
      final blockSame = PlacedBlock(source: srcA, orientation: srcA, cells: [(0, 0), (0, 1), (1, 0), (1, 1)]);

      final blockRot = _blockRotated(
        [(0, 0), (0, 1), (0, 2), (0, 3)], // source: horizontal I4
        [(0, 0), (1, 0), (2, 0), (3, 0)], // orientation: vertical I4
        [(0, 4), (1, 4), (2, 4), (3, 4)],
      );
      final p = _puzzle([blockSame, blockRot], maxX: 4);
      final m = computePuzzleMetrics(p);
      expect(m.orientationUsageRatio, closeTo(0.5, 0.001),
          reason: '2ブロック中1ブロックが orientation != source');
    });
  });

  // -------------------------------------------------------------------------
  // (B) レポートテスト（生成器を使う。assert なし、print のみ）
  // -------------------------------------------------------------------------
  group('PuzzleMetrics report', () {
    test('metrics report for easy/normal/hard seeds 1..100', () {
      final difficulties = [Difficulty.easy, Difficulty.normal, Difficulty.hard];

      for (final diff in difficulties) {
        final metrics = <PuzzleMetrics>[];
        final failedSeeds = <int>[];

        for (int seed = 1; seed <= 100; seed++) {
          final result = CompactPuzzleGeneratorV3.generate(difficulty: diff, seed: seed);
          switch (result) {
            case Ok(:final value):
              metrics.add(computePuzzleMetrics(value.puzzle));
            case Err():
              failedSeeds.add(seed);
          }
        }

        // 生成成功を hard assert
        expect(failedSeeds.isEmpty, isTrue,
            reason: '${diff.name}: 失敗 seed = $failedSeeds');

        // 集計
        final n = metrics.length;
        final sym180avg = metrics.map((m) => m.rotationalSymmetry180).reduce((a, b) => a + b) / n;
        final sym90vals = metrics.map((m) => m.rotationalSymmetry90).whereType<double>().toList();
        final sym90avg = sym90vals.isNotEmpty ? sym90vals.reduce((a, b) => a + b) / sym90vals.length : double.nan;
        final sym90nullRate = (n - sym90vals.length) / n;
        final sepRate = metrics.where((m) => m.straightCutSeparable).length / n;
        final protAvg = metrics.map((m) => m.protrusionRatio).reduce((a, b) => a + b) / n;
        final fillAvg = metrics.map((m) => m.fillRatio).reduce((a, b) => a + b) / n;
        final oriAvg = metrics.map((m) => m.orientationUsageRatio).reduce((a, b) => a + b) / n;
        final pcAvg = metrics.map((m) => m.pieceCount).reduce((a, b) => a + b) / n;

        print('');
        print('=== ${diff.name.toUpperCase()} (n=$n) ===');
        print('sym180_avg        : ${sym180avg.toStringAsFixed(3)}');
        print('sym90_avg(non-null): ${sym90avg.isNaN ? "N/A" : sym90avg.toStringAsFixed(3)}');
        print('sym90_null_rate   : ${sym90nullRate.toStringAsFixed(3)}');
        print('separable_rate    : ${sepRate.toStringAsFixed(3)}');
        print('protrusion_avg    : ${protAvg.toStringAsFixed(3)}');
        print('fill_avg          : ${fillAvg.toStringAsFixed(3)}');
        print('orientation_avg   : ${oriAvg.toStringAsFixed(3)}');
        print('piece_count_avg   : ${pcAvg.toStringAsFixed(1)}');

        // sym90 上位3件（非null）
        final withSym90 = <(double, int, PuzzleMetrics)>[];
        for (int i = 0; i < metrics.length; i++) {
          final s = metrics[i].rotationalSymmetry90;
          if (s != null) withSym90.add((s, i + 1, metrics[i]));
        }
        withSym90.sort((a, b) => b.$1.compareTo(a.$1));
        print('');
        print('--- sym90 top 3 ---');
        for (final entry in withSym90.take(3)) {
          print('  seed=${entry.$2} sym90=${entry.$1.toStringAsFixed(3)} sym180=${entry.$3.rotationalSymmetry180.toStringAsFixed(3)} sep=${entry.$3.straightCutSeparable} prot=${entry.$3.protrusionRatio.toStringAsFixed(3)}');
        }

        // straightCutSeparable=false かつ protrusionRatio 低い順 上位3件
        final nonSep = <(double, int, PuzzleMetrics)>[];
        for (int i = 0; i < metrics.length; i++) {
          if (!metrics[i].straightCutSeparable) {
            nonSep.add((metrics[i].protrusionRatio, i + 1, metrics[i]));
          }
        }
        nonSep.sort((a, b) => a.$1.compareTo(b.$1));
        print('');
        print('--- non-separable low-protrusion top 3 ---');
        for (final entry in nonSep.take(3)) {
          print('  seed=${entry.$2} prot=${entry.$1.toStringAsFixed(3)} sym180=${entry.$3.rotationalSymmetry180.toStringAsFixed(3)} fill=${entry.$3.fillRatio.toStringAsFixed(3)}');
        }

        // ASCII アート: sym90 top 3
        print('');
        print('--- sym90 top 3 ASCII art ---');
        _printTop3Ascii(withSym90.take(3).map((e) => e.$2).toList(), diff);

        // ASCII アート: non-sep low-prot top 3
        print('');
        print('--- non-sep low-prot top 3 ASCII art ---');
        _printTop3Ascii(nonSep.take(3).map((e) => e.$2).toList(), diff);
      }

      // orientationUsageRatio の検証サンプル: easy seed 1,2 の先頭2ブロック
      print('');
      print('=== orientationUsageRatio verification (easy seed 1,2) ===');
      for (final seed in [1, 2]) {
        final result = CompactPuzzleGeneratorV3.generate(difficulty: Difficulty.easy, seed: seed);
        if (result case Ok(:final value)) {
          final blocks = value.puzzle.blocks;
          for (int i = 0; i < 2 && i < blocks.length; i++) {
            final b = blocks[i];
            print('  seed=$seed block[$i] source.cells=${b.source.cells} ori.cells=${b.orientation.cells} same=${b.source == b.orientation}');
          }
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

void _printTop3Ascii(List<int> seeds, Difficulty diff) {
  for (final seed in seeds) {
    final result = CompactPuzzleGeneratorV3.generate(difficulty: diff, seed: seed);
    if (result case Ok(:final value)) {
      final puzzle = value.puzzle;
      final bb = puzzle.boundingBox;
      // セルからブロックインデックスへのマップ
      final cellBlock = <Cell, int>{};
      for (int i = 0; i < puzzle.blocks.length; i++) {
        for (final c in puzzle.blocks[i].cells) {
          cellBlock[c] = i;
        }
      }
      print('  seed=$seed (${diff.name})');
      for (int y = bb.minY; y <= bb.maxY; y++) {
        final sb = StringBuffer('    ');
        for (int x = bb.minX; x <= bb.maxX; x++) {
          final idx = cellBlock[(y, x)];
          if (idx == null) {
            sb.write(' ');
          } else {
            sb.write(String.fromCharCode('a'.codeUnitAt(0) + idx % 26));
          }
        }
        print(sb.toString());
      }
    }
  }
}
