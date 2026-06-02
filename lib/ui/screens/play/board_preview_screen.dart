import 'package:flutter/material.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';
import 'package:polyrush/game/board/board_painter.dart';

class BoardPreviewScreen extends StatelessWidget {
  const BoardPreviewScreen({super.key});

  static const _bg = Color(0xFFFBF7EC);

  @override
  Widget build(BuildContext context) {
    final result = VerifiedPuzzleGenerator.generate(
      difficulty: Difficulty.normal,
      seed: 1,
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('PolyRush（盤プレビュー）'),
      ),
      body: switch (result) {
        Ok(:final value) => SizedBox.expand(
            child: CustomPaint(
              painter: BoardPainter(puzzle: value.puzzle),
            ),
          ),
        Err() => const Center(
            child: Text('生成に失敗しました'),
          ),
      },
    );
  }
}
