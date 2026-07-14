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

/// ピース回転アニメ（平面内で -90°→0°）の所要時間。実機体感で調整する。
const int _rotateAnimMs = 180;

/// ピース反転（Y軸カード裏返し）アニメの所要時間。実機体感で調整する。
const int _flipAnimMs = 260;

/// 反転アニメ中間地点（t=0.5）での最大暗さ係数。
/// shade = 1.0 - _flipShadeDepth * sin(pi*t)（t=0.5 で最も暗い）。
const double _flipShadeDepth = 0.35;

/// ピース 1 個を指定セルサイズで描く汎用ペインタ。
///
/// トレイのサムネイルとドラッグ中の浮いたピースの両方に使う。
/// [block.orientation.cells] を (0,0) 基点に正規化して描画する。
class PiecePainter extends CustomPainter {
  const PiecePainter({
    required this.orientation,
    required this.colorIndex,
    required this.cellSize,
    this.shade = 1.0,
  });

  final PolyominoData orientation;
  final int colorIndex;
  final double cellSize;

  /// 反転（カード裏返し）アニメ中の明度係数（1.0=通常、小さいほど暗い）。
  final double shade;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = _pieceColors[colorIndex % _pieceColors.length];
    final color = shade >= 1.0
        ? baseColor
        : Color.lerp(baseColor, Colors.black, 1.0 - shade)!;
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
      old.cellSize != cellSize ||
      old.shade != shade;
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

class _PieceTrayState extends State<PieceTray> with TickerProviderStateMixin {
  /// 左詰めで隙間が閉じる/開くアニメーションの所要時間。
  /// 実機で詰めたくなったら FeelConfig へ昇格させる。
  static const int _reflowMs = 160;

  final ScrollController _scrollCtrl = ScrollController();

  /// ピースごとの回転／反転アニメ（見た目のみ・ドメイン不触）。
  final Map<int, AnimationController> _rotateCtrl = {};
  final Map<int, AnimationController> _flipCtrl = {};

  /// 反転アニメの「反転前」の形。1 回目のタップ（回転適用前）の時点で
  /// 確保しておく（ADR-0019 待ちなし方式では 2 回目のタップ時点だと
  /// すでに回転後の状態になっているため）。
  final Map<int, PolyominoData> _flipBeforeOrientation = {};

  Offset? _downPosition;
  int? _pickedIndex;
  bool _dragging = false;

  /// true のとき、このジェスチャはスクロールに委譲済み（掴みは発火しない）。
  bool _scrollDelegated = false;

  /// ダブルタップ（反転）判定の窓。1 回目のタップからこの時間内に同じピースを
  /// 再タップしたらダブルタップ＝反転とみなす（待ちなし方式）。
  /// 待ちあり方式（Timer で回転を保留）は「窓を短くすると反転が不安定、
  /// 長くすると回転がもっさりする」ジレンマがあったため廃止した。
  /// 待ちなし方式は 1 回目のタップで即座に回転を発火するため回転遅延がゼロになり、
  /// 判定窓を広げられる。実機評価（125ms では2回目のタップが間に合わない）により
  /// 300ms に設定した（ADR-0019 追補）。
  static const int _doubleTapMs = 300;

  /// 直前にタップしたピースの index（ダブルタップ判定用）。
  int? _lastTapIndex;

  /// 直前にタップした時刻（ダブルタップ判定用）。
  DateTime? _lastTapTime;

  @override
  void dispose() {
    for (final c in _rotateCtrl.values) {
      c.dispose();
    }
    for (final c in _flipCtrl.values) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PieceTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.puzzle, oldWidget.puzzle)) {
      // 新しいパズル → 前のパズルのピースに紐づくアニメ状態を破棄する。
      for (final c in _rotateCtrl.values) {
        c.dispose();
      }
      for (final c in _flipCtrl.values) {
        c.dispose();
      }
      _rotateCtrl.clear();
      _flipCtrl.clear();
      _flipBeforeOrientation.clear();
      _lastTapIndex = null;
      _lastTapTime = null;
    }
  }

  AnimationController _rotateControllerFor(int index) =>
      _rotateCtrl.putIfAbsent(
        index,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: _rotateAnimMs),
          value: 1.0, // 未操作時はアイドル（角度 0）
        ),
      );

  AnimationController _flipControllerFor(int index) => _flipCtrl.putIfAbsent(
    index,
    () => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _flipAnimMs),
      value: 1.0, // 未操作時はアイドル（角度 0・shade 1.0）
    ),
  );

  /// 回転タップ発火時: そのピースの反転アニメを即座にアイドルへ戻し、
  /// 回転アニメを最初から再生する。
  void _startRotateAnimation(int index) {
    final flip = _flipCtrl[index];
    flip?.stop();
    flip?.value = 1.0;
    final ctrl = _rotateControllerFor(index);
    ctrl.stop();
    ctrl.value = 0.0;
    ctrl.forward();
  }

  /// 反転タップ発火時: 進行中の回転アニメを中間状態を残さず即座に破棄し
  /// （要件A）、反転アニメだけを最初から再生する。
  void _startFlipAnimation(int index, PolyominoData before) {
    final rotate = _rotateCtrl[index];
    rotate?.stop();
    rotate?.value = 1.0;
    _flipBeforeOrientation[index] = before;
    final ctrl = _flipControllerFor(index);
    ctrl.stop();
    ctrl.value = 0.0;
    ctrl.forward();
  }

  /// ドラッグ開始時: 中途半端な傾きのままドラッグへ入らないよう、
  /// そのピースのアニメを即座に終了状態へスナップする（要件C）。
  void _snapAnimationsToEnd(int index) {
    final rotate = _rotateCtrl[index];
    rotate?.stop();
    rotate?.value = 1.0;
    final flip = _flipCtrl[index];
    flip?.stop();
    flip?.value = 1.0;
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
      _clearTapRecordForDragStart();
      _snapAnimationsToEnd(index);
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

  /// ドラッグ開始が確定した際、直前のタップ記録（ダブルタップ判定用）を
  /// クリアする。タップ→ドラッグ→タップという連続操作で、ドラッグ後の
  /// 新しいタップが直前のタップとのダブルタップとして誤判定されるのを防ぐ。
  void _clearTapRecordForDragStart() {
    _lastTapIndex = null;
    _lastTapTime = null;
  }

  /// タップを回転／反転に振り分ける（待ちなし方式・ADR-0019 追補）。
  ///
  /// トレイは自前のポインタ処理（GestureDetector ではなく Listener）でタップを
  /// 検出しているため、Flutter 標準の onDoubleTap が使えない。ここで手動判定する:
  /// タップのたびに即座に widget.onTapPiece（回転）を発火する（待ちなし）。
  /// 直前と同じピースが [_doubleTapMs] 以内に再タップされたら、それは
  /// ダブルタップ＝反転とみなし widget.onFlipPiece を発火する
  /// （1 回目のタップで発火済みの回転は onFlipPiece 側で打ち消す）。
  void _handleTap(int index) {
    final now = DateTime.now();
    final lastIndex = _lastTapIndex;
    final lastTime = _lastTapTime;

    if (lastIndex == index &&
        lastTime != null &&
        now.difference(lastTime).inMilliseconds <= _doubleTapMs) {
      // 同じピースの 2 回目 → ダブルタップ＝反転。直後の 3 回目のタップは
      // 記録をクリアするため新規の 1 回目として扱われる。
      // 反転前の形は 1 回目のタップ時点（回転適用前）に確保済みのものを使う
      // （この時点の widget.orientationOf は既に回転後の値のため使えない）。
      final before =
          _flipBeforeOrientation[index] ?? widget.orientationOf(index);
      widget.onFlipPiece(index);
      _startFlipAnimation(index, before);
      _lastTapIndex = null;
      _lastTapTime = null;
      return;
    }

    // 新規の 1 回目のタップ（または別ピース）→ 即座に回転を発火。
    // 2 回目のタップが反転になった場合に備え、回転適用前の形を確保しておく。
    _flipBeforeOrientation[index] = widget.orientationOf(index);
    widget.onTapPiece(index);
    _startRotateAnimation(index);
    _lastTapIndex = index;
    _lastTapTime = now;
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
                            child: _buildPieceVisual(i),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ピース [i] の見た目（回転・反転アニメの Transform で包んだ CustomPaint）。
  ///
  /// レイアウトサイズ（CustomPaint の size）は常に現在の
  /// [PieceTray.orientationOf] を基準にし、アニメの進行状況に左右されない
  /// （要件B）。Transform は描画のみに適用する。
  Widget _buildPieceVisual(int i) {
    final rotateCtrl = _rotateControllerFor(i);
    final flipCtrl = _flipControllerFor(i);
    final size = Size(_pieceDrawWidth(i), _pieceDrawHeight(i));

    return AnimatedBuilder(
      animation: Listenable.merge([rotateCtrl, flipCtrl]),
      builder: (context, _) {
        if (flipCtrl.value < 1.0) {
          final t = Curves.easeInOut.transform(flipCtrl.value);
          final before = _flipBeforeOrientation[i] ?? widget.orientationOf(i);
          final PolyominoData content;
          final double angleY;
          if (t < 0.5) {
            content = before;
            angleY = pi * t;
          } else {
            content = widget.orientationOf(i);
            angleY = pi * t - pi;
          }
          final shade = 1.0 - _flipShadeDepth * sin(pi * t);
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angleY);
          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: CustomPaint(
              size: size,
              painter: PiecePainter(
                orientation: content,
                colorIndex: i,
                cellSize: PieceTray._trayCell,
                shade: shade,
              ),
            ),
          );
        }

        final rotT = Curves.easeOutCubic.transform(rotateCtrl.value);
        final angle = -pi / 2 + pi / 2 * rotT;
        return Transform.rotate(
          angle: angle,
          alignment: Alignment.center,
          child: CustomPaint(
            size: size,
            painter: PiecePainter(
              orientation: widget.orientationOf(i),
              colorIndex: i,
              cellSize: PieceTray._trayCell,
            ),
          ),
        );
      },
    );
  }
}
