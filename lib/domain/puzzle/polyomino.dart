/// Free Polyomino の定数定義。
///
/// ## 用語
/// - **Free Polyomino**：回転・反転で重なる形を同一視した多角形の種類。
/// - **カノニカル形**：外接矩形の左上を原点 (0, 0) とした基準座標表現。
///
/// ## 座標系
/// [Cell] = `(y, x)` = `(row, col)`。
/// y が増える方向 = 下、x が増える方向 = 右。
/// 詳細は `docs/adr/0006-polyomino-coordinate-order.md` を参照。
///
/// ## セルリストの並び順
/// row-major 順（行の昇順、同じ行内は列の昇順）。
library;

/// ポリオミノ内の1マスを表す座標型。`(y, x)` = `(row, col)` の順。
typedef Cell = (int, int);

/// Free Polyomino の1種を表す不変データクラス。
///
/// [cells] はカノニカル形を row-major 順で保持する。
/// 回転・反転のバリアント生成は `PolyominoTransformer`（別ファイル）が担当する。
class PolyominoData {
  /// Free Polyomino の1種を生成する。
  const PolyominoData({
    required this.id,
    required this.size,
    required this.cells,
  });

  /// 識別子。セル数接尾辞で全種類を統一。例: `'I3'`, `'T4'`, `'F5'`。
  final String id;

  /// セル数（3 = トロミノ、4 = テトロミノ、5 = ペントミノ）。
  final int size;

  /// カノニカル形の座標リスト。`(y, x)` 順、row-major で格納。
  final List<Cell> cells;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PolyominoData) return false;
    if (id != other.id || size != other.size) return false;
    if (cells.length != other.cells.length) return false;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != other.cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, size, Object.hashAll(cells));

  @override
  String toString() => 'PolyominoData($id, size=$size, cells=$cells)';
}

// ─── トロミノ（3セル）: 2種 ────────────────────────────────────────

/// I3 トロミノ（直線型）
///
/// ```
/// ###
/// ```
const PolyominoData kI3 = PolyominoData(
  id: 'I3',
  size: 3,
  cells: [(0, 0), (0, 1), (0, 2)],
);

/// L3 トロミノ（L字型）
///
/// ```
/// ##
/// #
/// ```
const PolyominoData kL3 = PolyominoData(
  id: 'L3',
  size: 3,
  cells: [(0, 0), (0, 1), (1, 0)],
);

/// トロミノ全種（2種）。
const List<PolyominoData> kTrominoes = [kI3, kL3];

// ─── テトロミノ（4セル）: 5種 ──────────────────────────────────────

/// I4 テトロミノ（直線型）
///
/// ```
/// ####
/// ```
const PolyominoData kI4 = PolyominoData(
  id: 'I4',
  size: 4,
  cells: [(0, 0), (0, 1), (0, 2), (0, 3)],
);

/// O4 テトロミノ（正方形型）
///
/// ```
/// ##
/// ##
/// ```
const PolyominoData kO4 = PolyominoData(
  id: 'O4',
  size: 4,
  cells: [(0, 0), (0, 1), (1, 0), (1, 1)],
);

/// T4 テトロミノ（T字型）
///
/// ```
/// ###
///  #
/// ```
const PolyominoData kT4 = PolyominoData(
  id: 'T4',
  size: 4,
  cells: [(0, 0), (0, 1), (0, 2), (1, 1)],
);

/// L4 テトロミノ
///
/// ```
/// ##
/// #
/// #
/// ```
const PolyominoData kL4 = PolyominoData(
  id: 'L4',
  size: 4,
  cells: [(0, 0), (0, 1), (1, 0), (2, 0)],
);

/// S4 テトロミノ（S字型）
///
/// ```
///  ##
/// ##
/// ```
const PolyominoData kS4 = PolyominoData(
  id: 'S4',
  size: 4,
  cells: [(0, 1), (0, 2), (1, 0), (1, 1)],
);

/// テトロミノ全種（5種）。
const List<PolyominoData> kTetrominoes = [kI4, kO4, kT4, kL4, kS4];

// ─── ペントミノ（5セル）: 12種 ─────────────────────────────────────

/// F5 ペントミノ
///
/// ```
///  ##
/// ##
///  #
/// ```
const PolyominoData kF5 = PolyominoData(
  id: 'F5',
  size: 5,
  cells: [(0, 1), (0, 2), (1, 0), (1, 1), (2, 1)],
);

/// I5 ペントミノ（直線型）
///
/// ```
/// #####
/// ```
const PolyominoData kI5 = PolyominoData(
  id: 'I5',
  size: 5,
  cells: [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)],
);

/// L5 ペントミノ
///
/// ```
/// #
/// #
/// #
/// ##
/// ```
const PolyominoData kL5 = PolyominoData(
  id: 'L5',
  size: 5,
  cells: [(0, 0), (1, 0), (2, 0), (3, 0), (3, 1)],
);

/// N5 ペントミノ
///
/// ```
///  #
/// ##
/// #
/// #
/// ```
const PolyominoData kN5 = PolyominoData(
  id: 'N5',
  size: 5,
  cells: [(0, 1), (1, 0), (1, 1), (2, 0), (3, 0)],
);

/// P5 ペントミノ
///
/// ```
/// ##
/// ##
/// #
/// ```
const PolyominoData kP5 = PolyominoData(
  id: 'P5',
  size: 5,
  cells: [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0)],
);

/// T5 ペントミノ
///
/// ```
/// ###
///  #
///  #
/// ```
const PolyominoData kT5 = PolyominoData(
  id: 'T5',
  size: 5,
  cells: [(0, 0), (0, 1), (0, 2), (1, 1), (2, 1)],
);

/// U5 ペントミノ
///
/// ```
/// # #
/// ###
/// ```
const PolyominoData kU5 = PolyominoData(
  id: 'U5',
  size: 5,
  cells: [(0, 0), (0, 2), (1, 0), (1, 1), (1, 2)],
);

/// V5 ペントミノ
///
/// ```
/// #
/// #
/// ###
/// ```
const PolyominoData kV5 = PolyominoData(
  id: 'V5',
  size: 5,
  cells: [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)],
);

/// W5 ペントミノ
///
/// ```
/// #
/// ##
///  ##
/// ```
const PolyominoData kW5 = PolyominoData(
  id: 'W5',
  size: 5,
  cells: [(0, 0), (1, 0), (1, 1), (2, 1), (2, 2)],
);

/// X5 ペントミノ（十字型）
///
/// ```
///  #
/// ###
///  #
/// ```
const PolyominoData kX5 = PolyominoData(
  id: 'X5',
  size: 5,
  cells: [(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)],
);

/// Y5 ペントミノ
///
/// ```
///  #
/// ##
///  #
///  #
/// ```
const PolyominoData kY5 = PolyominoData(
  id: 'Y5',
  size: 5,
  cells: [(0, 1), (1, 0), (1, 1), (2, 1), (3, 1)],
);

/// Z5 ペントミノ
///
/// ```
/// ##
///  #
///  ##
/// ```
const PolyominoData kZ5 = PolyominoData(
  id: 'Z5',
  size: 5,
  cells: [(0, 0), (0, 1), (1, 1), (2, 1), (2, 2)],
);

/// ペントミノ全種（12種）。
const List<PolyominoData> kPentominoes = [
  kF5,
  kI5,
  kL5,
  kN5,
  kP5,
  kT5,
  kU5,
  kV5,
  kW5,
  kX5,
  kY5,
  kZ5,
];

// ─── 全種まとめ ────────────────────────────────────────────────────

/// Free Polyomino 全19種（トロミノ2 + テトロミノ5 + ペントミノ12）。
///
/// パズル生成時は [PolyominoData.size] でフィルタして難易度別プールを構成する。
/// 例: `kAllPolyominoes.where((p) => p.size == 4)` でテトロミノのみ取得。
const List<PolyominoData> kAllPolyominoes = [
  ...kTrominoes,
  ...kTetrominoes,
  ...kPentominoes,
];
