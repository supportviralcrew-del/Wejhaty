import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_theme.dart';

class WelcomeFeatureCard extends StatelessWidget {
  const WelcomeFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.delay,
  });

  final IconData icon;
  final String title;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final chevron = isAr ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [onSurface.withValues(alpha: 0.06), onSurface.withValues(alpha: 0.03)]
                : [Colors.white, const Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon bloom
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)],
                ),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(chevron, size: 11, color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ),
    );
  }
}
