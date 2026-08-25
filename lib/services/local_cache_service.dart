import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripproject/services/location_service.dart';
import 'package:tripproject/services/prayer_service.dart';
import 'package:tripproject/services/routing_service.dart';
import 'package:tripproject/services/weather_service.dart';

/// Persists weather, prayer, location, destination, music & video files to
/// SharedPreferences (as a single JSON blob) so everything survives app
/// restarts and works offline — on web, mobile, and desktop alike.
///
/// NOTE: this used to use path_provider + dart:io File. That approach
/// throws MissingPluginException on Flutter web (no real filesystem /
/// no web implementation registered for path_provider), which was taking
/// down every refresh() call silently. SharedPreferences already has a
/// working web implementation (backed by localStorage), so we reuse it here.
class LocalCacheService {
  static final LocalCacheService instance = LocalCacheService._();
  LocalCacheService._();

  static const _storageKey = 'trip_cache_json';

  SharedPreferences? _prefs;

  // ─── Init ─────────────────────────────────────────────────────────────────
  /// Loads the persisted JSON blob into memory so every load*() getter
  /// returns real data immediately afterwards — never a false "empty"
  /// that a later write would then persist over the user's data.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _ensureLoaded();
  }

  // ─── Weather ──────────────────────────────────────────────────────────────
  Future<void> saveWeather(WeatherData weather) async {
    await _write('weather', {
      'temperature': weather.temperature,
      'feelsLike': weather.feelsLike,
      'humidity': weather.humidity,
      'windSpeed': weather.windSpeed,
      'condition': weather.condition.name,
      'weatherCode': weather.weatherCode,
      'cloudCover': weather.cloudCover,
      'isDay': weather.isDay,
      'cityName': weather.cityName,
      'cityNameAr': weather.cityNameAr,
      'countryCode': weather.countryCode,
      'countryName': weather.countryName,
      'fetchedAt': weather.fetchedAt.toIso8601String(),
    });
  }

  WeatherData? loadWeather() {
    final map = _read<Map<String, dynamic>>('weather');
    if (map == null) return null;
    try {
      return WeatherData(
        temperature: (map['temperature'] as num).toDouble(),
        feelsLike: (map['feelsLike'] as num).toDouble(),
        humidity: (map['humidity'] as num).toInt(),
        windSpeed: (map['windSpeed'] as num).toDouble(),
        condition: WeatherCondition.values.firstWhere(
              (e) => e.name == map['condition'],
          orElse: () => WeatherCondition.unknown,
        ),
        // Older cached blobs (saved before this field existed) won't have
        // these keys, so fall back to sane defaults instead of throwing —
        // that would otherwise make loadWeather() return null for every
        // user's existing cache until their next successful online fetch.
        weatherCode: (map['weatherCode'] as num?)?.toInt() ?? -1,
        cloudCover: (map['cloudCover'] as num?)?.toInt() ?? 0,
        isDay: map['isDay'] as bool? ?? true,
        cityName: map['cityName'] as String? ?? 'Unknown',
        cityNameAr: map['cityNameAr'] as String? ?? '',
        countryCode: map['countryCode'] as String? ?? '',
        countryName: map['countryName'] as String? ?? 'Unknown',
        fetchedAt: DateTime.parse(map['fetchedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Prayer Times ─────────────────────────────────────────────────────────
  Map<String, dynamic> _prayerToMap(PrayerTime p) => {
    'name': p.name,
    'time': p.time.toIso8601String(),
  };

  Future<void> savePrayerTimes(PrayerTimesData data) async {
    await _write('prayerTimes', {
      'fajr': _prayerToMap(data.fajr),
      'sunrise': _prayerToMap(data.sunrise),
      'dhuhr': _prayerToMap(data.dhuhr),
      'asr': _prayerToMap(data.asr),
      'maghrib': _prayerToMap(data.maghrib),
      'isha': _prayerToMap(data.isha),
      'date': data.date.toIso8601String(),
      'timezone': data.timezone,
      'cityName': data.cityName,
      'cityNameAr': data.cityNameAr,
    });
  }

  PrayerTimesData? loadPrayerTimes() {
    final map = _read<Map<String, dynamic>>('prayerTimes');
    if (map == null) return null;
    try {
      PrayerTime parsePrayer(Map<String, dynamic> m) => PrayerTime(
        name: m['name'] as String,
        time: DateTime.parse(m['time'] as String),
      );

      return PrayerTimesData(
        fajr: parsePrayer(map['fajr'] as Map<String, dynamic>),
        sunrise: parsePrayer(map['sunrise'] as Map<String, dynamic>),
        dhuhr: parsePrayer(map['dhuhr'] as Map<String, dynamic>),
        asr: parsePrayer(map['asr'] as Map<String, dynamic>),
        maghrib: parsePrayer(map['maghrib'] as Map<String, dynamic>),
        isha: parsePrayer(map['isha'] as Map<String, dynamic>),
        date: DateTime.parse(map['date'] as String),
        timezone: map['timezone'] as String? ?? 'UTC',
        cityName: map['cityName'] as String? ?? 'Your Location',
        cityNameAr: map['cityNameAr'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Location ─────────────────────────────────────────────────────────────
  Future<void> saveLocation(LocationData location) async {
    await _write('location', {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy,
      'timestamp': location.timestamp.toIso8601String(),
    });
  }

  LocationData? loadLocation() {
    final map = _read<Map<String, dynamic>>('location');
    if (map == null) return null;
    try {
      return LocationData(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Destination ─────────────────────────────────────────────────────────
  Future<void> saveDestination({
    required String cityName,
    required double latitude,
    required double longitude,
  }) async {
    await _write('destination', {
      'cityName': cityName,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Map<String, dynamic>? loadDestination() {
    return _read<Map<String, dynamic>>('destination');
  }

  // ─── Route ────────────────────────────────────────────────────────────────
  Future<void> saveRoute(RouteData route) async {
    await _write('route', route.toJson());
  }

  RouteData? loadRoute() {
    final map = _read<Map<String, dynamic>>('route');
    if (map == null) return null;
    try {
      final route = RouteData.fromJson(map);
      return route.points.length >= 2 ? route : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Music Playlist ──────────────────────────────────────────────────────
  Future<void> saveMusicFiles(List<String> filePaths) async {
    await _write('musicFiles', filePaths);
  }

  List<String> loadMusicFiles() {
    final list = _read<List<dynamic>>('musicFiles');
    if (list == null) return const [];
    return list.whereType<String>().toList();
  }

  // ─── Music Display Names ─────────────────────────────────────────────────
  // Maps a track's file path to a user-chosen display name (set via rename
  // in MusicScreen). Stored as a plain JSON object of String -> String.
  // Deleting a track doesn't need a dedicated method — it's handled by
  // calling saveMusicFiles() with the track removed from the list, the same
  // way video deletion reuses saveVideoFiles().
  Future<void> saveMusicNames(Map<String, String> names) async {
    await _write('musicNames', names);
  }

  Map<String, String> loadMusicNames() {
    final map = _read<Map<String, dynamic>>('musicNames');
    if (map == null) return const {};
    return map.map((key, value) => MapEntry(key, value as String));
  }

  // ─── Video Playlist ──────────────────────────────────────────────────────
  Future<void> saveVideoFiles(List<String> filePaths) async {
    await _write('videoFiles', filePaths);
  }

  List<String> loadVideoFiles() {
    final list = _read<List<dynamic>>('videoFiles');
    if (list == null) return const [];
    return list.whereType<String>().toList();
  }

  // ─── Video Display Names ─────────────────────────────────────────────────
  // Maps a video's file path to a user-chosen display name (set via rename
  // in VideosScreen). Stored as a plain JSON object of String -> String.
  Future<void> saveVideoNames(Map<String, String> names) async {
    await _write('videoNames', names);
  }

  Map<String, String> loadVideoNames() {
    final map = _read<Map<String, dynamic>>('videoNames');
    if (map == null) return const {};
    return map.map((key, value) => MapEntry(key, value as String));
  }

  // ─── Adhkar Bookmarks ─────────────────────────────────────────────────────
  // Persists the user's saved adhkar/dua ids ('a:<titleEn>' / 'd:<titleEn>')
  // so bookmarks survive app restarts.
  Future<void> saveAdhkarBookmarks(List<String> ids) async {
    await _write('adhkarBookmarks', ids);
  }

  List<String> loadAdhkarBookmarks() {
    final list = _read<List<dynamic>>('adhkarBookmarks');
    if (list == null) return const [];
    return list.whereType<String>().toList();
  }

  // ─── Map Screen State ─────────────────────────────────────────────────────
  // Persists the Routes screen UI state (selected transport mode, selected
  // route card, and which corridor it belongs to) so everything looks the
  // same when the user comes back.
  Future<void> saveMapPrefs(Map<String, dynamic> prefs) async {
    await _write('mapPrefs', prefs);
  }

  Map<String, dynamic>? loadMapPrefs() {
    return _read<Map<String, dynamic>>('mapPrefs');
  }

  // ─── Last Refresh Time ───────────────────────────────────────────────────
  Future<void> saveLastRefresh(DateTime time) async {
    await _write('lastRefresh', time.toIso8601String());
  }

  DateTime? loadLastRefresh() {
    final str = _read<String>('lastRefresh');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // ─── Internal I/O ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _allData;

  Future<void> _ensureLoaded() async {
    if (_allData != null) return;
    if (_prefs == null) await init();
    try {
      final raw = _prefs?.getString(_storageKey);
      if (raw == null) {
        _allData = {};
        return;
      }
      _allData = json.decode(raw) as Map<String, dynamic>? ?? {};
    } catch (_) {
      _allData = {};
    }
  }

  Future<void> _write(String key, dynamic value) async {
    await _ensureLoaded();
    _allData![key] = value;
    await _flush();
  }

  T? _read<T>(String key) {
    if (_allData == null) return null;
    final val = _allData![key];
    if (val is T) return val;
    return null;
  }

  Future<void> _flush() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setString(_storageKey, json.encode(_allData));
    } catch (_) {
      // Silently fail on write errors
    }
  }

  // ─── Photos ────────────────────────────────────────────────────────────────
  Future<void> savePhotos(List<String> photoPaths) async {
    await _write('photos', photoPaths);
  }

  List<String> loadPhotos() {
    final list = _read<List<dynamic>>('photos');
    if (list == null) return const [];
    return list.whereType<String>().toList();
  }

  // ─── Checklist Items ───────────────────────────────────────────────────────
  Future<void> saveChecklistItems(List<Map<String, dynamic>> items) async {
    await _write('checklistItems', items);
  }

  List<Map<String, dynamic>> loadChecklistItems() {
    final list = _read<List<dynamic>>('checklistItems');
    if (list == null) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  // ─── Expenses ───────────────────────────────────────────────────────────────
  Future<void> saveExpenses(List<Map<String, dynamic>> expenses) async {
    await _write('expenses', expenses);
  }

  List<Map<String, dynamic>> loadExpenses() {
    final list = _read<List<dynamic>>('expenses');
    if (list == null) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Force a full read from disk/storage (useful on app restart).
  Future<void> reload() async {
    _allData = null;
    await _ensureLoaded();
  }
}