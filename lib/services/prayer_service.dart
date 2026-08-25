import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';

// ─── Prayer Time Model ────────────────────────────────────────────────────────

class PrayerTime {
  const PrayerTime({
    required this.name,
    required this.time,
    this.timezone,
  });

  final String name;
  final DateTime time;
  final String? timezone;

  /// Resolves the IANA [tz.Location] for this prayer's timezone, or null if
  /// unavailable/unparseable. Centralised here so `locationNow` and
  /// `timeToday` always agree on the same zone instead of drifting apart.
  tz.Location? get _resolvedLocation {
    if (timezone == null || timezone!.isEmpty) return null;
    try {
      tz_data.initializeTimeZones();
      return tz.getLocation(timezone!);
    } catch (_) {
      return null;
    }
  }

  /// Get current time in the location's timezone for accurate comparison
  DateTime get locationNow {
    final location = _resolvedLocation;
    if (location != null) return tz.TZDateTime.now(location);
    return DateTime.now();
  }

  /// Get the prayer time adjusted to today's date in the location's timezone.
  ///
  /// IMPORTANT: this must be built as a TZDateTime in the *same* location as
  /// `locationNow`, not a plain `DateTime(...)`. Dart's plain DateTime
  /// constructor stamps year/month/day/hour/minute using the device's own
  /// local timezone offset - so even though the numbers here (today's date,
  /// this prayer's hour/minute) are correct for the prayer's city, a plain
  /// DateTime would silently reinterpret them using the device's offset
  /// instead. If the device and the prayer's city are in different
  /// timezones, that mismatch shifts every comparison by the gap between
  /// the two offsets, which can reorder which prayers look "past" vs
  /// "upcoming" (e.g. Dhuhr appearing past when it hasn't happened yet).
  DateTime get timeToday {
    final location = _resolvedLocation;
    if (location != null) {
      final now = tz.TZDateTime.now(location);
      return tz.TZDateTime(location, now.year, now.month, now.day, time.hour, time.minute);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  bool get isPast => locationNow.isAfter(timeToday);

  /// Minutes until this prayer (negative if past)
  int get minutesUntil => timeToday.difference(locationNow).inMinutes;

  String get formattedTime {
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  IconData get icon {
    switch (name) {
      case 'Fajr': return Icons.wb_twilight;
      case 'Sunrise': return Icons.wb_sunny_outlined;
      case 'Dhuhr': return Icons.wb_sunny_outlined;
      case 'Asr': return Icons.wb_sunny;
      case 'Maghrib': return Icons.nights_stay_outlined;
      case 'Isha': return Icons.nightlight_round;
      default: return Icons.mosque;
    }
  }
}

class PrayerTimesData {
  const PrayerTimesData({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.timezone,
    required this.cityName,
    this.cityNameAr = '',
  });

  final PrayerTime fajr;
  final PrayerTime sunrise;
  final PrayerTime dhuhr;
  final PrayerTime asr;
  final PrayerTime maghrib;
  final PrayerTime isha;
  final DateTime date;
  final String timezone;
  final String cityName;
  final String cityNameAr;

  /// Localized city name for the given app language.
  String cityNameFor(bool isAr) =>
      isAr && cityNameAr.isNotEmpty ? cityNameAr : cityName;

  List<PrayerTime> get allPrayers => [fajr, dhuhr, asr, maghrib, isha];

  /// The next upcoming prayer (null if Isha is past)
  PrayerTime? get nextPrayer {
    for (final p in allPrayers) {
      if (!p.isPast) return p;
    }
    return null;
  }

  /// The most recent past prayer
  PrayerTime? get currentPrayer {
    PrayerTime? last;
    for (final p in allPrayers) {
      if (p.isPast) last = p;
    }
    return last;
  }
}

// ─── Prayer Service ───────────────────────────────────────────────────────────

/// Uses the free Aladhan.com API — no key required.
class PrayerService {
  static const _timeout = Duration(seconds: 12);
  static const _base = 'https://api.aladhan.com/v1';

  /// Fetches today's prayer times for [lat]/[lon].
  ///
  /// Pass [cityName] (resolved once by AppDataProvider via reverse
  /// geocoding in the app language) so the prayer card shows the exact
  /// same location name as the weather card and location chip. When null,
  /// the service reverse-geocodes itself, requesting names in [lang].
  Future<PrayerTimesData?> fetchPrayerTimes(
    double lat,
    double lon, {
    String? cityName,
    String? cityNameAr,
    String lang = 'en',
  }) async {
    try {
      // Always anchor to UTC "now" first - the device's local calendar day
      // isn't trustworthy here (that's part of what caused wrong times:
      // assuming the device's day/zone matches the queried city's).
      final utcNow = DateTime.now().toUtc();
      final method = _bestMethod(lat, lon);

      final firstDate = '${utcNow.day}-${utcNow.month}-${utcNow.year}';
      final timings1 = await _requestTimings(firstDate, lat, lon, method);
      if (timings1 == null) return null;

      final tzName = timings1.meta['timezone'] as String? ?? '';

      // Independently verify the city's real current offset from UTC via
      // a second, dedicated timezone API - this is what actually fixes
      // "every prayer time is incorrect": we no longer just trust however
      // Aladhan's own server happens to interpret that timezone (which can
      // silently go stale, e.g. after Jordan's 2022 permanent UTC+3 shift).
      final offsetSecs = tzName.isNotEmpty ? await _fetchOffsetSeconds(tzName) : null;
      final cityNow = offsetSecs != null
          ? utcNow.add(Duration(seconds: offsetSecs))
          : DateTime.now(); // fallback: assume device tz matches city tz

      // If the city's local calendar day differs from the UTC day we first
      // queried with (near midnight), refetch with the correct day so we
      // don't show yesterday's or tomorrow's times.
      Map<String, dynamic> timings = timings1.timings;
      if (cityNow.day != utcNow.day || cityNow.month != utcNow.month) {
        final cityDate = '${cityNow.day}-${cityNow.month}-${cityNow.year}';
        final timings2 = await _requestTimings(cityDate, lat, lon, method);
        if (timings2 != null) timings = timings2.timings;
      }

      // Get actual city name from coordinates using reverse geocoding
      // (skipped when the caller already resolved a localized city name).
      final actualCityName = cityName ?? await _getCityFromCoordinates(lat, lon, lang: lang);

      PrayerTime parse(String name, String key) {
        final raw = timings[key] as String? ?? '00:00';
        final parts = raw.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1].split(' ').first); // strip any suffix
        final t = DateTime(cityNow.year, cityNow.month, cityNow.day, h, m);
        return PrayerTime(name: name, time: t, timezone: tzName.isEmpty ? null : tzName);
      }

      return PrayerTimesData(
        fajr: parse('Fajr', 'Fajr'),
        sunrise: parse('Sunrise', 'Sunrise'),
        dhuhr: parse('Dhuhr', 'Dhuhr'),
        asr: parse('Asr', 'Asr'),
        maghrib: parse('Maghrib', 'Maghrib'),
        isha: parse('Isha', 'Isha'),
        date: cityNow,
        timezone: tzName.isEmpty ? 'Local' : tzName,
        cityName: actualCityName ??
            (tzName.isEmpty
                ? (lang == 'ar' ? 'موقعك الحالي' : 'Your Location')
                : _cityFromTimezone(tzName)),
        cityNameAr: cityNameAr ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<_TimingsResponse?> _requestTimings(
      String dateStr,
      double lat,
      double lon,
      int method,
      ) async {
    final uri = Uri.parse(
      '$_base/timings/$dateStr'
          '?latitude=$lat&longitude=$lon'
          '&method=$method'
          '&school=0'                   // Shafi'i Asr (shadow factor 1) - Jordan/Levant/Gulf convention
          '&midnightMode=0'
          '&latitudeAdjustmentMethod=3',
    );

    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final timings = data['timings'] as Map<String, dynamic>?;
    final meta = data['meta'] as Map<String, dynamic>?;
    if (timings == null) return null;

    return _TimingsResponse(timings: timings, meta: meta ?? const {});
  }

  /// Gets the real UTC offset (in seconds, including any DST) for an IANA
  /// timezone name using the local timezone database as primary resolution,
  /// falling back to worldtimeapi.org if local lookup fails.
  Future<int?> _fetchOffsetSeconds(String tzName) async {
    if (tzName.isEmpty) return null;
    try {
      tz_data.initializeTimeZones();
      final location = tz.getLocation(tzName);
      final now = tz.TZDateTime.now(location);
      return now.timeZoneOffset.inSeconds;
    } catch (_) {
      // Local database lookup failed; fallback to network request below.
    }
    try {
      final r = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/$tzName'))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = (j['raw_offset'] as num?)?.toInt() ?? 0;
        final dst = (j['dst_offset'] as num?)?.toInt() ?? 0;
        return raw + dst;
      }
    } catch (_) {
      // Falls through to null - caller uses device time as last resort.
    }
    return null;
  }


  // ── Best calculation method by coordinates ──────────────────────────────
  // Aladhan method IDs, matched to the region each was designed for. Falls
  // back to Muslim World League (3) - a reasonable global default - for
  // anywhere not covered below.
  int _bestMethod(double lat, double lon) {
    if (lat >= 22 && lat <= 27 && lon >= 51 && lon <= 56.5) return 16; // UAE
    if (lat >= 15 && lat <= 32 && lon >= 35 && lon <= 55) return 4; // Saudi
    if (lat >= 20 && lat <= 32 && lon >= 44 && lon <= 60) return 8; // Gulf
    if (lat >= 22 && lat <= 32 && lon >= 24 && lon <= 36) return 5; // Egypt
    if (lat >= 29 && lat <= 34 && lon >= 35 && lon <= 40) return 23; // Jordan
    if (lat >= 35 && lat <= 42 && lon >= 25 && lon <= 44) return 13; // Turkey
    if (lat >= 27 && lat <= 36 && lon >= -14 && lon <= -1) return 21; // Morocco
    if (lat >= 18 && lat <= 38 && lon >= -2 && lon <= 25) return 19; // Algeria/Tunisia
    if (lat >= 20 && lat <= 40 && lon >= 60 && lon <= 80) return 1; // Pakistan
    if (lat >= -12 && lat <= 8 && lon >= 95 && lon <= 145) return 20; // Indonesia
    if (lat >= 1 && lat <= 7 && lon >= 99 && lon <= 105) return 11; // Singapore
    if (lat >= 36 && lat <= 72 && lon >= -10 && lon <= 45) return 12; // Europe
    if (lat >= 15 && lat <= 72 && lon >= -170 && lon <= -50) return 2; // N. America
    if (lat >= 40 && lat <= 80 && lon >= 30 && lon <= 180) return 14; // Russia
    return 3; // Muslim World League - global default
  }

  // Fallback: compute prayer times algorithmically (solar-angle method),
  // used only when both Aladhan calls above fail (fully offline).
  PrayerTimesData computeLocalFallback(double lat, double lon, {String lang = 'en'}) {
    final now = DateTime.now();

    final dayOfYear = _dayOfYear(now);
    final eot = _equationOfTime(dayOfYear); // minutes
    final decl = _solarDeclination(dayOfYear); // radians
    final latRad = lat * math.pi / 180;

    // This solar noon is in UTC (the lon/15 term is the correction from
    // Greenwich), NOT local device time - must go through
    // DateTime.utc(...).toLocal() below, not be used directly as local.
    final solarNoonUtc = 12.0 - lon / 15.0 - eot / 60.0;

    double hourAngle(double angleDeg) {
      final angleRad = angleDeg * math.pi / 180;
      final cosHa = (math.sin(angleRad) - math.sin(latRad) * math.sin(decl)) /
          (math.cos(latRad) * math.cos(decl));
      if (cosHa.abs() > 1) return 0;
      return math.acos(cosHa) * 180 / math.pi / 15;
    }

    final sunriseHa = hourAngle(-0.833);
    final fajrHa = hourAngle(-18.0);
    final asrHa = _asrHourAngle(latRad, decl);
    final maghribHa = hourAngle(-0.833);
    final ishaHa = hourAngle(-17.0);

    DateTime toTime(double utcFractionalHours) {
      final totalMinutesUtc = (utcFractionalHours * 60).round();
      final utcDate = DateTime.utc(
        now.year,
        now.month,
        now.day,
        totalMinutesUtc ~/ 60,
        totalMinutesUtc % 60,
      );
      return utcDate.toLocal();
    }

    return PrayerTimesData(
      fajr: PrayerTime(name: 'Fajr', time: toTime(solarNoonUtc - fajrHa), timezone: 'Local'),
      sunrise: PrayerTime(name: 'Sunrise', time: toTime(solarNoonUtc - sunriseHa), timezone: 'Local'),
      dhuhr: PrayerTime(name: 'Dhuhr', time: toTime(solarNoonUtc + 0.03333), timezone: 'Local'),
      asr: PrayerTime(name: 'Asr', time: toTime(solarNoonUtc + asrHa), timezone: 'Local'),
      maghrib: PrayerTime(name: 'Maghrib', time: toTime(solarNoonUtc + maghribHa), timezone: 'Local'),
      isha: PrayerTime(name: 'Isha', time: toTime(solarNoonUtc + ishaHa), timezone: 'Local'),
      date: now,
      timezone: 'Local',
      cityName: lang == 'ar' ? 'موقعك الحالي' : 'Your Location',
    );
  }

  // ─── Solar helpers (fallback only) ──────────────────────────────────────

  int _dayOfYear(DateTime d) {
    return d.difference(DateTime(d.year, 1, 1)).inDays + 1;
  }

  double _equationOfTime(int day) {
    final b = 360.0 / 365 * (day - 81) * math.pi / 180;
    return 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
  }

  double _solarDeclination(int day) {
    return -23.45 * math.cos(2 * math.pi * (day + 10) / 365) * math.pi / 180;
  }

  double _asrHourAngle(double latRad, double decl) {
    // Shafi'i: shadow factor = 1 (matches school=0 used in the live API
    // calls above, and Jordan/Levant/Gulf convention).
    final targetAlt = math.atan(1 / (1 + math.tan((latRad - decl).abs())));
    final cosHa = (math.sin(targetAlt) - math.sin(latRad) * math.sin(decl)) /
        (math.cos(latRad) * math.cos(decl));
    if (cosHa.abs() > 1) return 0;
    return math.acos(cosHa) * 180 / math.pi / 15;
  }

  String _cityFromTimezone(String tz) {
    // e.g. "Asia/Amman" → "Amman"
    final parts = tz.split('/');
    return parts.last.replaceAll('_', ' ');
  }

  /// Get actual city name from coordinates using reverse geocoding.
  /// [lang] is sent as `Accept-Language` so names come back localized
  /// ('ar' → Arabic names, 'en' → English names).
  Future<String?> _getCityFromCoordinates(double lat, double lon, {String lang = 'en'}) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=$lat'
        '&lon=$lon'
        '&zoom=10', // City level
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept-Language': lang,
          'User-Agent': 'WejhatyApp/1.0',
        },
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final address = decoded['address'] as Map<String, dynamic>?;
      
      if (address == null) return null;

      // Try to get city name from various fields
      final city = address['city'] as String? ??
                  address['town'] as String? ??
                  address['village'] as String? ??
                  address['municipality'] as String? ??
                  address['county'] as String? ??
                  address['state'] as String?;

      return city;
    } catch (_) {
      return null;
    }
  }
}

class _TimingsResponse {
  const _TimingsResponse({required this.timings, required this.meta});
  final Map<String, dynamic> timings;
  final Map<String, dynamic> meta;
}