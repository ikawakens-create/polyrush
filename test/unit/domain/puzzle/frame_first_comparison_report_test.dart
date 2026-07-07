import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_first_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_metrics.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

// ADR-0020 判断9 + ⑤c: V3(NonTrivial) と frame-first の3構成を並べて計測する。
//   (A) ⑤b現状     = shuffleSets:false, tilingFirst:false
//   (B) Step1のみ   = shuffleSets:true,  tilingFirst:false
//   (C) Step1+2最終 = shuffleSets:true,  tilingFirst:true
// 充填率・separable率・生成成功率・実生成時間(早期確定込み)・distinct正準形状数を報告。
// ⑤c 目標: hard で C の生成時間 mean <= 100ms・max <= 500ms(CI上)。
// 生成時間はマシン依存でブレるため assert しない(レポートのみ)。非退行と目標達成の
// 判定は井川が CI ログで行い、Fable レビューに回す。
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
  group('V3 vs frame-first 比較計測(ADR-0020 判断9 + ⑤c 3構成)', () {
    for (final d in Difficulty.values) {
      test('${d.name}: V3＋frame-first 3構成の比較レポート', () {
        final v3 = _measure(
          d,
          (seed) =>
              NonTrivialPuzzleGenerator.generate(difficulty: d, seed: seed),
        );
        final ffA = _measure(
          d,
          (seed) => FrameFirstPuzzleGenerator.generate(
            difficulty: d,
            seed: seed,
            shuffleSets: false,
            tilingFirst: false,
          ),
        );
        final ffB = _measure(
          d,
          (seed) => FrameFirstPuzzleGenerator.generate(
            difficulty: d,
            seed: seed,
            shuffleSets: true,
            tilingFirst: false,
          ),
        );
        final ffC = _measure(
          d,
          (seed) => FrameFirstPuzzleGenerator.generate(
            difficulty: d,
            seed: seed,
            shuffleSets: true,
            tilingFirst: true,
          ),
        );
        print('');
        print('===== 比較計測: ${d.name} ($kSeeds seeds) =====');
        _report(d.name, 'V3(NonTrivial)      ', v3);
        _report(d.name, 'frameFirst A(5b現状) ', ffA);
        _report(d.name, 'frameFirst B(Step1)  ', ffB);
        _report(d.name, 'frameFirst C(最終)   ', ffC);

        expect(
          v3.success,
          greaterThan(0),
          reason: '${d.name}: V3 が生成できること(非退行の基準線)',
        );
        expect(
          ffA.success,
          greaterThan(0),
          reason: '${d.name}: frame-first A が生成できること',
        );
        expect(
          ffB.success,
          greaterThan(0),
          reason: '${d.name}: frame-first B が生成できること',
        );
        expect(
          ffC.success,
          greaterThan(0),
          reason: '${d.name}: frame-first C(最終形) が生成できること',
        );
      });
    }
  });
}
