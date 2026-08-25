import 'package:flutter/material.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/services/app_data_provider.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    // Premium members get the exclusive "Obsidian & Gold" ambience
    // (respects the in-settings premium-look toggle).
    final isPremium = AppDataProvider.instance.premiumThemeActive;

    final gradientColors = isDark
        ? (isPremium
              ? AppColors.premiumAmbientDark
              : const [Color(0xFF111827), Color(0xFF172033), Color(0xFF0D1117)])
        : (isPremium
              ? AppColors.premiumAmbientLight
              : const [Color(0xFFF8FAFC), Color(0xFFFFF7ED), Color(0xFFEFF6FF)]);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          if (isPremium)
            // Soft champagne-gold aura radiating from the top corner — the
            // signature Premium glow, visible on every screen.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: isDark
                        ? const Alignment(-0.9, -1.1)
                        : const Alignment(1.1, -1.1),
                    radius: 1.4,
                    colors: [
                      AppColors.pGold.withValues(alpha: isDark ? 0.14 : 0.20),
                      AppColors.pGold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: alignment,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  bgColor.withValues(alpha: 0.18),
                  bgColor.withValues(alpha: 0.86),
                ],
                stops: const [0.0, 0.62, 1.0],
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
