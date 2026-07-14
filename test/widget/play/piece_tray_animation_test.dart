// piece_tray.dart に追加したピース変形アニメ（回転=平面回転 / 反転=Y軸カード裏返し）の
// リグレッションテスト。
//
// アニメの「美しさ」自体はテストできないため、ここでは以下だけを検証する:
//   - 既存の待ちなし方式（ADR-0019）のタップ判定が壊れていないこと
//   - アニメ進行中に pump / ドラッグ開始しても例外が出ないこと（要件C）
//   - アニメ完了後、描画内容が最終状態（orientationOf の値・shade=1.0）に
//     正しく収束すること（鏡像バグ・暗転固定バグの検出）
//   - 反転アニメの中間で、描画に使われる orientation が「反転前」または
//     「反転後」以外の不正な値にならないこと（鏡像バグの検出）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/difficulty.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';
import 'package:polyrush/domain/puzzle/puzzle_generator.dart';
import 'package:polyrush/game/play/feel_config.dart';
import 'package:polyrush/game/play/piece_orientation_state.dart';
import 'package:polyrush/ui/screens/play/piece_tray.dart';

GeneratedPuzzle _buildTestPuzzle() {
  // 非対称ピース（L3）を使い、回転・反転で見た目が変わることを確実にする。
  final block0 = PlacedBlock(source: kL3, orientation: kL3, cells: kL3.cells);
  final block1 = PlacedBlock(source: kL3, orientation: kL3, cells: kL3.cells);
  return GeneratedPuzzle(
    frame: {...block0.cells, ...block1.cells},
    boundingBox: (minY: 0, maxY: 2, minX: 0, maxX: 2),
    blocks: [block0, block1],
    seed: 1,
    difficulty: Difficulty.easy,
  );
}

/// PlayScreen 実装を模した最小のテストハーネス。
/// _onTapPiece/_onFlipPiece と同じロジック（rotateCw / rotateCcw+flip）で
/// PieceOrientationState を更新する。play_screen.dart 自体は変更しない
/// （指示書の要件どおり、UI層=piece_tray.dart に閉じたテストにする）。
class _Harness extends StatefulWidget {
  const _Harness({required this.puzzle});
  final GeneratedPuzzle puzzle;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late PieceOrientationState orientations;
  int tapCount = 0;
  int flipCount = 0;
  int pickupCount = 0;
  int dropCount = 0;
  Set<int> hidden = {};

  @override
  void initState() {
    super.initState();
    orientations = PieceOrientationState.fromPuzzle(widget.puzzle);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: PieceTray(
          puzzle: widget.puzzle,
          feelConfig: const FeelConfig(),
          orientationOf: (i) => orientations.orientationOf(i),
          onTapPiece: (i) {
            setState(() {
              orientations.rotateCw(i);
              tapCount++;
            });
          },
          onFlipPiece: (i) {
            setState(() {
              orientations.rotateCcw(i);
              orientations.flip(i);
              flipCount++;
            });
          },
          onPickup: (i, pointerGlobal, itemGlobal) {
            pickupCount++;
            setState(() => hidden = {i});
          },
          onMove: (_) {},
          onDrop: (_) {
            dropCount++;
            setState(() => hidden = {});
          },
          hiddenIndices: hidden,
        ),
      ),
    );
  }
}

PiecePainter _painterFor(WidgetTester tester, int index) {
  final piece = find.byKey(ValueKey('tray-piece-$index'));
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: piece, matching: find.byType(CustomPaint)),
  );
  return customPaint.painter! as PiecePainter;
}

Future<TestGesture> _tap(WidgetTester tester, Offset at) async {
  final gesture = await tester.startGesture(at);
  await gesture.up();
  return gesture;
}

void main() {
  group('PieceTray アニメ（回転・反転）', () {
    testWidgets('シングルタップで onTapPiece が発火し、アニメ進行中の pump で例外が出ない', (
      tester,
    ) async {
      final puzzle = _buildTestPuzzle();
      await tester.pumpWidget(_Harness(puzzle: puzzle));

      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      final piece0 = find.byKey(const ValueKey('tray-piece-0'));
      await _tap(tester, tester.getCenter(piece0));
      await tester.pump();

      expect(harness.tapCount, 1, reason: 'シングルタップで onTapPiece が1回発火する');
      expect(harness.flipCount, 0, reason: 'シングルタップでは onFlipPiece は発火しない');

      // アニメ（180ms）の途中で複数回 pump しても例外が出ない。
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull, reason: '回転アニメ進行中の pump で例外が出ない');

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'アニメ完了までの pump で例外が出ない');
    });

    testWidgets('ダブルタップで onFlipPiece が発火する（待ちなし方式が壊れていない）', (tester) async {
      final puzzle = _buildTestPuzzle();
      await tester.pumpWidget(_Harness(puzzle: puzzle));

      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      final piece0 = find.byKey(const ValueKey('tray-piece-0'));
      final center = tester.getCenter(piece0);

      await _tap(tester, center);
      await tester.pump();
      await _tap(tester, center);
      await tester.pump();

      expect(harness.tapCount, 1, reason: '1回目のタップで回転(onTapPiece)が即座に1回発火する');
      expect(harness.flipCount, 1, reason: '2回目のタップ（窓内）で反転(onFlipPiece)が発火する');

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '反転アニメ完了までの pump で例外が出ない');
    });

    testWidgets('回転アニメ完了後、orientation と shade が最終状態に収束する', (tester) async {
      final puzzle = _buildTestPuzzle();
      await tester.pumpWidget(_Harness(puzzle: puzzle));

      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      final piece0 = find.byKey(const ValueKey('tray-piece-0'));
      await _tap(tester, tester.getCenter(piece0));
      await tester.pumpAndSettle();

      final painter = _painterFor(tester, 0);
      expect(
        painter.orientation,
        harness.orientations.orientationOf(0),
        reason: '回転アニメ収束後、描画 orientation が現在の向きと一致する',
      );
      expect(painter.shade, 1.0, reason: '回転アニメでは shade は常に 1.0 のまま');
    });

    testWidgets('反転アニメ完了後、orientation と shade が最終状態に収束する（鏡像・暗転固定バグ検出）', (
      tester,
    ) async {
      final puzzle = _buildTestPuzzle();
      await tester.pumpWidget(_Harness(puzzle: puzzle));

      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      final piece0 = find.byKey(const ValueKey('tray-piece-0'));
      final center = tester.getCenter(piece0);

      await _tap(tester, center);
      await tester.pump();
      await _tap(tester, center);
      await tester.pumpAndSettle();

      final painter = _painterFor(tester, 0);
      expect(
        painter.orientation,
        harness.orientations.orientationOf(0),
        reason: '反転アニメ収束後、描画 orientation が現在の向き(=反転後)と一致する（鏡像バグがあれば不一致になる）',
      );
      expect(painter.shade, 1.0, reason: '反転アニメ収束後、暗転したまま固まっていない');
    });

    testWidgets('アニメ進行中にドラッグを開始しても例外が出ずコールバックが発火する', (tester) async {
      final puzzle = _buildTestPuzzle();
      await tester.pumpWidget(_Harness(puzzle: puzzle));

      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      final piece0 = find.byKey(const ValueKey('tray-piece-0'));
      final center = tester.getCenter(piece0);

      // タップして回転アニメを開始し、完了前に別ジェスチャでドラッグを開始する。
      await _tap(tester, center);
      await tester.pump(const Duration(milliseconds: 30));

      final dragGesture = await tester.startGesture(center);
      await dragGesture.moveBy(const Offset(0, -160));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'アニメ進行中のドラッグ開始で例外が出ない');
      expect(harness.pickupCount, 1, reason: 'ドラッグ開始で onPickup が発火する');

      await dragGesture.up();
      await tester.pumpAndSettle();
      expect(harness.dropCount, 1, reason: '指を離すと onDrop が発火する');
      expect(tester.takeException(), isNull, reason: 'ドロップ後も例外が出ない');
    });

    testWidgets('反転アニメの中間では描画 orientation が反転前・反転後のいずれかである', (tester) async {
      final puzzle = _buildTestPuzzle();
      await tester.pumpWidget(_Harness(puzzle: puzzle));

      final harness = tester.state<_HarnessState>(find.byType(_Harness));
      final piece0 = find.byKey(const ValueKey('tray-piece-0'));
      final center = tester.getCenter(piece0);

      final before = harness.orientations.orientationOf(0);

      await _tap(tester, center);
      await tester.pump();
      await _tap(tester, center);
      await tester.pump();

      final after = harness.orientations.orientationOf(0);

      // 反転アニメ（260ms）の半分あたりまで進める。
      await tester.pump(const Duration(milliseconds: 130));

      final painter = _painterFor(tester, 0);
      expect(
        painter.orientation == before || painter.orientation == after,
        isTrue,
        reason: '反転アニメ中間の描画 orientation は反転前後のいずれかでなければならない（鏡像バグ検出）',
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
