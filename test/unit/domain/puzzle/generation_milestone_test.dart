// 仕様書 §19 マイルストーン「3難易度すべてで生成失敗率1%以下」を CI で
// 自動検証するテスト。ADR-0008 の申し送り（難易度別の却下率/フォールバック率の
// 実測）も兼ねる。集計値は print して CI ログで読めるようにする。
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

/// 各難易度で評価するシード数（0..N-1）。
const int kMilestoneSeedCount = 500;

/// 許容する最大の生成失敗率（仕様書 §19）。
const double kMaxFailureRate = 0.01;

void main() {
  group('生成エンジン マイルストーン（失敗率1%以下）', () {
    for (final difficulty in Difficulty.values) {
      test(
        '${difficulty.name}: seed 0..${kMilestoneSeedCount - 1} で失敗率 <= 1%',
        () {
          var failCount = 0;
          var fallbackCount = 0;
          var successCount = 0;
          final dist = <int, int>{};
          var attemptsTotal = 0;
          var attemptsMax = 0;

          for (var seed = 0; seed < kMilestoneSeedCount; seed++) {
            final result = VerifiedPuzzleGenerator.generate(
              difficulty: difficulty,
              seed: seed,
            );
            switch (result) {
              case Err():
                failCount++;
              case Ok(:final value):
                successCount++;
                if (value.isFallback) fallbackCount++;
                final sc = value.solutionCount;
                dist[sc] = (dist[sc] ?? 0) + 1;
                attemptsTotal += value.attemptsUsed;
                if (value.attemptsUsed > attemptsMax) {
                  attemptsMax = value.attemptsUsed;
                }
            }
          }

          final failRate = failCount / kMilestoneSeedCount;
          final fallbackRate =
              successCount > 0 ? fallbackCount / successCount : 0.0;
          final avgAttempts =
              successCount > 0 ? attemptsTotal / successCount : 0.0;
          final dist1 = dist[1] ?? 0;
          final dist2 = dist[2] ?? 0;
          final dist3 = dist[3] ?? 0;
          final dist4plus = dist.entries
              .where((e) => e.key >= 4)
              .fold<int>(0, (sum, e) => sum + e.value);

          print('===== マイルストーン集計: ${difficulty.name} =====');
          print('件数              : $kMilestoneSeedCount');
          print(
            'ハード失敗        : $failCount件 / '
            '${(failRate * 100).toStringAsFixed(2)}%',
          );
          print(
            'フォールバック    : $fallbackCount件 / '
            '${(fallbackRate * 100).toStringAsFixed(2)}%'
            '（成功$successCount件中）',
          );
          print(
            '解数分布          : 1解=$dist1 2解=$dist2 3解=$dist3 4以上=$dist4plus',
          );
          print(
            '試行回数(平均/最大): ${avgAttempts.toStringAsFixed(2)} / $attemptsMax',
          );
          print('================================================');

          expect(
            failRate <= kMaxFailureRate,
            isTrue,
            reason:
                '${difficulty.name} の生成失敗率 '
                '${(failRate * 100).toStringAsFixed(2)}% が許容 '
                '${(kMaxFailureRate * 100).toStringAsFixed(0)}% を超過。'
                '失敗 $failCount件 / $kMilestoneSeedCount件。',
          );
        },
      );
    }
  });
}
