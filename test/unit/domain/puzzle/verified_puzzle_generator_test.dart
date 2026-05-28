import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

void main() {
  // ─── 1. 基本動作 ──────────────────────────────────────────────────────────
  group('基本動作', () {
    for (final difficulty in Difficulty.values) {
      group(difficulty.name, () {
        test('seed=0 で Ok を返し solutionCount が 1〜3', () {
          final result = VerifiedPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: 0,
          );
          expect(
            result,
            isA<Ok<VerifiedPuzzle, GenerationError>>(),
            reason: '${difficulty.name}/seed=0: Ok を返すこと',
          );
          final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
          if (!vp.isFallback) {
            expect(
              vp.solutionCount,
              inInclusiveRange(1, 3),
              reason: '${difficulty.name}/seed=0: 通常採用時の解数は 1〜3',
            );
          }
          expect(
            vp.attemptsUsed,
            greaterThanOrEqualTo(1),
            reason: '${difficulty.name}/seed=0: attemptsUsed は 1 以上',
          );
        });

        test('seed=1 で Ok を返し attemptsUsed が 1 以上', () {
          final result = VerifiedPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: 1,
          );
          expect(
            result,
            isA<Ok<VerifiedPuzzle, GenerationError>>(),
            reason: '${difficulty.name}/seed=1: Ok を返すこと',
          );
          final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
          expect(
            vp.attemptsUsed,
            greaterThanOrEqualTo(1),
            reason: 'attemptsUsed は常に 1 以上',
          );
        });
      });
    }
  });

  // ─── 2. 決定論性 ──────────────────────────────────────────────────────────
  group('決定論性', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: 同じ引数で 2 回呼ぶと同一結果', () {
        final r1 = VerifiedPuzzleGenerator.generate(
          difficulty: difficulty,
          seed: 42,
        );
        final r2 = VerifiedPuzzleGenerator.generate(
          difficulty: difficulty,
          seed: 42,
        );

        expect(
          r1.runtimeType,
          equals(r2.runtimeType),
          reason: '${difficulty.name}: Ok/Err の種別が一致',
        );

        if (r1 is Ok<VerifiedPuzzle, GenerationError> &&
            r2 is Ok<VerifiedPuzzle, GenerationError>) {
          final v1 = r1.value;
          final v2 = r2.value;
          expect(
            v1.solutionCount,
            equals(v2.solutionCount),
            reason: '${difficulty.name}: solutionCount が一致',
          );
          expect(
            v1.attemptsUsed,
            equals(v2.attemptsUsed),
            reason: '${difficulty.name}: attemptsUsed が一致',
          );
          expect(
            v1.isFallback,
            equals(v2.isFallback),
            reason: '${difficulty.name}: isFallback が一致',
          );
          expect(
            v1.puzzle.frame,
            equals(v2.puzzle.frame),
            reason: '${difficulty.name}: puzzle.frame が一致',
          );
        }
      });
    }
  });

  // ─── 3. 回帰テスト ────────────────────────────────────────────────────────
  group('回帰テスト', () {
    test('easy/seed=2: 解 4 以上のパズルを通常採用していない', () {
      // Task 4 で easy/seed=2 のパズルが解 4 通りと判明した既知の問題（ADR-0008）。
      final result = VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 2,
      );
      expect(
        result,
        isA<Ok<VerifiedPuzzle, GenerationError>>(),
        reason: 'easy/seed=2: Ok を返すこと',
      );
      final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
      // フォールバックでない場合、solutionCount は必ず 1〜3。
      // フォールバックの場合は isFallback=true が設定されている。
      // どちらにせよ「解 4 以上のパズルを通常採用（isFallback=false）していない」
      // ことを確認する。
      if (!vp.isFallback) {
        expect(
          vp.solutionCount,
          lessThan(4),
          reason: 'easy/seed=2: 通常採用時は解 1〜3',
        );
      }
    });
  });

  // ─── 4. フォールバック ────────────────────────────────────────────────────
  group('フォールバック', () {
    test('countSolutions が常に閾値以上を返すとき isFallback=true で Ok', () {
      // overrideCountSolutions で常に 4 を返すことでフォールバック分岐を強制。
      final result = VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 0,
        overrideCountSolutions: ({
          required frame,
          required shapes,
          required limit,
        }) =>
            4,
      );
      expect(
        result,
        isA<Ok<VerifiedPuzzle, GenerationError>>(),
        reason: 'フォールバック時も Ok を返す',
      );
      final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
      expect(
        vp.isFallback,
        isTrue,
        reason: '全試行で却下されたので isFallback=true',
      );
      expect(
        vp.solutionCount,
        greaterThanOrEqualTo(4),
        reason: 'フォールバック時の solutionCount は 4 以上',
      );
      expect(
        vp.attemptsUsed,
        equals(VerifiedPuzzleGenerator.maxVerificationRetries),
        reason: 'フォールバック時は全リトライを消費',
      );
    });

    test('countSolutions の中で最小 solutionCount のパズルを選ぶ', () {
      var countCallCount = 0;
      // 1回目は 6, 2回目は 4 を返す → 最小(4)のパズルが採用される。
      // overrideConstruct で seed=0 固定にし、construct が確実に成功するようにする。
      final result = VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 0,
        overrideConstruct: (d, s) =>
            PuzzleGenerator.construct(difficulty: d, seed: 0),
        overrideCountSolutions: ({
          required frame,
          required shapes,
          required limit,
        }) {
          countCallCount++;
          return countCallCount == 1 ? 6 : 4;
        },
        overrideMaxRetries: 2,
      );
      final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
      expect(
        vp.solutionCount,
        equals(4),
        reason: '解数が最小のパズル(4)がフォールバック候補として選ばれる',
      );
    });
  });

  // ─── 5. allAttemptsFailed ─────────────────────────────────────────────────
  group('allAttemptsFailed', () {
    test('construct が常に例外を投げると Err(allAttemptsFailed)', () {
      final result = VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 0,
        overrideConstruct: (_, _) =>
            throw const GenerationFailedException('forced failure'),
      );
      expect(
        result,
        isA<Err<VerifiedPuzzle, GenerationError>>(),
        reason: '全試行失敗で Err を返す',
      );
      final err = result as Err<VerifiedPuzzle, GenerationError>;
      expect(
        err.error,
        GenerationError.allAttemptsFailed,
        reason: 'エラー種別は allAttemptsFailed',
      );
    });

    test('construct が最初の試行だけ成功し残りは例外 → Ok（フォールバックでない）', () {
      var constructCallCount = 0;
      // seed=0 固定で construct を呼び出すことで確実に成功させる。
      // 1回目は成功(解=1返す)、2回目以降は例外 → 1回目で採用されるので Ok(isFallback=false)
      final result = VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 0,
        overrideConstruct: (d, s) {
          constructCallCount++;
          if (constructCallCount == 1) {
            return PuzzleGenerator.construct(difficulty: d, seed: 0);
          }
          throw const GenerationFailedException('forced');
        },
        overrideCountSolutions: ({
          required frame,
          required shapes,
          required limit,
        }) =>
            1,
      );
      expect(result, isA<Ok<VerifiedPuzzle, GenerationError>>());
      final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
      expect(vp.isFallback, isFalse, reason: '1回目で採用できればフォールバックにならない');
      expect(vp.attemptsUsed, 1, reason: '1回目で採用');
    });
  });

  // ─── 6. overrideMaxRetries ────────────────────────────────────────────────
  group('overrideMaxRetries', () {
    test('maxRetries=1 のとき試行は 1 回のみ', () {
      var constructCallCount = 0;
      // seed=0 固定で construct が確実に成功するようにする。
      VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 0,
        overrideConstruct: (d, s) {
          constructCallCount++;
          return PuzzleGenerator.construct(difficulty: d, seed: 0);
        },
        overrideCountSolutions: ({
          required frame,
          required shapes,
          required limit,
        }) =>
            4,
        overrideMaxRetries: 1,
      );
      expect(
        constructCallCount,
        1,
        reason: 'maxRetries=1 なので construct の呼び出しは 1 回',
      );
    });
  });

  // ─── 7. 却下率実測 (slow) ─────────────────────────────────────────────────
  group('却下率実測', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: seed=0..199 の却下率・フォールバック率を計測', () {
        const seedCount = 200;
        var hadRejection = 0; // attemptsUsed > 1 だった件数
        var fallbackCount = 0; // isFallback=true だった件数
        var errCount = 0; // Err だった件数

        for (var seed = 0; seed < seedCount; seed++) {
          final result = VerifiedPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: seed,
          );
          switch (result) {
            case Ok(:final value):
              if (value.attemptsUsed > 1 || value.isFallback) hadRejection++;
              if (value.isFallback) fallbackCount++;
            case Err():
              errCount++;
          }
        }

        final rejectionRate = hadRejection / seedCount * 100;
        final fallbackRate = fallbackCount / seedCount * 100;

        // ignore: avoid_print
        print(
          '[却下率] difficulty=${difficulty.name}: '
          'rejection(>=1回)=${rejectionRate.toStringAsFixed(1)}% '
          '($hadRejection/$seedCount), '
          'fallback=${fallbackRate.toStringAsFixed(1)}% '
          '($fallbackCount/$seedCount), '
          'err=$errCount',
        );

        expect(
          errCount,
          0,
          reason: '${difficulty.name}: seed=0..199 で全試行失敗(Err)は発生しないはず',
        );
      }, tags: ['slow']);
    }
  });
}
