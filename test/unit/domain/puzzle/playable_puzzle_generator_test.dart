// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/playable_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

void main() {
  // ─── 1. 保証: PlayablePuzzleGenerator が常に単連結な枠を返す ──────────────
  group('保証: 単連結枠のみ返す', () {
    for (final difficulty in Difficulty.values) {
      group(difficulty.name, () {
        test('seed 1..50 で全件 Ok かつ単連結', () {
          for (var seed = 1; seed <= 50; seed++) {
            final result = PlayablePuzzleGenerator.generate(
              difficulty: difficulty,
              seed: seed,
            );
            expect(
              result,
              isA<Ok<VerifiedPuzzle, PlayablePuzzleError>>(),
              reason:
                  '${difficulty.name}/seed=$seed: Err が返ってはいけない '
                  '（リトライ予算 $maxFrameRetries 回で穴なし枠を見つけられるはず）',
            );
            final vp =
                (result as Ok<VerifiedPuzzle, PlayablePuzzleError>).value;
            expect(
              isFrameSimplyConnected(vp.puzzle.frame),
              isTrue,
              reason: '${difficulty.name}/seed=$seed: 返された枠が単連結であること',
            );
          }
        });

        test('seed 1..1000 で全件 Ok かつ単連結（リトライ予算の充足証明）', () {
          var errCount = 0;
          var holeCount = 0;
          for (var seed = 1; seed <= 1000; seed++) {
            final result = PlayablePuzzleGenerator.generate(
              difficulty: difficulty,
              seed: seed,
            );
            switch (result) {
              case Ok(:final value):
                if (!isFrameSimplyConnected(value.puzzle.frame)) holeCount++;
              case Err():
                errCount++;
            }
          }
          print(
            '[PlayablePuzzleGenerator 保証] ${difficulty.name}: '
            'seeds 1..1000, err=$errCount, hole=$holeCount',
          );
          expect(
            errCount,
            0,
            reason:
                '${difficulty.name}: seed 1..1000 で Err は 0 件のはず。'
                'Err が出た場合はリトライ予算 $maxFrameRetries 回が不足している。',
          );
          expect(
            holeCount,
            0,
            reason: '${difficulty.name}: 単連結でない枠がゲームに届いてはいけない。',
          );
        }, tags: ['slow']);
      });
    }
  });

  // ─── 2. 必要性の証拠: 新層なしでは穴あき枠がゲームに届く ──────────────────
  group('必要性の証拠: VerifiedPuzzleGenerator 単体では穴あき枠が存在する', () {
    for (final difficulty in Difficulty.values) {
      test(
        '${difficulty.name}: seed 1..300 中に isFrameSimplyConnected==false が 1 件以上',
        () {
          var holeCount = 0;
          for (var seed = 1; seed <= 300; seed++) {
            final result = VerifiedPuzzleGenerator.generate(
              difficulty: difficulty,
              seed: seed,
            );
            switch (result) {
              case Ok(:final value):
                if (!isFrameSimplyConnected(value.puzzle.frame)) holeCount++;
              case Err():
                break;
            }
          }
          print(
            '[必要性] ${difficulty.name}: '
            'seed 1..300 中 穴あき枠 $holeCount 件',
          );
          expect(
            holeCount,
            greaterThan(0),
            reason:
                '${difficulty.name}: seed 1..300 の範囲で穴あき枠が 1 件も見つからなかった。'
                '「新層が不要」である可能性がある — 井川に報告。',
          );
        },
        tags: ['slow'],
      );
    }
  });
}
