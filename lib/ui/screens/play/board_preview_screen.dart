import 'package:flutter/material.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';
import 'package:polyrush/game/board/board_painter.dart';

class BoardPreviewScreen extends StatelessWidget {
  const BoardPreviewScreen({super.key});

  static const _bg = Color(0xFFF4EFE6);

  static final _configs = <({Difficulty difficulty, int seed})>[
    (difficulty: Difficulty.easy, seed: 1),
    (difficulty: Difficulty.easy, seed: 2),
    (difficulty: Difficulty.easy, seed: 3),
    (difficulty: Difficulty.normal, seed: 1),
    (difficulty: Difficulty.normal, seed: 2),
    (difficulty: Difficulty.normal, seed: 3),
    (difficulty: Difficulty.hard, seed: 1),
    (difficulty: Difficulty.hard, seed: 2),
    (difficulty: Difficulty.hard, seed: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('PolyRush（盤ギャラリー）'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: _configs.length,
        itemBuilder: (context, index) {
          final cfg = _configs[index];
          final result = VerifiedPuzzleGenerator.generate(
            difficulty: cfg.difficulty,
            seed: cfg.seed,
          );
          final label = '${cfg.difficulty.name}/seed${cfg.seed}';
          return Column(
            children: [
              Expanded(
                child: switch (result) {
                  Ok(:final value) => CustomPaint(
                      painter: BoardPainter(
                        puzzle: value.puzzle,
                        padding: 8,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  Err() => const Center(
                      child: Text(
                        '失敗',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                },
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
