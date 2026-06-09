import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/ui/screens/play/tray_layout.dart';

void main() {
  group('packedItemStartX', () {
    final widths = [40.0, 60.0, 50.0];

    test('隠れアイテムが無いとき各アイテムは順に詰む', () {
      expect(packedItemStartX(itemWidths: widths, hidden: {}, index: 0),
          16 + 12, reason: '先頭 = 左padding16 + 左gap12');
      expect(packedItemStartX(itemWidths: widths, hidden: {}, index: 1),
          16 + (12 + 40 + 12) + 12);
      expect(packedItemStartX(itemWidths: widths, hidden: {}, index: 2),
          16 + (12 + 40 + 12) + (12 + 60 + 12) + 12);
    });

    test('隠れアイテムは幅0として詰められ後続が左に寄る', () {
      expect(packedItemStartX(itemWidths: widths, hidden: {1}, index: 2),
          16 + (12 + 40 + 12) + 12, reason: 'index1 を飛ばす');
    });

    test('先頭が隠れると2番目が先頭位置に詰む', () {
      expect(packedItemStartX(itemWidths: [40.0, 60.0], hidden: {0}, index: 1),
          16 + 12);
    });

    test('padding を変えても計算が一致する', () {
      expect(
        packedItemStartX(
            itemWidths: [40.0, 60.0],
            hidden: {},
            index: 1,
            scrollPaddingLeft: 0,
            itemHGap: 0),
        40,
      );
    });
  });
}
