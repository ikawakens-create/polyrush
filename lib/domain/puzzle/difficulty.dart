library;

import 'package:polyrush/domain/puzzle/polyomino.dart';

List<PolyominoData> _easyPool() => [...kTrominoes, ...kTetrominoes];
List<PolyominoData> _standardPool() => [...kTetrominoes, ...kPentominoes];

enum Difficulty {
  easy(
    blockCount: 3,
    minTotalCells: 9,
    maxTotalCells: 12,
    poolBuilder: _easyPool,
  ),
  normal(
    blockCount: 4,
    minTotalCells: 16,
    maxTotalCells: 20,
    poolBuilder: _standardPool,
  ),
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

  final int blockCount;
  final int minTotalCells;
  final int maxTotalCells;
  final List<PolyominoData> Function() poolBuilder;

  List<PolyominoData> get pool => poolBuilder();
}
