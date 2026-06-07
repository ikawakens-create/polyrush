import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/board/grid_geometry.dart';

/// プレイ画面用の枠描画（ADR-0014）。
///
/// board_painter.dart とは独立した新規クラス。
/// ピースは描かず、枠の空きスロットと外周線のみを描く。
class PlayBoardPainter extends CustomPainter {
  const PlayBoardPainter({required this.puzzle, this.padding = 16.0});

  final GeneratedPuzzle puzzle;
  final double padding;

  static const _bg = Color(0xFFF4EFE6);
  static const _slotFill = Color(0xFFDDD8CC);
  static const _slotStroke = Color(0xFFB0A898);
  static const _edgeStroke = Color(0xFF1B2A4A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    final geo = GridGeometry.fit(
      boundingBox: puzzle.boundingBox,
      canvasSize: size,
      padding: padding,
    );

    final slotFill = Paint()..color = _slotFill;
    final slotBorder = Paint()
      ..color = _slotStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final cell in puzzle.frame) {
      final rect = geo.cellRect(cell);
      canvas.drawRect(rect, slotFill);
      canvas.drawRect(rect, slotBorder);
    }

    final edgePaint = Paint()
      ..color = _edgeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square;

    for (final cell in puzzle.frame) {
      final rect = geo.cellRect(cell);
      final y = cell.$1;
      final x = cell.$2;

      if (!puzzle.frame.contains((y - 1, x))) {
        canvas.drawLine(rect.topLeft, rect.topRight, edgePaint);
      }
      if (!puzzle.frame.contains((y + 1, x))) {
        canvas.drawLine(rect.bottomLeft, rect.bottomRight, edgePaint);
      }
      if (!puzzle.frame.contains((y, x - 1))) {
        canvas.drawLine(rect.topLeft, rect.bottomLeft, edgePaint);
      }
      if (!puzzle.frame.contains((y, x + 1))) {
        canvas.drawLine(rect.topRight, rect.bottomRight, edgePaint);
      }
    }
  }

  @override
  bool shouldRepaint(PlayBoardPainter old) => old.puzzle != puzzle;
}
