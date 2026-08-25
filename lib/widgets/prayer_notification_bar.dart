import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/prayer_service.dart';
import 'package:tripproject/services/weather_service.dart';

/// Collapsible pill-shaped notification bar shown at the top of the home screen.
/// Displays the next prayer time name + scheduled time + live countdown.
/// Can be dismissed (collapsed) by the user; toggled globally from Settings.
class PrayerNotificationBar extends StatefulWidget {
  const PrayerNotificationBar({super.key});

  @override
  State<PrayerNotificationBar> createState() => _PrayerNotificationBarState();
}

class _PrayerNotificationBarState extends State<PrayerNotificationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _collapseController;
  bool _collapsed = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Tick every second to keep the countdown live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _collapseController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    if (_collapsed) {
      _collapseController.forward();
    } else {
      _collapseController.reverse();
    }
  }

  String _translatePrayerName(String name, bool isAr) {
    if (!isAr) return name;
    switch (name) {
      case 'Fajr':    return 'الفجر';
      case 'Sunrise': return 'الشروق';
      case 'Dhuhr':   return 'الظهر';
      case 'Asr':     return 'العصر';
      case 'Maghrib': return 'المغرب';
      case 'Isha':    return 'العشاء';
      default:        return name;
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String? _countdownLabel(PrayerTime? next) {
    if (next == null) return null;
    final diff = next.timeToday.difference(next.locationNow);
    if (diff.isNegative) return null;
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) return '${_twoDigits(h)}:${_twoDigits(m)}:${_twoDigits(s)}';
    return '${_twoDigits(m)}:${_twoDigits(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppDataProvider.instance,
      builder: (context, _) {
        final provider = AppDataProvider.instance;

        // Don't show if the setting is off
        if (!provider.showNotificationBar) return const SizedBox.shrink();

        final prayerTimes = provider.prayerTimes;
        // Don't show if no prayer data yet
        if (prayerTimes == null) return const SizedBox.shrink();

        final next = prayerTimes.nextPrayer;
        final isAr = provider.language == 'ar';
        final countdown = _countdownLabel(next);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Surface color for the pill
        final pillBg = isDark
            ? const Color(0xFF1E1E2E)
            : Colors.white;
        final shadow = isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.12);

        // Chevron icon direction based on collapsed state & RTL
        final chevronIcon = _collapsed
            ? (isAr ? Icons.keyboard_arrow_left_rounded : Icons.keyboard_arrow_right_rounded)
            : Icons.keyboard_arrow_down_rounded;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleCollapsed,
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                      children: [
                        // ── Collapse / expand chevron ──
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              chevronIcon,
                              key: ValueKey(chevronIcon),
                              size: 18,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // ── Weather / sun icon ──
                        if (!_collapsed) ...[
                          Icon(
                            _weatherIcon(provider),
                            size: 22,
                            color: const Color(0xFFF4C542),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // ── Prayer text content ──
                        if (!_collapsed)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isAr
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (next != null)
                                  Text(
                                    isAr
                                        ? '${_translatePrayerName(next.name, true)} في ${_localizeDigits(next.formattedTime, provider.useArabicNumbers)}'
                                        : '${next.name} at ${next.formattedTime}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else
                                  Text(
                                    isAr ? 'لا توجد صلاة قادمة' : 'No upcoming prayer',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.black54,
                                    ),
                                  ),
                                if (countdown != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    countdown,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          Expanded(
                            child: Text(
                              next != null
                                  ? (isAr
                                      ? _translatePrayerName(next.name, true)
                                      : next.name)
                                  : '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              textAlign: isAr ? TextAlign.right : TextAlign.left,
                            ),
                          ),

                        // ── App logo icon ──
                        if (!_collapsed) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B5BDB),
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Image.asset(
                                'assets/icon/RoadTripLogo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _weatherIcon(AppDataProvider provider) {
    final condition = provider.weather?.condition;
    switch (condition) {
      case WeatherCondition.clearSky:     return Icons.wb_sunny_rounded;
      case WeatherCondition.partlyCloudy: return Icons.wb_cloudy_rounded;
      case WeatherCondition.overcast:     return Icons.cloud_rounded;
      case WeatherCondition.rain:         return Icons.grain_rounded;
      case WeatherCondition.drizzle:      return Icons.grain_rounded;
      case WeatherCondition.thunderstorm: return Icons.thunderstorm_rounded;
      case WeatherCondition.snow:         return Icons.ac_unit_rounded;
      case WeatherCondition.fog:          return Icons.foggy;
      default:                            return Icons.wb_sunny_rounded;
    }
  }

  String _localizeDigits(String input, bool useArabic) {
    if (!useArabic) return input;
    const western = '0123456789';
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = western.indexOf(ch);
      buffer.write(idx == -1 ? ch : eastern[idx]);
    }
    return buffer.toString();
  }
}
