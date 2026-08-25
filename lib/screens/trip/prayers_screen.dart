import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/widgets/glass_card.dart'; // used by _buildEmptyPrayerTimes
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/prayer_service.dart';
import 'package:tripproject/screens/adhkar_screen.dart';
import 'package:vibration/vibration.dart';

/// Normalizes a bearing difference (e.g. Qibla offset minus current device
/// heading) to the range (-180, 180]. Positive means the target bearing is
/// clockwise from the current heading (turn right); negative means it's
/// counter-clockwise (turn left).
double _shortestAngleDeg(double degrees) {
  var d = degrees % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// Same as [_shortestAngleDeg] but in radians, for use directly in
/// Transform.rotate — a needle rotated by this angle always takes the
/// shortest visual path instead of spinning the long way around when it
/// crosses 0/360.
double _normalizeDegrees(double degrees) {
  final normalized = degrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

// `direction.qiblah` is the LIVE value: flutter_qiblah recomputes it on
// every compass tick as (qiblah bearing - current heading), so it's what
// should drive anything on-screen that needs to react as the phone turns
// (needle rotation, "turn left/right" hints, alignment detection) — this
// matches the plugin's own official example, which rotates its needle by
// `-qiblah`. `direction.offset` is the fixed, location-only bearing from
// true north to Mecca — it barely changes as you rotate the phone, so it's
// only appropriate for a static "Qibla is N° from North" label, never for
// driving a live needle/alignment check.
double _qiblahNeedleAngleDeg(QiblahDirection direction) =>
    _normalizeDegrees(direction.qiblah);

double _turnToQiblaDeg(QiblahDirection direction) =>
    _shortestAngleDeg(direction.qiblah);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _NextPrayerInfo {
  final String name;
  final DateTime dateTime;

  const _NextPrayerInfo({required this.name, required this.dateTime});
}

class _PrayersScreenState extends State<PrayersScreen> {
  Timer? _tickTimer;

  // ── Performance-critical design ────────────────────────────────────────
  // The old implementation called setState on the WHOLE screen every second
  // (countdown tick) plus again on every throttled compass sample, forcing
  // the banner image, prayer list, ads and everything else to rebuild
  // constantly — that was the source of the persistent jank. Now the only
  // per-second work is pushing a new string into [_countdownText], which
  // rebuilds just the countdown Text. Full-screen rebuilds happen only on
  // rare structural changes (next prayer changed, day rolled over, prayer
  // times loaded, language switched).
  final ValueNotifier<String> _countdownText = ValueNotifier('--:--:--');

  // Whether a live compass reading has arrived. Drives only the small
  // "Live compass" chip on the Qibla card via a ValueListenableBuilder.
  final ValueNotifier<bool> _liveCompassVN = ValueNotifier(false);

  StreamSubscription<QiblahDirection>? _qiblahSubscription;

  _NextPrayerInfo? _cachedNextPrayerInfo;
  Duration? _cachedRemaining;
  int? _cachedDay;

  // Signature of provider data the current build is based on, so we can
  // ignore irrelevant provider notifications without recomparing deeply.
  dynamic _sigPrayerTimes;
  String? _sigLanguage;
  bool _sigArabicNumbers = false;

  // Accent color per prayer, matching the design reference.
  static const Map<String, Color> _prayerColors = {
    'Fajr': Color(0xFF6C63E5),
    'Sunrise': Color(0xFFF2A93B),
    'Dhuhr': Color(0xFF2E9E6D),
    'Asr': Color(0xFFF2A93B),
    'Maghrib': Color(0xFF8B5CF6),
    'Isha': Color(0xFF3B82C4),
  };

  // Prayer icon per prayer for the list rows
  static const Map<String, IconData> _prayerIcons = {
    'Fajr': Icons.wb_twilight,
    'Sunrise': Icons.wb_sunny_outlined,
    'Dhuhr': Icons.wb_sunny_outlined,
    'Asr': Icons.wb_sunny,
    'Maghrib': Icons.nights_stay_outlined,
    'Isha': Icons.nightlight_round,
  };

  @override
  void initState() {
    super.initState();

    // Ticks once a second but ONLY updates the countdown string notifier;
    // the screen itself rebuilds only when something structural changes.
    _refreshTick();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _refreshTick();
    });

    // Rebuild for rare data changes (prayer times loaded/changed, language
    // or numeral settings switched). Cheap signature comparison filters out
    // the frequent notifications (e.g. location pings).
    AppDataProvider.instance.addListener(_onProviderChanged);

    _initQiblahStream();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = AppDataProvider.instance;
    final changed = !identical(provider.prayerTimes, _sigPrayerTimes) ||
        provider.language != _sigLanguage ||
        provider.useArabicNumbers != _sigArabicNumbers;
    if (!changed) return;
    _refreshTick();
    setState(() {});
  }

  /// Recomputes the next prayer + countdown. Updates the countdown notifier
  /// every call; triggers a full setState only when displayed structure
  /// changes (different next prayer, availability flip, or date change).
  void _refreshTick() {
    final provider = AppDataProvider.instance;
    final prayerTimes = provider.prayerTimes;

    final info = _computeNextPrayer(prayerTimes);
    Duration? remaining;
    if (info != null && prayerTimes != null) {
      remaining = info.dateTime.difference(prayerTimes.fajr.locationNow);
    }

    final text =
        info != null && remaining != null ? _formatDuration(remaining) : '';
    if (_countdownText.value != text) _countdownText.value = text;

    final day = DateTime.now().day;
    final structural = day != _cachedDay ||
        (info == null) != (_cachedNextPrayerInfo == null) ||
        info?.name != _cachedNextPrayerInfo?.name;

    _cachedNextPrayerInfo = info;
    _cachedRemaining = remaining;
    _cachedDay = day;
    _sigPrayerTimes = prayerTimes;
    _sigLanguage = provider.language;
    _sigArabicNumbers = provider.useArabicNumbers;

    if (structural && mounted && !_isFirstRefresh) {
      setState(() {});
    }
    _isFirstRefresh = false;
  }

  bool _isFirstRefresh = true;

  /// Subscribes to the device's live compass heading via flutter_qiblah.
  /// Actively checks (and if needed requests) location permission first —
  /// without this the stream errors out silently on a fresh install and
  /// the card would never show a live needle. Wrapped defensively: on
  /// platforms/devices where this isn't supported (web, most emulators,
  /// phones without a magnetometer, or permission permanently denied), we
  /// just leave the notifier false and the Qibla card falls back to a
  /// static, non-rotating bearing instead of crashing or spinning forever
  /// waiting for data.
  Future<void> _initQiblahStream() async {
    if (kIsWeb) return;
    try {
      final status = await FlutterQiblah.checkLocationStatus().timeout(
        const Duration(seconds: 3),
        onTimeout: () => LocationStatus(false, LocationPermission.denied),
      );

      if (!status.enabled || status.status == LocationPermission.denied) {
        final granted = await FlutterQiblah.requestPermissions().timeout(
          const Duration(seconds: 3),
          onTimeout: () => LocationPermission.denied,
        );
        if (granted != LocationPermission.always &&
            granted != LocationPermission.whileInUse) {
          return;
        }
      } else if (status.status == LocationPermission.deniedForever) {
        return;
      }

      _qiblahSubscription = FlutterQiblah.qiblahStream.listen(
            (direction) {
          // The compass fires dozens of events per second. The old code
          // rebuilt the entire prayers screen (throttled to ~2.5x/sec) —
          // still enough to cause visible jank while scrolling. Now we only
          // flip a bool notifier that rebuilds the tiny status chip once.
          if (!_liveCompassVN.value) _liveCompassVN.value = true;
        },
        onError: (_) {},
      );
    } catch (_) {
      // Live compass unavailable — chip stays on "Location bearing".
    }
  }

  @override
  void dispose() {
    AppDataProvider.instance.removeListener(_onProviderChanged);
    _tickTimer?.cancel();
    _countdownText.dispose();
    _liveCompassVN.dispose();
    _qiblahSubscription?.cancel();
    super.dispose();
  }

  void _toggleReminder(String prayerName) {
    HapticFeedback.selectionClick();
    final enabled = AppDataProvider.instance.isPrayerReminderEnabled(
      prayerName,
    );
    AppDataProvider.instance.setPrayerReminderEnabled(prayerName, !enabled);
    setState(() {});
  }

  // ignore: unused_element
  void _togglePreAdhanReminder(bool isAr) {
    HapticFeedback.lightImpact();
    final enabling = !AppDataProvider.instance.showNotificationBar;
    AppDataProvider.instance.setShowNotificationBar(enabling);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabling
              ? (isAr
              ? 'سيتم تنبيهك قبل الأذان'
              : 'You will be reminded before Adhan')
              : (isAr ? 'تم إيقاف التنبيه' : 'Reminder turned off'),
          style: _uiFont(isAr, fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Converts Western digits (0-9) in [input] to Eastern Arabic-Indic digits
  /// (٠-٩) whenever the "Arabic Numerals" setting is enabled, regardless of
  /// the app's UI language — the setting is independent of language, same
  /// as on the Settings screen. Non-digit characters (colons, slashes,
  /// letters, spaces) pass through untouched, so it's safe to run over
  /// already-formatted strings like "5:32 AM" or "12/3".
  String _localizeDigits(String input) {
    if (!AppDataProvider.instance.useArabicNumbers) return input;
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

  /// Best-effort parse of a formatted time string ("5:32 AM", "05:32", "17:05")
  /// into minutes-since-midnight. Returns null if the format can't be read,
  /// so callers can gracefully skip the "next prayer" highlight instead of
  /// crashing on an unexpected format.
  ///
  /// NOTE: this always runs on the raw, un-localized time string coming
  /// from prayerTimes (never on the output of _localizeDigits), so Arabic
  /// numerals in the display never affect this parsing logic.
  // ignore: unused_element
  int? _parseMinutesSinceMidnight(String formatted) {
    try {
      final match = RegExp(
        r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?',
      ).firstMatch(formatted);
      if (match == null) return null;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final meridiem = match.group(3)?.toUpperCase();

      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  /// Works out which prayer is next (wrapping around to tomorrow's Fajr if
  /// every prayer for today has already passed) so we can both highlight it
  /// in the list and drive the live countdown card.
  _NextPrayerInfo? _computeNextPrayer(dynamic prayerTimes) {
    if (prayerTimes == null) return null;
    // Use the prayer's timezone-aware current time
    final now = prayerTimes.fajr.locationNow;

    final entries = <String, PrayerTime>{
      'Fajr': prayerTimes.fajr,
      'Sunrise': prayerTimes.sunrise,
      'Dhuhr': prayerTimes.dhuhr,
      'Asr': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isha': prayerTimes.isha,
    };

    String? bestName;
    DateTime? bestTime;

    entries.forEach((name, prayer) {
      final candidate = prayer.timeToday;
      if (candidate.isAfter(now)) {
        if (bestTime == null || candidate.isBefore(bestTime!)) {
          bestTime = candidate;
          bestName = name;
        }
      }
    });

    // Every prayer today has passed: wrap around to tomorrow's Fajr.
    if (bestName == null) {
      final tomorrow = now.add(const Duration(days: 1));
      final fajrTime = prayerTimes.fajr.timeToday;
      bestTime = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        fajrTime.hour,
        fajrTime.minute,
      );
      bestName = 'Fajr';
    }

    if (bestName == null || bestTime == null) return null;
    return _NextPrayerInfo(name: bestName!, dateTime: bestTime!);
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return _localizeDigits('00:00:00');
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return _localizeDigits('$h:$m:$s');
  }

  // -------------------------------------------------------------------
  // Gregorian date + approximate Hijri date, for the header card.
  // -------------------------------------------------------------------

  static const List<String> _gregorianMonthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _gregorianMonthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  static const List<String> _hijriMonthsAr = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
  static const List<String> _hijriMonthsEn = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  static const List<String> _enWeekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _arWeekdays = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  String _gregorianDateLabel(bool isAr) {
    final now = DateTime.now();
    final weekday = isAr
        ? _arWeekdays[now.weekday - 1]
        : _enWeekdays[now.weekday - 1];
    final month = isAr
        ? _gregorianMonthsAr[now.month - 1]
        : _gregorianMonthsEn[now.month - 1];
    final label = isAr
        ? '$weekday، ${now.day} $month ${now.year}'
        : '$weekday, ${now.day} $month ${now.year}';
    return _localizeDigits(label);
  }

  /// Converts a Gregorian date to an approximate Hijri date using the
  /// tabular ("Kuwaiti algorithm") civil calendar. This is a widely used
  /// public-domain approximation good enough for display purposes — it can
  /// occasionally be off by a day versus local moon-sighting or the
  /// Umm al-Qura calendar, which is expected for any tabular conversion.
  List<int> _gregorianToHijri(DateTime date) {
    int julianDayFromGregorian(int y, int m, int d) {
      final a = ((14 - m) / 12).floor();
      final y2 = y + 4800 - a;
      final m2 = m + 12 * a - 3;
      return d +
          ((153 * m2 + 2) / 5).floor() +
          365 * y2 +
          (y2 / 4).floor() -
          (y2 / 100).floor() +
          (y2 / 400).floor() -
          32045;
    }

    final jd = julianDayFromGregorian(date.year, date.month, date.day);
    final l = jd - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    var ll = l - 10631 * n + 354;
    final j =
        (((10985 - ll) / 5316).floor()) * ((50 * ll) / 17719).floor() +
            ((ll / 5670).floor()) * ((43 * ll) / 15238).floor();
    ll =
        ll -
            ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
            (j / 16).floor() * ((15238 * j) / 43).floor() +
            29;
    final month = ((24 * ll) / 709).floor();
    final day = ll - ((709 * month) / 24).floor();
    final year = 30 * n + j - 30;
    return [day, month, year];
  }

  String _hijriDateLabel(bool isAr) {
    final parts = _gregorianToHijri(DateTime.now());
    final day = parts[0];
    final monthIdx = (parts[1] - 1).clamp(0, 11);
    final year = parts[2];
    final month = isAr ? _hijriMonthsAr[monthIdx] : _hijriMonthsEn[monthIdx];
    final suffix = isAr ? 'هـ' : 'AH';
    final label = '$day $month $year $suffix';
    return _localizeDigits(label);
  }

  // -------------------------------------------------------------------
  // Qibla direction
  // -------------------------------------------------------------------

  (double, double)? _readDeviceLatLon() {
    final loc = AppDataProvider.instance.location;
    if (loc == null) return null;
    return (loc.latitude, loc.longitude);
  }

  /// Builds a "City, Country" label when possible.
  String? _locationLabel(dynamic prayerTimes) {
    final provider = AppDataProvider.instance;

    // First try manual location
    if (provider.isManualLocation &&
        provider.manualCityName != null &&
        provider.manualCityName!.isNotEmpty) {
      final country = provider.manualCountryName;
      if (country != null && country.isNotEmpty) {
        return '${provider.manualCityName}، $country';
      }
      return provider.manualCityName;
    }

    // Try prayer times city name
    final cityName = prayerTimes?.cityName as String?;
    if (cityName != null && cityName.isNotEmpty) return cityName;

    // Fallback to weather data city name
    final weatherCity = provider.weather?.cityName;
    if (weatherCity != null && weatherCity.isNotEmpty) return weatherCity;

    return null;
  }

  double _qiblaBearing(double lat, double lon) {
    const kaabaLat = 21.422487;
    const kaabaLon = 39.826206;
    final phiK = kaabaLat * math.pi / 180;
    final lambdaK = kaabaLon * math.pi / 180;
    final phi = lat * math.pi / 180;
    final lambda = lon * math.pi / 180;
    final y = math.sin(lambdaK - lambda);
    final x =
        math.cos(phi) * math.tan(phiK) -
            math.sin(phi) * math.cos(lambdaK - lambda);
    var bearing = math.atan2(y, x) * 180 / math.pi;
    bearing = (bearing + 360) % 360;
    return bearing;
  }

  // ignore: unused_element
  String _compassLabel(double bearing, bool isAr) {
    const en = [
      'North',
      'Northeast',
      'East',
      'Southeast',
      'South',
      'Southwest',
      'West',
      'Northwest',
    ];
    const ar = [
      'شمال',
      'شمال شرقي',
      'شرق',
      'جنوب شرقي',
      'جنوب',
      'جنوب غربي',
      'غرب',
      'شمال غربي',
    ];
    final idx = (((bearing + 22.5) % 360) / 45).floor() % 8;
    return isAr ? ar[idx] : en[idx];
  }

  /// Regular UI text uses Poppins for Latin script and Tajawal for Arabic.
  TextStyle _uiFont(
      bool isAr, {
        required double fontSize,
        FontWeight fontWeight = FontWeight.w400,
        Color? color,
        double? height,
        FontStyle? fontStyle,
        double? letterSpacing,
        List<FontFeature>? fontFeatures,
      }) {
    final needsTajawal = isAr || AppDataProvider.instance.useArabicNumbers;
    return needsTajawal
        ? GoogleFonts.tajawal(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      fontFeatures: fontFeatures,
    )
        : GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      fontFeatures: fontFeatures,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final isAr = provider.language == 'ar';
    final prayerTimes = provider.prayerTimes;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Computed once per second inside _refreshTick (not here), so scrolling
    // never triggers prayer-time math.
    final nextPrayerInfo = _cachedNextPrayerInfo;
    final remaining = _cachedRemaining;
    final nextPrayerName = nextPrayerInfo?.name;

    // Consistent surface color matching the reference design
    final bgColor = isDark ? colorScheme.surface : const Color(0xFFF5F5F8);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.prayerCard.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAr
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: AppColors.prayerCard,
                  size: 22,
                ),
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          title: Text(
            isAr ? 'مواقيت الصلاة' : 'Prayer Times',
            style: _uiFont(
              isAr,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: colorScheme.onSurface,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.prayerCard.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.prayerCard,
                    size: 18,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isAr
                              ? 'عرض التقويم غير متاح بعد'
                              : 'Calendar view not wired up yet',
                          style: _uiFont(isAr, fontSize: 13),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Purple gradient header card with countdown ──
              _FadeSlideIn(
                child: _buildCountdownCard(
                  context,
                  isAr,
                  nextPrayerInfo,
                  remaining,
                  prayerTimes,
                ),
              ),
              const SizedBox(height: 20),

              // ── Prayer times list ──
              if (prayerTimes == null)
                _buildEmptyPrayerTimes(isAr, colorScheme)
              else
                _FadeSlideIn(
                  child: _buildPrayerListCard(
                    context,
                    isAr,
                    prayerTimes,
                    nextPrayerName,
                  ),
                ),
              const SizedBox(height: 20),

              // ── Qibla direction card ──
              _FadeSlideIn(child: _buildQiblaCard(context, isAr)),

              const SizedBox(height: 20),

              // ── Adkar entry point ──
              _FadeSlideIn(child: _buildAdhkarNavCard(context, isAr)),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // COUNTDOWN HEADER CARD — Purple gradient, mosque silhouette, dates,
  // next prayer name, live countdown, location chip.
  // =====================================================================

  // Each banner covers the period *starting* at the named prayer.
  // ignore: unused_field
  static const Map<String, String> _bannerAssetByPeriod = {
    'Fajr': 'assets/PrayersBanner/FajrBANNER.png',
    'Dhuhr': 'assets/PrayersBanner/DuhrBANNER.png',
    'Asr': 'assets/PrayersBanner/AsrBANNER.png',
    'Maghrib': 'assets/PrayersBanner/MagribBANNER.png',
    'Isha': 'assets/PrayersBanner/IshaBANNER.png',
  };

  // ignore: unused_element
  String? _currentPeriodName(dynamic prayerTimes) {
    if (prayerTimes == null) return null;
    final now = prayerTimes.fajr.locationNow;
    final fajr = prayerTimes.fajr.timeToday;
    final dhuhr = prayerTimes.dhuhr.timeToday;
    final asr = prayerTimes.asr.timeToday;
    final maghrib = prayerTimes.maghrib.timeToday;
    final isha = prayerTimes.isha.timeToday;

    if (now.isBefore(fajr)) return 'Isha';
    if (now.isBefore(dhuhr)) return 'Fajr';
    if (now.isBefore(asr)) return 'Dhuhr';
    if (now.isBefore(maghrib)) return 'Asr';
    if (now.isBefore(isha)) return 'Maghrib';
    return 'Isha';
  }

  Widget _buildCountdownCard(
      BuildContext context,
      bool isAr,
      _NextPrayerInfo? info,
      Duration? remaining,
      dynamic prayerTimes,
      ) {
    final translatedName = info != null
        ? _translatePrayerName(info.name, isAr)
        : null;
    final locationLabel = _locationLabel(prayerTimes);
    final currentPeriod = _currentPeriodName(prayerTimes);
    final bannerAsset = currentPeriod != null
        ? _bannerAssetByPeriod[currentPeriod]
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        child: Stack(
          children: [
            // Banner image background
            if (bannerAsset != null)
              Positioned.fill(
                child: Image.asset(
                  bannerAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to gradient if image fails to load
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6C63E5),
                            Color(0xFF5046C4),
                            Color(0xFF3D33A8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF6C63E5),
                        Color(0xFF5046C4),
                        Color(0xFF3D33A8),
                      ],
                    ),
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row: Dates (left) — Next Prayer label (right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Gregorian + Hijri dates
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _gregorianDateLabel(isAr),
                              style: _uiFont(
                                isAr,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _hijriDateLabel(isAr),
                              style: _uiFont(
                                isAr,
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right: "Next Prayer" label
                      if (info != null)
                        Text(
                          isAr ? 'الصلاة القادمة' : 'Next Prayer',
                          style: _uiFont(
                            isAr,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Center: Prayer name + countdown + "Remaining"
                  if (info != null && remaining != null) ...[
                    // Prayer name — right-aligned
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        translatedName ?? '',
                        style: _uiFont(
                          isAr,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Large countdown timer — right-aligned. Driven by a
                    // ValueNotifier so the once-a-second update repaints
                    // ONLY this text instead of the whole screen.
                    Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<String>(
                        valueListenable: _countdownText,
                        builder: (context, value, _) => Text(
                          value,
                          style: _uiFont(
                            isAr,
                            fontSize: 38,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            color: Colors.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // "Remaining" label
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isAr ? 'متبقي' : 'Remaining',
                        style: _uiFont(
                          isAr,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        isAr
                            ? 'تعذر تحديد أوقات الصلاة'
                            : 'Prayer times unavailable',
                        style: _uiFont(
                          isAr,
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Location chip at the bottom
                  if (locationLabel != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              locationLabel,
                              style: _uiFont(
                                isAr,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // PRAYER LIST CARD — Clean white/surface card with 6 rows
  // =====================================================================

  Widget _buildPrayerListCard(
      BuildContext context,
      bool isAr,
      dynamic prayerTimes,
      String? nextPrayerName,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in [
            ('Fajr', prayerTimes.fajr.formattedTime),
            ('Sunrise', prayerTimes.sunrise.formattedTime),
            ('Dhuhr', prayerTimes.dhuhr.formattedTime),
            ('Asr', prayerTimes.asr.formattedTime),
            ('Maghrib', prayerTimes.maghrib.formattedTime),
            ('Isha', prayerTimes.isha.formattedTime),
          ].asMap().entries) ...[
            _buildPrayerRow(
              context,
              isAr,
              entry.value.$1,
              entry.value.$2,
              nextPrayerName == entry.value.$1,
            ),
            if (entry.key != 5)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
          ],
        ],
      ),
    );
  }

  /// A single prayer row matching the reference design exactly:
  /// small colored icon → bold name → colored time → colored bell icon
  Widget _buildPrayerRow(
      BuildContext context,
      bool isAr,
      String name,
      String time,
      bool isNext,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final translatedName = _translatePrayerName(name, isAr);
    final accent = _prayerColors[name] ?? AppColors.prayerCard;
    final icon = _prayerIcons[name] ?? Icons.mosque;
    final reminderOn = AppDataProvider.instance.isPrayerReminderEnabled(name);
    final isSunrise = name == 'Sunrise';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isNext
            ? accent.withValues(alpha: isDark ? 0.1 : 0.05)
            : Colors.transparent,
        borderRadius: isNext ? BorderRadius.circular(0) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Prayer icon with colored tint
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          // Prayer name
          Expanded(
            child: Text(
              translatedName,
              style: _uiFont(
                isAr,
                fontSize: 16,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // Time in accent color
          Text(
            _localizeDigits(time),
            style: _uiFont(
              isAr,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isNext
                  ? accent
                  : (isDark
                  ? colorScheme.onSurface.withValues(alpha: 0.75)
                  : colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: 12),
          // Notification bell
          GestureDetector(
            onTap: () => _toggleReminder(name),
            child: Icon(
              isSunrise
                  ? Icons.notifications_off_outlined
                  : (reminderOn
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded),
              size: 20,
              color: isSunrise
                  ? colorScheme.onSurface.withValues(alpha: 0.2)
                  : (reminderOn
                  ? accent
                  : colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrayerTimes(bool isAr, ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.location_off_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isAr
                  ? 'تعذر تحديد أوقات الصلاة. تأكد من تفعيل الموقع.'
                  : 'Prayer times unavailable. Make sure location is enabled.',
              style: _uiFont(
                isAr,
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // QIBLA DIRECTION CARD — Kaaba icon, bearing, "View on Map"
  // =====================================================================

  Widget _buildQiblaCard(BuildContext context, bool isAr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    final latLon = _readDeviceLatLon();
    final staticBearing = latLon != null
        ? _qiblaBearing(latLon.$1, latLon.$2)
        : null;
    final locationLabel = _locationLabel(AppDataProvider.instance.prayerTimes);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          HapticFeedback.selectionClick();

          // Show rewarded ad for free users before opening Qibla (as requested)
          final provider = AppDataProvider.instance;
          if (!provider.isSubscribed) {
            // 1) try rewarded ad (3.5m cooldown inside provider)
            if (provider.canShowAd) {
              await provider.showRewardedAd();
            } else {
              // 2) fallback: try 10-credit charge if ad on cooldown and not enough points
              // Still allow opening Qibla even if ad not shown — don't block user
              // If you want to enforce, uncomment next lines:
              // if (!provider.consumeQiblaCredits() && context.mounted) {
              //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تحتاج 10 رصيد أو مشاهدة إعلان' : 'Need 10 credits or watch an ad')));
              //   return;
              // }
            }
          }

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QiblaFinderScreen(
                  isAr: isAr,
                  locationLabel: locationLabel,
                  initialBearing: staticBearing,
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Kaaba emoji in a circle — 🕋
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.prayerCard.withValues(alpha: 0.12)
                      : const Color(0xFFF0EEF8),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🕋', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              // Qibla Direction info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'اتجاه القبلة' : 'Qibla Direction',
                      style: _uiFont(
                        isAr,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Live/static status chip — rebuilt only when the first
                    // compass sample arrives (bool notifier), never on
                    // compass ticks.
                    ValueListenableBuilder<bool>(
                      valueListenable: _liveCompassVN,
                      builder: (context, hasLiveCompass, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasLiveCompass
                                ? Icons.sensors_rounded
                                : Icons.explore_outlined,
                            size: 14,
                            color: hasLiveCompass
                                ? const Color(0xFF2E9E6D)
                                : colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              hasLiveCompass
                                  ? (isAr ? 'بوصلة مباشرة' : 'Live compass')
                                  : (isAr
                                  ? 'اتجاه تقريبي'
                                  : 'Location bearing'),
                              overflow: TextOverflow.ellipsis,
                              style: _uiFont(
                                isAr,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasLiveCompass
                                    ? const Color(0xFF2E9E6D)
                                    : colorScheme.onSurface.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // "View on Map" button — independently tappable (its own
              // InkWell wins the tap over the card's outer InkWell), opens
              // a dedicated map screen showing a line from the user's
              // current location to the Kaaba.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: latLon == null
                      ? null
                      : () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QiblaMapScreen(
                          isAr: isAr,
                          userLat: latLon.$1,
                          userLon: latLon.$2,
                          bearingDeg: staticBearing ?? 0,
                          locationLabel: locationLabel,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.prayerCard.withValues(alpha: 0.12)
                                : const Color(0xFFF0EEF8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.map_outlined,
                            color: AppColors.prayerCard,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr ? 'عرض على الخريطة' : 'View on Map',
                          style: _uiFont(
                            isAr,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // ADKAR NAV CARD
  // =====================================================================

  Widget _buildAdhkarNavCard(BuildContext context, bool isAr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdhkarScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.sunsetOrange.withValues(alpha: 0.28),
                      AppColors.sunsetOrange.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.sunsetOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'الأذكار والأدعية' : 'Adhkar & Duas',
                      style: _uiFont(
                        isAr,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr
                          ? 'تصفح الأذكار والأدعية وعدّاد التسبيح'
                          : 'Browse adhkar, duas, and tally counters',
                      style: _uiFont(
                        isAr,
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _translatePrayerName(String name, bool isAr) {
    if (!isAr) return name;
    switch (name) {
      case 'Fajr':
        return 'الفجر';
      case 'Sunrise':
        return 'الشروق';
      case 'Dhuhr':
        return 'الظهر';
      case 'Asr':
        return 'العصر';
      case 'Maghrib':
        return 'المغرب';
      case 'Isha':
        return 'العشاء';
      default:
        return name;
    }
  }
}

// ---------------------------------------------------------------------------
// Dedicated full-screen Qibla compass — opened by tapping the Qibla card.
// Runs its own live flutter_qiblah stream (independent lifecycle from the
// Prayers screen), shows a big needle pointing at the Kaaba, and confirms
// alignment with a subtle green glow + haptic tap once the device is
// pointed at Qibla. Falls back to the static, location-based bearing when
// a live compass isn't available.
// ---------------------------------------------------------------------------

/// Immutable snapshot of the low-frequency Qibla readouts. Emitted through a
/// ValueNotifier only when something actually changes, keeping text rebuilds
/// rare while the compass needle animates at full frame rate.
class _QiblaHud {
  const _QiblaHud({
    this.bearing,
    this.heading,
    this.turnAmount,
    this.aligned = false,
  });

  final int? bearing; // Qibla bearing from north
  final int? heading; // phone heading from north (live only)
  final int? turnAmount; // signed degrees still to turn (live only)
  final bool aligned;

  bool get isLive => heading != null;
}

class QiblaFinderScreen extends StatefulWidget {
  const QiblaFinderScreen({
    super.key,
    required this.isAr,
    this.locationLabel,
    this.initialBearing,
  });

  final bool isAr;
  final String? locationLabel;
  final double? initialBearing;

  @override
  State<QiblaFinderScreen> createState() => _QiblaFinderScreenState();
}

class _QiblaFinderScreenState extends State<QiblaFinderScreen>
    with TickerProviderStateMixin {
  QiblahDirection? _qiblahDirection;
  StreamSubscription<QiblahDirection>? _qiblahSubscription;
  Timer? _loadingFallbackTimer;
  bool _alignmentFeedbackShown = false;
  bool _qiblahUnavailable = false;
  bool _loading = true;
  bool _hasFirstSample = false;

  // ── Performance-critical design ────────────────────────────────────────
  // The compass stream fires far more often than Flutter should rebuild a
  // whole screen. So the listener only stores readings and drives a Ticker
  // that smooths angles frame-by-frame into ValueNotifiers. Each notifier
  // rebuilds ONLY the tiny widget that depends on it (a Transform or one
  // Text), so compass motion stays perfectly smooth without ever calling
  // setState in the hot path.
  final ValueNotifier<double> _ringRotation = ValueNotifier(0); // deg
  final ValueNotifier<double> _glyphOrbit = ValueNotifier(0); // deg
  final ValueNotifier<_QiblaHud> _hud = ValueNotifier(_QiblaHud());

  // Alignment flips at most twice per approach — the big compass frame
  // (ring, needle, colors) rebuilds ONLY on this notifier, never when the
  // heading/turn integers change. Previously every degree of movement
  // rebuilt the whole 280x296 compass stack, which is what made the window
  // feel laggy.
  final ValueNotifier<bool> _alignedVN = ValueNotifier(false);

  // Accuracy level ("مستوى الدقة") shown under the bearing readout.
  // 0 = unknown, 1 = low, 2 = medium, 3 = high. With a live compass it is
  // derived from the angular jitter of recent raw heading samples (stable
  // signal → high); without one it falls back to the GPS fix accuracy.
  final ValueNotifier<int> _accuracyVN = ValueNotifier(0);

  // Rolling window of recent RAW (unsmoothed) heading readings used to
  // estimate compass signal quality.
  final List<double> _headingSamples = [];

  Ticker? _smoothingTicker;

  // Internal smoothed angles (degrees).
  double _smoothedRing = 0;
  double _smoothedGlyph = 0;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    _initStream();
    // Safety fallback: ensure loading spinner never blocks the user longer than 2 seconds
    _loadingFallbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          if (_qiblahDirection == null) {
            _qiblahUnavailable = true;
          }
        });
      }
    });
    // Static bearing readout while there's no live compass. The accuracy
    // chip starts from the GPS fix quality; a live compass overrides it as
    // soon as samples start arriving.
    final staticBearing = widget.initialBearing ?? _getFallbackBearing();
    if (staticBearing != null) {
      _hud.value = _QiblaHud(bearing: staticBearing.round());
    }
    _accuracyVN.value = _gpsAccuracyLevel();
  }

  Future<void> _initStream() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _qiblahUnavailable = true;
          _loading = false;
        });
      }
      return;
    }
    try {
      final status = await FlutterQiblah.checkLocationStatus().timeout(
        const Duration(seconds: 3),
        onTimeout: () => LocationStatus(false, LocationPermission.denied),
      );

      if (!status.enabled || status.status == LocationPermission.denied) {
        final granted = await FlutterQiblah.requestPermissions().timeout(
          const Duration(seconds: 3),
          onTimeout: () => LocationPermission.denied,
        );
        if (granted != LocationPermission.always &&
            granted != LocationPermission.whileInUse) {
          if (mounted) {
            setState(() {
              _qiblahUnavailable = true;
              _loading = false;
            });
          }
          return;
        }
      } else if (status.status == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _qiblahUnavailable = true;
            _loading = false;
          });
        }
        return;
      }

      _qiblahSubscription = FlutterQiblah.qiblahStream.listen(
            (direction) {
          if (!mounted) return;
          _qiblahDirection = direction;
          final firstSample = !_hasFirstSample;
          _hasFirstSample = true;

          // Snap on the very first reading so the compass doesn't sweep
          // from 0°, then let the ticker chase subsequent readings.
          if (firstSample) {
            _smoothedRing = _normalizeDegrees(-direction.direction);
            _smoothedGlyph = _qiblahNeedleAngleDeg(direction);
          }
          if (_loading) {
            setState(() => _loading = false);
          }
          _updateHud(direction);
          _updateAccuracy(direction);
          _maybeVibrateOnAlign(direction);
          _smoothingTicker ??=
              (createTicker(_onTick)..start());
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _qiblahUnavailable = true;
              _loading = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _qiblahUnavailable = true;
          _loading = false;
        });
      }
    }
  }

  /// Frame-rate independent exponential smoothing toward the latest compass
  /// targets. Runs only while the screen shows live data; each frame just
  /// updates ValueNotifiers, so only the rotating Transforms rebuild.
  void _onTick(Duration elapsed) {
    final direction = _qiblahDirection;
    if (direction == null || !mounted) return;

    // k ≈ 14/s: fast enough to feel responsive, slow enough to hide
    // sensor noise. dt-based, so behaviour is identical at 60/90/120 Hz.
    const k = 14.0;
    final dt = elapsed.inMicroseconds / 1e6;
    final t = (1 - math.exp(-k * dt)).clamp(0.0, 1.0);

    final ringTarget = _normalizeDegrees(-direction.direction);
    final glyphTarget = _qiblahNeedleAngleDeg(direction);

    _smoothedRing =
        _smoothedRing + _shortestAngleDeg(ringTarget - _smoothedRing) * t;
    _smoothedGlyph =
        _smoothedGlyph + _shortestAngleDeg(glyphTarget - _smoothedGlyph) * t;

    _ringRotation.value = _normalizeDegrees(_smoothedRing);
    _glyphOrbit.value = _normalizeDegrees(_smoothedGlyph);
  }

  /// Pushes the low-frequency textual readouts (bearing / heading / turn /
  /// aligned). Only notifies listeners when a displayed value changes.
  void _updateHud(QiblahDirection direction) {
    final hud = _QiblaHud(
      bearing: _normalizeDegrees(direction.offset).round(),
      heading: _normalizeDegrees(direction.direction).round(),
      turnAmount: _turnToQiblaDeg(direction).round(),
      aligned: _turnToQiblaDeg(direction).abs() <= 3,
    );
    final old = _hud.value;
    if (old.bearing != hud.bearing ||
        old.heading != hud.heading ||
        old.turnAmount != hud.turnAmount ||
        old.aligned != hud.aligned) {
      _hud.value = hud;
    }
    // ValueNotifier ignores equal values, so the compass frame only
    // rebuilds on an actual aligned/not-aligned transition.
    _alignedVN.value = hud.aligned;

    // Run the alignment glow pulse only while aligned — previously it
    // repeated forever, burning frames even when idle.
    if (hud.aligned && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hud.aligned && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  /// Estimates compass signal quality from the angular jitter (mean
  /// absolute deviation) of the last few RAW heading samples. A stable
  /// magnetometer reading produces low jitter → "high" accuracy; a noisy /
  /// disturbed signal (metal nearby, fast movement, needs figure-8
  /// calibration) produces high jitter → "low". Notifies only when the
  /// displayed level actually changes.
  void _updateAccuracy(QiblahDirection direction) {
    _headingSamples.add(_normalizeDegrees(direction.direction));
    if (_headingSamples.length > 20) _headingSamples.removeAt(0);
    if (_headingSamples.length < 8) return;

    // Circular mean of the samples.
    double sinSum = 0, cosSum = 0;
    for (final s in _headingSamples) {
      final rad = s * math.pi / 180;
      sinSum += math.sin(rad);
      cosSum += math.cos(rad);
    }
    final mean = math.atan2(sinSum, cosSum);

    // Mean absolute angular deviation from that mean, in degrees.
    double devSum = 0;
    for (final s in _headingSamples) {
      devSum += _shortestAngleDeg(
        (s * math.pi / 180 - mean) * 180 / math.pi,
      ).abs();
    }
    final jitter = devSum / _headingSamples.length;

    final level = jitter <= 2.5 ? 3 : (jitter <= 6 ? 2 : 1);
    if (_accuracyVN.value != level) _accuracyVN.value = level;
  }

  /// Fallback accuracy level when there is no live compass: derived from
  /// the GPS fix's horizontal accuracy. The Qibla bearing is computed from
  /// this position, so a poor fix means an approximate direction.
  int _gpsAccuracyLevel() {
    final loc = AppDataProvider.instance.location;
    final accuracy = loc?.accuracy ?? -1;
    if (accuracy < 0) return 0; // no accuracy info at all
    if (accuracy <= 20) return 3;
    if (accuracy <= 100) return 2;
    return 1;
  }

  void _maybeVibrateOnAlign(QiblahDirection direction) {
    final delta = _turnToQiblaDeg(direction).abs();
    final aligned = delta <= 3;

    if (aligned && !_alignmentFeedbackShown) {
      // One-shot confirmation when alignment begins. (The old version ran
      // a repeating vibrate+sound timer every 300 ms — expensive and noisy.)
      _alignmentFeedbackShown = true;
      Vibration.vibrate(duration: 100, amplitude: 255);
      HapticFeedback.heavyImpact();
      _playAlignmentSound();
    } else if (!aligned && _alignmentFeedbackShown) {
      _alignmentFeedbackShown = false;
    }
  }

  Future<void> _playAlignmentSound() async {
    try {
      // Use system sound for quick alignment feedback
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // Non-fatal — some devices have no system sound pool.
    }
  }

  double? _getFallbackBearing() {
    final loc = AppDataProvider.instance.location;
    if (loc != null) {
      const kaabaLat = 21.422487;
      const kaabaLon = 39.826206;
      final phiK = kaabaLat * math.pi / 180;
      final lambdaK = kaabaLon * math.pi / 180;
      final phi = loc.latitude * math.pi / 180;
      final lambda = loc.longitude * math.pi / 180;
      final y = math.sin(lambdaK - lambda);
      final x =
          math.cos(phi) * math.tan(phiK) -
              math.sin(phi) * math.cos(lambdaK - lambda);
      var bearing = math.atan2(y, x) * 180 / math.pi;
      return (bearing + 360) % 360;
    }
    return null;
  }

  @override
  void dispose() {
    _smoothingTicker?.dispose();
    _loadingFallbackTimer?.cancel();
    _qiblahSubscription?.cancel();
    _pulseController.dispose();
    _ringRotation.dispose();
    _glyphOrbit.dispose();
    _hud.dispose();
    _alignedVN.dispose();
    _accuracyVN.dispose();
    super.dispose();
  }

  TextStyle _font(
      bool isAr, {
        required double fontSize,
        FontWeight fontWeight = FontWeight.w400,
        Color? color,
      }) {
    final needsTajawal = isAr || AppDataProvider.instance.useArabicNumbers;
    return needsTajawal
        ? GoogleFonts.tajawal(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    )
        : GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  String _localizeDigits(String input) {
    if (!AppDataProvider.instance.useArabicNumbers) return input;
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

  /// Kaaba glyph — now uses 🕋 emoji as requested, orbiting the ring.
  Widget _buildKaabaGlyph() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC9A227), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: const Text('🕋', style: TextStyle(fontSize: 20)),
    );
  }

  /// Accuracy pill: icon + "مستوى الدقة / Accuracy" + level word, color-
  /// coded (green high / amber medium / red low / grey unknown).
  Widget _buildAccuracyChip(BuildContext context, bool isAr, int level) {
    final colorScheme = Theme.of(context).colorScheme;

    late final Color color;
    late final String label;
    late final IconData icon;
    switch (level) {
      case 3:
        color = const Color(0xFF2E9E6D);
        label = isAr ? 'عالية' : 'High';
        icon = Icons.gps_fixed_rounded;
      case 2:
        color = const Color(0xFFF2A93B);
        label = isAr ? 'متوسطة' : 'Medium';
        icon = Icons.gps_not_fixed_rounded;
      case 1:
        color = const Color(0xFFE05252);
        label = isAr ? 'منخفضة' : 'Low';
        icon = Icons.gps_off_rounded;
      default:
        color = colorScheme.onSurface.withValues(alpha: 0.4);
        label = isAr ? 'غير متاحة' : 'Unavailable';
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            isAr ? 'دقة البوصلة' : 'Compass',
            style: _font(
              isAr,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          Text(
            '  •  ',
            style: _font(
              isAr,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          Text(
            label,
            style: _font(
              isAr,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// A single "Rotate Left" / "Rotate Right" pill.
  Widget _buildRotateChip(
      BuildContext context,
      bool isAr, {
        required bool isLeft,
        required bool active,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active
        ? AppColors.prayerCard
        : colorScheme.onSurface.withValues(alpha: 0.35);
    final label = isLeft
        ? (isAr ? 'استدر يسارًا' : 'Rotate Left')
        : (isAr ? 'استدر يمينًا' : 'Rotate Right');
    final icon = isLeft
        ? Icons.rotate_left_rounded
        : Icons.rotate_right_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? AppColors.prayerCard.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? AppColors.prayerCard.withValues(alpha: 0.4)
              : colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: _font(
              isAr,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final colorScheme = Theme.of(context).colorScheme;
    // Live values arrive through ValueNotifiers (see _onTick / _updateHud);
    // build() itself only runs on rare state changes like loading screens.

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              isAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            isAr ? 'مكتشف القبلة' : 'Qibla Finder',
            style: _font(isAr, fontWeight: FontWeight.w700, fontSize: 20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Top corners: accuracy (left) + location (right) as per reference ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _accuracyVN,
                      builder: (context, level, _) => _buildAccuracyChip(context, isAr, level),
                    ),
                    if (widget.locationLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 13, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                            const SizedBox(width: 4),
                            Text(widget.locationLabel!, style: _font(isAr, fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                          ],
                        ),
                      )
                    else
                      const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Compass frame ──
                // Rebuilds ONLY when alignment flips (accent color change).
                // Rotation is handled inside by ValueNotifier-driven
                // Transforms at frame rate; per-degree HUD changes never
                // reach this subtree anymore.
                ValueListenableBuilder<bool>(
                  valueListenable: _alignedVN,
                  builder: (context, aligned, _) {
                    final accent = aligned
                        ? const Color(0xFF2E9E6D)
                        : AppColors.prayerCard;
                    // Glow wrapper pulses only while aligned (controller is
                    // stopped otherwise); `child` below is fully cached.
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final glow = aligned
                            ? 0.25 + (_pulseController.value * 0.25)
                            : 0.0;
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: aligned
                                ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF2E9E6D,
                                ).withValues(alpha: glow),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ]
                                : [],
                          ),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: 280,
                        height: 296,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Thick colored ring - fixed, doesn't rotate
                            Positioned(
                              top: 16,
                              child: Container(
                                width: 264,
                                height: 264,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.surface,
                                  border: Border.all(color: accent, width: 13),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        // Compass ticks - rotate to show detected direction at top.
                        // Driven directly by the smoothing ticker at frame
                        // rate; the ticks CustomPaint is a cached, repaint-
                        // isolated child so it never repaints, only the
                        // transform layer updates.
                        Positioned(
                          top: 16,
                          child: ValueListenableBuilder<double>(
                            valueListenable: _ringRotation,
                            builder: (context, ringRotation, child) {
                              return Transform.rotate(
                                angle: ringRotation * math.pi / 180,
                                child: child,
                              );
                            },
                            child: RepaintBoundary(
                              child: SizedBox(
                                width: 264,
                                height: 264,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: const Size(264, 264),
                                      painter: _CompassTicksPainter(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    // North marker — rotates with the ring
                                    Positioned(
                                      top: 14,
                                      child: Text(
                                        'N',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.95),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Kaaba glyph — orbits the ring's edge at the live
                        // Qibla bearing, exactly like the reference: it
                        // slides around wherever Qibla currently sits
                        // relative to where the phone is pointing, and only
                        // reaches the top once you're actually aligned. The
                        // outer rotate swings its *position* around the ring
                        // center; the inner counter-rotate cancels that same
                        // rotation out of the glyph's own orientation so the
                        // icon stays upright while it orbits instead of
                        // spinning. Per-frame rotation via ValueNotifier (no
                        // tween restarts = no rubber-band lag).
                        ValueListenableBuilder<double>(
                          valueListenable: _glyphOrbit,
                          builder: (context, orbitAngleDeg, child) {
                            return Transform.rotate(
                              angle: orbitAngleDeg * math.pi / 180,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Transform.translate(
                                  offset: const Offset(0, 4),
                                  child: Transform.rotate(
                                    angle: -orbitAngleDeg * math.pi / 180,
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: RepaintBoundary(child: _buildKaabaGlyph()),
                        ),
                        // Center needle — fixed, vertical, never rotates.
                        // It's purely a "you are here / this is your
                        // heading" marker; the only thing that changes is
                        // its color, which switches to green once the
                        // Kaaba glyph above has orbited to the top (i.e.
                        // `aligned` becomes true) — matching the reference
                        // exactly: the needle never spins, only the ring
                        // and the Kaaba glyph glued to it do.
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Soft 8-point star glow behind the needle.
                              Transform.rotate(
                                angle: math.pi / 4,
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              // The leaf-shaped needle itself — always
                              // vertical, only its color animates.
                              CustomPaint(
                                size: const Size(46, 160),
                                painter: _QiblaLeafPainter(color: accent),
                              ),
                              // Center badge — purple mosque icon as per provided image
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7B5CF6),
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                  },
                ),

                const SizedBox(height: 28),

                // Low-frequency readouts (bearing / heading / turn amount).
                // Rebuilt only when a displayed integer actually changes.
                ValueListenableBuilder<_QiblaHud>(
                  valueListenable: _hud,
                  builder: (context, hud, _) {
                    final accent = hud.aligned
                        ? const Color(0xFF2E9E6D)
                        : AppColors.prayerCard;
                    final rotateRight = (hud.turnAmount ?? 0) < 0; // FIX: was inverted — to the right showed left

                    if (hud.bearing == null) {
                      return Text(
                        isAr
                            ? 'تعذر تحديد اتجاه القبلة'
                            : 'Could not determine Qibla direction',
                        style: _font(
                          isAr,
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Text(
                          _localizeDigits('${hud.bearing}°'),
                          style: _font(
                            isAr,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (hud.isLive && hud.heading != null) ...[
                          Text(
                            isAr
                                ? _localizeDigits('اتجاه الهاتف ${hud.heading}°')
                                : 'Phone heading ${hud.heading}°',
                            textAlign: TextAlign.center,
                            style: _font(
                              isAr,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (hud.aligned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E9E6D).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF2E9E6D).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🕋', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  isAr ? 'أنت تواجه القبلة الآن' : 'You are facing the Qibla ✓',
                                  textAlign: TextAlign.center,
                                  style: _font(
                                    isAr,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E9E6D),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (hud.isLive) ...[
                          Text(
                            isAr
                                ? 'أدر جهازك لمحاذاة السهم مع الكعبة'
                                : 'Turn your device to align the arrow with the Kaaba',
                            textAlign: TextAlign.center,
                            style: _font(
                              isAr,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // ── Guidance: Move Left / Move Right with big arrow ──
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.prayerCard.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.prayerCard.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!rotateRight) ...[
                                  Icon(Icons.arrow_back_rounded, color: AppColors.prayerCard, size: 22),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  isAr
                                      ? _localizeDigits('${hud.turnAmount?.abs() ?? 0}° ${rotateRight ? 'إلى اليمين' : 'إلى اليسار'}')
                                      : '${hud.turnAmount?.abs() ?? 0}° ${rotateRight ? 'to the right' : 'to the left'}',
                                  textAlign: TextAlign.center,
                                  style: _font(
                                    isAr,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.prayerCard,
                                  ),
                                ),
                                if (rotateRight) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, color: AppColors.prayerCard, size: 22),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildRotateChip(
                                context,
                                isAr,
                                isLeft: true,
                                active: !rotateRight,
                              ),
                              const SizedBox(width: 12),
                              _buildRotateChip(
                                context,
                                isAr,
                                isLeft: false,
                                active: rotateRight,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'ابقِ الهاتف مسطحًا وبعيدًا عن المعادن، وحرّكه على شكل 8 إذا تغير الاتجاه.'
                                        : 'Keep the phone flat and away from metal. Move it in a figure 8 if the compass drifts.',
                                    style: _font(
                                      isAr,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Text(
                            isAr
                                ? 'أدر الجهاز حتى يشير السهم للأعلى'
                                : 'Rotate your device until the arrow points up',
                            textAlign: TextAlign.center,
                            style: _font(
                              isAr,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                if (_qiblahUnavailable) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'البوصلة الحية غير متاحة على هذا الجهاز. الاتجاه المعروض تقريبي بناءً على موقعك.'
                                : 'Live compass isn\'t available on this device. The direction shown is an approximate, location-based bearing.',
                            style: _font(
                              isAr,
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Uniform tick marks around the inner face, every 15°, matching the
// reference design's evenly spaced dashes (no cardinal emphasis).
class _CompassTicksPainter extends CustomPainter {
  _CompassTicksPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 14;
    const tickLength = 8.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg += 15) {
      final angle = deg * math.pi / 180;
      final start = Offset(
        center.dx + (outerRadius - tickLength) * math.sin(angle),
        center.dy - (outerRadius - tickLength) * math.cos(angle),
      );
      final end = Offset(
        center.dx + outerRadius * math.sin(angle),
        center.dy - outerRadius * math.cos(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompassTicksPainter oldPainter) =>
      oldPainter.color != color;
}

// Vertical "leaf" / lens shape for the center Qibla needle — two mirrored
// curves tapering to a point at top and bottom, echoing the leaf-shaped
// needle used by several popular Qibla-compass apps.
class _QiblaLeafPainter extends CustomPainter {
  _QiblaLeafPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w * 0.86, h * 0.5, w / 2, h)
      ..quadraticBezierTo(w * 0.14, h * 0.5, w / 2, 0)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.25), 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.65)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _QiblaLeafPainter oldPainter) =>
      oldPainter.color != color;
}

// ---------------------------------------------------------------------------
// QIBLA MAP SCREEN — opened from the "View on Map" button on the Qibla
// card. Shows a real OpenStreetMap map (via flutter_map — free tiles, no
// API key) with a line from the user's current location to the Kaaba in
// Makkah, plus the great-circle distance.
// ---------------------------------------------------------------------------

class QiblaMapScreen extends StatelessWidget {
  const QiblaMapScreen({
    super.key,
    required this.isAr,
    required this.userLat,
    required this.userLon,
    required this.bearingDeg,
    this.locationLabel,
  });

  final bool isAr;
  final double userLat;
  final double userLon;
  final double bearingDeg;
  final String? locationLabel;

  static const double _kaabaLat = 21.4225;
  static const double _kaabaLon = 39.8262;
  static const LatLng _kaabaLatLng = LatLng(_kaabaLat, _kaabaLon);

  /// Great-circle distance to the Kaaba in kilometers (haversine formula).
  double get _distanceKm {
    const earthRadiusKm = 6371.0;
    final phi1 = userLat * math.pi / 180;
    final phi2 = _kaabaLat * math.pi / 180;
    final dPhi = (_kaabaLat - userLat) * math.pi / 180;
    final dLambda = (_kaabaLon - userLon) * math.pi / 180;
    final a =
        math.sin(dPhi / 2) * math.sin(dPhi / 2) +
            math.cos(phi1) *
                math.cos(phi2) *
                math.sin(dLambda / 2) *
                math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Points along the great-circle path from [start] to [end], via
  /// spherical linear interpolation — so the line drawn on the map follows
  /// the true shortest path over the globe instead of a straight
  /// (rhumb-line) segment on the flat projection.
  List<LatLng> _greatCirclePoints(LatLng start, LatLng end, {int segments = 64}) {
    final phi1 = start.latitude * math.pi / 180;
    final lambda1 = start.longitude * math.pi / 180;
    final phi2 = end.latitude * math.pi / 180;
    final lambda2 = end.longitude * math.pi / 180;

    final dPhi = phi2 - phi1;
    final dLambda = lambda2 - lambda1;
    final a =
        math.sin(dPhi / 2) * math.sin(dPhi / 2) +
            math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final delta = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    if (delta == 0) return [start, end];

    final points = <LatLng>[];
    for (int i = 0; i <= segments; i++) {
      final f = i / segments;
      final A = math.sin((1 - f) * delta) / math.sin(delta);
      final B = math.sin(f * delta) / math.sin(delta);
      final x =
          A * math.cos(phi1) * math.cos(lambda1) +
              B * math.cos(phi2) * math.cos(lambda2);
      final y =
          A * math.cos(phi1) * math.sin(lambda1) +
              B * math.cos(phi2) * math.sin(lambda2);
      final z = A * math.sin(phi1) + B * math.sin(phi2);
      final phi = math.atan2(z, math.sqrt(x * x + y * y));
      final lambda = math.atan2(y, x);
      points.add(LatLng(phi * 180 / math.pi, lambda * 180 / math.pi));
    }
    return points;
  }

  String _localizeDigits(String input) {
    if (!AppDataProvider.instance.useArabicNumbers) return input;
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

  TextStyle _font(
      bool isAr, {
        required double fontSize,
        FontWeight fontWeight = FontWeight.w400,
        Color? color,
      }) {
    final needsTajawal = isAr || AppDataProvider.instance.useArabicNumbers;
    return needsTajawal
        ? GoogleFonts.tajawal(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    )
        : GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final distanceKm = _distanceKm;
    final distanceLabel = distanceKm >= 100
        ? _localizeDigits(distanceKm.round().toString())
        : _localizeDigits(distanceKm.toStringAsFixed(1));

    final userLatLng = LatLng(userLat, userLon);
    final linePoints = _greatCirclePoints(userLatLng, _kaabaLatLng);
    final bounds = LatLngBounds.fromPoints([userLatLng, _kaabaLatLng]);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10131C)
          : const Color(0xFFF6F5FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          isAr ? 'الاتجاه إلى الكعبة' : 'Direction to the Kaaba',
          style: _font(
            isAr,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(48),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      // Free OpenStreetMap raster tiles — no API key.
                      // Set a descriptive package userAgent per OSM's tile
                      // usage policy (https://operations.osmfoundation.org/policies/tiles/).
                      TileLayer(
                        urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.tripproject.app',
                        maxNativeZoom: 19,
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: linePoints,
                            strokeWidth: 3.5,
                            color: AppColors.prayerCard,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: userLatLng,
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(
                                  0xFF3B82C4,
                                ).withValues(alpha: 0.25),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF3B82C4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: _kaabaLatLng,
                            width: 34,
                            height: 34,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFC9A227),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text('🕋', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        alignment: AttributionAlignment.bottomLeft,
                        attributions: [
                          TextSourceAttribution(
                            '© OpenStreetMap contributors',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2333) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'من' : 'From',
                            style: _font(
                              isAr,
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locationLabel ??
                                (isAr ? 'موقعك الحالي' : 'Your location'),
                            style: _font(
                              isAr,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$distanceLabel ${isAr ? 'كم' : 'km'}',
                          style: _font(
                            isAr,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.prayerCard,
                          ),
                        ),
                        Text(
                          isAr ? 'إلى مكة' : 'to Makkah',
                          style: _font(
                            isAr,
                            fontSize: 10,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Reusable drawn Kaaba icon — gradient-shaded black cube, gold kiswah band
// wrapping the full width, and a small gold door with a rounded top below
// the band. Scales cleanly from ~15 px (map marker) to ~30 px (compass
// glyph) while staying crisp.
// ---------------------------------------------------------------------------

class _KaabaIcon extends StatelessWidget {
  const _KaabaIcon({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = width * 0.88;
    final bandTop = h * 0.48;
    final bandHeight = h * 0.17;
    final doorWidth = w * 0.26;
    final doorTop = bandTop + bandHeight + h * 0.08;
    final doorHeight = (h - doorTop - h * 0.07).clamp(0.0, h);

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cube body — subtle top-lit gradient so it reads as 3D.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w * 0.10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF34343D), Color(0xFF0B0B0F)],
                ),
              ),
            ),
          ),
          // Gold kiswah band wrapping the full width.
          Positioned(
            left: 0,
            right: 0,
            top: bandTop,
            child: Container(
              height: bandHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE3BC4B), Color(0xFFC9A227)],
                ),
              ),
            ),
          ),
          // Gold door with rounded top, centered under the band.
          Positioned(
            left: w / 2 - doorWidth / 2,
            top: doorTop,
            child: Container(
              width: doorWidth,
              height: doorHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(doorWidth * 0.5),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE3BC4B), Color(0xFFB8901F)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Entrance animation wrapper (fade + slide-up), used to stagger list items.
// ---------------------------------------------------------------------------

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
