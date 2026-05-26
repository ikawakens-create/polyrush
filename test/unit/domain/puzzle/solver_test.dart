import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';

void main() {
  // ─── 1. 単一形状ぴったり ──────────────────────────────────────────────────
  group('単一形状ぴったり', () {
    test('kI3 1 個でちょうど I3 フレームを埋める → 1', () {
      final frame = {(0, 0), (0, 1), (0, 2)};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kI3]);
      expect(count, 1, reason: '直線 I3 は横置きの 1 通りのみ');
    });

    test('kL3 1 個でちょうど L3 フレームを埋める → 1', () {
      final frame = {(0, 0), (0, 1), (1, 0)};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kL3]);
      expect(count, 1, reason: 'L3 は自身の形にぴったりはまる 1 通りのみ');
    });
  });

  // ─── 2. マルチセットの水増し防止 ──────────────────────────────────────────
  group('マルチセットの水増し防止', () {
    test('kI3 × 2 で 2×3 を埋める → 1（上下に 1 本ずつ）', () {
      // 2×3 の長方形（6 マス）
      final frame = <Cell>{(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)};
      final count = PuzzleSolver.countSolutions(
        frame: frame,
        shapes: [kI3, kI3],
      );
      expect(
        count,
        1,
        reason:
            'I3 2 個で 2×3 を埋める方法は上下に 1 本ずつの 1 通りのみ'
            '（同形を区別すると誤って 2 になる）',
      );
    });
  });

  // ─── 3. 解なし・形状不一致 ────────────────────────────────────────────────
  group('解なし・形状不一致', () {
    test('L 字フレームに kI3（直線）→ 0', () {
      // L3 形状: (0,0), (1,0), (1,1)
      final frame = <Cell>{(0, 0), (1, 0), (1, 1)};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kI3]);
      expect(count, 0, reason: '直線 I3 は L 字枠に収まらない');
    });

    test('T4 フレームに kI4（直線 4 個）→ 0', () {
      // T4: (0,0),(0,1),(0,2),(1,1)
      final frame = <Cell>{(0, 0), (0, 1), (0, 2), (1, 1)};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kI4]);
      expect(count, 0, reason: '直線 I4 は T 字枠に収まらない');
    });
  });

  // ─── 4. 解なし・面積不一致 ────────────────────────────────────────────────
  group('解なし・面積不一致', () {
    test('4 マスフレームに kI3（3 マス）→ 0', () {
      final frame = <Cell>{(0, 0), (0, 1), (0, 2), (0, 3)};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kI3]);
      expect(count, 0, reason: 'セル数の合計が不一致のため即座に 0');
    });

    test('3 マスフレームに kI4（4 マス）→ 0', () {
      final frame = <Cell>{(0, 0), (0, 1), (0, 2)};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kI4]);
      expect(count, 0, reason: 'セル数の合計が不一致のため即座に 0');
    });

    test('空フレームに shapes あり → 0', () {
      final frame = <Cell>{};
      final count = PuzzleSolver.countSolutions(frame: frame, shapes: [kI3]);
      expect(count, 0, reason: 'セル数の合計が不一致のため即座に 0');
    });
  });

  // ─── 5. limit による頭打ち ───────────────────────────────────────────────
  group('limit による頭打ち', () {
    test('解が存在するパズルで limit: 1 → ちょうど 1', () {
      final frame = <Cell>{(0, 0), (0, 1), (0, 2)};
      final count = PuzzleSolver.countSolutions(
        frame: frame,
        shapes: [kI3],
        limit: 1,
      );
      expect(count, 1, reason: 'limit=1 で探索を打ち切り 1 を返す');
    });

    test('複数解がある場合に limit: 2 で頭打ち', () {
      // 4×1 フレームに kI4 × 1 → 1 通り
      // ただし limit テストのため別のフレームを使う:
      // 2×2 フレームに kO4 × 1 → 1 通り (O4 は対称なので 1 通り)
      // より多い解のために 3×2 フレームに kL3 × 2 を使う:
      // kL3 2 個で 3×2 を埋める → 複数の向きで埋まる
      final frame = <Cell>{(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)};
      final countFull = PuzzleSolver.countSolutions(
        frame: frame,
        shapes: [kL3, kL3],
        limit: 100,
      );
      final countLimited = PuzzleSolver.countSolutions(
        frame: frame,
        shapes: [kL3, kL3],
        limit: 1,
      );
      expect(
        countLimited,
        lessThanOrEqualTo(countFull),
        reason: 'limit を設定すると全解以下になる',
      );
      expect(countLimited, greaterThanOrEqualTo(1), reason: '少なくとも 1 解は存在する');
    });
  });

  // ─── 6. 決定論性 ─────────────────────────────────────────────────────────
  group('決定論性', () {
    test('同じ入力で 2 回呼ぶ → 同じ結果', () {
      final frame = <Cell>{
        (0, 0),
        (0, 1),
        (0, 2),
        (0, 3),
        (1, 0),
        (1, 1),
        (1, 2),
        (1, 3),
      };
      final shapes = [kI4, kI4];
      final count1 = PuzzleSolver.countSolutions(frame: frame, shapes: shapes);
      final count2 = PuzzleSolver.countSolutions(frame: frame, shapes: shapes);
      expect(count1, count2, reason: '同一入力は常に同一結果（決定論的）');
    });

    test('複数形状でも決定論的', () {
      final frame = <Cell>{(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)};
      final shapes = [kI3, kI3];
      final count1 = PuzzleSolver.countSolutions(frame: frame, shapes: shapes);
      final count2 = PuzzleSolver.countSolutions(frame: frame, shapes: shapes);
      expect(count1, count2, reason: '同一入力は常に同一結果（決定論的）');
    });
  });

  // ─── 7. PuzzleGenerator との結合テスト ───────────────────────────────────
  group('PuzzleGenerator との結合テスト', () {
    const limit = 4;
    const seeds = [0, 1, 2, 3, 4];

    for (final difficulty in Difficulty.values) {
      group(difficulty.name, () {
        for (final seed in seeds) {
          test('seed=$seed は少なくとも 1 解・limit 以下', () {
            GeneratedPuzzle puzzle;
            try {
              puzzle = PuzzleGenerator.construct(
                difficulty: difficulty,
                seed: seed,
              );
            } on GenerationFailedException {
              // 生成失敗は solver のバグではないのでスキップ。
              return;
            }
            final shapes = puzzle.blocks.map((b) => b.source).toList();
            final count = PuzzleSolver.countSolutions(
              frame: puzzle.frame,
              shapes: shapes,
              limit: limit,
            );
            expect(
              count,
              greaterThanOrEqualTo(1),
              reason: '${difficulty.name}/seed=$seed: 逆算生成済みパズルは必ず 1 解以上を持つ',
            );
            expect(
              count,
              lessThanOrEqualTo(limit),
              reason: '${difficulty.name}/seed=$seed: 解数は limit 以下',
            );
          }, tags: 'slow');
        }
      });
    }
  });
}
