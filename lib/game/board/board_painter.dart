import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/board/grid_geometry.dart';

class BoardPainter extends CustomPainter {
  const BoardPainter({required this.puzzle, this.padding = 16.0});

  final GeneratedPuzzle puzzle;
  final double padding;

  static const _bg = Color(0xFFF4EFE6);
  static const _cellBorder = Color(0xFF1B2A4A);
  static const _boardEdge = Color(0xFF1B2A4A);

  static const _pieceColors = <Color>[
    Color(0xFFE53935), // 赤
    Color(0xFF1E88E5), // 青
    Color(0xFF43A047), // 緑
    Color(0xFF8E24AA), // 紫
    Color(0xFFFDD835), // 黄
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = _bg;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final geo = GridGeometry.fit(
      boundingBox: puzzle.boundingBox,
      canvasSize: size,
      padding: padding,
    );

    final borderPaint = Paint()
      ..color = _cellBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < puzzle.blocks.length; i++) {
      final block = puzzle.blocks[i];
      final color = _pieceColors[i % _pieceColors.length];
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final cell in block.cells) {
        final rect = geo.cellRect(cell);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, borderPaint);
      }
    }

    final edgePaint = Paint()
      ..color = _boardEdge
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
  bool shouldRepaint(BoardPainter oldDelegate) => oldDelegate.puzzle != puzzle;
}
