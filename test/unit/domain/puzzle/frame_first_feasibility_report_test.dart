import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/solver.dart';

// ===========================================================================
// ADR-0020(枠ファースト生成器)の実現可能性を判断するための計測専用テスト。
//
// 目的(HANDOFF_ROADMAP_solo_v1 §2-2 / ロードマップ ④):
//   「良い枠を先に生成 → その枠を敷き詰め可能なピースセットをソルバで列挙 →
//    採点して採用」という枠ファースト方式が実用的な計算量で回るかを、
//    実装前に CI で計測する(測ってから組み込む原則)。
//
// Fable が Go/NoGo を判断するために、以下 3 つの数字をレポートに出す:
//   [1] ランダム枠あたり、既存ピースプールから見つかる敷き詰め可能セットの平均個数
//   [2] 1 枠あたりの探索所要時間(ms)の min / mean / max
//   [3] 見つかったセットのうち解数 1〜3(既存の採用基準)に収まる割合
//
// 設計上の重要事項:
//   - 挙動不変・計測のみ。確定資産(solver.dart / verified_puzzle_generator.dart
//     ほか CLAUDE.md 変更禁止リスト)には一切触れない。
//   - solver の公開 API は countSolutions のみ。よって「各候補セットが枠を
//     敷き詰められるか」を知るには candidateSet × countSolutions の総当たりに
//     なる。この総当たりが破綻しないかを測ること自体が本テストの主眼。
//     limit=4 の 1 回の呼び出しで 0=不可 / 1〜3=採用基準内 / 4=可だが基準外(頭打ち)
//     を同時に判別できる。
//   - 枠のランダム生成ロジックはテスト内ヘルパーとして実装する。lib/ 配下には
//     置かない(⑤で正式実装する際の参考実装という位置づけ)。
//   - 探索空間が大きいため「小規模パイロット」として設計する。枠数は控えめ、
//     1 枠あたりに時間予算(kFrameBudgetMs)を設け、超過したら打ち切って
//     「打ち切り」として報告する。打ち切りが多発すること自体が
//     「総当たりでは重い」という Go/NoGo の判断材料になる。
// ===========================================================================

// --- パイロットの規模(すべて名前付き定数。増減はここだけ触る)---
const int kFramesEasy = 10;
const int kFramesNormal = 5;
const int kFramesHard = 3;

/// 1 枠あたりの探索時間予算。超えたら残り候補を打ち切る(CI を絶対に固めない)。
const int kFrameBudgetMs = 12000;

/// countSolutions の limit。0/1〜3/4(頭打ち) を 1 回で判別するため 4。
const int kSolverLimit = 4;

/// 充填率の許容帯(枠生成の制約)。
const double kFillMin = 0.85;
const double kFillMax = 0.95;

/// アスペクト比の上限(枠生成の制約)。
const double kAspectMax = 1.6;

/// 外接矩形の各辺の探索上限(5×6 まで見れば全難易度の帯を覆える)。
const int kMaxBoxSide = 6;

const List<Cell> _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

int _frameCountFor(Difficulty d) => switch (d) {
  Difficulty.easy => kFramesEasy,
  Difficulty.normal => kFramesNormal,
  Difficulty.hard => kFramesHard,
};

// --- 枠形状の検査ヘルパー(いずれも純関数)---

/// cells が (y,x) 4 近傍で単一連結か。
bool _isConnected(Set<Cell> cells) {
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

/// h×w の外接矩形内で、cells に囲まれた空セル(穴)が存在するか。
/// 矩形の縁にある背景セルから塗り広げ、到達できない背景セルがあれば穴。
bool _hasHole(Set<Cell> cells, int h, int w) {
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

/// cells が h×w 外接矩形の 4 辺すべてに接するか(接していないと実 bbox が縮み、
/// 充填率・アスペクト比の前提が崩れる)。
bool _touchesAllEdges(Set<Cell> cells, int h, int w) {
  var top = false, bottom = false, left = false, right = false;
  for (final c in cells) {
    if (c.$1 == 0) top = true;
    if (c.$1 == h - 1) bottom = true;
    if (c.$2 == 0) left = true;
    if (c.$2 == w - 1) right = true;
  }
  return top && bottom && left && right;
}

int _neighborsIn(Cell c, Set<Cell> s) {
  var n = 0;
  for (final d in _dirs) {
    if (s.contains((c.$1 + d.$1, c.$2 + d.$2))) n++;
  }
  return n;
}

/// 枠の正準文字列(重複形状の判定用)。
String _canon(Set<Cell> f) {
  final l = f.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return l.map((c) => '${c.$1},${c.$2}').join(';');
}

/// 難易度制約(セル数帯)を満たし、かつ充填率∈[0.85,0.95]・アスペクト≤1.6 を
/// 満たしうる (h, w, n) の三つ組をすべて列挙する。
/// ここが空なら「その難易度では制約を満たす枠が存在しない」= 重要な知見。
List<(int h, int w, int n)> _validBoxNs(Difficulty d) {
  final res = <(int, int, int)>[];
  for (var h = 2; h <= kMaxBoxSide; h++) {
    for (var w = h; w <= kMaxBoxSide; w++) {
      if (w / h > kAspectMax + 1e-9) continue; // w >= h なのでこれで十分
      final area = h * w;
      final loN = (kFillMin * area).ceil();
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

/// h×w の充満矩形から (h*w - n) セルを縁から彫り、ずんぐり型の枠を作る。
/// 各除去は「単一連結を保つ・穴を作らない・4 辺への接触を保つ」を満たすものだけ。
/// 隣接数の少ない(角・突起)セルを優先して彫り、きれいな凹みを作る。
/// 失敗時は null(呼び出し側が別シードで再試行)。
Set<Cell>? _carveFrame(int h, int w, int n, math.Random rng) {
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

/// 難易度 d の制約を満たす枠を 1 つ生成する(seed から決定論的)。
Set<Cell>? _generateFrame(Difficulty d, List<(int, int, int)> boxes, int seed) {
  final rng = math.Random(seed);
  for (var attempt = 0; attempt < 40; attempt++) {
    final box = boxes[rng.nextInt(boxes.length)];
    final f = _carveFrame(box.$1, box.$2, box.$3, rng);
    if (f != null) return f;
  }
  return null;
}

/// pool から重複ありで blockCount 個を選び、セル数合計が targetCells に一致する
/// 組み合わせ(マルチセット)をすべて列挙する。
/// countSolutions はセル数不一致だと 0 を即返すため、ここで合計一致に絞ることで
/// 無駄な呼び出しを避ける。サイズ昇順ソート + 上下界枝刈りで列挙自体は高速。
List<List<PolyominoData>> _enumerateSets(
  List<PolyominoData> pool,
  int blockCount,
  int targetCells,
) {
  final sorted = List<PolyominoData>.of(pool)
    ..sort((a, b) => a.size.compareTo(b.size));
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
      if (s > cells) break; // 昇順なので以降はさらに大きく、全て不適
      chosen.add(sorted[i]);
      rec(i, count - 1, cells - s);
      chosen.removeLast();
    }
  }

  rec(0, blockCount, targetCells);
  return results;
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
double _minL(List<double> xs) => xs.isEmpty ? 0 : xs.reduce(math.min);
double _maxL(List<double> xs) => xs.isEmpty ? 0 : xs.reduce(math.max);

void main() {
  for (final d in Difficulty.values) {
    group(d.name, () {
      test('枠ファースト実現可能性 計測パイロット', () {
        final boxes = _validBoxNs(d);
        expect(
          boxes,
          isNotEmpty,
          reason:
              '${d.name}: 充填率∈[$kFillMin,$kFillMax]・アスペクト≤$kAspectMax・'
              'セル数∈[${d.minTotalCells},${d.maxTotalCells}] を満たす枠が'
              '存在すること',
        );

        final pool = d.pool;
        final frameCount = _frameCountFor(d);

        final tileablePerFrame = <int>[];
        final frameMs = <double>[];
        final candidateCounts = <int>[];
        final distinctN = <int>{};
        final distinctShapes = <String>{};
        var totalTileable = 0;
        var totalWithin13 = 0;
        var framesGenerated = 0;
        var framesTruncated = 0;
        var invariantChecked = false;

        for (var i = 0; i < frameCount; i++) {
          final seed = 1000 * (d.index + 1) + i;
          final frame = _generateFrame(d, boxes, seed);
          if (frame == null) continue;
          framesGenerated++;

          final n = frame.length;
          distinctN.add(n);
          distinctShapes.add(_canon(frame));

          final sets = _enumerateSets(pool, d.blockCount, n);
          candidateCounts.add(sets.length);

          // 列挙の不変条件を 1 度だけ軽く検査(全セットのセル数合計 == n)。
          if (!invariantChecked && sets.isNotEmpty) {
            invariantChecked = true;
            final ok = sets.every(
              (s) => s.fold<int>(0, (a, p) => a + p.size) == n,
            );
            expect(ok, isTrue, reason: '${d.name}: 候補セットのセル数合計は常に枠セル数 n に一致');
          }

          final sw = Stopwatch()..start();
          var tileable = 0;
          var within13 = 0;
          var evaluated = 0;
          var truncated = false;
          for (final set in sets) {
            if (sw.elapsedMilliseconds > kFrameBudgetMs) {
              truncated = true;
              break;
            }
            final c = PuzzleSolver.countSolutions(
              frame: frame,
              shapes: set,
              limit: kSolverLimit,
            );
            evaluated++;
            if (c >= 1) tileable++;
            if (c >= 1 && c <= 3) within13++;
          }
          sw.stop();

          if (truncated) {
            framesTruncated++;
            print(
              '  [${d.name}] frame#$i N=$n 候補=${sets.length} '
              '評価$evaluated件で予算(${kFrameBudgetMs}ms)超過→打ち切り',
            );
            continue; // 打ち切り枠は平均から除外(別途カウント)
          }

          tileablePerFrame.add(tileable);
          frameMs.add(sw.elapsedMicroseconds / 1000.0);
          totalTileable += tileable;
          totalWithin13 += within13;
        }

        // ---- レポート出力 ----
        final within13Frac = totalTileable == 0
            ? 0.0
            : totalWithin13 / totalTileable * 100;
        final b = StringBuffer()
          ..writeln('')
          ..writeln('===== 枠ファースト計測: ${d.name} =====')
          ..writeln('制約充足 (h,w,n) 候補: $boxes')
          ..writeln(
            '枠生成: 成功 $framesGenerated / 要求 $frameCount '
            '(打ち切り $framesTruncated) / '
            'distinct形状 ${distinctShapes.length} / N種 ${distinctN.toList()..sort()}',
          )
          ..writeln(
            '候補セット数/枠: mean=${_mean(candidateCounts.map((e) => e.toDouble()).toList()).toStringAsFixed(0)} '
            'min=${_minL(candidateCounts.map((e) => e.toDouble()).toList())} '
            'max=${_maxL(candidateCounts.map((e) => e.toDouble()).toList())}  '
            '(= candidateSet × countSolutions の総当たり規模)',
          )
          ..writeln('--- Fable 判定用メトリクス ---')
          ..writeln(
            '[1] 敷き詰め可能セット/枠: '
            'mean=${_mean(tileablePerFrame.map((e) => e.toDouble()).toList()).toStringAsFixed(1)} '
            '(完了枠 n=${tileablePerFrame.length})',
          )
          ..writeln(
            '[2] 探索時間/枠(ms): '
            'min=${_minL(frameMs).toStringAsFixed(0)} '
            'mean=${_mean(frameMs).toStringAsFixed(0)} '
            'max=${_maxL(frameMs).toStringAsFixed(0)}',
          )
          ..writeln(
            '[3] 解数1〜3(採用基準内)の割合: '
            '$totalWithin13 / $totalTileable = ${within13Frac.toStringAsFixed(1)}%',
          );
        print(b.toString());

        expect(
          framesGenerated,
          greaterThan(0),
          reason: '${d.name}: 枠を 1 つ以上生成できること',
        );
      });
    });
  }
}
