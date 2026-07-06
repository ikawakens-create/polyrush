import 'package:polyrush/domain/puzzle/polyomino.dart';

/// 枠ファースト生成器(ADR-0020 判断5)のピースセット列挙部。
///
/// pool から**重複なし(全ピース異種)**で [blockCount] 個を選び、セル数合計が
/// [targetCells] に一致する組み合わせをすべて返す。V3 の usedSourceIds と同じ重複禁止ルール
/// (実物ウボンゴも1タスク内は全異種)。PuzzleSolver.countSolutions はセル数不一致だと0を
/// 即返すため、合計一致に絞ることで無駄呼び出しを避ける。サイズ昇順＋上下界枝刈りで高速。
List<List<PolyominoData>> enumerateDistinctPieceSets(
  List<PolyominoData> pool,
  int blockCount,
  int targetCells,
) {
  final sorted = List<PolyominoData>.of(pool)
    ..sort((a, b) => a.size.compareTo(b.size));
  if (sorted.isEmpty) return const [];
  final minSize = sorted.first.size;
  final maxSize = sorted.last.size;
  final results = <List<PolyominoData>>[];
  final chosen = <PolyominoData>[];

  void rec(int start, int count, int cells) {
    if (count == 0) {
      if (cells == 0) results.add(List<PolyominoData>.of(chosen));
      return;
    }
    if (cells < minSize * count || cells > maxSize * count) return;
    for (var i = start; i < sorted.length; i++) {
      final s = sorted[i].size;
      if (s > cells) break; // 昇順なので以降はさらに大きく不適
      chosen.add(sorted[i]);
      rec(i + 1, count - 1, cells - s); // i+1 = 重複なし(同一ピース再利用禁止)
      chosen.removeLast();
    }
  }

  rec(0, blockCount, targetCells);
  return results;
}
