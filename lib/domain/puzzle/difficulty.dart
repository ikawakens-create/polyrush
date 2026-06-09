/// パズル難易度の定義。
///
/// 各難易度はブロック数・セル数範囲・ピースプールを保持する。
/// [pool] を呼び出すたびに新しいリストが生成される。
library;

import 'package:polyrush/domain/puzzle/polyomino.dart';

List<PolyominoData> _easyPool() => [...kTrominoes, ...kTetrominoes];
List<PolyominoData> _standardPool() => [...kTetrominoes, ...kPentominoes];

/// パズルの難易度設定。
enum Difficulty {
  /// 初級: トロミノ＋テトロミノ 3 ブロック、合計 9〜12 セル。
  easy(
    blockCount: 3,
    minTotalCells: 9,
    maxTotalCells: 12,
    poolBuilder: _easyPool,
  ),

  /// 中級: テトロミノ＋ペントミノ 4 ブロック、合計 16〜20 セル。
  normal(
    blockCount: 4,
    minTotalCells: 16,
    maxTotalCells: 20,
    poolBuilder: _standardPool,
  ),

  /// 上級: テトロミノ＋ペントミノ 5 ブロック、合計 20〜25 セル。
  hard(
    blockCount: 5,
    minTotalCells: 20,
    maxTotalCells: 25,
    poolBuilder: _standardPool,
  );

  const Difficulty({
    required this.blockCount,
    required this.minTotalCells,
    required this.maxTotalCells,
    required this.poolBuilder,
  });

  /// 配置するブロック（ピース）の個数。
  final int blockCount;

  /// パズル枠の最小セル数（難易度保証の下限）。
  final int minTotalCells;

  /// パズル枠の最大セル数（難易度保証の上限）。
  final int maxTotalCells;

  /// 呼び出すたびに新しいプールリストを生成するビルダー関数。
  final List<PolyominoData> Function() poolBuilder;

  /// 難易度に対応したピースプールを返す（毎回新しいリスト）。
  List<PolyominoData> get pool => poolBuilder();
}
