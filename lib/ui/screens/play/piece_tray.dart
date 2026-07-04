import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/play/feel_config.dart';
import 'package:polyrush/ui/screens/play/tray_layout.dart';

const _pieceColors = <Color>[
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFFDD835),
];

const _pieceBorderColor = Color(0xFF1B2A4A);

/// ピース 1 個を指定セルサイズで描く汎用ペインタ。
///
/// トレイのサムネイルとドラッグ中の浮いたピースの両方に使う。
/// [block.orientation.cells] を (0,0) 基点に正規化して描画する。
class PiecePainter extends CustomPainter {
  const PiecePainter({
    required this.orientation,
    required this.colorIndex,
    required this.cellSize,
  });

  final PolyominoData orientation;
  final int colorIndex;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _pieceColors[colorIndex % _pieceColors.length];
    final fill = Paint()..color = color;
    final border = Paint()
      ..color = _pieceBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cells = orientation.cells;
    final minY = cells.map((c) => c.$1).reduce((a, b) => a < b ? a : b);
    final minX = cells.map((c) => c.$2).reduce((a, b) => a < b ? a : b);

    for (final cell in cells) {
      final rect = Rect.fromLTWH(
        (cell.$2 - minX) * cellSize,
        (cell.$1 - minY) * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.orientation != orientation ||
      old.colorIndex != colorIndex ||
      old.cellSize != cellSize;
}

/// ピースを横並びで表示するトレイ。
///
/// トレイ全体を 1 つの Listener で覆い、触れた座標から最近傍のピースを選んで掴む
/// （正方形・最近傍判定）。掴み範囲は [FeelConfig.trayPickupRadius]（トレイセル単位）で調整。
/// [FeelConfig.dragStartSlop] 以上ポインタが動いた時点で方向を判定する:
///   縦方向（上下どちらでも） → 掴み開始（onPickup）
///   横方向（真横寄り） → スクロールに委譲し掴みは発火しない。
/// Listener はジェスチャアリーナに参加しないため、委譲時も親の
/// SingleChildScrollView が横スクロールを受け取れる。
class PieceTray extends StatefulWidget {
  const PieceTray({
    super.key,
    required this.puzzle,
    required this.feelConfig,
    required this.orientationOf,
    required this.onTapPiece,
    required this.onFlipPiece,
    required this.onPickup,
    required this.onMove,
    required this.onDrop,
    this.hiddenIndices = const {},
  });

  final GeneratedPuzzle puzzle;
  final FeelConfig feelConfig;

  /// ピース [index] の現在の向き（ADR-0019）。描画・最近傍判定に使う。
  final PolyominoData Function(int index) orientationOf;

  /// ピース [index] がタップされたとき（回転）に呼ばれる。
  final void Function(int index) onTapPiece;

  /// ピース [index] がダブルタップされたとき（左右反転）に呼ばれる（②.5 反転UI）。
  final void Function(int index) onFlipPiece;

  final void Function(int index, Offset pointerGlobal, Offset itemGlobal)
  onPickup;
  final void Function(Offset pointerGlobal) onMove;
  final void Function(Offset pointerGlobal) onDrop;

  /// 非表示にするピースのインデックス集合（配置済み・ドラッグ中）。
  final Set<int> hiddenIndices;

  static const double _trayCell = 28.0;

  @override
  State<PieceTray> createState() => _PieceTrayState();
}

class _PieceTrayState extends State<PieceTray> {
  /// 左詰めで隙間が閉じる/開くアニメーションの所要時間。
  /// 実機で詰めたくなったら FeelConfig へ昇格させる。
  static const int _reflowMs = 160;

  final ScrollController _scrollCtrl = ScrollController();

  Offset? _downPosition;
  int? _pickedIndex;
  bool _dragging = false;

  /// true のとき、このジェスチャはスクロールに委譲済み（掴みは発火しない）。
  bool _scrollDelegated = false;

  /// ダブルタップ（反転）判定の待ち時間。1 回目のタップからこの時間内に
  /// 同じピースを再タップしたら反転、時間切れなら回転を発火する。
  /// 実機評価により 250ms は回転の遅延が気になったため 125ms に短縮した
  /// （ADR-0019 ③）。さらに詰めたくなったら FeelConfig へ昇格させる。
  static const int _doubleTapMs = 125;

  /// 回転を保留しているタイマー（ダブルタップ待ち）。dispose でキャンセルする。
  Timer? _tapTimer;

  /// 回転を保留しているピースの index（ダブルタップ待ち）。
  int? _pendingTapIndex;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  double get _scrollOffset => _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;

  // ピース i の描画幅・高さ（hitboxPad を除く）
  double _pieceDrawWidth(int i) {
    final cells = widget.orientationOf(i).cells;
    final minX = cells.map((c) => c.$2).reduce(min);
    final maxX = cells.map((c) => c.$2).reduce(max);
    return (maxX - minX + 1) * PieceTray._trayCell;
  }

  double _pieceDrawHeight(int i) {
    final cells = widget.orientationOf(i).cells;
    final minY = cells.map((c) => c.$1).reduce(min);
    final maxY = cells.map((c) => c.$1).reduce(max);
    return (maxY - minY + 1) * PieceTray._trayCell;
  }

  // Row 内でアイテム（Padding(horizontal:12) の内側）が占める幅・高さ（hitboxPad 込み）
  double _itemWidth(int i) =>
      _pieceDrawWidth(i) + widget.feelConfig.hitboxPad * 2;
  // ピース i の内容左端のコンテンツ座標（スクロール前）。
  // 左詰め: 非表示（配置済み・ドラッグ中）のピースは幅 0 として詰める。
  // 計算は純粋関数 packedItemStartX に委譲し CI で検証する。
  double _contentItemStartX(int i) => packedItemStartX(
    itemWidths: [
      for (var j = 0; j < widget.puzzle.blocks.length; j++) _itemWidth(j),
    ],
    hidden: widget.hiddenIndices,
    index: i,
  );

  // ピース i の全セル中心のコンテンツ座標リスト（最近傍計算に使う）。
  List<Offset> _cellCentersInContent(int i) {
    final cells = widget.orientationOf(i).cells;
    final minY = cells.map((c) => c.$1).reduce(min);
    final minX = cells.map((c) => c.$2).reduce(min);

    // CustomPaint 左上のコンテンツ座標（hitboxPad のパディングを加算）
    final startX = _contentItemStartX(i) + widget.feelConfig.hitboxPad;
    const startY = 8.0; // scrollPadding.top

    return cells
        .map(
          (c) => Offset(
            startX + (c.$2 - minX + 0.5) * PieceTray._trayCell,
            startY +
                widget.feelConfig.hitboxPad +
                (c.$1 - minY + 0.5) * PieceTray._trayCell,
          ),
        )
        .toList();
  }

  // ピース i の中心のグローバル座標（onPickup の itemGlobal として渡す戻り先）。
  Offset _itemCenterGlobal(int i) {
    final box = context.findRenderObject() as RenderBox;
    final contentCenterX =
        _contentItemStartX(i) +
        widget.feelConfig.hitboxPad +
        _pieceDrawWidth(i) / 2;
    const contentTopY = 8.0; // scrollPadding.top
    final contentCenterY =
        contentTopY + widget.feelConfig.hitboxPad + _pieceDrawHeight(i) / 2;
    return box.localToGlobal(
      Offset(contentCenterX - _scrollOffset, contentCenterY),
    );
  }

  void _onPointerDown(PointerDownEvent e) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(e.position);
    // スクロールオフセットを加算してコンテンツ座標に変換
    final contentX = local.dx + _scrollOffset;
    final contentY = local.dy;

    final hRad = widget.feelConfig.trayPickupRadius * PieceTray._trayCell;
    final upRad = widget.feelConfig.trayPickupRadius * PieceTray._trayCell;
    final downRad =
        (widget.feelConfig.trayPickupRadius +
            widget.feelConfig.trayPickupDownBonus) *
        PieceTray._trayCell;
    int? bestIndex;
    double bestDist = double.infinity;

    for (int i = 0; i < widget.puzzle.blocks.length; i++) {
      if (widget.hiddenIndices.contains(i)) continue;
      for (final center in _cellCentersInContent(i)) {
        final dxAbs = (center.dx - contentX).abs();
        // contentY - center.dy > 0 のとき触れた点はセル中心より下（画面座標は下が正）
        final dyRaw = contentY - center.dy;
        final vLimit = dyRaw > 0 ? downRad : upRad;
        final dyAbs = dyRaw.abs();
        if (dxAbs <= hRad && dyAbs <= vLimit) {
          // 横・縦それぞれの許容で正規化した最大値（非対称な箱）で最近傍を選ぶ
          final nd = max(dxAbs / hRad, dyAbs / vLimit);
          if (nd < bestDist) {
            bestDist = nd;
            bestIndex = i;
          }
        }
      }
    }

    _downPosition = e.position;
    _pickedIndex = bestIndex;
    _dragging = false;
    _scrollDelegated = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_dragging) {
      widget.onMove(e.position);
      return;
    }
    // スクロール委譲済み、またはピースが選ばれていない場合は何もしない
    if (_scrollDelegated || _pickedIndex == null) return;

    final down = _downPosition;
    if (down == null) return;
    final d = e.position - down;
    if (d.distance < widget.feelConfig.dragStartSlop) return;

    // slop 超え → 方向で掴みかスクロールかを決定する
    // 縦方向（上下どちらでも）に動けば掴み、横に動けばスクロール
    final dyAbs = d.dy.abs();
    final dxAbs = d.dx.abs();

    if (dyAbs >= dxAbs * widget.feelConfig.grabDirectionRatio) {
      // 縦方向（上下どちらでも）の動き → 掴み開始
      _dragging = true;
      final index = _pickedIndex!;
      _cancelPendingTapForDragStart(index);
      widget.onPickup(index, e.position, _itemCenterGlobal(index));
    } else {
      // 横方向（真横寄り） → スクロールに委譲（以後このジェスチャでは掴まない）
      _scrollDelegated = true;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_dragging) {
      widget.onDrop(e.position);
    } else if (!_scrollDelegated && _pickedIndex != null) {
      // 指がほぼ動かなかった = タップ → 回転
      // （縦ドラッグ=掴み / 横ドラッグ=スクロール と排他になる）
      final down = _downPosition;
      if (down != null &&
          (e.position - down).distance < widget.feelConfig.dragStartSlop) {
        _handleTap(_pickedIndex!);
      }
    }
    _reset();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_dragging) widget.onDrop(e.position);
    _reset();
  }

  void _reset() {
    _downPosition = null;
    _pickedIndex = null;
    _dragging = false;
    _scrollDelegated = false;
  }

  /// ドラッグ開始が確定した際、保留中のタップ判定（ダブルタップ待ち）を
  /// 解消する（PR #93: ドラッグ中に保留タイマーが誤って回転を発火する
  /// バグの修正）。
  ///
  /// ドラッグ開始する [dragIndex] のタップが保留中なら、それは
  /// ドラッグの起点となった 1 回目のタップなのでキャンセルして破棄する
  /// （回転させない）。別ピースのタップが保留中なら、その回転を
  /// 先に確定してから保留をクリアする（_handleTap の「別ピース」分岐と同じ扱い）。
  void _cancelPendingTapForDragStart(int dragIndex) {
    final timer = _tapTimer;
    final pending = _pendingTapIndex;
    if (timer == null || !timer.isActive) return;

    timer.cancel();
    _tapTimer = null;
    _pendingTapIndex = null;
    if (pending != null && pending != dragIndex) {
      widget.onTapPiece(pending);
    }
  }

  /// タップを回転／反転に振り分ける（②.5 反転UI・ADR-0019 追補）。
  ///
  /// トレイは自前のポインタ処理（GestureDetector ではなく Listener）でタップを
  /// 検出しているため、Flutter 標準の onDoubleTap が使えない。ここで手動判定する:
  /// 1 回目のタップは即座に回転せず [_doubleTapMs] だけ待つ。待っている間に
  /// 同じピースを再タップしたら「ダブルタップ＝反転」とみなし回転しない。
  /// 別ピースをタップしたら保留中の回転を先に確定してから新しいタップを保留する。
  /// 時間切れなら「シングルタップ＝回転」を発火する。
  void _handleTap(int index) {
    final timer = _tapTimer;
    final pending = _pendingTapIndex;

    // 同じピースの 2 回目 → ダブルタップ＝反転（保留中の回転はキャンセル）
    if (timer != null && timer.isActive && pending == index) {
      timer.cancel();
      _tapTimer = null;
      _pendingTapIndex = null;
      widget.onFlipPiece(index);
      return;
    }

    // 別ピースの保留が残っていれば、その回転を先に確定する
    if (timer != null && timer.isActive && pending != null) {
      timer.cancel();
      widget.onTapPiece(pending);
    }

    // このタップを保留し、時間切れで回転を発火する
    _pendingTapIndex = index;
    _tapTimer = Timer(const Duration(milliseconds: _doubleTapMs), () {
      final fire = _pendingTapIndex;
      _tapTimer = null;
      _pendingTapIndex = null;
      if (fire != null) widget.onTapPiece(fire);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Container(
        color: const Color(0xFFEAE5D8),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.puzzle.blocks.length; i++)
                AnimatedSize(
                  key: ValueKey('tray-piece-$i'),
                  duration: const Duration(milliseconds: _reflowMs),
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  child: widget.hiddenIndices.contains(i)
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Padding(
                            padding: EdgeInsets.all(
                              widget.feelConfig.hitboxPad,
                            ),
                            child: CustomPaint(
                              size: Size(
                                _pieceDrawWidth(i),
                                _pieceDrawHeight(i),
                              ),
                              painter: PiecePainter(
                                orientation: widget.orientationOf(i),
                                colorIndex: i,
                                cellSize: PieceTray._trayCell,
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
