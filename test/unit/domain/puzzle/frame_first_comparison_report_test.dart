import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_first_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

// ADR-0020 判断9: V3(NonTrivial) と frame-first を並べて計測し、非退行と実用性を確認する。
// 充填率・separable率・生成成功率・実生成時間(早期確定込み)・distinct 正準形状数を報告。
const int kSeeds = 20;

class _Agg {
  int total = 0;
  int success = 0;
  final List<double> fill = [];
  int separable = 0;
  final List<double> ms = [];
  final Set<String> shapes = {};
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
double _max(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b);

_Agg _measure(
  Difficulty d,
  Result<VerifiedPuzzle, CompactPuzzleError> Function(int seed) gen,
) {
  final a = _Agg();
  for (var i = 0; i < kSeeds; i++) {
    final seed = 100000 * (d.index + 1) + i * 97 + 1;
    final sw = Stopwatch()..start();
    final r = gen(seed);
    sw.stop();
    a.total++;
    a.ms.add(sw.elapsedMicroseconds / 1000.0);
    if (r is Ok<VerifiedPuzzle, CompactPuzzleError>) {
      a.success++;
      final p = r.value.puzzle;
      final m = computePuzzleMetrics(p);
      a.fill.add(m.fillRatio);
      if (m.straightCutSeparable) a.separable++;
      a.shapes.add(FrameGenerator.canonicalKey(p.frame));
    }
  }
  return a;
}

void _report(String difficulty, String label, _Agg a) {
  final sepRate = a.success == 0 ? 0.0 : a.separable / a.success * 100;
  print(
    '  [$difficulty] $label: '
    '成功 ${a.success}/${a.total} / '
    '充填率 mean=${_mean(a.fill).toStringAsFixed(3)} / '
    'separable ${sepRate.toStringAsFixed(1)}% / '
    '生成時間ms mean=${_mean(a.ms).toStringAsFixed(1)} max=${_max(a.ms).toStringAsFixed(1)} / '
    'distinct正準形状 ${a.shapes.length}',
  );
}

void main() {
  group('V3 vs frame-first 比較計測(ADR-0020 判断9)', () {
    for (final d in Difficulty.values) {
      test('${d.name}: 両生成器の比較レポート', () {
        final v3 = _measure(
          d,
          (seed) =>
              NonTrivialPuzzleGenerator.generate(difficulty: d, seed: seed),
        );
        final ff = _measure(
          d,
          (seed) =>
              FrameFirstPuzzleGenerator.generate(difficulty: d, seed: seed),
        );
        print('');
        print('===== 比較計測: ${d.name} ($kSeeds seeds) =====');
        _report(d.name, 'V3(NonTrivial)', v3);
        _report(d.name, 'frame-first   ', ff);

        expect(
          ff.success,
          greaterThan(0),
          reason: '${d.name}: frame-first が生成できること',
        );
        expect(
          v3.success,
          greaterThan(0),
          reason: '${d.name}: V3 が生成できること(非退行確認)',
        );
      });
    }
  });
}
