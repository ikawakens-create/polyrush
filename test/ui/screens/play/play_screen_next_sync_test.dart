import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/ui/screens/play/play_screen.dart';

void main() {
  testWidgets('「次へ」後も orientations が現在のパズルに同期している（回帰: _goNext）',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PlayScreen()));
    await tester.pumpAndSettle();

    final dynamic s = tester.state(find.byType(PlayScreen));

    expect(s.debugOrientationsInSync, isTrue,
        reason: '初期パズルで orientations が同期していない');

    for (var i = 0; i < 8; i++) {
      s.debugGoNext();
      await tester.pumpAndSettle();
      expect(s.debugOrientationsInSync, isTrue,
          reason: '「次へ」${i + 1} 回目の後、orientations が新パズルに同期していない');
    }
  });
}
