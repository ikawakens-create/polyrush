import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/play/piece_orientation_state.dart';

/// [difficulty] / [seed] のパズルを生成する。生成に失敗した場合は null を返す
/// (normal/hard は稀に生成失敗するため、テストは失敗分をスキップして続行する)。
GeneratedPuzzle? _tryGenerate(Difficulty difficulty, int seed) {
  final result = NonTrivialPuzzleGenerator.generate(
    difficulty: difficulty,
    seed: seed,
  );
  switch (result) {
    case Ok(:final value):
      return value.puzzle;
    case Err():
      return null;
  }
}

/// [block] が対称ピース(allUniqueOrientations が1種のみ)かどうか。
bool _isSymmetric(PlacedBlock block) =>
    PolyominoTransformer.allUniqueOrientations(block.source).length == 1;

/// [block.orientation] を基準にした回転4種(重複除去)の cells 文字列集合。
Set<String> _easyRotationKeys(PlacedBlock block) {
  final keys = <String>{};
  var current = block.orientation;
  for (var i = 0; i < 4; i++) {
    keys.add(current.cells.toString());
    current = PolyominoTransformer.rotate90(current);
  }
  return keys;
}

void main() {
  group('PieceOrientationState.scrambled', () {
    test('決定論: 同じ puzzle から2回生成すると全ピースの向きが一致する', () {
      for (final difficulty in Difficulty.values) {
        for (final seed in [1, 2, 3, 4, 5]) {
          final puzzle = _tryGenerate(difficulty, seed);
          if (puzzle == null) continue;

          final a = PieceOrientationState.scrambled(puzzle, difficulty);
          final b = PieceOrientationState.scrambled(puzzle, difficulty);

          expect(
            a.length,
            puzzle.blocks.length,
            reason: '$difficulty seed=$seed: ピース数が一致する',
          );
          for (var i = 0; i < a.length; i++) {
            expect(
              a.orientationOf(i),
              b.orientationOf(i),
              reason: '$difficulty seed=$seed piece=$i: 2回の生成が同じ向きになる',
            );
          }
        }
      }
    });

    test('easy 回転限定: 配られた向きが block.orientation の回転セットに含まれる', () {
      var checked = 0;
      for (var seed = 1; seed <= 30; seed++) {
        final puzzle = _tryGenerate(Difficulty.easy, seed);
        if (puzzle == null) continue;

        final state = PieceOrientationState.scrambled(puzzle, Difficulty.easy);
        for (var i = 0; i < puzzle.blocks.length; i++) {
          final block = puzzle.blocks[i];
          final rotationKeys = _easyRotationKeys(block);
          expect(
            rotationKeys.contains(state.orientationOf(i).cells.toString()),
            isTrue,
            reason:
                'easy seed=$seed piece=$i: 配られた向きは block.orientation の'
                '回転セット内に限られ、反転向きは混ざらない',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(0), reason: '少なくとも1件は検証できている');
    });

    test('easy floor: 非対称ピースのうち解の向きと一致するのはちょうど1個', () {
      var checked = 0;
      for (var seed = 1; seed <= 30; seed++) {
        final puzzle = _tryGenerate(Difficulty.easy, seed);
        if (puzzle == null) continue;

        final state = PieceOrientationState.scrambled(puzzle, Difficulty.easy);
        var matches = 0;
        for (var i = 0; i < puzzle.blocks.length; i++) {
          final block = puzzle.blocks[i];
          if (_isSymmetric(block)) continue;
          if (state.orientationOf(i) == block.orientation) matches++;
        }
        expect(
          matches,
          1,
          reason: 'easy seed=$seed: 非対称ピースの解の向き一致数はちょうど floor=1 個',
        );
        checked++;
      }
      expect(checked, greaterThan(0), reason: '少なくとも1件は検証できている');
    });

    test('normal/hard cap: 非対称ピースの一致数が2以下', () {
      var checked = 0;
      for (final difficulty in [Difficulty.normal, Difficulty.hard]) {
        for (var seed = 1; seed <= 30; seed++) {
          final puzzle = _tryGenerate(difficulty, seed);
          if (puzzle == null) continue;

          final state = PieceOrientationState.scrambled(puzzle, difficulty);
          var matches = 0;
          for (var i = 0; i < puzzle.blocks.length; i++) {
            final block = puzzle.blocks[i];
            if (_isSymmetric(block)) continue;
            if (state.orientationOf(i) == block.orientation) matches++;
          }
          expect(
            matches,
            lessThanOrEqualTo(2),
            reason: '$difficulty seed=$seed: 非対称ピースの解の向き一致数は cap=2 以下',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(0), reason: '少なくとも1件は検証できている');
    });
  });
}
