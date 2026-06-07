import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/game/board/play_board_painter.dart';
import 'package:polyrush/ui/screens/play/play_screen.dart';

void main() {
  group('PlayScreen', () {
    group('A. ビルド', () {
      testWidgets('例外なしでビルドできる', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: PlayScreen()));
        expect(
          tester.takeException(),
          isNull,
          reason: 'PlayScreen が例外なしでビルドされる',
        );
      });

      testWidgets('トレイピース 3 個が存在する（easy=3 ブロック）', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: PlayScreen()));
        expect(
          find.byKey(const ValueKey('tray-piece-0')),
          findsOneWidget,
          reason: 'ピース 0 がトレイにある',
        );
        expect(
          find.byKey(const ValueKey('tray-piece-1')),
          findsOneWidget,
          reason: 'ピース 1 がトレイにある',
        );
        expect(
          find.byKey(const ValueKey('tray-piece-2')),
          findsOneWidget,
          reason: 'ピース 2 がトレイにある',
        );
      });

      testWidgets('PlayBoardPainter を持つ CustomPaint が存在する', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: PlayScreen()));
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .toList();
        expect(
          painters.any((w) => w.painter is PlayBoardPainter),
          isTrue,
          reason: 'PlayBoardPainter が CustomPaint として存在する',
        );
      });
    });

    group('B. ドラッグ', () {
      testWidgets('ピース 0 をドラッグして離すとトレイへ戻る', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: PlayScreen()));

        await tester.drag(
          find.byKey(const ValueKey('tray-piece-0')),
          const Offset(60, -160),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'ドラッグ中に例外が発生しない',
        );
        expect(
          find.byKey(const ValueKey('tray-piece-0')),
          findsOneWidget,
          reason: '離した後もトレイにピース 0 が存在する',
        );
      });
    });
  });
}
