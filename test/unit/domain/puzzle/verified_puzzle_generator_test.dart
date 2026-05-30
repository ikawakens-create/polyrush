import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';
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
    test(
      'easy/seed=2: 同一シードで決定論的に同じ有効パズルを返す（救済の検証ではない）',
      () {
        // このテストは「generate が救済経路を実際に踏んだか」は主張しない。
        // 検証するのは (1) 決定論性 と (2) 出力の妥当性 のみ。
        final r1 = VerifiedPuzzleGenerator.generate(
          difficulty: Difficulty.easy,
          seed: 2,
        );
        final r2 = VerifiedPuzzleGenerator.generate(
          difficulty: Difficulty.easy,
          seed: 2,
        );
        expect(
          r1,
          isA<Ok<VerifiedPuzzle, GenerationError>>(),
          reason: 'easy/seed=2: 1 回目が Ok を返すこと',
        );
        expect(
          r2,
          isA<Ok<VerifiedPuzzle, GenerationError>>(),
          reason: 'easy/seed=2: 2 回目が Ok を返すこと',
        );
        final v1 = (r1 as Ok<VerifiedPuzzle, GenerationError>).value;
        final v2 = (r2 as Ok<VerifiedPuzzle, GenerationError>).value;
        // (1) 決定論: 同じシードで 2 回呼ぶと frame が完全一致する。
        expect(
          v1.puzzle.frame,
          equals(v2.puzzle.frame),
          reason: 'easy/seed=2: 決定論的に同じ frame が得られること',
        );
        // (2) 有効な良問: 通常採用時（isFallback=false）は解数 ≤ 3。
        if (!v1.isFallback) {
          expect(
            v1.solutionCount,
            lessThanOrEqualTo(3),
            reason: 'easy/seed=2: 通常採用時の解数は 3 以下（有効な良問）',
          );
        }
      },
    );
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

  // ─── 8. 地の数字実測 ──────────────────────────────────────────────────────────
  group('地の数字実測', () {
    test('construct(easy, seed:2) の解数を実測値で固定', () {
      final puzzle = PuzzleGenerator.construct(
        difficulty: Difficulty.easy,
        seed: 2,
      );
      final shapes = puzzle.blocks.map((b) => b.source).toList();
      // limit を 10 にして 4 以上の解数も正確に数える（デフォルト 4 だと打ち切りになる）。
      final count = PuzzleSolver.countSolutions(
        frame: puzzle.frame,
        shapes: shapes,
        limit: 10,
      );
      expect(
        count,
        equals(4),
        reason: 'construct(easy, seed:2) の解数を実測値で固定。'
            '「seed=2は解4」という従来の言い伝えの真偽をここで確定させる。',
      );
    });
  });

  // ─── 9. generate の迂回証明 ───────────────────────────────────────────────────
  group('generate の迂回証明', () {
    test('generate(easy, 2) は construct(easy, 2) とは別パズルを作る', () {
      // generate は attempt=0 から _deriveSubSeed(2, 0) = 3329051 をサブシードとして
      // construct を呼ぶため、construct(easy, seed:2) とは異なるパズルになる。
      final viaConstruct = PuzzleGenerator.construct(
        difficulty: Difficulty.easy,
        seed: 2,
      );
      final result = VerifiedPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 2,
      );
      expect(
        result,
        isA<Ok<VerifiedPuzzle, GenerationError>>(),
        reason: 'generate(easy, 2) が Ok を返すこと',
      );
      final viaGenerate = (result as Ok<VerifiedPuzzle, GenerationError>).value;
      // GeneratedPuzzle に == がないため frame（Set<Cell>）で直接比較する。
      expect(
        viaGenerate.puzzle.frame,
        isNot(equals(viaConstruct.frame)),
        reason: 'generate は attempt0 からサブシード派生seedで construct を呼ぶため、'
            'construct(easy,2) とは別パズルになる（＝seed=2の問題は救済ではなく迂回される）。',
      );
    });
  });

  // ─── 10. hard 妥当性スイープ (slow) ──────────────────────────────────────────
  group('hard 妥当性スイープ', () {
    test('hard: seed=0..199 の出力はすべて有効（解数 ≤ 3 またはフォールバック）', () {
      // このテストは出力の妥当性のみを検証する。generate は試行回数を外部公開
      // しないため「救済経路を実際に踏んだか」は検証できない（観測性ギャップ）。
      // 救済経路の本物の回帰テストは観測性追加（将来のB案）を要する。
      for (var seed = 0; seed < 200; seed++) {
        final result = VerifiedPuzzleGenerator.generate(
          difficulty: Difficulty.hard,
          seed: seed,
        );
        expect(
          result,
          isA<Ok<VerifiedPuzzle, GenerationError>>(),
          reason: 'hard/seed=$seed: Ok を返すこと',
        );
        final vp = (result as Ok<VerifiedPuzzle, GenerationError>).value;
        expect(
          vp.solutionCount <= 3 || vp.isFallback,
          isTrue,
          reason: 'hard/seed=$seed: 解数が 3 以下、またはフォールバックであること',
        );
      }
    }, tags: ['slow']);
  });
}
