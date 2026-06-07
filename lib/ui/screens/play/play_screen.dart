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

/// プレイ画面（Phase 2 PR-C: 配置済みピースの取り出し・置き直し）（ADR-0014）。
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

  // 盤面ピース掴み待機状態（押下してまだ slop 未満）
  int? _pendingPlacedIndex;
  Offset? _pendingDownGlobal;
  bool _boardDragging = false;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  Set<Cell> get _occupied =>
      _placed.expand((p) => p.cells).toSet();

  Set<int> _buildHiddenIndices() {
    final hidden = <int>{};
    if (_draggingIndex != null) hidden.add(_draggingIndex!);
    hidden.addAll(_placed.map((p) => p.colorIndex));
    return hidden;
  }

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

  /// トレイ上の指定 index のアイテム中心 global 座標を取得する。
  Offset? _trayItemCenter(int colorIndex) {
    final key = ValueKey('tray-piece-$colorIndex');
    // WidgetsBinding から Element を探す
    Offset? result;
    void visitor(Element element) {
      if (element.widget.key == key) {
        final box = element.renderObject as RenderBox?;
        if (box != null && box.hasSize) {
          result = box.localToGlobal(box.size.center(Offset.zero));
        }
        return;
      }
      element.visitChildren(visitor);
    }
    if (mounted) {
      WidgetsBinding.instance.rootElement?.visitChildren(visitor);
    }
    return result;
  }

  /// ドラッグ開始共通処理。トレイからも盤面からも呼ぶ。
  void _beginDrag(
    int colorIndex,
    Offset pointerGlobal,
    Offset trayCenterGlobal,
    GeneratedPuzzle puzzle,
  ) {
    _returnCtrl?.stop();
    _pickupCtrl?.dispose();

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
      _draggingIndex = colorIndex;
      _dragPosition = pointerGlobal;
      _trayItemGlobal = trayCenterGlobal;
      _dragScale = 1.0;
      _ghostCells = const [];
      _ghostValid = false;
    });

    _pickupCtrl!.forward();
  }

  void _onPickup(
    int index,
    Offset pointerGlobal,
    Offset trayItemGlobal,
    GeneratedPuzzle puzzle,
  ) {
    _beginDrag(index, pointerGlobal, trayItemGlobal, puzzle);
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

    final stackCtx = _stackKey.currentContext;
    if (stackCtx == null) return;
    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final boardCtx = _boardKey.currentContext;
    if (boardCtx == null) return;
    final boardBox = boardCtx.findRenderObject() as RenderBox?;
    if (boardBox == null) return;

    final block = puzzle.blocks[index];
    final cells = block.orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);
    final maxY = cells.map((c) => c.$1).reduce((a, b) => a > b ? a : b);
    final maxX = cells.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
    final pieceW = (maxX - minX + 1) * _cellSize;
    final pieceH = (maxY - minY + 1) * _cellSize;

    // _floatingPieceOffset と同じ式でスタックローカルのピース左上を計算し、
    // グローバル→盤面ローカルへ変換して fingerOffset の二重適用を防ぐ。
    final stackLocal = stackBox.globalToLocal(pointerGlobal);
    final stackLocalTL = Offset(
      stackLocal.dx - pieceW / 2,
      stackLocal.dy - _feelConfig.fingerOffset - pieceH / 2,
    );
    final globalTL = stackBox.localToGlobal(stackLocalTL);
    final pieceTL = boardBox.globalToLocal(globalTL);

    // 左上セルの格子からのズレを計算してスナップ
    final rawColF =
        (pieceTL.dx - geo.boardOrigin.dx) / geo.cellSize + geo.originCol;
    final rawRowF =
        (pieceTL.dy - geo.boardOrigin.dy) / geo.cellSize + geo.originRow;

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
      // ゴースト判定では浮いているピース自身の占有は除外する
      final occupiedWithoutDragging = _placed
          .where((p) => p.colorIndex != index)
          .expand((p) => p.cells)
          .toSet();
      final valid = canPlace(candidate, frame, occupiedWithoutDragging);
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

  // ── 盤面ピース掴み処理 ──────────────────────────────────────────

  void _onBoardPointerDown(PointerDownEvent e, GeneratedPuzzle puzzle) {
    if (_draggingIndex != null) return;

    final boardCtx = _boardKey.currentContext;
    if (boardCtx == null) return;
    final boardBox = boardCtx.findRenderObject() as RenderBox?;
    if (boardBox == null) return;

    final geo = _currentGeo(puzzle);
    if (geo == null) return;

    final localPos = boardBox.globalToLocal(e.position);
    final cell = geo.pixelToCell(localPos);
    if (cell == null) return;

    // 押下セルがどの配置済みピースに含まれるか探す
    for (final p in _placed) {
      if (p.cells.contains(cell)) {
        _pendingPlacedIndex = p.colorIndex;
        _pendingDownGlobal = e.position;
        _boardDragging = false;
        return;
      }
    }
  }

  void _onBoardPointerMove(PointerMoveEvent e, GeneratedPuzzle puzzle) {
    // すでにトレイドラッグ中なら盤面側は何もしない
    if (_draggingIndex != null && !_boardDragging) return;

    if (_boardDragging) {
      _onMove(e.position, puzzle);
      return;
    }

    final pending = _pendingPlacedIndex;
    final down = _pendingDownGlobal;
    if (pending == null || down == null) return;

    final dist = (e.position - down).distance;
    if (dist >= _feelConfig.dragStartSlop) {
      // slop 超え → 盤面から外して浮かせる
      _boardDragging = true;

      // _placed から除去（_occupied を更新）
      _placed.removeWhere((p) => p.colorIndex == pending);

      // 元のトレイ位置を取得
      final trayCenter = _trayItemCenter(pending);
      // トレイ中心が取れない場合は画面下端あたりへフォールバック
      final fallback = Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height * 0.85,
      );

      _pendingPlacedIndex = null;
      _pendingDownGlobal = null;

      _beginDrag(pending, e.position, trayCenter ?? fallback, puzzle);
    }
  }

  void _onBoardPointerUp(PointerUpEvent e, GeneratedPuzzle puzzle) {
    if (_boardDragging) {
      _boardDragging = false;
      _onDrop(e.position, puzzle);
    }
    _pendingPlacedIndex = null;
    _pendingDownGlobal = null;
  }

  void _onBoardPointerCancel(PointerCancelEvent e, GeneratedPuzzle puzzle) {
    if (_boardDragging) {
      _boardDragging = false;
      _onDrop(e.position, puzzle);
    }
    _pendingPlacedIndex = null;
    _pendingDownGlobal = null;
  }

  // ── 描画 ─────────────────────────────────────────────────────────

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
              _settingsSlider(
                setModalState,
                label: 'dragStartSlop  ${_feelConfig.dragStartSlop.round()}px',
                value: _feelConfig.dragStartSlop,
                min: 0,
                max: 24,
                onChanged: (v) => setState(
                  () => _feelConfig = _feelConfig.copyWith(dragStartSlop: v),
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
                    child: Listener(
                      onPointerDown: (e) =>
                          _onBoardPointerDown(e, value.puzzle),
                      onPointerMove: (e) =>
                          _onBoardPointerMove(e, value.puzzle),
                      onPointerUp: (e) =>
                          _onBoardPointerUp(e, value.puzzle),
                      onPointerCancel: (e) =>
                          _onBoardPointerCancel(e, value.puzzle),
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
                  ),
                  Expanded(
                    flex: 4,
                    child: PieceTray(
                      puzzle: value.puzzle,
                      feelConfig: _feelConfig,
                      hiddenIndices: _buildHiddenIndices(),
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
