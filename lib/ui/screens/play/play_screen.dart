import 'package:flutter/material.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v3.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';
import 'package:polyrush/game/board/play_board_painter.dart';
import 'package:polyrush/game/play/feel_config.dart';
import 'package:polyrush/ui/screens/play/piece_tray.dart';

/// プレイ画面（Phase 2 PR-A: 触れる足場）（ADR-0014）。
///
/// - V3 生成器で easy/seed=1 を 1 回だけ生成する。
/// - 上部 60% に空き枠、下部 40% にトレイを表示する。
/// - トレイのピースを掴むと実寸で浮かび、追従し、離すとトレイへ戻る。
/// - 吸着・配置・完成判定・回転・タイマーは後続 PR で実装する。
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  static const double _floatCellSize = 40.0;

  late final Result<VerifiedPuzzle, CompactPuzzleError> _result;
  FeelConfig _feelConfig = const FeelConfig();

  int? _draggingIndex;
  Offset? _dragPosition; // グローバル座標
  Offset? _trayItemGlobal; // 掴んだトレイアイテムの中心グローバル座標
  double _dragScale = 1.0;

  AnimationController? _pickupCtrl;
  AnimationController? _returnCtrl;
  Animation<double>? _scaleAnim;
  Animation<Offset>? _returnPosAnim;
  Animation<double>? _returnScaleAnim;

  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _result = CompactPuzzleGeneratorV3.generate(
      difficulty: Difficulty.easy,
      seed: 1,
    );
  }

  @override
  void dispose() {
    _pickupCtrl?.dispose();
    _returnCtrl?.dispose();
    super.dispose();
  }

  void _onPickup(int index, Offset pointerGlobal, Offset trayItemGlobal) {
    _returnCtrl?.stop();
    _pickupCtrl?.dispose();

    _pickupCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _feelConfig.pickupMs),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: _feelConfig.pickupScale)
        .animate(CurvedAnimation(parent: _pickupCtrl!, curve: Curves.easeOut));
    _scaleAnim!.addListener(
      () => setState(() => _dragScale = _scaleAnim!.value),
    );

    setState(() {
      _draggingIndex = index;
      _dragPosition = pointerGlobal;
      _trayItemGlobal = trayItemGlobal;
      _dragScale = 1.0;
    });

    _pickupCtrl!.forward();
  }

  void _onMove(Offset pointerGlobal) {
    setState(() => _dragPosition = pointerGlobal);
  }

  void _onDrop(Offset pointerGlobal) {
    if (_draggingIndex == null || _trayItemGlobal == null) return;

    final startGlobal = _dragPosition ?? pointerGlobal;
    final endGlobal = _trayItemGlobal!;
    final startScale = _dragScale;

    _pickupCtrl?.stop();
    _returnCtrl?.dispose();
    _returnCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _feelConfig.returnMs),
    );

    _returnPosAnim = Tween<Offset>(begin: startGlobal, end: endGlobal).animate(
      CurvedAnimation(parent: _returnCtrl!, curve: Curves.easeIn),
    );
    _returnScaleAnim = Tween<double>(begin: startScale, end: 1.0).animate(
      CurvedAnimation(parent: _returnCtrl!, curve: Curves.easeIn),
    );

    _returnCtrl!.addListener(() {
      setState(() {
        _dragPosition = _returnPosAnim!.value;
        _dragScale = _returnScaleAnim!.value;
      });
    });
    _returnCtrl!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _draggingIndex = null;
          _dragPosition = null;
          _dragScale = 1.0;
        });
      }
    });
    _returnCtrl!.forward();
  }

  Offset? _floatingPieceOffset(PlacedBlock block) {
    if (_dragPosition == null) return null;
    final ctx = _stackKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final local = box.globalToLocal(_dragPosition!);
    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY = cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX = cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
    final pieceW = (maxX - minX + 1) * _floatCellSize;
    final pieceH = (maxY - minY + 1) * _floatCellSize;

    return Offset(
      local.dx - pieceW / 2,
      local.dy - _feelConfig.fingerOffset - pieceH / 2,
    );
  }

  Widget _buildFloatingPiece(List<PlacedBlock> blocks) {
    final index = _draggingIndex;
    if (index == null) return const SizedBox.shrink();

    final block = blocks[index];
    final offset = _floatingPieceOffset(block);
    if (offset == null) return const SizedBox.shrink();

    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final maxY = cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxX = cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
    final pieceW = (maxX - minX + 1) * _floatCellSize;
    final pieceH = (maxY - minY + 1) * _floatCellSize;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: Transform.scale(
          scale: _dragScale,
          child: CustomPaint(
            size: Size(pieceW, pieceH),
            painter: PiecePainter(
              block: block,
              colorIndex: index,
              cellSize: _floatCellSize,
            ),
          ),
        ),
      ),
    );
  }

  void _openSettingsPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '手触り調整',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _settingsSlider(
                setModalState,
                label: 'fingerOffset  ${_feelConfig.fingerOffset.round()}px',
                value: _feelConfig.fingerOffset,
                min: 0,
                max: 120,
                onChanged: (v) => setState(
                  () => _feelConfig = _feelConfig.copyWith(fingerOffset: v),
                ),
              ),
              _settingsSlider(
                setModalState,
                label: 'hitboxPad  ${_feelConfig.hitboxPad.round()}px',
                value: _feelConfig.hitboxPad,
                min: 0,
                max: 40,
                onChanged: (v) => setState(
                  () => _feelConfig = _feelConfig.copyWith(hitboxPad: v),
                ),
              ),
              _settingsSlider(
                setModalState,
                label: 'pickupScale  ${_feelConfig.pickupScale.toStringAsFixed(2)}',
                value: _feelConfig.pickupScale,
                min: 1.0,
                max: 1.5,
                onChanged: (v) => setState(
                  () => _feelConfig = _feelConfig.copyWith(pickupScale: v),
                ),
              ),
              _settingsSlider(
                setModalState,
                label: 'pickupMs  ${_feelConfig.pickupMs}ms',
                value: _feelConfig.pickupMs.toDouble(),
                min: 0,
                max: 500,
                onChanged: (v) => setState(
                  () =>
                      _feelConfig = _feelConfig.copyWith(pickupMs: v.round()),
                ),
              ),
              _settingsSlider(
                setModalState,
                label: 'returnMs  ${_feelConfig.returnMs}ms',
                value: _feelConfig.returnMs.toDouble(),
                min: 0,
                max: 500,
                onChanged: (v) => setState(
                  () =>
                      _feelConfig = _feelConfig.copyWith(returnMs: v.round()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsSlider(
    StateSetter setModalState, {
    required String label,
    required double value,
    required double min,
    required double max,
    required void Function(double) onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) {
              onChanged(v);
              setModalState(() {});
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4EFE6),
        elevation: 0,
        title: const Text('PolyRush（プレイ）'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettingsPanel(context),
          ),
        ],
      ),
      body: switch (_result) {
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
        Ok(:final value) => Stack(
            key: _stackKey,
            children: [
              Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CustomPaint(
                        painter: PlayBoardPainter(puzzle: value.puzzle),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: PieceTray(
                      puzzle: value.puzzle,
                      feelConfig: _feelConfig,
                      onPickup: _onPickup,
                      onMove: _onMove,
                      onDrop: _onDrop,
                    ),
                  ),
                ],
              ),
              _buildFloatingPiece(value.puzzle.blocks),
            ],
          ),
      },
    );
  }
}
