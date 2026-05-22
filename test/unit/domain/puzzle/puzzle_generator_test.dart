import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';

// BFS で frame の連結成分が 1 つかどうかを検証するユーティリティ。
bool _isConnected(Set<Cell> cells) {
  if (cells.isEmpty) return true;
  final visited = <Cell>{};
  final queue = Queue<Cell>()..add(cells.first);
  visited.add(cells.first);
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final n in [
      (current.$1 - 1, current.$2),
      (current.$1 + 1, current.$2),
      (current.$1, current.$2 - 1),
      (current.$1, current.$2 + 1),
    ]) {
      if (cells.contains(n) && visited.add(n)) queue.add(n);
    }
  }
  return visited.length == cells.length;
}

// 難易度の全ブロックが pool に含まれるか確認するユーティリティ。
bool _allSourcesInPool(GeneratedPuzzle puzzle) {
  final pool = puzzle.difficulty.pool;
  return puzzle.blocks.every(
    (b) => pool.any((p) => PolyominoTransformer.areEquivalent(b.source, p)),
  );
}

void main() {
  // ─── 1. isAdjacent ──────────────────────────────────────────────────────
  group('isAdjacent', () {
    test('x+1 方向は辺隣接', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (0, 1)), isTrue);
    });
    test('x-1 方向は辺隣接', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (0, -1)), isTrue);
    });
    test('y+1 方向は辺隣接', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (1, 0)), isTrue);
    });
    test('y-1 方向は辺隣接', () {
      expect(PuzzleGenerator.isAdjacent((3, 5), (2, 5)), isTrue);
    });
    test('対角線 (1,1) は辺隣接でない', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (1, 1)), isFalse);
    });
    test('対角線 (-1,-1) は辺隣接でない', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (-1, -1)), isFalse);
    });
    test('同一セルは辺隣接でない', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (0, 0)), isFalse);
    });
    test('距離 2 は辺隣接でない', () {
      expect(PuzzleGenerator.isAdjacent((0, 0), (0, 2)), isFalse);
    });
  });

  // ─── 2. listBoundaryCells ────────────────────────────────────────────────
  group('listBoundaryCells', () {
    test('単一セル (0,0) の境界マスは 4 個', () {
      final boundary = PuzzleGenerator.listBoundaryCells({(0, 0)});
      expect(
        boundary,
        equals({(-1, 0), (1, 0), (0, -1), (0, 1)}),
        reason: '単一セルの周囲4マスが境界',
      );
    });
    test('境界マスに配置済みセルは含まれない', () {
      const placed = {(0, 0), (0, 1)};
      final boundary = PuzzleGenerator.listBoundaryCells(placed);
      expect(
        boundary.intersection(placed),
        isEmpty,
        reason: '境界マスは配置済みセルを除外する',
      );
    });
    test('L-Tromino の境界マスは 7 個', () {
      // kL3 = [(0,0),(0,1),(1,0)]
      final placed = {(0, 0), (0, 1), (1, 0)};
      final boundary = PuzzleGenerator.listBoundaryCells(placed);
      expect(boundary.length, 7, reason: 'L-Tromino の境界マスは 7 個');
    });
    test('I-Tetromino の境界マスは 10 個', () {
      // kI4 = [(0,0),(0,1),(0,2),(0,3)]
      final placed = {(0, 0), (0, 1), (0, 2), (0, 3)};
      final boundary = PuzzleGenerator.listBoundaryCells(placed);
      expect(boundary.length, 10, reason: 'I-Tetromino の境界マスは 10 個');
    });
    test('O4 (2×2) の境界マスは 8 個', () {
      // kO4 = [(0,0),(0,1),(1,0),(1,1)]
      final placed = {(0, 0), (0, 1), (1, 0), (1, 1)};
      final boundary = PuzzleGenerator.listBoundaryCells(placed);
      expect(boundary.length, 8, reason: '2×2 正方形の境界マスは 8 個');
    });
    test('全ての境界マスは配置済みセルのいずれかに辺隣接する', () {
      final placed = {(0, 0), (0, 1), (1, 0)};
      final boundary = PuzzleGenerator.listBoundaryCells(placed);
      for (final b in boundary) {
        expect(
          placed.any((p) => PuzzleGenerator.isAdjacent(b, p)),
          isTrue,
          reason: '境界マス $b は配置済みセルに辺隣接すべき',
        );
      }
    });
  });

  // ─── 3. listPlacementCandidates ──────────────────────────────────────────
  group('listPlacementCandidates', () {
    test('単一セル配置済みに I3 を置く候補が存在する', () {
      final candidates = PuzzleGenerator.listPlacementCandidates(
        kI3,
        {(0, 0)},
      );
      expect(candidates, isNotEmpty, reason: '隣接配置の候補は必ず存在する');
    });
    test('全候補が既配置セルと重ならない (条件A)', () {
      final placed = {(0, 0), (0, 1), (1, 0)};
      final candidates =
          PuzzleGenerator.listPlacementCandidates(kT4, placed);
      for (final candidate in candidates) {
        final overlap = candidate.where(placed.contains).toList();
        expect(overlap, isEmpty, reason: '候補 $candidate に重複あり');
      }
    });
    test('全候補が既配置セルと少なくとも1辺隣接する (条件B)', () {
      final placed = {(0, 0), (0, 1), (1, 0)};
      final candidates =
          PuzzleGenerator.listPlacementCandidates(kL4, placed);
      for (final candidate in candidates) {
        final hasAdj = candidate.any(
          (c) => placed.any((p) => PuzzleGenerator.isAdjacent(c, p)),
        );
        expect(hasAdj, isTrue, reason: '候補 $candidate に辺隣接なし');
      }
    });
    test('候補リストに重複なし（セル集合が一致するものは1件のみ）', () {
      final placed = {(0, 0), (0, 1), (1, 0)};
      final candidates =
          PuzzleGenerator.listPlacementCandidates(kI3, placed);
      final keys = candidates.map((c) => c.toString()).toList();
      final unique = keys.toSet();
      expect(
        keys.length,
        unique.length,
        reason: '候補リストに重複配置が存在する',
      );
    });
    test('O4 (対称ピース) を単一セルに置く候補は重複除去される', () {
      // O4 は全向き同一。境界4マスのどれにピースのどのセルを当てても、
      // 候補は限られる。重複除去後は重複がないこと。
      final candidates = PuzzleGenerator.listPlacementCandidates(kO4, {(0, 0)});
      final keys = candidates.map((c) => c.toString()).toSet();
      expect(keys.length, candidates.length, reason: '重複候補が存在する');
    });
    test('全候補のセル数はピースのセル数と一致する', () {
      final candidates =
          PuzzleGenerator.listPlacementCandidates(kT4, {(0, 0), (1, 0)});
      for (final c in candidates) {
        expect(
          c.length,
          kT4.cells.length,
          reason: '候補 $c のセル数がピースサイズと不一致',
        );
      }
    });
    test('候補リストが空にならない（L-Tromino vs I-Tromino 1個配置済み）', () {
      final candidates =
          PuzzleGenerator.listPlacementCandidates(kL3, {(0, 0), (0, 1), (0, 2)});
      expect(candidates, isNotEmpty);
    });
    test('候補の各セルはソート済み（row-major 順）', () {
      final candidates = PuzzleGenerator.listPlacementCandidates(kI3, {(0, 0)});
      for (final c in candidates) {
        for (var i = 0; i < c.length - 1; i++) {
          final a = c[i];
          final b = c[i + 1];
          expect(
            a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 <= b.$2),
            isTrue,
            reason: '候補 $c の並び順が row-major でない',
          );
        }
      }
    });
  });

  // ─── 4. Difficulty enum ──────────────────────────────────────────────────
  group('Difficulty', () {
    test('easy.blockCount == 3', () {
      expect(Difficulty.easy.blockCount, 3);
    });
    test('normal.blockCount == 4', () {
      expect(Difficulty.normal.blockCount, 4);
    });
    test('hard.blockCount == 5', () {
      expect(Difficulty.hard.blockCount, 5);
    });
    test('easy のセル数範囲 [9, 12]', () {
      expect(Difficulty.easy.minTotalCells, 9);
      expect(Difficulty.easy.maxTotalCells, 12);
    });
    test('normal のセル数範囲 [16, 20]', () {
      expect(Difficulty.normal.minTotalCells, 16);
      expect(Difficulty.normal.maxTotalCells, 20);
    });
    test('hard のセル数範囲 [20, 25]', () {
      expect(Difficulty.hard.minTotalCells, 20);
      expect(Difficulty.hard.maxTotalCells, 25);
    });
    test('easy.pool はトロミノとテトロミノを含む', () {
      final pool = Difficulty.easy.pool;
      expect(
        pool.any((p) => kTrominoes.contains(p)),
        isTrue,
        reason: 'easy プールにトロミノがない',
      );
      expect(
        pool.any((p) => kTetrominoes.contains(p)),
        isTrue,
        reason: 'easy プールにテトロミノがない',
      );
      expect(
        pool.any((p) => kPentominoes.contains(p)),
        isFalse,
        reason: 'easy プールにペントミノが混入している',
      );
    });
    test('normal.pool と hard.pool はテトロミノとペントミノを含む', () {
      for (final d in [Difficulty.normal, Difficulty.hard]) {
        final pool = d.pool;
        expect(pool.any((p) => kTetrominoes.contains(p)), isTrue,
            reason: '${d.name} プールにテトロミノがない');
        expect(pool.any((p) => kPentominoes.contains(p)), isTrue,
            reason: '${d.name} プールにペントミノがない');
        expect(pool.any((p) => kTrominoes.contains(p)), isFalse,
            reason: '${d.name} プールにトロミノが混入している');
      }
    });
  });

  // ─── 5. 基本動作 ─────────────────────────────────────────────────────────
  group('基本動作', () {
    test('easy: construct が成功する (seed=0)', () {
      expect(
        () => PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0),
        returnsNormally,
      );
    });
    test('normal: construct が成功する (seed=0)', () {
      expect(
        () =>
            PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: 0),
        returnsNormally,
      );
    });
    test('hard: construct が成功する (seed=0)', () {
      expect(
        () => PuzzleGenerator.construct(difficulty: Difficulty.hard, seed: 0),
        returnsNormally,
      );
    });
    test('puzzle.seed は引数 seed と一致する', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 42);
      expect(puzzle.seed, 42);
    });
    test('puzzle.difficulty は引数 difficulty と一致する', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: 0);
      expect(puzzle.difficulty, Difficulty.normal);
    });
  });

  // ─── 6. ブロック数 ────────────────────────────────────────────────────────
  group('blocks.length', () {
    test('easy: blocks.length == 3', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0);
      expect(puzzle.blocks.length, 3);
    });
    test('normal: blocks.length == 4', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: 0);
      expect(puzzle.blocks.length, 4);
    });
    test('hard: blocks.length == 5', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.hard, seed: 0);
      expect(puzzle.blocks.length, 5);
    });
  });

  // ─── 7. セル総数が難易度範囲内 ─────────────────────────────────────────────
  group('frame.length の範囲', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: frame.length が [${diff.minTotalCells}, ${diff.maxTotalCells}] 内', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 1);
        expect(
          puzzle.frame.length,
          inInclusiveRange(diff.minTotalCells, diff.maxTotalCells),
          reason:
              '${diff.name}: frame.length=${puzzle.frame.length}',
        );
      });
    }
  });

  // ─── 8. frame == 全 blocks の和集合 ──────────────────────────────────────
  group('frame == union(blocks[i].cells)', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: frame は全ブロックセルの和集合と完全一致する', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 2);
        final union = <Cell>{};
        for (final b in puzzle.blocks) {
          union.addAll(b.cells);
        }
        expect(
          puzzle.frame,
          equals(union),
          reason: '${diff.name}: frame と blocks 和集合が不一致',
        );
      });
    }
  });

  // ─── 9. boundingBox の正確性 ─────────────────────────────────────────────
  group('boundingBox', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: boundingBox.minY が frame の min-y と一致', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 3);
        final minY =
            puzzle.frame.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
        expect(
          puzzle.boundingBox.minY,
          minY,
          reason: '${diff.name}: minY 不一致',
        );
      });
      test('${diff.name}: boundingBox.maxY が frame の max-y と一致', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 3);
        final maxY =
            puzzle.frame.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
        expect(
          puzzle.boundingBox.maxY,
          maxY,
          reason: '${diff.name}: maxY 不一致',
        );
      });
      test('${diff.name}: boundingBox.minX が frame の min-x と一致', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 3);
        final minX =
            puzzle.frame.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
        expect(
          puzzle.boundingBox.minX,
          minX,
          reason: '${diff.name}: minX 不一致',
        );
      });
      test('${diff.name}: boundingBox.maxX が frame の max-x と一致', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 3);
        final maxX =
            puzzle.frame.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
        expect(
          puzzle.boundingBox.maxX,
          maxX,
          reason: '${diff.name}: maxX 不一致',
        );
      });
    }
  });

  // ─── 10. ブロック間のセル重複なし ────────────────────────────────────────
  group('ブロック間のセル重複なし', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: 全ブロック間でセル重複がない', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 4);
        final all = <Cell>[];
        for (final b in puzzle.blocks) {
          all.addAll(b.cells);
        }
        expect(
          all.length,
          all.toSet().length,
          reason: '${diff.name}: ブロック間にセル重複あり',
        );
      });
    }
  });

  // ─── 11. 2個目以降は既配置と辺隣接 ─────────────────────────────────────
  group('隣接制約', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: 2個目以降のブロックは直前配置済みセルに辺隣接する', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 5);
        final cumulative = <Cell>{};
        cumulative.addAll(puzzle.blocks[0].cells);
        for (var i = 1; i < puzzle.blocks.length; i++) {
          final b = puzzle.blocks[i];
          final hasAdj = b.cells.any(
            (c) => cumulative.any((p) => PuzzleGenerator.isAdjacent(c, p)),
          );
          expect(
            hasAdj,
            isTrue,
            reason: '${diff.name}: blocks[$i] が既配置と隣接していない',
          );
          cumulative.addAll(b.cells);
        }
      });
    }
  });

  // ─── 12. source が pool に含まれる ────────────────────────────────────────
  group('source の pool 帰属', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: 全 blocks[i].source が difficulty.pool に含まれる', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 6);
        expect(
          _allSourcesInPool(puzzle),
          isTrue,
          reason: '${diff.name}: pool に含まれない source あり',
        );
      });
    }
  });

  // ─── 13. frame の連結性 ──────────────────────────────────────────────────
  group('frame の連結性', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: frame は連結グラフを構成する (BFS)', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 7);
        expect(
          _isConnected(puzzle.frame),
          isTrue,
          reason: '${diff.name}: frame が非連結',
        );
      });
    }
  });

  // ─── 14. 面積一致 ────────────────────────────────────────────────────────
  group('面積一致', () {
    for (final diff in Difficulty.values) {
      test(
          '${diff.name}: frame.length == blocks の cells 合計',
          () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 8);
        final total =
            puzzle.blocks.fold(0, (s, b) => s + b.cells.length);
        expect(
          puzzle.frame.length,
          total,
          reason: '${diff.name}: frame.length=${ puzzle.frame.length}, sum=$total',
        );
      });
    }
  });

  // ─── 15. frame ⊂ boundingBox ─────────────────────────────────────────────
  group('frame ⊂ boundingBox', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: 全 frame セルが boundingBox 内に収まる', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 9);
        final bb = puzzle.boundingBox;
        for (final c in puzzle.frame) {
          expect(
            c.$1 >= bb.minY && c.$1 <= bb.maxY,
            isTrue,
            reason: '${diff.name}: cell $c の y が boundingBox 外',
          );
          expect(
            c.$2 >= bb.minX && c.$2 <= bb.maxX,
            isTrue,
            reason: '${diff.name}: cell $c の x が boundingBox 外',
          );
        }
      });
    }
  });

  // ─── 16. source は正規化済み ─────────────────────────────────────────────
  group('PlacedBlock.source は正規化済み', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: normalize(source).cells == source.cells', () {
        final puzzle =
            PuzzleGenerator.construct(difficulty: diff, seed: 10);
        for (var i = 0; i < puzzle.blocks.length; i++) {
          final src = puzzle.blocks[i].source;
          final normalized = PolyominoTransformer.normalize(src);
          expect(
            normalized.cells,
            src.cells,
            reason: '${diff.name}: blocks[$i].source が非正規化',
          );
        }
      });
    }
  });

  // ─── 17. 再現性 ──────────────────────────────────────────────────────────
  group('再現性', () {
    test('同じ (difficulty, seed) で2回呼ぶと frame が完全一致する', () {
      final p1 =
          PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: 99);
      final p2 =
          PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: 99);
      expect(p1.frame, equals(p2.frame));
    });
    test('同じ (difficulty, seed) で2回呼ぶと blocks が完全一致する', () {
      final p1 =
          PuzzleGenerator.construct(difficulty: Difficulty.hard, seed: 77);
      final p2 =
          PuzzleGenerator.construct(difficulty: Difficulty.hard, seed: 77);
      expect(p1.blocks.length, p2.blocks.length);
      for (var i = 0; i < p1.blocks.length; i++) {
        expect(
          p1.blocks[i].cells,
          equals(p2.blocks[i].cells),
          reason: 'blocks[$i].cells が不一致',
        );
        expect(
          p1.blocks[i].source,
          equals(p2.blocks[i].source),
          reason: 'blocks[$i].source が不一致',
        );
      }
    });
    test('同じ (difficulty, seed) で2回呼ぶと boundingBox が完全一致する', () {
      final p1 =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 55);
      final p2 =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 55);
      expect(p1.boundingBox.minY, p2.boundingBox.minY);
      expect(p1.boundingBox.maxY, p2.boundingBox.maxY);
      expect(p1.boundingBox.minX, p2.boundingBox.minX);
      expect(p1.boundingBox.maxX, p2.boundingBox.maxX);
    });
  });

  // ─── 18. 多様性 ──────────────────────────────────────────────────────────
  group('多様性', () {
    test('easy: seed 0..19 で生成した 20 個の frame が全て異なる', () {
      final frames = <Set<Cell>>{};
      for (var s = 0; s < 20; s++) {
        final p =
            PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: s);
        frames.add(p.frame);
      }
      expect(
        frames.length,
        20,
        reason: '異なる seed で同じ frame が生成された',
      );
    });
  });

  // ─── 19. ピースの向きの多様性 ───────────────────────────────────────────
  group('ピースの向きの多様性 (seed 0..99)', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: blocks[0] のユニーク (source.id, cells) が >= 5', () {
        final uniqueKeys = <String>{};
        for (var s = 0; s < 100; s++) {
          final puzzle =
              PuzzleGenerator.construct(difficulty: diff, seed: s);
          final b = puzzle.blocks[0];
          final normalizedCells = PolyominoTransformer.normalize(
            PolyominoData(
              id: b.source.id,
              size: b.source.size,
              cells: b.cells,
            ),
          ).cells;
          uniqueKeys.add('${b.source.id}:$normalizedCells');
        }
        expect(
          uniqueKeys.length,
          greaterThanOrEqualTo(5),
          reason:
              '${diff.name}: ユニーク向き数=${uniqueKeys.length} < 5 → 向きランダム未実装の可能性',
        );
      });
    }
  });

  // ─── 20. マルチセット（同一ピース重複OK）─────────────────────────────────
  group('マルチセット', () {
    for (final diff in Difficulty.values) {
      test('${diff.name}: seed 0..99 の中に同じ source.id を持つブロックが 2 個以上の puzzle がある', () {
        var found = false;
        for (var s = 0; s < 100 && !found; s++) {
          final puzzle =
              PuzzleGenerator.construct(difficulty: diff, seed: s);
          final ids = puzzle.blocks.map((b) => b.source.id).toList();
          final unique = ids.toSet();
          if (unique.length < ids.length) found = true;
        }
        expect(
          found,
          isTrue,
          reason: '${diff.name}: 100 試行で重複 source.id が一度も出現しなかった',
        );
      });
    }
  });

  // ─── 21. 失敗ハンドリング ────────────────────────────────────────────────
  group('失敗ハンドリング', () {
    test('GenerationFailedException: overrideMaxAttempts=0 で即時失敗', () {
      expect(
        () => PuzzleGenerator.construct(
          difficulty: Difficulty.easy,
          seed: 0,
          overrideMaxAttempts: 0,
        ),
        throwsA(isA<GenerationFailedException>()),
      );
    });
    test('GenerationFailedException: エラーメッセージに seed が含まれる', () {
      try {
        PuzzleGenerator.construct(
          difficulty: Difficulty.easy,
          seed: 42,
          overrideMaxAttempts: 0,
        );
        fail('GenerationFailedException がスローされるべき');
      } on GenerationFailedException catch (e) {
        expect(
          e.message,
          contains('42'),
          reason: 'メッセージに seed=42 が含まれない',
        );
      }
    });
    test('GenerationFailedException.toString() が正しい形式', () {
      const ex = GenerationFailedException('test message');
      expect(ex.toString(), 'GenerationFailedException: test message');
    });
  });

  // ─── 22. エッジケース ────────────────────────────────────────────────────
  group('エッジケース', () {
    test('seed = 0 で動作する', () {
      expect(
        () => PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0),
        returnsNormally,
      );
    });
    test('seed = -1 で動作する', () {
      expect(
        () => PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: -1),
        returnsNormally,
      );
    });
    test('seed = (1 << 31) - 1 で動作する', () {
      expect(
        () => PuzzleGenerator.construct(
          difficulty: Difficulty.easy,
          seed: (1 << 31) - 1,
        ),
        returnsNormally,
      );
    });
  });

  // ─── 23. イミュータブル違反テスト ────────────────────────────────────────
  group('イミュータブル', () {
    test('puzzle.frame.add() は UnsupportedError をスローする', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0);
      expect(
        () => puzzle.frame.add((99, 99)),
        throwsA(isA<UnsupportedError>()),
      );
    });
    test('puzzle.blocks.add() は UnsupportedError をスローする', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0);
      final dummy = PlacedBlock(source: kI3, cells: [(0, 0), (0, 1), (0, 2)]);
      expect(
        () => puzzle.blocks.add(dummy),
        throwsA(isA<UnsupportedError>()),
      );
    });
    test('puzzle.blocks[0].cells.add() は UnsupportedError をスローする', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0);
      expect(
        () => puzzle.blocks[0].cells.add((99, 99)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  // ─── 24. パフォーマンス ──────────────────────────────────────────────────
  group('パフォーマンス', () {
    test('1問あたり 50ms 以内 (easy, seed=0)', () {
      final sw = Stopwatch()..start();
      PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0);
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(50),
        reason: '生成時間 ${sw.elapsedMilliseconds}ms が 50ms を超過',
      );
    });
    test('10問の合計が 500ms 以内 (hard)', () {
      final sw = Stopwatch()..start();
      for (var s = 0; s < 10; s++) {
        PuzzleGenerator.construct(difficulty: Difficulty.hard, seed: s);
      }
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: '10問合計 ${sw.elapsedMilliseconds}ms が 500ms を超過',
      );
    });
  });

  // ─── 25. ADR-0006 準拠 ───────────────────────────────────────────────────
  group('ADR-0006 準拠', () {
    test('boundingBox フィールド名が minY/maxY/minX/maxX', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: 0);
      // フィールドにアクセスできること（型推論でコンパイル時チェック）
      expect(
        puzzle.boundingBox.minY,
        lessThanOrEqualTo(puzzle.boundingBox.maxY),
      );
      expect(
        puzzle.boundingBox.minX,
        lessThanOrEqualTo(puzzle.boundingBox.maxX),
      );
    });
    test('frame の Cell は (y, x) 順 — boundingBox.minY が frame の min y と一致', () {
      final puzzle =
          PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: 0);
      final minFirstComponent =
          puzzle.frame.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
      expect(
        puzzle.boundingBox.minY,
        minFirstComponent,
        reason: 'minY は Cell の第1要素 (y/row) の最小値と一致すべき',
      );
    });
  });

  // ─── 26. ストレステスト ───────────────────────────────────────────────────
  group('ストレステスト', () {
    test(
      'easy: 1000 問生成、失敗数 < 10',
      () {
        var failures = 0;
        final failedSeeds = <int>[];
        final sw = Stopwatch()..start();
        for (var s = 0; s < 1000; s++) {
          try {
            PuzzleGenerator.construct(difficulty: Difficulty.easy, seed: s);
          } on GenerationFailedException {
            failures++;
            failedSeeds.add(s);
          }
        }
        sw.stop();
        if (failedSeeds.isNotEmpty) {
          // ignore: avoid_print
          print('easy 失敗 seed: $failedSeeds');
        }
        // ignore: avoid_print
        print('easy 1000問: ${sw.elapsedMilliseconds}ms, 失敗$failures件');
        expect(sw.elapsedMilliseconds, lessThan(30000),
            reason: 'easy 1000問が 30秒を超過');
        expect(failures, lessThan(10), reason: 'easy 失敗数=$failures >= 10');
      },
      tags: ['slow'],
    );
    test(
      'normal: 1000 問生成、失敗数 < 10',
      () {
        var failures = 0;
        final failedSeeds = <int>[];
        final sw = Stopwatch()..start();
        for (var s = 0; s < 1000; s++) {
          try {
            PuzzleGenerator.construct(difficulty: Difficulty.normal, seed: s);
          } on GenerationFailedException {
            failures++;
            failedSeeds.add(s);
          }
        }
        sw.stop();
        if (failedSeeds.isNotEmpty) {
          // ignore: avoid_print
          print('normal 失敗 seed: $failedSeeds');
        }
        // ignore: avoid_print
        print('normal 1000問: ${sw.elapsedMilliseconds}ms, 失敗$failures件');
        expect(sw.elapsedMilliseconds, lessThan(30000),
            reason: 'normal 1000問が 30秒を超過');
        expect(failures, lessThan(10), reason: 'normal 失敗数=$failures >= 10');
      },
      tags: ['slow'],
    );
    test(
      'hard: 1000 問生成、失敗数 < 10',
      () {
        var failures = 0;
        final failedSeeds = <int>[];
        final sw = Stopwatch()..start();
        for (var s = 0; s < 1000; s++) {
          try {
            PuzzleGenerator.construct(difficulty: Difficulty.hard, seed: s);
          } on GenerationFailedException {
            failures++;
            failedSeeds.add(s);
          }
        }
        sw.stop();
        if (failedSeeds.isNotEmpty) {
          // ignore: avoid_print
          print('hard 失敗 seed: $failedSeeds');
        }
        // ignore: avoid_print
        print('hard 1000問: ${sw.elapsedMilliseconds}ms, 失敗$failures件');
        expect(sw.elapsedMilliseconds, lessThan(30000),
            reason: 'hard 1000問が 30秒を超過');
        expect(failures, lessThan(10), reason: 'hard 失敗数=$failures >= 10');
      },
      tags: ['slow'],
    );
  });
}
