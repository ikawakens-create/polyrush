import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/frame_generator.dart';
import 'package:polyrush/domain/puzzle/frame_tiler.dart';
import 'package:polyrush/domain/puzzle/piece_set_enumerator.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/solver.dart';

String _serialize(List<PlacedBlock> t) {
  final parts = t.map((b) {
    final cs = b.cells.toList()
      ..sort((a, c) => a.$1 != c.$1 ? a.$1 - c.$1 : a.$2 - c.$2);
    return '${b.source.id}:${cs.map((c) => '${c.$1},${c.$2}').join('/')}';
  }).toList()..sort();
  return parts.join('|');
}

void main() {
  // ADR-0020 判断2 条件(b): countSolutions>=1 のセットに対し firstTiling が必ず1解を返し、
  // その解が枠を過不足なく被覆すること。solver と新モジュールの探索が食い違えばここで検出。
  // 条件(a): 決定論(同じ枠+セットで常に同一 tiling)。
  group('FrameTiler 整合性・決定論(判断2)', () {
    const framesPerDifficulty = {
      Difficulty.easy: 3,
      Difficulty.normal: 2,
      Difficulty.hard: 1,
    };

    for (final d in Difficulty.values) {
      test('${d.name}: count>=1 ⇔ firstTiling成功 / 被覆過不足なし / 決定論', () {
        var checked = 0;
        var tileableChecked = 0;
        for (var i = 0; i < framesPerDifficulty[d]!; i++) {
          final frame = FrameGenerator.generate(d, 5000 * (d.index + 1) + i);
          if (frame == null) continue;
          final sets = enumerateDistinctPieceSets(
            d.pool,
            d.blockCount,
            frame.length,
          );
          for (final set in sets) {
            final count = PuzzleSolver.countSolutions(
              frame: frame,
              shapes: set,
              limit: 4,
            );
            final tiling = FrameTiler.firstTiling(frame, set);
            checked++;

            // 整合性: count>=1 ⇔ tiling!=null
            expect(
              tiling != null,
              count >= 1,
              reason: '${d.name}: count=$count と firstTiling の有無が一致すること',
            );

            if (tiling != null) {
              tileableChecked++;
              // 被覆: 全ブロックのセル和 == 枠、重複なし
              final covered = <Cell>{};
              for (final b in tiling) {
                covered.addAll(b.cells);
                expect(
                  b.cells.length,
                  b.source.size,
                  reason: '${d.name}: 各ブロックのセル数が source.size と一致',
                );
              }
              expect(
                covered.length,
                frame.length,
                reason: '${d.name}: 被覆セル総数が枠と一致(重複なし)',
              );
              expect(
                covered,
                equals(frame),
                reason: '${d.name}: 被覆集合が枠と一致(過不足なし)',
              );
              // 使用ピースがセットと一致(重複なし・全異種)
              final usedIds = tiling.map((b) => b.source.id).toList()..sort();
              final setIds = set.map((p) => p.id).toList()..sort();
              expect(
                usedIds,
                equals(setIds),
                reason: '${d.name}: 使用ピースが採用セットと一致',
              );

              // 決定論: 2回目も同一
              final tiling2 = FrameTiler.firstTiling(frame, set);
              expect(
                _serialize(tiling2!),
                _serialize(tiling),
                reason: '${d.name}: 同一入力で同一 tiling(決定論)',
              );
            }
          }
        }
        expect(checked, greaterThan(0), reason: '${d.name}: セットを1つ以上検査できること');
        expect(
          tileableChecked,
          greaterThan(0),
          reason: '${d.name}: 敷き詰め可能セットを1つ以上検査できること',
        );
      });
    }
  });
}
