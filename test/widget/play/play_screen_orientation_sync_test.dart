// PR #89 の状態同期バグ（「次へ」で _result だけ更新され _orientations が
// 前パズルのまま残る）のリグレッションテスト。
//
// _applyResult() ヘルパーにより _result と _orientations は常にセットで
// 更新される。その不変条件が初期ロード・「次へ」の両方で保たれることを
// PlayScreenState.debugOrientationsInSyncWithResult() で検証する。
//
// 「次へ」ボタン自体はクリアオーバーレイ内にしか出ず、クリアはピクセル
// 依存で widget テストが不安定になるため、状態遷移は debugGoToNextPuzzle()
// フックから直接叩く。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/ui/screens/play/play_screen.dart';

void main() {
  group('PlayScreen 状態同期（PR #89 リグレッション）', () {
    testWidgets('初期ロード直後、_orientations は _result と同期している', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlayScreen()));

      final state = tester.state<PlayScreenState>(find.byType(PlayScreen));
      expect(
        state.debugOrientationsInSyncWithResult(),
        isTrue,
        reason: '初期ロード時点で _orientations が現在のパズルと一致する',
      );
    });

    testWidgets('「次へ」を繰り返しても _orientations は毎回 _result と同期する', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlayScreen()));

      final state = tester.state<PlayScreenState>(find.byType(PlayScreen));

      for (var i = 0; i < 10; i++) {
        state.debugGoToNextPuzzle();
        await tester.pump();

        expect(
          state.debugOrientationsInSyncWithResult(),
          isTrue,
          reason: '「次へ」${i + 1} 回目の後も _orientations が新パズルと一致する',
        );
        expect(tester.takeException(), isNull, reason: '「次へ」後に例外が発生しない');
      }
    });
  });
}
