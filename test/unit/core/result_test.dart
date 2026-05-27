import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/core/result.dart';

void main() {
  // ─── 1. Ok ────────────────────────────────────────────────────────────────
  group('Ok', () {
    test('value を保持する', () {
      const ok = Ok<int, String>(42);
      expect(ok.value, 42, reason: 'Ok に渡した値が取得できること');
    });

    test('同じ value の Ok 同士は等価', () {
      expect(
        Ok<int, String>(1),
        equals(Ok<int, String>(1)),
        reason: '同じ value なら == が true',
      );
    });

    test('異なる value の Ok 同士は等価でない', () {
      expect(
        Ok<int, String>(1),
        isNot(equals(Ok<int, String>(2))),
        reason: '異なる value なら == が false',
      );
    });

    test('hashCode が等価な Ok と一致する', () {
      expect(
        Ok<int, String>(1).hashCode,
        equals(Ok<int, String>(1).hashCode),
        reason: '等価な Ok は同じ hashCode を持つ',
      );
    });

    test('toString が Ok(value) 形式', () {
      expect(Ok<int, String>(7).toString(), 'Ok(7)');
    });
  });

  // ─── 2. Err ───────────────────────────────────────────────────────────────
  group('Err', () {
    test('error を保持する', () {
      const err = Err<int, String>('oops');
      expect(err.error, 'oops', reason: 'Err に渡したエラー値が取得できること');
    });

    test('同じ error の Err 同士は等価', () {
      expect(
        Err<int, String>('e'),
        equals(Err<int, String>('e')),
        reason: '同じ error なら == が true',
      );
    });

    test('異なる error の Err 同士は等価でない', () {
      expect(
        Err<int, String>('a'),
        isNot(equals(Err<int, String>('b'))),
        reason: '異なる error なら == が false',
      );
    });

    test('hashCode が等価な Err と一致する', () {
      expect(
        Err<int, String>('x').hashCode,
        equals(Err<int, String>('x').hashCode),
        reason: '等価な Err は同じ hashCode を持つ',
      );
    });

    test('toString が Err(error) 形式', () {
      expect(Err<int, String>('fail').toString(), 'Err(fail)');
    });
  });

  // ─── 3. Ok ≠ Err ─────────────────────────────────────────────────────────
  group('Ok と Err は等価でない', () {
    test('同じ型パラメータでも Ok と Err は等価でない', () {
      expect(
        Ok<int, int>(1),
        isNot(equals(Err<int, int>(1))),
        reason: 'Ok と Err は異なるサブクラスのため等価でない',
      );
    });
  });

  // ─── 4. sealed class の switch 網羅性 ────────────────────────────────────
  group('sealed class の switch 網羅性', () {
    String describe(Result<int, String> r) => switch (r) {
          Ok(:final value) => 'ok:$value',
          Err(:final error) => 'err:$error',
        };

    test('Ok case が選択される', () {
      expect(
        describe(const Ok(10)),
        'ok:10',
        reason: 'Ok に対して Ok case が選択される',
      );
    });

    test('Err case が選択される', () {
      expect(
        describe(const Err('boom')),
        'err:boom',
        reason: 'Err に対して Err case が選択される',
      );
    });
  });
}
