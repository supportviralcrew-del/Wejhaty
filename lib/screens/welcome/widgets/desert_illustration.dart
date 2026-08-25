import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tripproject/core/theme/app_colors.dart';

/// Premium animated desert scene — sun pulse, twinkling stars,
/// scrolling road dashes and a gently bobbing vehicle.
class DesertIllustration extends StatefulWidget {
  const DesertIllustration({super.key});

  @override
  State<DesertIllustration> createState() => _DesertIllustrationState();
}

class _DesertIllustrationState extends State<DesertIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _sun;
  late final AnimationController _road;
  late final AnimationController _car;

  @override
  void initState() {
    super.initState();
    _sun = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _road = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _car = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sun.dispose();
    _road.dispose();
    _car.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sun, _road, _car]),
      builder: (_, __) => CustomPaint(
        painter: _DesertIllustrationPainter(
          sunPulse: Curves.easeInOut.transform(_sun.value),
          roadOffset: _road.value,
          carBob: Curves.easeInOut.transform(_car.value),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DesertIllustrationPainter extends CustomPainter {
  final double sunPulse;
  final double roadOffset;
  final double carBob;

  _DesertIllustrationPainter({
    required this.sunPulse,
    required this.roadOffset,
    required this.carBob,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawSun(canvas, size);
    _drawRidges(canvas, size);
    _drawDesert(canvas, size);
    _drawRoad(canvas, size);
    _drawVehicle(canvas, size);
    _drawVignette(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF070B1A),
            Color(0xFF121E36),
            Color(0xFF1E2E4E),
            Color(0xFF3A4A6E),
            Color(0xFF7A5A4A),
            Color(0xFFB07A3A),
            Color(0xFFE8A84A),
          ],
          stops: [0.0, 0.18, 0.33, 0.48, 0.65, 0.82, 1.0],
        ).createShader(rect),
    );
    // Twinkling stars — opacity modulated by sunPulse
    final stars = [
      (x: 0.12, y: 0.12, s: 1.0),
      (x: 0.26, y: 0.18, s: 0.6),
      (x: 0.38, y: 0.11, s: 0.85),
      (x: 0.54, y: 0.16, s: 0.45),
      (x: 0.68, y: 0.10, s: 0.7),
      (x: 0.82, y: 0.17, s: 0.5),
      (x: 0.92, y: 0.13, s: 0.9),
    ];
    for (final star in stars) {
      final tw = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(sunPulse * math.pi * 2 + star.x * 10));
      canvas.drawCircle(
        Offset(size.width * star.x, size.height * star.y),
        1.2 * star.s * tw,
        Paint()..color = Colors.white.withValues(alpha: 0.55 * tw * star.s),
      );
    }
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.72, size.height * 0.20);
    final pulse = 0.92 + 0.08 * sunPulse;
    // Outer aura
    canvas.drawCircle(
      center,
      62 * pulse,
      Paint()
        ..color = AppColors.sunsetAmber.withValues(alpha: 0.22 + 0.10 * sunPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );
    canvas.drawCircle(
      center,
      44 * pulse,
      Paint()
        ..color = AppColors.sunsetAmber.withValues(alpha: 0.38 + 0.12 * sunPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.98),
            const Color(0xFFFFD9A3).withValues(alpha: 0.9),
            AppColors.sunsetAmber,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 22)),
    );
    // Core highlight
    canvas.drawCircle(center + const Offset(-4, -4), 4, Paint()..color = Colors.white.withValues(alpha: 0.75));
  }

  void _drawRidges(Canvas canvas, Size size) {
    final farY = size.height * 0.42;
    final farPath = Path()
      ..moveTo(0, farY)
      ..lineTo(size.width * 0.22, farY - 34)
      ..lineTo(size.width * 0.42, farY - 16)
      ..lineTo(size.width * 0.6, farY - 46)
      ..lineTo(size.width * 0.78, farY - 20)
      ..lineTo(size.width, farY - 38)
      ..lineTo(size.width, farY)
      ..close();
    canvas.drawPath(
      farPath,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF4A5570).withValues(alpha: 0.36), const Color(0xFF33395A).withValues(alpha: 0.55)],
        ).createShader(farPath.getBounds()),
    );
    final nearY = size.height * 0.47;
    final nearPath = Path()
      ..moveTo(0, nearY + 12)
      ..lineTo(size.width * 0.3, nearY - 10)
      ..lineTo(size.width * 0.55, nearY + 6)
      ..lineTo(size.width * 0.8, nearY - 16)
      ..lineTo(size.width, nearY)
      ..lineTo(size.width, nearY + 30)
      ..lineTo(0, nearY + 30)
      ..close();
    canvas.drawPath(
      nearPath,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF2A3A52).withValues(alpha: 0.72), const Color(0xFF232C46).withValues(alpha: 0.92)],
        ).createShader(nearPath.getBounds()),
    );
  }

  void _drawDesert(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, size.height * 0.46, size.width, size.height * 0.54);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD4A574), Color(0xFFC79355), Color(0xFF9A6B3A), Color(0xFF80571F), Color(0xFF5A3D15), Color(0xFF4A3417)],
          stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ).createShader(rect),
    );
    // Dune waves with very subtle drift
    final drift = 6 * math.sin(roadOffset * math.pi * 2);
    final dune1 = Path()
      ..moveTo(drift, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.3 + drift, size.height * 0.52, size.width * 0.62 + drift, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.82 + drift, size.height * 0.61, size.width + drift, size.height * 0.56)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(dune1, Paint()..color = Colors.black.withValues(alpha: 0.05));
    final dune2 = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.60, size.width * 0.7, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.68, size.width, size.height * 0.63)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(dune2, Paint()..color = Colors.black.withValues(alpha: 0.03));
  }

  void _drawRoad(Canvas canvas, Size size) {
    final roadY = size.height * 0.73;
    final h = size.height * 0.055;
    canvas.drawRect(
      Rect.fromLTWH(0, roadY, size.width, h),
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF3A3835), const Color(0xFF2B2A28), const Color(0xFF1F1E1C)],
        ).createShader(Rect.fromLTWH(0, roadY, size.width, h)),
    );
    // Scrolling dashes
    const dashW = 18.0;
    const gap = 26.0;
    final offset = roadOffset * (dashW + gap);
    for (double x = -gap + offset; x < size.width + gap; x += dashW + gap) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, roadY + h / 2), width: dashW, height: 3.5),
          const Radius.circular(2),
        ),
        Paint()
          ..color = AppColors.sunsetAmber.withValues(alpha: 0.70)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
      );
    }
    // Edge highlight
    canvas.drawRect(
      Rect.fromLTWH(0, roadY, size.width, 1),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
  }

  void _drawVehicle(Canvas canvas, Size size) {
    final bob = (carBob - 0.5) * 3.5; // -1.75 … +1.75
    final center = Offset(size.width * 0.46, size.height * 0.655 + bob);

    // Shadow scales with bob
    final shadowAlpha = 0.30 - 0.06 * carBob;
    canvas.drawOval(
      Rect.fromCenter(center: center + const Offset(0, 20), width: 98, height: 13),
      Paint()
        ..color = Colors.black.withValues(alpha: shadowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 90, height: 32),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4E5D6E), Color(0xFF35424F), Color(0xFF212B34)],
        ).createShader(bodyRect.outerRect),
    );
    // Cabin
    final cabin = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center + const Offset(-4, -17), width: 52, height: 24),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      cabin,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF4A5A6A), Color(0xFF3D4C5C)],
        ).createShader(cabin.outerRect),
    );
    // Windows
    for (final dx in [-16.0, 4.0, 20.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center + Offset(dx, -17), width: 12, height: 10),
          const Radius.circular(3),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [AppColors.sunsetBlue.withValues(alpha: 0.62), AppColors.sunsetBlue.withValues(alpha: 0.28)],
          ).createShader(Rect.fromCenter(center: center + Offset(dx, -17), width: 12, height: 10)),
      );
    }
    // Wheels with subtle rotation illusion (offset)
    for (final wx in [-28.0, -6.0, 16.0, 30.0]) {
      canvas.drawCircle(center + Offset(wx, 15), 8.8, Paint()..color = const Color(0xFF121212));
      canvas.drawCircle(center + Offset(wx, 15), 4.6, Paint()..color = const Color(0xFF2A2A2A));
      canvas.drawCircle(center + Offset(wx, 15), 2.4, Paint()..color = AppColors.textMuted.withValues(alpha: 0.85));
      // Spin tick
      final angle = roadOffset * math.pi * 4 + wx;
      final tick = Offset(math.cos(angle) * 3.0, math.sin(angle) * 3.0);
      canvas.drawCircle(center + Offset(wx, 15) + tick, 0.9, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
    // Headlight cone + core
    final headPos = center + const Offset(38, -2);
    final cone = Path()
      ..moveTo(headPos.dx, headPos.dy)
      ..lineTo(headPos.dx + 28, headPos.dy - 10)
      ..lineTo(headPos.dx + 28, headPos.dy + 10)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
        ).createShader(cone.getBounds())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(headPos, 5.2, Paint()..color = Colors.white.withValues(alpha: 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(headPos, 4.2, Paint()..color = Colors.white.withValues(alpha: 0.95));
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.15,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.14)],
          stops: const [0.68, 1.0],
        ).createShader(rect),
    );
    // Top safe fade for logo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 36),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _DesertIllustrationPainter old) =>
      old.sunPulse != sunPulse || old.roadOffset != roadOffset || old.carBob != carBob;
}
