import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';

/// Small uppercase (in English) section heading used above a [SettingsGroup].
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel({super.key, required this.text, required this.isAr});

  final String text;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: isAr ? 0 : 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// A flat, rounded card that lays out its children as divided rows —
/// the standard grouping used throughout the Settings, About and FAQ
/// screens.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A single tappable settings row: icon badge + title/subtitle + trailing
/// control, all RTL-aware.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.isAr,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.stacked = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isAr;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final iconBadge = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 17, color: iconColor),
    );

    final textColumn = Column(
      crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w500, color: onSurface),
          softWrap: true,
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: isAr ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: onSurface.withValues(alpha: 0.5)),
            softWrap: true,
          ),
        ],
      ],
    );

    final content = stacked
        ? Column(
      crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          children: [iconBadge, const SizedBox(width: 14), Expanded(child: textColumn)],
        ),
        const SizedBox(height: 14),
        if (trailing != null) trailing!,
      ],
    )
        : Row(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      children: [
        iconBadge,
        const SizedBox(width: 14),
        Expanded(child: textColumn),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: content,
        ),
      ),
    );
  }
}

/// The chevron used as trailing content for navigational rows — points
/// the correct direction for the current text direction automatically.
class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key, required this.isAr});
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Icon(
      isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      size: 22,
    );
  }
}

/// Consistent switch styling shared across settings rows.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.primary,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}