import 'package:flutter/material.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTheme.borderRadius;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF1C2333) : const Color(0xFFF1F5F9);
    final border = isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.08);
    final shadow = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.06);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: fill,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
