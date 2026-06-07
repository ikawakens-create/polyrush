import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyrush/core/result.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/compact_puzzle_generator_v3.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/domain/puzzle/verified_puzzle_generator.dart';
import 'package:polyrush/game/board/grid_geometry.dart';
import 'package:polyrush/game/board/play_board_painter.dart';
import 'package:polyrush/game/play/feel_config.dart';
import 'package:polyrush/game/play/placement_logic.dart';
import 'package:polyrush/ui/screens/play/piece_tray.dart';

/// プレイ画面（Phase 2 PR-B: ゴースト着地プレビュー＋吸着＋配置）（ADR-0014）。
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late final Result<VerifiedPuzzle, CompactPuzzleError> _result;
  FeelConfig _feelConfig = const FeelConfig();

  // ドラッグ状態
  int? _draggingIndex;
  Offset? _dragPosition;
  Offset? _trayItemGlobal;
  double _dragScale = 1.0;
  double _cellSize = 40.0;

  // 配置済みピース
  final List<({List<Cell> cells, int colorIndex})> _placed = [];

  // ゴースト
  List<Cell> _ghostCells = const [];
  bool _ghostValid = false;

  // アニメーション
  AnimationController? _pickupCtrl;
  AnimationController? _returnCtrl;
  Animation<double>? _scaleAnim;
  Animation<Offset>? _returnPosAnim;
  Animation<double>? _returnScaleAnim;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  Set<Cell> get _occupied =>
      _placed.expand((p) => p.cells).toSet();

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

  GridGeometry? _currentGeo(GeneratedPuzzle puzzle) {
    final ctx = _boardKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;
    return GridGeometry.fit(
      boundingBox: puzzle.boundingBox,
      canvasSize: size,
      padding: 16.0,
    );
  }

  void _onPickup(
    int index,
    Offset pointerGlobal,
    Offset trayItemGlobal,
    GeneratedPuzzle puzzle,
  ) {
    _returnCtrl?.stop();
    _pickupCtrl?.dispose();

    // セルサイズを盤面ジオメトリから取得
    final geo = _currentGeo(puzzle);
    if (geo != null) {
      _cellSize = geo.cellSize;
    }

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
      _ghostCells = const [];
      _ghostValid = false;
    });

    _pickupCtrl!.forward();
  }

  void _onMove(Offset pointerGlobal, GeneratedPuzzle puzzle) {
    setState(() {
      _dragPosition = pointerGlobal;
    });
    _updateGhost(pointerGlobal, puzzle);
  }

  void _updateGhost(Offset pointerGlobal, GeneratedPuzzle puzzle) {
    final index = _draggingIndex;
    if (index == null) return;

    final geo = _currentGeo(puzzle);
    if (geo == null) return;

    final boardCtx = _boardKey.currentContext;
    if (boardCtx == null) return;
    final boardBox = boardCtx.findRenderObject() as RenderBox?;
    if (boardBox == null) return;

    final boardLocal = boardBox.globalToLocal(pointerGlobal);

    // ポインタが指すセル（指オフセットを考慮）
    final adjustedLocal = Offset(
      boardLocal.dx,
      boardLocal.dy - _feelConfig.fingerOffset,
    );

    final block = puzzle.blocks[index];
    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final pieceW = (cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b) - minX + 1) * geo.cellSize;
    final pieceH = (cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b) - minY + 1) * geo.cellSize;

    // ピース左上のピクセル座標（盤面ローカル）
    final pieceTL = Offset(
      adjustedLocal.dx - pieceW / 2,
      adjustedLocal.dy - pieceH / 2,
    );

    // 左上セルの格子からのズレを計算してスナップ
    final rawColF = (pieceTL.dx - geo.boardOrigin.dx) / geo.cellSize + geo.originCol;
    final rawRowF = (pieceTL.dy - geo.boardOrigin.dy) / geo.cellSize + geo.originRow;

    final snapCol = rawColF.round();
    final snapRow = rawRowF.round();

    final residualX = (rawColF - snapCol).abs();
    final residualY = (rawRowF - snapRow).abs();
    final residual = sqrt(residualX * residualX + residualY * residualY);

    final normalizedCells = cells
        .map((c) => (c.$1 - minY, c.$2 - minX))
        .toList();

    if (residual <= _feelConfig.snapRadius) {
      final origin = (snapRow + minY, snapCol + minX);
      final candidate = placedCellsAt(normalizedCells, (origin.$1, origin.$2));
      final frame = puzzle.frame.toSet();
      final valid = canPlace(candidate, frame, _occupied);
      setState(() {
        _ghostCells = candidate;
        _ghostValid = valid;
      });
    } else {
      setState(() {
        _ghostCells = const [];
        _ghostValid = false;
      });
    }
  }

  void _onDrop(Offset pointerGlobal, GeneratedPuzzle puzzle) {
    if (_draggingIndex == null || _trayItemGlobal == null) return;

    // スナップ有効かつ配置可能なら確定
    if (_ghostValid && _ghostCells.isNotEmpty) {
      final index = _draggingIndex!;
      HapticFeedback.lightImpact();
      setState(() {
        _placed.add((cells: _ghostCells, colorIndex: index));
        _draggingIndex = null;
        _dragPosition = null;
        _dragScale = 1.0;
        _ghostCells = const [];
        _ghostValid = false;
      });
      return;
    }

    // 配置できなければトレイへ戻る
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
      CurvedAnimation(parent: _returnCtrl!, curve: Curves.easeOut),
    );
    _returnScaleAnim = Tween<double>(begin: startScale, end: 1.0).animate(
      CurvedAnimation(parent: _returnCtrl!, curve: Curves.easeOut),
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
          _ghostCells = const [];
          _ghostValid = false;
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
    final pieceW = (maxX - minX + 1) * _cellSize;
    final pieceH = (maxY - minY + 1) * _cellSize;

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
    final pieceW = (maxX - minX + 1) * _cellSize;
    final pieceH = (maxY - minY + 1) * _cellSize;

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
              cellSize: _cellSize,
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
              _settingsSlider(
                setModalState,
                label: 'snapRadius  ${_feelConfig.snapRadius.toStringAsFixed(2)}',
                value: _feelConfig.snapRadius,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setState(
                  () => _feelConfig = _feelConfig.copyWith(snapRadius: v),
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
                    child: CustomPaint(
                      key: _boardKey,
                      painter: PlayBoardPainter(
                        puzzle: value.puzzle,
                        placed: _placed,
                        ghostCells: _ghostCells,
                        ghostValid: _ghostValid,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: PieceTray(
                      puzzle: value.puzzle,
                      feelConfig: _feelConfig,
                      hiddenIndices: {
                        if (_draggingIndex != null) _draggingIndex!,
                        ..._placed.map((p) => p.colorIndex),
                      },
                      onPickup: (index, pointerGlobal, itemGlobal) =>
                          _onPickup(index, pointerGlobal, itemGlobal, value.puzzle),
                      onMove: (pointerGlobal) =>
                          _onMove(pointerGlobal, value.puzzle),
                      onDrop: (pointerGlobal) =>
                          _onDrop(pointerGlobal, value.puzzle),
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
