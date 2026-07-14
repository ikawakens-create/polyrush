import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/multi_set_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';

// ADR-0021: MultiSetPuzzleGenerator の性質テスト。
// 既存 public API のみを使い、確定資産は変更しない。通常レーン(slowタグなし)。

const List<int> _seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

int _cellCmp(Cell a, Cell b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2;

// 構成署名(source id multiset)。variant 間の相異なりを判定する。
String _compSig(MultiSetPuzzle m, int i) {
  final ids = m.variants[i].puzzle.blocks.map((b) => b.source.id).toList()
    ..sort();
  return ids.join('+');
}

// 結果全体の決定論署名(枠 + 各 variant の解数 + ブロック配置・順序込み)。
String _resultSig(MultiSetPuzzle m) {
  final vs = m.variants.map((vp) {
    final blocks = vp.puzzle.blocks.map((b) {
      final cs = b.cells.toList()..sort(_cellCmp);
      return '${b.source.id}:${cs.map((c) => '${c.$1},${c.$2}').join(';')}';
    }).toList()..sort();
    return '${vp.solutionCount}#${blocks.join('/')}';
  }).toList();
  return '${m.canonicalKey}||${vs.join('~')}';
}

List<MultiSetPuzzle> _collectOks(Difficulty d, {int maxVariants = 6}) {
  final oks = <MultiSetPuzzle>[];
  for (final seed in _seeds) {
    final r = MultiSetPuzzleGenerator.generate(
      difficulty: d,
      seed: seed,
      maxVariants: maxVariants,
    );
    if (r is Ok<MultiSetPuzzle, CompactPuzzleError>) oks.add(r.value);
  }
  return oks;
}

void main() {
  group('MultiSetPuzzleGenerator.generate', () {
    for (final d in Difficulty.values) {
      test('${d.name}: 少なくとも1つの seed で Ok・variant は1以上', () {
        final oks = _collectOks(d);
        expect(oks, isNotEmpty, reason: '${d.name} で Ok が1つも出ない');
        for (final m in oks) {
          expect(m.variants, isNotEmpty);
        }
      });

      test('${d.name}: 各 variant が枠を過不足なく敷き・採用基準を満たす', () {
        final oks = _collectOks(d);
        for (final m in oks) {
          // canonicalKey は枠と整合。
          expect(m.canonicalKey, FrameGenerator.canonicalKey(m.frame));
          final comps = <String>{};
          for (var i = 0; i < m.variants.length; i++) {
            final vp = m.variants[i];
            // 解数1〜3・isFallback は常に false(ADR-0021)。
            expect(vp.solutionCount, inInclusiveRange(1, 3));
            expect(vp.isFallback, isFalse);
            // 枠の過不足なし被覆(重なりなし)。
            final cells = <Cell>[];
            for (final b in vp.puzzle.blocks) {
              cells.addAll(b.cells);
            }
            expect(
              cells.length,
              m.frame.length,
              reason: '重なり/取りこぼしがある(セル総数不一致)',
            );
            expect(cells.toSet(), equals(m.frame), reason: '枠を被覆していない');
            // 枠と puzzle.frame の一致。
            expect(vp.puzzle.frame, equals(m.frame));
            // 相異なる構成。
            expect(
              comps.add(_compSig(m, i)),
              isTrue,
              reason: 'variant 間でピース構成が重複している',
            );
          }
        }
      });

      test('${d.name}: maxVariants=6 の上限を超えない', () {
        final oks = _collectOks(d);
        for (final m in oks) {
          expect(m.variants.length, lessThanOrEqualTo(6));
        }
      });

      test('${d.name}: 決定論(同一入力で完全一致)', () {
        for (final seed in _seeds) {
          final a = MultiSetPuzzleGenerator.generate(
            difficulty: d,
            seed: seed,
            maxVariants: 6,
          );
          final b = MultiSetPuzzleGenerator.generate(
            difficulty: d,
            seed: seed,
            maxVariants: 6,
          );
          if (a is Ok<MultiSetPuzzle, CompactPuzzleError> &&
              b is Ok<MultiSetPuzzle, CompactPuzzleError>) {
            expect(_resultSig(a.value), _resultSig(b.value));
          } else {
            expect(a.runtimeType, b.runtimeType, reason: 'Ok/Err が非決定的');
          }
        }
      });

      test('${d.name}: maxVariants=1 のとき Ok なら variant はちょうど1', () {
        for (final seed in _seeds) {
          final r = MultiSetPuzzleGenerator.generate(
            difficulty: d,
            seed: seed,
            maxVariants: 1,
          );
          if (r is Ok<MultiSetPuzzle, CompactPuzzleError>) {
            expect(r.value.variants.length, 1);
          }
        }
      });
    }

    test('normal: 実際に複数 variant を返す枠が存在する(⑥ の実効性)', () {
      final oks = _collectOks(Difficulty.normal);
      final maxLen = oks.fold<int>(0, (a, m) => math_max(a, m.variants.length));
      expect(
        maxLen,
        greaterThanOrEqualTo(2),
        reason: 'normal で2つ以上の variant を返す枠が1つも無い',
      );
    });
  });
}

int math_max(int a, int b) => a > b ? a : b;
