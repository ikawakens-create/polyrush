import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/board/grid_geometry.dart';

/// プレイ画面用の枠描画（ADR-0014）。
///
/// board_painter.dart とは独立した新規クラス。
/// 空きスロット・外周線に加え、配置済みピースとゴーストを描く。
class PlayBoardPainter extends CustomPainter {
  const PlayBoardPainter({
    required this.puzzle,
    this.padding = 16.0,
    this.placed = const [],
    this.ghostCells = const [],
    this.ghostValid = false,
  });

  final GeneratedPuzzle puzzle;
  final double padding;

  /// 配置済みピース。各要素の cells はグローバルセル座標。
  final List<({List<Cell> cells, int colorIndex})> placed;

  /// ゴースト（浮いているピースが着くセル一覧）。グローバルセル座標。
  final List<Cell> ghostCells;

  /// ゴーストが有効位置（frame 内かつ未占有）なら true。
  final bool ghostValid;

  static const _bg = Color(0xFFF4EFE6);
  static const _slotFill = Color(0xFFDDD8CC);
  static const _slotStroke = Color(0xFFB0A898);
  static const _edgeStroke = Color(0xFF1B2A4A);

  static const _pieceColors = <Color>[
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
    Color(0xFFFDD835),
  ];

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

    // 空きスロット
    for (final cell in puzzle.frame) {
      final rect = geo.cellRect(cell);
      canvas.drawRect(rect, slotFill);
      canvas.drawRect(rect, slotBorder);
    }

    // 配置済みピース
    for (final p in placed) {
      final color = _pieceColors[p.colorIndex % _pieceColors.length];
      final fill = Paint()..color = color;
      final border = Paint()
        ..color = _edgeStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final cell in p.cells) {
        final rect = geo.cellRect(cell);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, border);
      }
    }

    // ゴーストオーバーレイ
    if (ghostCells.isNotEmpty) {
      final ghostColor = ghostValid
          ? const Color(0x6643A047)
          : const Color(0x66E53935);
      final ghostFill = Paint()..color = ghostColor;
      for (final cell in ghostCells) {
        final rect = geo.cellRect(cell);
        canvas.drawRect(rect, ghostFill);
      }
    }

    // 外周線
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
  bool shouldRepaint(PlayBoardPainter old) =>
      old.puzzle != puzzle ||
      old.placed != placed ||
      old.ghostCells != ghostCells ||
      old.ghostValid != ghostValid;
}
