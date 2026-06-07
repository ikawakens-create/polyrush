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
class _TrayItem extends StatelessWidget {
  const _TrayItem({
    super.key,
    required this.block,
    required this.colorIndex,
    required this.hitboxPad,
    required this.trayCell,
    required this.onPickup,
    required this.onMove,
    required this.onDrop,
  });

  final PlacedBlock block;
  final int colorIndex;
  final double hitboxPad;
  final double trayCell;
  final void Function(Offset pointerGlobal, Offset itemGlobal) onPickup;
  final void Function(Offset pointerGlobal) onMove;
  final void Function(Offset pointerGlobal) onDrop;

  @override
  Widget build(BuildContext context) {
    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY = cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX = cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);

    final pieceW = (maxX - minX + 1) * trayCell;
    final pieceH = (maxY - minY + 1) * trayCell;

    return Listener(
      onPointerDown: (e) {
        final box = context.findRenderObject() as RenderBox;
        // Listener の外辺は hitboxPad ぶん広いので CustomPaint の中心を正確に計算する
        final itemCenter = box.localToGlobal(
          Offset(hitboxPad + pieceW / 2, hitboxPad + pieceH / 2),
        );
        onPickup(e.position, itemCenter);
      },
      onPointerMove: (e) => onMove(e.position),
      onPointerUp: (e) => onDrop(e.position),
      onPointerCancel: (e) => onDrop(e.position),
      child: Padding(
        padding: EdgeInsets.all(hitboxPad),
        child: CustomPaint(
          size: Size(pieceW, pieceH),
          painter: PiecePainter(
            block: block,
            colorIndex: colorIndex,
            cellSize: trayCell,
          ),
        ),
      ),
    );
  }
}

/// ピースを横並びで表示するトレイ。
///
/// 各ピースをサムネイルサイズで描き、掴み・追従・離しを [PlayScreen] へ通知する。
class PieceTray extends StatelessWidget {
  const PieceTray({
    super.key,
    required this.puzzle,
    required this.feelConfig,
    required this.onPickup,
    required this.onMove,
    required this.onDrop,
  });

  final GeneratedPuzzle puzzle;
  final FeelConfig feelConfig;
  final void Function(int index, Offset pointerGlobal, Offset itemGlobal)
      onPickup;
  final void Function(Offset pointerGlobal) onMove;
  final void Function(Offset pointerGlobal) onDrop;

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
                child: _TrayItem(
                  key: ValueKey('tray-piece-$i'),
                  block: puzzle.blocks[i],
                  colorIndex: i,
                  hitboxPad: feelConfig.hitboxPad,
                  trayCell: _trayCell,
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
}
