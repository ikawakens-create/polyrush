import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/frame_tiler.dart';
import 'package:polyrush/domain/puzzle/piece_set_enumerator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:polyrush/domain/puzzle/solver.dart';

// ⑥-a: 実パイプラインの採用ルール(solutionCount in 1..3、normal/hard は
// 非separable を良形とみなす)を通した後に、1枠から「実際に出題できる異なる
// 採用セット」がどれだけ取れるかを計測するレポート。⑥ multi-set 化の前提
// (測ってから組み込む)を数字で裏取りする。lib は一切変更せず既存 public
// API のみで測る。生成の early-return は使わず、全候補セットを走査する。

GeneratedPuzzle _buildPuzzle(
  Set<Cell> frame,
  List<PlacedBlock> blocks,
  int seed,
  Difficulty d,
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
    difficulty: d,
  );
}

// 採用セットの「構成」署名(source id 集合)。ピース構成が違えば別パズルと見なす。
String _setSig(List<PolyominoData> set) {
  final ids = set.map((p) => p.id).toList()..sort();
  return ids.join('+');
}

// 採用セットの「分割」署名(各ピースの絶対セル集合を正規化して連結)。
String _tilingSig(List<PlacedBlock> blocks) {
  final parts = <String>[];
  for (final b in blocks) {
    final cs = b.cells.toList()
      ..sort((a, z) => a.$1 != z.$1 ? a.$1 - z.$1 : a.$2 - z.$2);
    parts.add(cs.map((c) => '${c.$1},${c.$2}').join(';'));
  }
  parts.sort();
  return parts.join('|');
}

({double mean, int min, int max, double median}) _stats(List<int> xs) {
  if (xs.isEmpty) return (mean: 0, min: 0, max: 0, median: 0);
  final s = List<int>.of(xs)..sort();
  final sum = s.fold<int>(0, (a, b) => a + b);
  final mid = s.length ~/ 2;
  final median = s.length.isOdd
      ? s[mid].toDouble()
      : (s[mid - 1] + s[mid]) / 2.0;
  return (mean: sum / s.length, min: s.first, max: s.last, median: median);
}

String _fmt(({double mean, int min, int max, double median}) s) =>
    'mean=${s.mean.toStringAsFixed(1)} median=${s.median.toStringAsFixed(1)} '
    'min=${s.min} max=${s.max}';

void main() {
  const seedCounts = {
    Difficulty.easy: 50,
    Difficulty.normal: 40,
    Difficulty.hard: 30,
  };

  test('⑥ multi-set feasibility report: distinct accepted sets per frame', () {
    final sw = Stopwatch()..start();
    final buf = StringBuffer()
      ..writeln('=== ⑥ multi-set feasibility report (real pipeline rules) ===');

    final maxDistinctAccepted = <Difficulty, int>{};

    for (final d in Difficulty.values) {
      final n = seedCounts[d]!;
      final pool = d.pool;
      final isEasy = d == Difficulty.easy;

      final tileablePerFrame = <int>[];
      final acceptedPerFrame = <int>[];
      final acceptedNonSepPerFrame = <int>[];
      final distinctSetSigPerFrame = <int>[];
      final distinctTilingSigPerFrame = <int>[];
      final frameKeys = <String>{};
      var framesGenerated = 0;

      for (var seed = 1; seed <= n; seed++) {
        final frame = FrameGenerator.generate(d, seed);
        if (frame == null) continue;
        framesGenerated++;
        frameKeys.add(FrameGenerator.canonicalKey(frame));

        final sets = enumerateDistinctPieceSets(
          pool,
          d.blockCount,
          frame.length,
        );
        var tileable = 0, accepted = 0, acceptedNonSep = 0;
        final setSigs = <String>{};
        final tilingSigs = <String>{};

        for (final set in sets) {
          final tiling = FrameTiler.firstTiling(frame, set);
          if (tiling == null) continue; // 敷き詰め不能
          tileable++;
          final count = PuzzleSolver.countSolutions(
            frame: frame,
            shapes: set,
            limit: 4,
          );
          if (count < 1 || count > 3) continue; // 採用基準(1..3)
          accepted++;
          setSigs.add(_setSig(set));
          tilingSigs.add(_tilingSig(tiling));
          if (!isEasy) {
            final m = computePuzzleMetrics(
              _buildPuzzle(frame, tiling, seed, d),
            );
            if (!m.straightCutSeparable) acceptedNonSep++;
          }
        }

        tileablePerFrame.add(tileable);
        acceptedPerFrame.add(accepted);
        acceptedNonSepPerFrame.add(acceptedNonSep);
        distinctSetSigPerFrame.add(setSigs.length);
        distinctTilingSigPerFrame.add(tilingSigs.length);

        expect(
          accepted,
          lessThanOrEqualTo(tileable),
          reason: 'accepted は tileable の部分集合',
        );
        expect(
          setSigs.length,
          lessThanOrEqualTo(accepted),
          reason: 'distinct 構成署名は accepted 数以下',
        );
      }

      final dStat = _stats(distinctSetSigPerFrame);
      maxDistinctAccepted[d] = dStat.max;

      buf
        ..writeln(
          '--- ${d.name} '
          '(seeds=$n framesGenerated=$framesGenerated '
          'distinctFrames=${frameKeys.length}) ---',
        )
        ..writeln('tileable   sets/frame : ${_fmt(_stats(tileablePerFrame))}')
        ..writeln('accepted   sets/frame : ${_fmt(_stats(acceptedPerFrame))}');
      if (!isEasy) {
        buf.writeln(
          'accepted&nonSep/frame : ${_fmt(_stats(acceptedNonSepPerFrame))}',
        );
      }
      buf
        ..writeln('distinct set-sigs/frm : ${_fmt(dStat)}')
        ..writeln(
          'distinct tiling-sigs  : '
          '${_fmt(_stats(distinctTilingSigPerFrame))}',
        );
    }

    sw.stop();
    buf.writeln('(elapsed ${sw.elapsedMilliseconds} ms)');
    // ignore: avoid_print
    print(buf.toString());

    // feasibility: normal で1枠から2つ以上の異なる採用構成が取れること(⑥の前提)。
    expect(
      maxDistinctAccepted[Difficulty.normal]!,
      greaterThanOrEqualTo(2),
      reason: 'normal の少なくとも1枠で distinct 採用構成が2以上(multi-set 実現可能)',
    );
  });
}
