import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/board/grid_geometry.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({required this.puzzle, this.padding = 24.0});

  final GeneratedPuzzle puzzle;
  final double padding;

  static const _cellFill = Color(0xFFFFFDF5);
  static const _cellBorder = Color(0xFFD8D2C0);
  static const _bg = Color(0xFFFBF7EC);

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
      ..strokeWidth = 2.0;

    for (final cell in puzzle.frame) {
      final rect = geo.cellRect(cell);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => oldDelegate.puzzle != puzzle;
}
