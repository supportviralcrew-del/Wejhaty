import 'package:flutter/material.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';

/// ─── Premium visual effects ──────────────────────────────────────────────
/// Exclusive decoration toolkit for subscribed users: animated light sweeps,
/// gilded borders and shimmering gold text.

/// A slow diagonal highlight that periodically sweeps across its child.
/// Purely decorative — ignores pointers and repeats forever.
class GoldSheen extends StatefulWidget {
  const GoldSheen({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 4600),
    this.opacity = 0.12,
    this.bandWidth = 70,
    this.borderRadius,
  });

  final Widget child;
  final Duration period;
  final double opacity;

  /// Approximate band width in logical pixels — mapped to a soft gradient
  /// falloff (the band itself has no hard edges).
  final double bandWidth;
  final BorderRadius? borderRadius;

  @override
  State<GoldSheen> createState() => _GoldSheenState();
}

class _GoldSheenState extends State<GoldSheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
              // A soft diagonal light band that sweeps across the card.
              // Implemented by SLIDING the gradient axis (begin/end move
              // together beyond the box) — never a rotated rectangle, so
              // there are no hard band edges to look corrupted.
              final shift = -1.8 + 3.6 * _controller.value;
              final half = (widget.bandWidth / 320.0).clamp(0.06, 0.24);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.2 + shift, -1.2),
                    end: Alignment(1.2 + shift, 1.2),
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: widget.opacity),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: [0.5 - half, 0.5, 0.5 + half],
                  ),
                ),
              );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text painted with the signature champagne-gold gradient.
class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, this.style, this.textAlign, this.maxLines});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  static const LinearGradient gradient = LinearGradient(
    colors: [AppColors.pGoldSoft, AppColors.pGold, AppColors.pGoldDeep, AppColors.pGold],
    stops: [0.0, 0.45, 0.75, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      ),
    );
  }
}

/// A card wrapped in a fine champagne-gold border with an optional warm glow.
/// The signature container for premium-only surfaces.
class GildedCard extends StatelessWidget {
  const GildedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingMd),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.glowing = true,
    this.background,
    this.borderRadius = AppTheme.radiusLg,
    this.sheen = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool glowing;
  final Color? background;
  final double borderRadius;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final fill =
        background ?? Theme.of(context).colorScheme.surface;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.pGoldSoft, AppColors.pGoldDeep, AppColors.pGoldSoft],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: AppColors.pGoldDeep.withValues(alpha: isDark ? 0.28 : 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(1.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - 1.1 < 0 ? 0 : borderRadius - 1.1),
          color: fill,
        ),
        padding: padding,
        child: child,
      ),
    );

    if (sheen) card = GoldSheen(borderRadius: radius, opacity: isDark ? 0.10 : 0.16, child: card);

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: radius, onTap: onTap, child: card),
      );
    }
    return card;
  }
}
