import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator_selector.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';

// ⑥-c(A2方式): generateSelectedPuzzle が multi-set 経路でも
// 「単一 VerifiedPuzzle を返す」既存契約を守ることを検証する。
// play_screen はこの契約にのみ依存しているため、ここが守られていれば画面は不変でよい。

const List<int> _seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

int _cellCmp(Cell a, Cell b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2;

String _sig(VerifiedPuzzle vp) {
  final blocks = vp.puzzle.blocks.map((b) {
    final cs = b.cells.toList()..sort(_cellCmp);
    return '${b.source.id}:${cs.map((c) => '${c.$1},${c.$2}').join(';')}';
  }).toList()..sort();
  return '${vp.solutionCount}#${blocks.join('/')}';
}

void main() {
  group('generateSelectedPuzzle (multi-set A2 経路)', () {
    test('multi-set トグルが有効', () {
      expect(kUseMultiSetGenerator, isTrue);
    });

    for (final d in Difficulty.values) {
      test('${d.name}: Ok が返り、枠を過不足なく敷き、解数1〜3', () {
        var okCount = 0;
        for (final seed in _seeds) {
          final r = generateSelectedPuzzle(difficulty: d, seed: seed);
          if (r is! Ok<VerifiedPuzzle, CompactPuzzleError>) continue;
          okCount++;
          final vp = r.value;
          expect(vp.solutionCount, greaterThanOrEqualTo(1));
          expect(vp.solutionCount, lessThanOrEqualTo(3));
          expect(vp.puzzle.blocks.length, d.blockCount);

          final cells = <Cell>[];
          for (final b in vp.puzzle.blocks) {
            cells.addAll(b.cells);
          }
          expect(cells.length, vp.puzzle.frame.length, reason: '重なり/取りこぼし');
          expect(cells.toSet(), equals(vp.puzzle.frame), reason: '枠を被覆していない');
        }
        expect(okCount, greaterThan(0), reason: '${d.name} で Ok が1つも出ない');
      });

      test('${d.name}: 決定論(同一 seed は同一パズル)', () {
        for (final seed in _seeds) {
          final a = generateSelectedPuzzle(difficulty: d, seed: seed);
          final b = generateSelectedPuzzle(difficulty: d, seed: seed);
          if (a is Ok<VerifiedPuzzle, CompactPuzzleError> &&
              b is Ok<VerifiedPuzzle, CompactPuzzleError>) {
            expect(_sig(a.value), _sig(b.value));
          } else {
            expect(a.runtimeType, b.runtimeType, reason: 'Ok/Err が非決定的');
          }
        }
      });
    }

    test('normal: seed を変えると複数の異なるパズルが出る(単調でない)', () {
      final sigs = <String>{};
      for (final seed in _seeds) {
        final r = generateSelectedPuzzle(
          difficulty: Difficulty.normal,
          seed: seed,
        );
        if (r is Ok<VerifiedPuzzle, CompactPuzzleError>)
          sigs.add(_sig(r.value));
      }
      expect(
        sigs.length,
        greaterThanOrEqualTo(5),
        reason: 'seed を変えてもパズルが十分に散らばらない',
      );
    });
  });
}
