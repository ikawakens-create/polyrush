import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/domain/puzzle/frame_connectivity.dart';
import 'package:polyrush/domain/puzzle/polyomino.dart';

void main() {
  // ─── 1. 単純な形（true） ──────────────────────────────────────────────────
  group('単純な形（true）', () {
    test('1マス', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 0)}),
        isTrue,
        reason: '1マスは穴なし・連結',
      );
    });

    test('直線（横3マス）', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 0), (0, 1), (0, 2)}),
        isTrue,
        reason: '直線は穴なし・連結',
      );
    });

    test('L字（3マス）', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 0), (1, 0), (1, 1)}),
        isTrue,
        reason: 'L字は穴なし・連結',
      );
    });

    test('十字（X5 形状）', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)}),
        isTrue,
        reason: '十字は穴なし・連結',
      );
    });

    test('2x2 正方形', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 0), (0, 1), (1, 0), (1, 1)}),
        isTrue,
        reason: '2x2 正方形は穴なし・連結',
      );
    });

    test('C字（外に開いた凹み）', () {
      // ###
      // #
      // ###
      final frame = <Cell>{
        (0, 0), (0, 1), (0, 2),
        (1, 0),
        (2, 0), (2, 1), (2, 2),
      };
      expect(
        isFrameSimplyConnected(frame),
        isTrue,
        reason: 'C字の凹みは外に開いているため穴ではない',
      );
    });
  });

  // ─── 2. 穴あり（false） ───────────────────────────────────────────────────
  group('穴あり（false）', () {
    test('3x3 ドーナツ（中央1マスが穴）', () {
      // ###
      // # #
      // ###
      final frame = <Cell>{
        (0, 0), (0, 1), (0, 2),
        (1, 0), (1, 2),
        (2, 0), (2, 1), (2, 2),
      };
      expect(
        isFrameSimplyConnected(frame),
        isFalse,
        reason: '中央 (1,1) が 4 方向を frame に囲まれた穴',
      );
    });

    test('大きめ枠に1マスの内部穴', () {
      // ####
      // # ##   ← (1,1) が穴
      // ####
      final frame = <Cell>{
        (0, 0), (0, 1), (0, 2), (0, 3),
        (1, 0), (1, 2), (1, 3),
        (2, 0), (2, 1), (2, 2), (2, 3),
      };
      expect(
        isFrameSimplyConnected(frame),
        isFalse,
        reason: '(1,1) が 4 方向すべてを frame で囲まれた穴',
      );
    });

    test('対角ピンチで挟まれた空きマス（4-連結 Flood Fill で穴と判定）', () {
      // .#.
      // #.#   ← (1,1) は 4-近傍すべてが frame
      // .#.
      final frame = <Cell>{(0, 1), (1, 0), (1, 2), (2, 1)};
      expect(
        isFrameSimplyConnected(frame),
        isFalse,
        reason:
            'ダイヤモンド形の中央 (1,1) は 4-連結では外から到達不能な穴。'
            '8-連結なら対角を通れるが 4-連結では穴として弾く（ADR-0009 判断3）',
      );
    });
  });

  // ─── 3. 非連結（false） ───────────────────────────────────────────────────
  group('非連結（false）', () {
    test('離れた2マス', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 0), (0, 2)}),
        isFalse,
        reason: '(0,0) と (0,2) の間に (0,1) がなく 4-連結でない',
      );
    });

    test('角だけで接する2マス（対角のみ）', () {
      expect(
        isFrameSimplyConnected(<Cell>{(0, 0), (1, 1)}),
        isFalse,
        reason: '対角接触のみでは 4-連結でない',
      );
    });
  });

  // ─── 4. 空 frame ──────────────────────────────────────────────────────────
  group('空 frame', () {
    test('空の Set は false', () {
      expect(
        isFrameSimplyConnected(<Cell>{}),
        isFalse,
        reason: '空の枠は単連結でない',
      );
    });
  });
}
