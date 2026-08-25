import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/widgets/animated_tap_card.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.heroTag,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    
    return AnimatedTapCard(
      heroTag: heroTag,
      onTap: onTap ?? () {},
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: onTap ?? () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(double.infinity, 36),
                ),
                child: Text(
                  isAr ? 'عرض' : 'View',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}