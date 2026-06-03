import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/board/grid_geometry.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({required this.puzzle, this.padding = 16.0});

  final GeneratedPuzzle puzzle;
  final double padding;

  static const _bg = Color(0xFFF4EFE6);
  static const _cellFill = Color(0xFFFCFAF5);
  static const _cellBorder = Color(0xFF1B2A4A);
  static const _boardEdge = Color(0xFF1B2A4A);
  static const _goldLine = Color(0xFFC8A24A);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = _bg;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final geo = GridGeometry.fit(
      boundingBox: puzzle.boundingBox,
      canvasSize: size,
      padding: padding,
    );

    final fillPaint = Paint()
      ..color = _cellFill
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = _cellBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final cell in puzzle.frame) {
      final rect = geo.cellRect(cell);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }

    final boardRect = Rect.fromLTWH(
      geo.boardOrigin.dx,
      geo.boardOrigin.dy,
      geo.cols * geo.cellSize,
      geo.rows * geo.cellSize,
    );

    final edgePaint = Paint()
      ..color = _boardEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRect(boardRect, edgePaint);

    final goldPaint = Paint()
      ..color = _goldLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(boardRect.deflate(3.0), goldPaint);
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => oldDelegate.puzzle != puzzle;
}
