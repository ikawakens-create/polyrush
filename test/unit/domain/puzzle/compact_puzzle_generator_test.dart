import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

void main() {
  // ─── 1. 基本動作 ──────────────────────────────────────────────────────────
  group('基本動作', () {
    for (final difficulty in Difficulty.values) {
      group(difficulty.name, () {
        for (var seed = 1; seed <= 20; seed++) {
          final s = seed;
          test('seed=$s で Ok を返す', () {
            final result = CompactPuzzleGenerator.generate(
              difficulty: difficulty,
              seed: s,
            );
            expect(
              result,
              isA<Ok<VerifiedPuzzle, CompactPuzzleError>>(),
              reason: '${difficulty.name}/seed=$s: Ok を返すこと',
            );
            final vp = (result as Ok<VerifiedPuzzle, CompactPuzzleError>).value;
            expect(
              vp.solutionCount,
              inInclusiveRange(1, 3),
              reason: '${difficulty.name}/seed=$s: solutionCount は 1〜3',
            );
            expect(
              vp.isFallback,
              isFalse,
              reason:
                  '${difficulty.name}/seed=$s: Compact はフォールバックしない（常に false）',
            );
            expect(
              isFrameSimplyConnected(vp.puzzle.frame),
              isTrue,
              reason: '${difficulty.name}/seed=$s: 枠が単連結であること（穴なし）',
            );
            expect(
              vp.puzzle.frame.length,
              inInclusiveRange(
                difficulty.minTotalCells,
                difficulty.maxTotalCells,
              ),
              reason: '${difficulty.name}/seed=$s: frame のセル数が難易度範囲内',
            );
          });
        }
      });
    }
  });

  // ─── 2. 充填率の改善 ──────────────────────────────────────────────────────
  //
  // 接触辺数最大化の効果検証。CI で数値計測する（ADR-0010 判断2の実測）。
  // 本物ウボンゴの充填率は平均約 72%（ADR-0010 Context）。
  // まず 0.55 を下限合格ラインとする。これを下回るなら接触辺数最大化が効いていないサイン。
  group('充填率の改善', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: seed=1..20 の平均充填率が 0.55 以上', () {
        var totalFillRate = 0.0;
        const seedCount = 20;

        for (var seed = 1; seed <= seedCount; seed++) {
          final result = CompactPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: seed,
          );
          expect(
            result,
            isA<Ok<VerifiedPuzzle, CompactPuzzleError>>(),
            reason: '${difficulty.name}/seed=$seed: Ok を返すこと（充填率計測の前提）',
          );
          final vp = (result as Ok<VerifiedPuzzle, CompactPuzzleError>).value;
          final bb = vp.puzzle.boundingBox;
          final area = (bb.maxX - bb.minX + 1) * (bb.maxY - bb.minY + 1);
          final fillRate = vp.puzzle.frame.length / area;

          expect(
            fillRate,
            greaterThanOrEqualTo(0.40),
            reason:
                '${difficulty.name}/seed=$seed: 個別充填率が 0.40 以上'
                '（昔の 30% 台が解消されたことの確認）',
          );

          totalFillRate += fillRate;
        }

        final avgFillRate = totalFillRate / seedCount;
        expect(
          avgFillRate,
          greaterThanOrEqualTo(0.55),
          reason:
              '${difficulty.name}: 平均充填率が 0.55 以上'
              '（接触辺数最大化の効果。本物平均は 0.72）',
        );
      });
    }
  });

  // ─── 3. 決定論性 ──────────────────────────────────────────────────────────
  group('決定論性', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: 同じ引数で 2 回呼ぶと同一 frame', () {
        const seed = 42;
        final r1 = CompactPuzzleGenerator.generate(
          difficulty: difficulty,
          seed: seed,
        );
        final r2 = CompactPuzzleGenerator.generate(
          difficulty: difficulty,
          seed: seed,
        );
        expect(
          r1.runtimeType,
          equals(r2.runtimeType),
          reason: '${difficulty.name}: Ok/Err の種別が一致',
        );
        if (r1 is Ok<VerifiedPuzzle, CompactPuzzleError> &&
            r2 is Ok<VerifiedPuzzle, CompactPuzzleError>) {
          expect(
            r1.value.puzzle.frame,
            equals(r2.value.puzzle.frame),
            reason: '${difficulty.name}: puzzle.frame が完全一致（決定論的）',
          );
          expect(
            r1.value.solutionCount,
            equals(r2.value.solutionCount),
            reason: '${difficulty.name}: solutionCount が一致',
          );
          expect(
            r1.value.attemptsUsed,
            equals(r2.value.attemptsUsed),
            reason: '${difficulty.name}: attemptsUsed が一致',
          );
        }
      });
    }
  });

  // ─── 4. リトライ予算（slow） ──────────────────────────────────────────────
  //
  // maxCompactRetries=8 でリトライ予算が足りることの実測（ADR-0010 申し送り）。
  group('リトライ予算', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: seed=1..500 で Err が1件も出ないこと', () {
        for (var seed = 1; seed <= 500; seed++) {
          final result = CompactPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: seed,
          );
          expect(
            result,
            isA<Ok<VerifiedPuzzle, CompactPuzzleError>>(),
            reason:
                '${difficulty.name}/seed=$seed: '
                'maxCompactRetries=8 でリトライ予算が足りること（ADR-0010 申し送り）',
          );
        }
      }, tags: ['slow']);
    }
  });

  // ─── 5. 接触辺数ロジックの単体確認 ──────────────────────────────────────
  group('接触辺数ロジック', () {
    test('既配置1マスの右隣に candidate 1マス → 接触辺数1', () {
      final placed = <Cell>{(0, 0)};
      final candidate = [(0, 1)];
      expect(
        CompactPuzzleGenerator.countContactEdges(candidate, placed),
        equals(1),
        reason: '既配置(0,0)に対して右隣(0,1)は1辺接触',
      );
    });

    test('既配置1マスに対して接触しない candidate → 接触辺数0', () {
      final placed = <Cell>{(0, 0)};
      final candidate = [(2, 2)];
      expect(
        CompactPuzzleGenerator.countContactEdges(candidate, placed),
        equals(0),
        reason: '既配置と辺接触しない位置は0',
      );
    });

    test('既配置2マス(0,0)(1,0)に対し横に並ぶ candidate(0,1)(1,1) → 接触辺数2', () {
      final placed = <Cell>{(0, 0), (1, 0)};
      final candidate = [(0, 1), (1, 1)];
      // (0,1)の左(0,0) → +1、(1,1)の左(1,0) → +1
      expect(
        CompactPuzzleGenerator.countContactEdges(candidate, placed),
        equals(2),
        reason: '縦2マス既配置に対して横2マスのcandidate → 2辺接触',
      );
    });

    test('コの字の中心に candidate → 接触辺数3', () {
      // 既配置: (0,1)(1,0)(1,2) でコの字。candidate: (1,1)
      // (1,1)上(0,1)→+1、(1,1)左(1,0)→+1、(1,1)右(1,2)→+1
      final placed = <Cell>{(0, 1), (1, 0), (1, 2)};
      final candidate = [(1, 1)];
      expect(
        CompactPuzzleGenerator.countContactEdges(candidate, placed),
        equals(3),
        reason: 'コの字の中心に1マス配置 → 3辺接触',
      );
    });

    test('candidate 内のセル同士の隣接は数えない', () {
      // 既配置: (0,0)。candidate: (0,1)(0,2)。
      // (0,1)←(0,0) → +1。(0,2)は既配置に隣接しない。
      // (0,1)と(0,2)は互いに隣接するが既配置でないので数えない。
      final placed = <Cell>{(0, 0)};
      final candidate = [(0, 1), (0, 2)];
      expect(
        CompactPuzzleGenerator.countContactEdges(candidate, placed),
        equals(1),
        reason: 'candidate 内セル同士の接触は数えない。既配置との接触のみ',
      );
    });

    test('4方向すべてから既配置に囲まれる candidate → 接触辺数4', () {
      // 既配置: 上下左右の4マス。candidate: 中心1マス。
      final placed = <Cell>{(0, 1), (2, 1), (1, 0), (1, 2)};
      final candidate = [(1, 1)];
      expect(
        CompactPuzzleGenerator.countContactEdges(candidate, placed),
        equals(4),
        reason: '4方向すべてから既配置に囲まれる → 4辺接触（最大値）',
      );
    });
  });

  // ─── 6. source 重複なし・dedup 後も Err ゼロ（slow） ────────────────────────
  //
  // dedup 制約（同一 source.id を1パズル内で2回以上使わない）の正しさと、
  // 制約追加後もリトライ予算が足りることを実測する。
  group('source重複なし・dedup後もErrゼロ', () {
    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: seed=1..500 で source.id 重複なし・Errなし', () {
        for (var seed = 1; seed <= 500; seed++) {
          final result = CompactPuzzleGenerator.generate(
            difficulty: difficulty,
            seed: seed,
          );
          // (B) dedup 後も generate がすべて Ok であること。
          expect(
            result,
            isA<Ok<VerifiedPuzzle, CompactPuzzleError>>(),
            reason:
                '${difficulty.name}/seed=$seed: '
                'dedup 制約追加後も Err が増えていないこと',
          );
          if (result is Ok<VerifiedPuzzle, CompactPuzzleError>) {
            // (A) 各パズル内に source.id の重複がないこと。
            final ids = result.value.puzzle.blocks
                .map((b) => b.source.id)
                .toList();
            expect(
              ids.toSet().length,
              equals(ids.length),
              reason:
                  '${difficulty.name}/seed=$seed: '
                  'blocks 内の source.id がすべて異なること（重複なし）',
            );
          }
        }
      }, tags: ['slow']);
    }
  });
}
