import 'package:flutter/material.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/game/board/board_painter.dart';
import 'package:polyrush/ui/screens/play/play_screen.dart';

class BoardPreviewScreen extends StatefulWidget {
  const BoardPreviewScreen({super.key});

  @override
  State<BoardPreviewScreen> createState() => _BoardPreviewScreenState();
}

class _BoardPreviewScreenState extends State<BoardPreviewScreen> {
  static const _bg = Color(0xFFF4EFE6);

  Difficulty _difficulty = Difficulty.easy;
  int _seed = 1;

  @override
  Widget build(BuildContext context) {
    final result = CompactPuzzleGenerator.generate(
      difficulty: _difficulty,
      seed: _seed,
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('PolyRush（本番プレビュー）'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ToggleButtons(
              isSelected: [
                _difficulty == Difficulty.easy,
                _difficulty == Difficulty.normal,
                _difficulty == Difficulty.hard,
              ],
              onPressed: (index) {
                setState(() {
                  _difficulty = Difficulty.values[index];
                  _seed = 1;
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Easy'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Normal'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Hard'),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _seed > 1 ? () => setState(() => _seed--) : null,
              ),
              Text('seed: $_seed', style: const TextStyle(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _seed++),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (result) {
                Ok(:final value) => CustomPaint(
                  painter: BoardPainter(puzzle: value.puzzle, padding: 16),
                  child: const SizedBox.expand(),
                ),
                Err(:final error) => Center(
                  child: Text(
                    '生成に失敗しました: ${error.name}',
                    style: const TextStyle(
                      color: Color(0xFFB71C1C),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: switch (result) {
              Ok(:final value) => Builder(
                builder: (_) {
                  final bb = value.puzzle.boundingBox;
                  final w = bb.maxX - bb.minX + 1;
                  final h = bb.maxY - bb.minY + 1;
                  final area = w * h;
                  final cells = value.puzzle.frame.length;
                  final rate = cells / area * 100;
                  return Text(
                    '難易度: ${_difficulty.name}  seed: $_seed\n'
                    '解数: ${value.solutionCount}  試行: ${value.attemptsUsed}  '
                    'フォールバック: ${value.isFallback}\n'
                    '充填率: ${rate.toStringAsFixed(1)}%  '
                    '($cells / $area マス, 外接 $w×$h)',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              Err() => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}
