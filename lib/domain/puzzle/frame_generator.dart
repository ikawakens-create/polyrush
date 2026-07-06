import 'dart:math' as math;

import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';

/// 枠ファースト生成器(ADR-0020)の枠生成部。
///
/// 「良い枠を先に作る」段の実装。難易度制約(セル数)＋充填率＋アスペクト比≤1.6 を満たす
/// ずんぐり型の単連結・穴なし枠を決定論的に生成する。ADR-0020 判断3/4/6。
///
/// - 充填率下限は easy のみ 0.75、normal/hard は 0.85(判断6・併用方針)。
/// - [canonicalKey] は8二面体変換の最小正規化キー(判断4・重複排除／将来のデイリー枠ID)。
///
/// 参考実装は PR #96 のテスト内ヘルパー(_carveFrame ほか)。本モジュールで lib へ正式化した。
class FrameGenerator {
  FrameGenerator._();

  static const double kFillMax = 0.95;
  static const double kAspectMax = 1.6;
  static const int kMaxBoxSide = 6;

  /// 充填率下限(ADR-0020 判断6)。easy のみ 0.75、他は 0.85。
  static double fillLowerBound(Difficulty d) =>
      d == Difficulty.easy ? 0.75 : 0.85;

  static const List<Cell> _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  /// 難易度制約・充填率帯・アスペクト比を同時に満たす (h, w, n) の三つ組を列挙する。
  /// 空なら「制約を満たす枠が存在しない」ことを意味する。
  static List<(int h, int w, int n)> validBoxNs(Difficulty d) {
    final lo = fillLowerBound(d);
    final res = <(int, int, int)>[];
    for (var h = 2; h <= kMaxBoxSide; h++) {
      for (var w = h; w <= kMaxBoxSide; w++) {
        if (w / h > kAspectMax + 1e-9) continue;
        final area = h * w;
        final loN = (lo * area).ceil();
        final hiN = (kFillMax * area).floor();
        final from = math.max(loN, d.minTotalCells);
        final to = math.min(hiN, d.maxTotalCells);
        for (var n = from; n <= to; n++) {
          res.add((h, w, n));
        }
      }
    }
    return res;
  }

  /// 難易度 d の制約を満たす枠を1つ生成(seed から決定論的)。生成不能なら null。
  static Set<Cell>? generate(Difficulty d, int seed) {
    final boxes = validBoxNs(d);
    if (boxes.isEmpty) return null;
    final rng = math.Random(seed);
    for (var attempt = 0; attempt < 40; attempt++) {
      final box = boxes[rng.nextInt(boxes.length)];
      final f = _carveFrame(box.$1, box.$2, box.$3, rng);
      if (f != null) return f;
    }
    return null;
  }

  /// 8二面体変換(回転4×反転2)の最小正規化キー(判断4)。
  /// 回転・反転で一致する枠は同一キーになる。
  static String canonicalKey(Set<Cell> frame) {
    var best = '';
    var cur = frame.toList();
    for (var refl = 0; refl < 2; refl++) {
      cur = refl == 0
          ? frame.toList()
          : frame.map((c) => (c.$1, -c.$2)).toList();
      for (var rot = 0; rot < 4; rot++) {
        cur = cur.map((c) => (c.$2, -c.$1)).toList(); // 90度回転
        final key = _cellsKey(cur);
        if (best.isEmpty || key.compareTo(best) < 0) best = key;
      }
    }
    return best;
  }

  // --- 内部ヘルパー(参考実装 PR #96 と同一ロジック) ---

  static Set<Cell>? _carveFrame(int h, int w, int n, math.Random rng) {
    final cells = <Cell>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        cells.add((y, x));
      }
    }
    var toRemove = h * w - n;
    var guard = 0;
    while (toRemove > 0) {
      if (++guard > 500) return null;
      final candidates = <Cell>[];
      for (final c in cells.toList()) {
        cells.remove(c);
        final ok =
            _isConnected(cells) &&
            !_hasHole(cells, h, w) &&
            _touchesAllEdges(cells, h, w);
        cells.add(c);
        if (ok) candidates.add(c);
      }
      if (candidates.isEmpty) return null;
      var minNb = _neighborsIn(candidates.first, cells);
      for (final c in candidates) {
        final k = _neighborsIn(c, cells);
        if (k < minNb) minNb = k;
      }
      final best = candidates
          .where((c) => _neighborsIn(c, cells) == minNb)
          .toList();
      final chosen = best[rng.nextInt(best.length)];
      cells.remove(chosen);
      toRemove--;
    }
    return cells;
  }

  static bool _isConnected(Set<Cell> cells) {
    if (cells.isEmpty) return false;
    final start = cells.first;
    final seen = <Cell>{start};
    final stack = <Cell>[start];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      for (final d in _dirs) {
        final nb = (c.$1 + d.$1, c.$2 + d.$2);
        if (cells.contains(nb) && seen.add(nb)) stack.add(nb);
      }
    }
    return seen.length == cells.length;
  }

  static bool _hasHole(Set<Cell> cells, int h, int w) {
    final bg = <Cell>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = (y, x);
        if (!cells.contains(c)) bg.add(c);
      }
    }
    if (bg.isEmpty) return false;
    final seen = <Cell>{};
    final stack = <Cell>[];
    for (final c in bg) {
      if (c.$1 == 0 || c.$1 == h - 1 || c.$2 == 0 || c.$2 == w - 1) {
        if (seen.add(c)) stack.add(c);
      }
    }
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      for (final d in _dirs) {
        final nb = (c.$1 + d.$1, c.$2 + d.$2);
        if (bg.contains(nb) && seen.add(nb)) stack.add(nb);
      }
    }
    return seen.length != bg.length;
  }

  static bool _touchesAllEdges(Set<Cell> cells, int h, int w) {
    var t = false, b = false, l = false, r = false;
    for (final c in cells) {
      if (c.$1 == 0) t = true;
      if (c.$1 == h - 1) b = true;
      if (c.$2 == 0) l = true;
      if (c.$2 == w - 1) r = true;
    }
    return t && b && l && r;
  }

  static int _neighborsIn(Cell c, Set<Cell> s) {
    var n = 0;
    for (final d in _dirs) {
      if (s.contains((c.$1 + d.$1, c.$2 + d.$2))) n++;
    }
    return n;
  }

  static String _cellsKey(List<Cell> cells) {
    var minY = cells.first.$1, minX = cells.first.$2;
    for (final c in cells) {
      if (c.$1 < minY) minY = c.$1;
      if (c.$2 < minX) minX = c.$2;
    }
    final norm = cells.map((c) => (c.$1 - minY, c.$2 - minX)).toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return norm.map((c) => '${c.$1},${c.$2}').join(';');
  }
}
