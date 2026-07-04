import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

// ロードマップ ②a: easy forgiveness 計測CI(Fable 2026-07-04 方向確定)。
//
// 挙動は一切変えない。easy シード帯で「解数(solutionCount)の分布」と
// 「orientationUsageRatio の分布」を出す計測レポートのみ。
// 得られた数字は、③ で forgiveness(floor/cap 方式)を実装する際に
// 「floor=1 で足りるか、解数≥2 の追加救済が要るか」の判断材料にする。
void main() {
  group('EASY forgiveness 計測(②a)', () {
    test('easy seed 1..100: 解数分布と orientationUsageRatio 分布', () {
      const int seedStart = 1;
      const int seedEnd = 100;

      // 解数ヒストグラム(1..3 を想定。範囲外は素直に別キーで数える)
      final solutionHist = <int, int>{};
      int failed = 0;

      // orientationUsageRatio 統計
      double ratioSum = 0.0;
      double ratioMin = double.infinity;
      double ratioMax = double.negativeInfinity;
      int bucket0 = 0; // = 0.0
      int bucketLow = 0; // (0, 0.34]
      int bucketMid = 0; // (0.34, 0.67]
      int bucketHigh = 0; // (0.67, 1.0]

      int total = 0;

      for (int seed = seedStart; seed <= seedEnd; seed++) {
        final r = NonTrivialPuzzleGenerator.generate(
          difficulty: Difficulty.easy,
          seed: seed,
        );
        if (r is! Ok) {
          failed++;
          continue;
        }
        total++;
        final vp = (r as Ok).value;

        final int sc = vp.solutionCount as int;
        solutionHist[sc] = (solutionHist[sc] ?? 0) + 1;

        final m = computePuzzleMetrics(vp.puzzle);
        final double ratio = m.orientationUsageRatio;
        ratioSum += ratio;
        if (ratio < ratioMin) ratioMin = ratio;
        if (ratio > ratioMax) ratioMax = ratio;
        if (ratio == 0.0) {
          bucket0++;
        } else if (ratio <= 0.34) {
          bucketLow++;
        } else if (ratio <= 0.67) {
          bucketMid++;
        } else {
          bucketHigh++;
        }
      }

      final double ratioMean = total > 0 ? ratioSum / total : 0.0;
      if (total == 0) {
        ratioMin = 0.0;
        ratioMax = 0.0;
      }

      final scKeys = solutionHist.keys.toList()..sort();
      final int geq2 = scKeys
          .where((k) => k >= 2)
          .fold<int>(0, (a, k) => a + solutionHist[k]!);
      final double geq2pct = total > 0 ? (geq2 / total * 100) : 0.0;

      print('');
      print('=== EASY forgiveness 計測レポート (seed $seedStart..$seedEnd) ===');
      print('  生成成功: $total / ${seedEnd - seedStart + 1} 件(失敗: $failed)');
      print('  --- 解数(solutionCount) 分布 ---');
      for (final k in scKeys) {
        final int n = solutionHist[k]!;
        final double pct = total > 0 ? (n / total * 100) : 0.0;
        print('    解数=$k: $n 件 (${pct.toStringAsFixed(1)}%)');
      }
      print('    参考: 解数>=2 は $geq2 件 (${geq2pct.toStringAsFixed(1)}%)');
      print('  --- orientationUsageRatio 分布 ---');
      print(
        '    min=${ratioMin.toStringAsFixed(3)} '
        'mean=${ratioMean.toStringAsFixed(3)} '
        'max=${ratioMax.toStringAsFixed(3)}',
      );
      print('    =0        : $bucket0 件');
      print('    (0, 0.34] : $bucketLow 件');
      print('    (0.34,0.67]: $bucketMid 件');
      print('    (0.67, 1] : $bucketHigh 件');
      print('  (ADR-0018 既報 easy 平均 0.567 と比較)');
      print('');

      // 計測が成立していることの軽い担保(easy は全 seed で生成できる想定)。
      expect(total, greaterThan(0), reason: 'easy が1件以上生成できる');
      expect(failed, 0, reason: 'easy は全 seed で生成できる想定');
    }, tags: ['report']);
  });
}
