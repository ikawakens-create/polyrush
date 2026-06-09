import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrush/game/play/confetti_physics.dart';

void main() {
  const config = ConfettiBurstConfig();

  // ─── A. particlePositionAt ────────────────────────────────────────
  group('A. particlePositionAt', () {
    const p = ConfettiParticle(
      originX: 100,
      originY: 200,
      velocityX: 50,
      velocityY: -300,
      colorIndex: 0,
      rotation: 0,
      angularVelocity: 0,
      size: 8,
    );

    test('t=0 で原点を返す', () {
      final pos = particlePositionAt(p, 0, config.gravity);
      expect(pos.x, 100, reason: 'x は originX と等しい');
      expect(pos.y, 200, reason: 'y は originY と等しい');
    });

    test('t>0 で x は等速移動', () {
      final pos = particlePositionAt(p, 1, config.gravity);
      expect(pos.x, closeTo(150, 1e-9), reason: 'x = 100 + 50*1 = 150');
    });

    test('t>0 で重力により y が増加する', () {
      final pos0 = particlePositionAt(p, 0, config.gravity);
      final pos1 = particlePositionAt(p, 1, config.gravity);
      expect(
        pos1.y,
        greaterThan(pos0.y),
        reason: '重力加速で t=1 の y は t=0 の y より大きい（下方向が正）',
      );
    });

    test('y = originY + vy*t + 0.5*g*t^2 の放物線', () {
      final pos = particlePositionAt(p, 1, config.gravity);
      final expected = 200.0 + (-300.0) * 1 + 0.5 * config.gravity * 1 * 1;
      expect(pos.y, closeTo(expected, 1e-9), reason: '放物線の式に従う');
    });
  });

  // ─── B. particleOpacityAt ─────────────────────────────────────────
  group('B. particleOpacityAt', () {
    const lifetime = 1.4;

    test('t=0 で 1.0', () {
      expect(
        particleOpacityAt(0, lifetime),
        1.0,
        reason: 't=0 は完全不透明',
      );
    });

    test('t=lifetime で 0.0', () {
      expect(
        particleOpacityAt(lifetime, lifetime),
        0.0,
        reason: 't=lifetime は完全透明',
      );
    });

    test('中間で線形に減衰する', () {
      final mid = particleOpacityAt(lifetime / 2, lifetime);
      expect(mid, closeTo(0.5, 1e-9), reason: '中間時刻では 0.5');
    });

    test('t<0 は 1.0 にクランプ', () {
      expect(
        particleOpacityAt(-0.1, lifetime),
        1.0,
        reason: '負の時刻は 1.0 にクランプ',
      );
    });

    test('t>lifetime は 0.0 にクランプ', () {
      expect(
        particleOpacityAt(lifetime + 0.5, lifetime),
        0.0,
        reason: 'lifetime 超過は 0.0 にクランプ',
      );
    });
  });

  // ─── C. generateBurst ─────────────────────────────────────────────
  group('C. generateBurst', () {
    const originX = 200.0;
    const originY = 300.0;

    List<ConfettiParticle> burst({int seed = 42}) => generateBurst(
          originX: originX,
          originY: originY,
          count: config.count,
          seed: seed,
          config: config,
        );

    test('同一 seed で同一結果（再現性）', () {
      final a = burst(seed: 99);
      final b = burst(seed: 99);
      expect(a.length, b.length, reason: '粒数が等しい');
      for (int i = 0; i < a.length; i++) {
        expect(
          a[i].velocityX,
          closeTo(b[i].velocityX, 1e-9),
          reason: '粒 $i の velocityX が一致',
        );
        expect(
          a[i].colorIndex,
          b[i].colorIndex,
          reason: '粒 $i の colorIndex が一致',
        );
      }
    });

    test('count 個生成される', () {
      expect(
        burst().length,
        config.count,
        reason: '生成数が count と等しい',
      );
    });

    test('colorIndex が 0..4 に収まる', () {
      for (final p in burst()) {
        expect(p.colorIndex, inInclusiveRange(0, 4), reason: 'colorIndex は 0..4');
      }
    });

    test('速度の大きさが minSpeed..maxSpeed に収まる', () {
      for (final p in burst()) {
        final speed = sqrt(p.velocityX * p.velocityX + p.velocityY * p.velocityY);
        expect(
          speed,
          greaterThanOrEqualTo(config.minSpeed - 1e-9),
          reason: 'speed >= minSpeed',
        );
        expect(
          speed,
          lessThanOrEqualTo(config.maxSpeed + 1e-9),
          reason: 'speed <= maxSpeed',
        );
      }
    });
  });
}
