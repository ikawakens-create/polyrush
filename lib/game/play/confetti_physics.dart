import 'dart:math';

/// 手触り定数。実機調整を前提としているため、実機確認後に値を更新すること。
class ConfettiBurstConfig {
  const ConfettiBurstConfig({
    this.count = 80,
    this.gravity = 900.0,
    this.lifetimeSeconds = 1.4,
    this.minSpeed = 300.0,
    this.maxSpeed = 700.0,
    this.minSize = 6.0,
    this.maxSize = 12.0,
    this.maxAngularSpeed = 8.0,
  });

  final int count;
  final double gravity; // px/s²、下方向が正
  final double lifetimeSeconds;
  final double minSpeed; // px/s
  final double maxSpeed; // px/s
  final double minSize; // px
  final double maxSize; // px
  final double maxAngularSpeed; // rad/s
}

/// 1つの紙吹雪の粒（不変）。
class ConfettiParticle {
  const ConfettiParticle({
    required this.originX,
    required this.originY,
    required this.velocityX,
    required this.velocityY,
    required this.colorIndex,
    required this.rotation,
    required this.angularVelocity,
    required this.size,
  });

  final double originX;
  final double originY;
  final double velocityX;
  final double velocityY; // 上向きが負
  final int colorIndex; // 0..4、ピース5色を流用
  final double rotation; // ラジアン
  final double angularVelocity; // ラジアン/秒
  final double size; // px
}

/// 時刻 [tSeconds] における粒の位置。
({double x, double y}) particlePositionAt(
  ConfettiParticle p,
  double tSeconds,
  double gravity,
) {
  return (
    x: p.originX + p.velocityX * tSeconds,
    y: p.originY + p.velocityY * tSeconds + 0.5 * gravity * tSeconds * tSeconds,
  );
}

/// 時刻 [tSeconds] における粒の回転角（ラジアン）。
double particleRotationAt(ConfettiParticle p, double tSeconds) {
  return p.rotation + p.angularVelocity * tSeconds;
}

/// 時刻 [tSeconds] における粒の不透明度（0..1 にクランプ）。
double particleOpacityAt(double tSeconds, double lifetimeSeconds) {
  if (tSeconds <= 0) return 1.0;
  if (tSeconds >= lifetimeSeconds) return 0.0;
  return (1.0 - tSeconds / lifetimeSeconds).clamp(0.0, 1.0);
}

/// [seed] で再現可能なバースト生成。
List<ConfettiParticle> generateBurst({
  required double originX,
  required double originY,
  required int count,
  required int seed,
  required ConfettiBurstConfig config,
}) {
  final rng = Random(seed);
  final particles = <ConfettiParticle>[];

  for (int i = 0; i < count; i++) {
    final speed =
        config.minSpeed +
        rng.nextDouble() * (config.maxSpeed - config.minSpeed);

    // 70% の確率で上半分（-π..0）に向かわせ、打ち上がってから落ちる見栄えにする
    final double angle;
    if (rng.nextDouble() < 0.7) {
      angle = -pi + rng.nextDouble() * pi;
    } else {
      angle = rng.nextDouble() * pi;
    }

    final vx = speed * cos(angle);
    // 上半分（-π..0）のとき sin は負 → vy < 0 で上向き
    final vy = speed * sin(angle);

    final colorIndex = rng.nextInt(5);
    final size =
        config.minSize + rng.nextDouble() * (config.maxSize - config.minSize);
    final rotation = rng.nextDouble() * 2 * pi;
    final angularVelocity =
        (rng.nextDouble() * 2.0 - 1.0) * config.maxAngularSpeed;

    particles.add(
      ConfettiParticle(
        originX: originX,
        originY: originY,
        velocityX: vx,
        velocityY: vy,
        colorIndex: colorIndex,
        rotation: rotation,
        angularVelocity: angularVelocity,
        size: size,
      ),
    );
  }

  return particles;
}
