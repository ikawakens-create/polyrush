import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/non_trivial_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/play/piece_orientation_state.dart';

void main() {
  group('PieceOrientationState', () {
    late GeneratedPuzzle puzzle;

    setUp(() {
      final result = NonTrivialPuzzleGenerator.generate(
        difficulty: Difficulty.easy,
        seed: 1,
      );
      switch (result) {
        case Ok(:final value):
          puzzle = value.puzzle;
        case Err():
          fail('easy seed 1 の生成に失敗した');
      }
    });

    test('fromPuzzle は各ピースを解の向きで初期化する', () {
      final state = PieceOrientationState.fromPuzzle(puzzle);
      for (var i = 0; i < puzzle.blocks.length; i++) {
        expect(
          state.orientationOf(i).cells,
          puzzle.blocks[i].orientation.cells,
        );
      }
    });

    test('rotateCw を 4 回適用すると元の向きに戻る', () {
      final state = PieceOrientationState.fromPuzzle(puzzle);
      final before = state.orientationOf(0).cells;
      for (var n = 0; n < 4; n++) {
        state.rotateCw(0);
      }
      expect(state.orientationOf(0).cells, before);
    });

    test('flip を 2 回適用すると元の向きに戻る', () {
      final state = PieceOrientationState.fromPuzzle(puzzle);
      final before = state.orientationOf(0).cells;
      state.flip(0);
      state.flip(0);
      expect(state.orientationOf(0).cells, before);
    });

    test('rotateCcw の後に rotateCw を適用すると元の向きに戻る', () {
      final state = PieceOrientationState.fromPuzzle(puzzle);
      final before = state.orientationOf(0).cells;
      state.rotateCcw(0);
      state.rotateCw(0);
      expect(state.orientationOf(0).cells, before);
    });

    test('rotateCw → rotateCcw → flip の結果は flip 単独の結果と一致する'
        '（待ちなし方式ダブルタップの実効セマンティクスが「反転のみ」になること）', () {
      final withRotation = PieceOrientationState.fromPuzzle(puzzle);
      withRotation.rotateCw(0);
      withRotation.rotateCcw(0);
      withRotation.flip(0);

      final flipOnly = PieceOrientationState.fromPuzzle(puzzle);
      flipOnly.flip(0);

      expect(
        withRotation.orientationOf(0).cells,
        flipOnly.orientationOf(0).cells,
      );
    });
  });
}
