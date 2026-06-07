import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/play/feel_config.dart';

const _pieceColors = <Color>[
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFFDD835),
];

const _pieceBorderColor = Color(0xFF1B2A4A);

/// ピース 1 個を指定セルサイズで描く汎用ペインタ。
///
/// トレイのサムネイルとドラッグ中の浮いたピースの両方に使う。
/// [block.orientation.cells] を (0,0) 基点に正規化して描画する。
class PiecePainter extends CustomPainter {
  const PiecePainter({
    required this.block,
    required this.colorIndex,
    required this.cellSize,
  });

  final PlacedBlock block;
  final int colorIndex;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _pieceColors[colorIndex % _pieceColors.length];
    final fill = Paint()..color = color;
    final border = Paint()
      ..color = _pieceBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);

    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        (cell.$2 - minX) * cellSize,
        (cell.$1 - minY) * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.block != block ||
      old.colorIndex != colorIndex ||
      old.cellSize != cellSize;
}

/// トレイ内のピース 1 個を表すウィジェット。
///
/// [Listener] でポインタイベントを拾い、掴み・追従・離しを
/// コールバック経由で [PieceTray] → [PlayScreen] へ通知する。
/// [dragStartSlop] 以上ポインタが動いた時点で初めて掴み開始とみなす。
class _TrayItem extends StatefulWidget {
  const _TrayItem({
    super.key,
    required this.block,
    required this.colorIndex,
    required this.hitboxPad,
    required this.trayCell,
    required this.dragStartSlop,
    required this.onPickup,
    required this.onMove,
    required this.onDrop,
  });

  final PlacedBlock block;
  final int colorIndex;
  final double hitboxPad;
  final double trayCell;
  final double dragStartSlop;
  final void Function(Offset pointerGlobal, Offset itemGlobal) onPickup;
  final void Function(Offset pointerGlobal) onMove;
  final void Function(Offset pointerGlobal) onDrop;

  @override
  State<_TrayItem> createState() => _TrayItemState();
}

class _TrayItemState extends State<_TrayItem> {
  Offset? _downPosition;
  bool _dragging = false;

  void _reset() {
    _downPosition = null;
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final cells = widget.block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY = cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX = cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);

    final pieceW = (maxX - minX + 1) * widget.trayCell;
    final pieceH = (maxY - minY + 1) * widget.trayCell;

    return Listener(
      onPointerDown: (e) {
        _downPosition = e.position;
        _dragging = false;
      },
      onPointerMove: (e) {
        if (_dragging) {
          widget.onMove(e.position);
          return;
        }
        final down = _downPosition;
        if (down == null) return;
        final dist = (e.position - down).distance;
        if (dist >= widget.dragStartSlop) {
          _dragging = true;
          final box = context.findRenderObject() as RenderBox;
          // Listener の外辺は hitboxPad ぶん広いので CustomPaint の中心を正確に計算する
          final itemCenter = box.localToGlobal(
            Offset(widget.hitboxPad + pieceW / 2, widget.hitboxPad + pieceH / 2),
          );
          widget.onPickup(e.position, itemCenter);
        }
      },
      onPointerUp: (e) {
        if (_dragging) widget.onDrop(e.position);
        _reset();
      },
      onPointerCancel: (e) {
        if (_dragging) widget.onDrop(e.position);
        _reset();
      },
      child: Padding(
        padding: EdgeInsets.all(widget.hitboxPad),
        child: CustomPaint(
          size: Size(pieceW, pieceH),
          painter: PiecePainter(
            block: widget.block,
            colorIndex: widget.colorIndex,
            cellSize: widget.trayCell,
          ),
        ),
      ),
    );
  }
}

/// ピースを横並びで表示するトレイ。
///
/// 各ピースをサムネイルサイズで描き、掴み・追従・離しを [PlayScreen] へ通知する。
/// [hiddenIndices] に含まれるピースは非表示（配置済みまたはドラッグ中）。
class PieceTray extends StatelessWidget {
  const PieceTray({
    super.key,
    required this.puzzle,
    required this.feelConfig,
    required this.onPickup,
    required this.onMove,
    required this.onDrop,
    this.hiddenIndices = const {},
  });

  final GeneratedPuzzle puzzle;
  final FeelConfig feelConfig;
  final void Function(int index, Offset pointerGlobal, Offset itemGlobal)
      onPickup;
  final void Function(Offset pointerGlobal) onMove;
  final void Function(Offset pointerGlobal) onDrop;

  /// 非表示にするピースのインデックス集合（配置済み・ドラッグ中）。
  final Set<int> hiddenIndices;

  static const double _trayCell = 28.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAE5D8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < puzzle.blocks.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: hiddenIndices.contains(i)
                    ? SizedBox(
                        key: ValueKey('tray-piece-$i'),
                        width: _trayItemWidth(puzzle.blocks[i]),
                        height: _trayItemHeight(puzzle.blocks[i]),
                      )
                    : _TrayItem(
                        key: ValueKey('tray-piece-$i'),
                        block: puzzle.blocks[i],
                        colorIndex: i,
                        hitboxPad: feelConfig.hitboxPad,
                        trayCell: _trayCell,
                        dragStartSlop: feelConfig.dragStartSlop,
                        onPickup: (pointerGlobal, itemGlobal) =>
                            onPickup(i, pointerGlobal, itemGlobal),
                        onMove: onMove,
                        onDrop: onDrop,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  double _trayItemWidth(PlacedBlock block) {
    final cells = block.orientation.cells;
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX = cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
    return (maxX - minX + 1) * _trayCell + feelConfig.hitboxPad * 2;
  }

  double _trayItemHeight(PlacedBlock block) {
    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY = cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    return (maxY - minY + 1) * _trayCell + feelConfig.hitboxPad * 2;
  }
}
