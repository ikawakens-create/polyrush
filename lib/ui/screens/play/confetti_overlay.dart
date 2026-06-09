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
/// [active] が false→true になった瞬間に1回バーストする。
/// [IgnorePointer] でラップしているため操作を妨げない。
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.active,
    this.onFinished,
  });

  final bool active;
  final VoidCallback? onFinished;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<ConfettiParticle> _particles = const [];
  Size _size = Size.zero;

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
    if (!oldWidget.active && widget.active) {
      // 次フレームで LayoutBuilder が確定してから _size を使う
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _startBurst();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startBurst() {
    if (_size == Size.zero) return;
    setState(() {
      _particles = generateBurst(
        originX: _size.width / 2,
        originY: _size.height * _kOriginYRatio,
        count: _kConfig.count,
        seed: DateTime.now().millisecondsSinceEpoch,
        config: _kConfig,
      );
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = Size(constraints.maxWidth, constraints.maxHeight);
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
    for (final p in particles) {
      final opacity = particleOpacityAt(t, config.lifetimeSeconds);
      if (opacity <= 0) continue;

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
      // 紙片: 縦長の長方形
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
