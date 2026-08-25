import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/utils/responsive.dart';

class PlaceholderTabScreen extends StatelessWidget {
  const PlaceholderTabScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.sunsetOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 40, color: AppColors.sunsetOrange),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: Responsive.scaledFontSize(context, 22),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
