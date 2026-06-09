/// パズル解数カウンター。
///
/// ## 座標系
/// `(y, x) = (row, col)`（ADR-0006 準拠）。
/// 詳細は `docs/adr/0006-polyomino-coordinate-order.md` を参照。
///
/// ## アルゴリズム
/// バックトラッキングによる全解探索（仕様書 § 4.3.3 準拠）。
/// 「一番左上のマス」を起点に各形状の全向きを試し、再帰的に配置を確定する。
/// 同一形状が複数あるマルチセットの場合、種類ごとに1回ずつ試すことで
/// 水増し（同じ配置を別順で数えること）を防ぐ。
library;

import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/polyomino_transformer.dart';

/// バックトラッキングで枠への敷き詰め解数を数える静的ユーティリティクラス。
///
/// インスタンス化禁止。公開 API は [countSolutions] のみ。
class PuzzleSolver {
  PuzzleSolver._();

  /// [frame] に [shapes] を敷き詰める解の数を最大 [limit] 件数える。
  ///
  /// - [frame]: 埋めるべき空きマスの集合。
  /// - [shapes]: 使用するブロック形状のリスト（同じ形が複数あってもよい）。
  /// - [limit]: 探索を打ち切る上限（`limit` 以上の解があれば `limit` を返す）。
  /// - 戻り値: 発見した解の数（`0` 以上 `limit` 以下）。
  static int countSolutions({
    required Set<Cell> frame,
    required List<PolyominoData> shapes,
    int limit = 4,
  }) {
    assert(limit >= 1, 'limit must be >= 1');

    final totalCells = shapes.fold<int>(0, (sum, s) => sum + s.size);
    if (totalCells != frame.length) return 0;

    // 形状ごとの使用可能個数をマップで管理する。
    final remaining = <PolyominoData, int>{};
    for (final s in shapes) {
      remaining[s] = (remaining[s] ?? 0) + 1;
    }

    // 各形状の全向きをキャッシュ（同じ形状で何度も計算しないため）。
    final orientationCache = <PolyominoData, List<List<Cell>>>{};
    List<List<Cell>> orientationsOf(PolyominoData shape) {
      return orientationCache.putIfAbsent(
        shape,
        () => PolyominoTransformer.allUniqueOrientations(
          shape,
        ).map((o) => o.cells).toList(),
      );
    }

    final empty = Set<Cell>.from(frame);
    var count = 0;

    void backtrack(Set<Cell> empty, Map<PolyominoData, int> remaining) {
      if (count >= limit) return;

      if (empty.isEmpty) {
        count++;
        return;
      }

      // 一番左上のマス: y（行）が小さい順、同じなら x（列）が小さい順。
      Cell pivot = empty.first;
      for (final c in empty) {
        if (c.$1 < pivot.$1 || (c.$1 == pivot.$1 && c.$2 < pivot.$2)) {
          pivot = c;
        }
      }

      // 種類ごとに1回ずつ試す（水増し防止）。
      for (final entry in remaining.entries) {
        if (count >= limit) break;
        if (entry.value <= 0) continue;

        final shape = entry.key;
        for (final orientCells in orientationsOf(shape)) {
          if (count >= limit) break;

          // orientCells の最小セル（ (y,x) 辞書順最小）を求める。
          Cell minCell = orientCells.first;
          for (final c in orientCells) {
            if (c.$1 < minCell.$1 ||
                (c.$1 == minCell.$1 && c.$2 < minCell.$2)) {
              minCell = c;
            }
          }

          // offset = pivot - minCell。minCell が pivot を覆うように平行移動。
          final dy = pivot.$1 - minCell.$1;
          final dx = pivot.$2 - minCell.$2;
          final placed = orientCells
              .map((c) => (c.$1 + dy, c.$2 + dx))
              .toList();

          // 全セルが空きマスに含まれる場合のみ配置可能。
          if (!placed.every(empty.contains)) continue;

          // 配置して再帰、戻ったら元に戻す（バックトラッキング）。
          for (final c in placed) {
            empty.remove(c);
          }
          remaining[shape] = entry.value - 1;

          backtrack(empty, remaining);

          for (final c in placed) {
            empty.add(c);
          }
          remaining[shape] = entry.value;
        }
      }
    }

    backtrack(empty, remaining);
    return count;
  }
}
