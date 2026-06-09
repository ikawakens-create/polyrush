/// ポリオミノの回転・反転ユーティリティ。
///
/// すべてのメソッドは **新しい [PolyominoData] を返す**（元のインスタンスは変更しない）。
/// 戻り値は必ず **正規化済み**（左上が `(0,0)`、セルは `(y昇順, x昇順)` でソート済み）。
/// 座標は `(y, x) = (row, col)` の順。詳細は `docs/adr/0006-polyomino-coordinate-order.md` を参照。
library;

import 'package:polyrush/domain/puzzle/polyomino.dart';

/// ポリオミノの回転・反転・正規化を行う静的ユーティリティクラス。
///
/// インスタンス化禁止。すべての操作は静的メソッドとして提供する。
class PolyominoTransformer {
  PolyominoTransformer._();

  /// バウンディングボックスの左上を `(0,0)` に揃え、
  /// セルを `(y昇順, x昇順)` でソートする。
  static PolyominoData normalize(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    final minY = p.cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final minX = p.cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final shifted = p.cells.map((c) => (c.$1 - minY, c.$2 - minX)).toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    return PolyominoData(id: p.id, size: p.size, cells: shifted);
  }

  /// 90度時計回りに回転する（結果は正規化済み）。
  ///
  /// 変換式: `(y, x) → (x, H−1−y)` ただし H はバウンディングボックスの高さ。
  static PolyominoData rotate90(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    final h = p.cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b) + 1;
    final transformed = p.cells.map((c) => (c.$2, h - 1 - c.$1)).toList();
    return normalize(PolyominoData(id: p.id, size: p.size, cells: transformed));
  }

  /// 180度回転する（結果は正規化済み）。
  ///
  /// `rotate90` を2回適用することで導出する。
  static PolyominoData rotate180(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    return rotate90(rotate90(p));
  }

  /// 90度反時計回り（270度時計回り）に回転する（結果は正規化済み）。
  ///
  /// `rotate90` を3回適用することで導出する。
  static PolyominoData rotate270(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    return rotate90(rotate90(rotate90(p)));
  }

  /// 左右反転する（垂直軸を基準に鏡映、結果は正規化済み）。
  ///
  /// 変換式: `(y, x) → (y, W−1−x)` ただし W はバウンディングボックスの幅。
  static PolyominoData flipHorizontal(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    final w = p.cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b) + 1;
    final transformed = p.cells.map((c) => (c.$1, w - 1 - c.$2)).toList();
    return normalize(PolyominoData(id: p.id, size: p.size, cells: transformed));
  }

  /// 上下反転する（水平軸を基準に鏡映、結果は正規化済み）。
  ///
  /// 変換式: `(y, x) → (H−1−y, x)` ただし H はバウンディングボックスの高さ。
  static PolyominoData flipVertical(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    final h = p.cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b) + 1;
    final transformed = p.cells.map((c) => (h - 1 - c.$1, c.$2)).toList();
    return normalize(PolyominoData(id: p.id, size: p.size, cells: transformed));
  }

  /// 2つのポリオミノが回転・反転で一致するか判定する（Free Polyomino 同値）。
  ///
  /// `a` の全ユニーク向きのいずれかが `b` の正規化済み形状と一致すれば `true`。
  static bool areEquivalent(PolyominoData a, PolyominoData b) {
    assert(a.cells.isNotEmpty, 'Polyomino must have at least one cell');
    assert(b.cells.isNotEmpty, 'Polyomino must have at least one cell');
    final bKey = _cellsKey(normalize(b).cells);
    return allUniqueOrientations(a).any((q) => _cellsKey(q.cells) == bKey);
  }

  /// 回転4種 × 反転2種 = 最大8種のうち、重複を除いたユニークな向きを返す。
  ///
  /// 重複判定は正規化済み cells の文字列キーで行う。
  /// 返却される各要素は正規化済み（`minY == 0` かつ `minX == 0`）。
  static Set<PolyominoData> allUniqueOrientations(PolyominoData p) {
    assert(p.cells.isNotEmpty, 'Polyomino must have at least one cell');
    final seen = <String>{};
    final result = <PolyominoData>[];

    void add(PolyominoData q) {
      final key = _cellsKey(q.cells);
      if (seen.add(key)) {
        result.add(q);
      }
    }

    var current = normalize(p);
    for (var i = 0; i < 4; i++) {
      add(current);
      add(flipHorizontal(current));
      current = rotate90(current);
    }

    return result.toSet();
  }

  /// 正規化済み cells リストを文字列キーに変換するヘルパー。
  ///
  /// normalize 後の cells は (y昇順, x昇順) でソート済みのため、
  /// `toString()` で一意のキーが得られる。
  static String _cellsKey(List<Cell> cells) => cells.toString();
}
