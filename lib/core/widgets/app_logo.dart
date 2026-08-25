import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF9800).withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(Icons.directions_car_rounded, size: size * 0.52, color: Colors.white),
    );
  }
}
