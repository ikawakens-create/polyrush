import 'package:flutter/material.dart';
import 'package:polyrush/game/play/confetti_physics.dart';

// ピース5色（piece_tray.dart と同じ値。import 依存を増やさないためここで再定義）
const _confettiColors = <Color>[
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFFDD835),
];

const _kConfig = ConfettiBurstConfig();

// バースト起点: 画面幅の中央、高さの 40%
const double _kOriginYRatio = 0.4;

/// クリア時に画面全体に重ねる紙吹雪オーバーレイ。
///
/// [active] が true の間、サイズ確定後に1回バーストする。
/// [IgnorePointer] でラップしているため操作を妨げない。
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.active, this.onFinished});

  final bool active;
  final VoidCallback? onFinished;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<ConfettiParticle> _particles = const [];

  // このバーストを生成済みか（active の1サイクルにつき1回だけ生成する）
  bool _burstSpawned = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_kConfig.lifetimeSeconds * 1000).round(),
      ),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // active が false に戻ったら次のクリアに備えてリセット
    if (oldWidget.active && !widget.active) {
      _burstSpawned = false;
      _particles = const [];
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnBurst(Size size) {
    if (size.isEmpty) return;
    _burstSpawned = true;
    _particles = generateBurst(
      originX: size.width / 2,
      originY: size.height * _kOriginYRatio,
      count: _kConfig.count,
      seed: DateTime.now().millisecondsSinceEpoch,
      config: _kConfig,
    );
    // build 中の呼び出しを避けるため、次フレームで forward する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _controller.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          // active かつ未生成かつサイズ確定 → このサイズで生成する
          if (widget.active && !_burstSpawned && !size.isEmpty) {
            _spawnBurst(size);
          }

          if (!widget.active || _particles.isEmpty) {
            return const SizedBox.expand();
          }

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * _kConfig.lifetimeSeconds;
              return CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  t: t,
                  config: _kConfig,
                ),
                child: const SizedBox.expand(),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.config,
  });

  final List<ConfettiParticle> particles;
  final double t;
  final ConfettiBurstConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = particleOpacityAt(t, config.lifetimeSeconds);
    if (opacity <= 0) return;

    for (final p in particles) {
      final pos = particlePositionAt(p, t, config.gravity);
      final angle = particleRotationAt(p, t);
      final color = _confettiColors[p.colorIndex % _confettiColors.length]
          .withValues(alpha: opacity);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(pos.x, pos.y);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 1.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.t != t || old.particles != particles;
}
