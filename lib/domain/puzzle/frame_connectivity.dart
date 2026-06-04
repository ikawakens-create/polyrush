/// 枠の単連結性判定（ADR-0009 判断2・3）。
///
/// 参照: docs/adr/0009-simply-connected-frame.md
library;

import 'package:polyrush/domain/puzzle/polyomino.dart';

/// 枠が単連結かどうかを判定する（ADR-0009 判断2・3）。
///
/// 単連結 = (a) 枠の全セルが 4-連結で繋がっている、かつ
/// (b) 内部に外へ通じない空きマス（穴）が無い、の両方を満たす。
///
/// - [frame] が空なら false を返す。
/// - (a) 任意の 1 セルから 4-近傍 BFS し、到達数 = 全セル数なら連結。
/// - (b) 枠の外接矩形を上下左右 1 マスずつ広げた領域の角（必ず空き）から
///   空きマスを 4-連結で Flood Fill する。外接矩形内に到達できなかった
///   空きマスが 1 つでもあれば「囲まれた穴」として false を返す。
///
/// 空きマスの塗りつぶしは 4-連結で行う（ADR-0009 判断3）。
/// ブロックは辺隣接でしか配置されないため対角の隙間からピースは通れない。
/// 8-連結に変更してはならない。
bool isFrameSimplyConnected(Set<Cell> frame) {
  if (frame.isEmpty) return false;
  var minY = frame.first.$1, maxY = frame.first.$1;
  var minX = frame.first.$2, maxX = frame.first.$2;
  for (final c in frame) {
    if (c.$1 < minY) minY = c.$1;
    if (c.$1 > maxY) maxY = c.$1;
    if (c.$2 < minX) minX = c.$2;
    if (c.$2 > maxX) maxX = c.$2;
  }
  // (a) 連結性
  final seen = <Cell>{frame.first};
  final stack = <Cell>[frame.first];
  while (stack.isNotEmpty) {
    final (y, x) = stack.removeLast();
    for (final n in [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]) {
      if (frame.contains(n) && seen.add(n)) stack.add(n);
    }
  }
  if (seen.length != frame.length) return false;
  // (b) 穴検査（外周から Flood Fill）
  final loY = minY - 1, hiY = maxY + 1, loX = minX - 1, hiX = maxX + 1;
  final outside = <Cell>{(loY, loX)};
  final q = <Cell>[(loY, loX)];
  while (q.isNotEmpty) {
    final (y, x) = q.removeLast();
    for (final n in [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]) {
      final (ny, nx) = n;
      if (ny < loY || ny > hiY || nx < loX || nx > hiX) continue;
      if (frame.contains(n)) continue;
      if (outside.add(n)) q.add(n);
    }
  }
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final c = (y, x);
      if (!frame.contains(c) && !outside.contains(c)) return false;
    }
  }
  return true;
}
