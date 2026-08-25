import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tripproject/core/theme/app_colors.dart';

/// A refined, cinematic desert-road loop used behind the splash screen.
///
/// The car travels along the road's own vanishing-point perspective —
/// small and far near the horizon, growing larger as it approaches the
/// camera — rather than sitting at a fixed size disconnected from the
/// road geometry.
class DesertRoadAnimation extends StatefulWidget {
  const DesertRoadAnimation({super.key});

  @override
  State<DesertRoadAnimation> createState() => _DesertRoadAnimationState();
}

class _DesertRoadAnimationState extends State<DesertRoadAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Offset> _starSeeds;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    final rng = math.Random(7);
    _starSeeds = List.generate(
      22,
          (_) => Offset(rng.nextDouble(), rng.nextDouble() * 0.4),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _DesertRoadPainter(t: _controller.value, starSeeds: _starSeeds),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _DesertRoadPainter extends CustomPainter {
  _DesertRoadPainter({required this.t, required this.starSeeds});

  final double t;
  final List<Offset> starSeeds;

  // Shared road geometry so the car and lane markings agree perfectly.
  double _vanishY(Size size) => size.height * 0.58;
  double _roadHalfWidth(Size size, double y) {
    final vanishY = _vanishY(size);
    final progress = ((y - vanishY) / (size.height - vanishY)).clamp(0.0, 1.0);
    return size.width * 0.16 * progress + 3;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawSun(canvas, size);
    _drawRidgeLine(canvas, size, depth: 0.5, opacity: 0.3);
    _drawRidgeLine(canvas, size, depth: 0.58, opacity: 0.5);
    _drawDesertFloor(canvas, size);
    _drawRoad(canvas, size);
    _drawCar(canvas, size);
  }

  // ---------------------------------------------------------------------
  // Sky
  // ---------------------------------------------------------------------

  void _drawSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.6);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A1220),
          Color(0xFF152238),
          Color(0xFF2C3A54),
          Color(0xFF8C5346),
          AppColors.sunsetAmber,
        ],
        stops: [0.0, 0.3, 0.52, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawStars(Canvas canvas, Size size) {
    for (var i = 0; i < starSeeds.length; i++) {
      final seed = starSeeds[i];
      final dx = seed.dx * size.width;
      final dy = seed.dy * size.height * 0.6;
      final twinkle = 0.3 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i));
      final fade = (1 - seed.dy).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(dx, dy),
        0.6 + (i % 3) * 0.35,
        Paint()..color = Colors.white.withValues(alpha: twinkle * fade * 0.5),
      );
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.74, size.height * 0.22);

    canvas.drawCircle(
      center,
      44,
      Paint()
        ..color = AppColors.sunsetAmber.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.9), AppColors.sunsetAmber],
        ).createShader(Rect.fromCircle(center: center, radius: 18)),
    );
  }

  // ---------------------------------------------------------------------
  // Terrain
  // ---------------------------------------------------------------------

  void _drawRidgeLine(Canvas canvas, Size size, {required double depth, required double opacity}) {
    final baseY = size.height * depth;
    final shift = (t * size.width * 0.08) % size.width;

    final path = Path()..moveTo(-size.width, baseY);
    const segments = 7;
    for (var i = 0; i <= segments; i++) {
      final x = -size.width + shift + (2 * size.width / segments) * i;
      final peak = baseY - 30 * (0.5 + 0.5 * math.sin(i * 1.7));
      path.lineTo(x, peak);
    }
    path
      ..lineTo(2 * size.width, size.height)
      ..lineTo(-size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFF1A2436).withValues(alpha: opacity));
  }

  void _drawDesertFloor(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, size.height * 0.56, size.width, size.height * 0.44);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFAE7E43), Color(0xFF6E4823), Color(0xFF3C2913)],
        ).createShader(rect),
    );
  }

  // ---------------------------------------------------------------------
  // Road + vehicle
  // ---------------------------------------------------------------------

  void _drawRoad(Canvas canvas, Size size) {
    final vanishY = _vanishY(size);
    final baseY = size.height;
    final centerX = size.width * 0.5;
    final baseHalfWidth = _roadHalfWidth(size, baseY);

    final roadPath = Path()
      ..moveTo(centerX - 3, vanishY)
      ..lineTo(centerX - baseHalfWidth, baseY)
      ..lineTo(centerX + baseHalfWidth, baseY)
      ..lineTo(centerX + 3, vanishY)
      ..close();

    canvas.drawPath(
      roadPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF34332F), Color(0xFF1D1C1A)],
        ).createShader(Rect.fromLTWH(0, vanishY, size.width, baseY - vanishY)),
    );

    // Perspective-correct lane dashes.
    const dashCount = 8;
    final loop = t % 1.0;
    for (var i = 0; i < dashCount; i++) {
      final progress = ((i / dashCount) + loop) % 1.0;
      final eased = Curves.easeInCubic.transform(progress);
      final y = ui.lerpDouble(vanishY + 4, baseY - 6, eased)!;
      final halfW = ui.lerpDouble(1.0, 6.0, eased)!;
      final h = ui.lerpDouble(5, 20, eased)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(centerX, y), width: halfW * 2, height: h),
          const Radius.circular(2),
        ),
        Paint()..color = AppColors.sunsetAmber.withValues(alpha: 0.5 + 0.3 * eased),
      );
    }
  }

  void _drawCar(Canvas canvas, Size size) {
    final vanishY = _vanishY(size);
    final baseY = size.height;

    // Drive the car along the same perspective curve as the lane dashes,
    // so it visibly comes from far away and grows as it nears the camera.
    final progress = t % 1.0;
    final eased = Curves.easeInCubic.transform(progress);

    final y = ui.lerpDouble(vanishY + 10, baseY - 18, eased)!;
    final scale = ui.lerpDouble(0.16, 1.0, eased)!;
    final centerX = size.width * 0.5;

    // Fade in as it emerges from the horizon, fade out just before the loop
    // cuts back to the start, so the reset isn't visible as a hard pop.
    final opacity = progress < 0.06
        ? progress / 0.06
        : (progress > 0.94 ? (1 - progress) / 0.06 : 1.0);
    if (opacity <= 0.01) return;

    canvas.save();
    canvas.translate(centerX, y);
    canvas.scale(scale);

    // Grounding shadow.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 15), width: 60, height: 10),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-27, -8, 54, 18),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = AppColors.sunsetOrange.withValues(alpha: opacity)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sunsetOrange.withValues(alpha: opacity),
            AppColors.sunsetOrange.withValues(alpha: opacity * 0.75),
          ],
        ).createShader(bodyRect.outerRect),
    );

    final cabinRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-16, -18, 26, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(cabinRect, Paint()..color = const Color(0xFF232E3A).withValues(alpha: opacity));

    canvas.drawRect(
      const Rect.fromLTWH(-14, -17, 22, 8),
      Paint()..color = AppColors.sunsetBlue.withValues(alpha: 0.5 * opacity),
    );

    for (final dx in [-16.0, 16.0]) {
      canvas.drawCircle(Offset(dx, 9), 5, Paint()..color = const Color(0xFF141414).withValues(alpha: opacity));
      canvas.drawCircle(Offset(dx, 9), 2.1, Paint()..color = AppColors.textMuted.withValues(alpha: 0.8 * opacity));
    }

    // A single soft headlight glow instead of a hard-edged beam wedge.
    canvas.drawCircle(
      const Offset(24, -1),
      4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      const Offset(24, -1),
      1.6,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * opacity),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DesertRoadPainter oldDelegate) => oldDelegate.t != t;
}