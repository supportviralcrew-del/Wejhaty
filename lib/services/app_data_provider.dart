import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripproject/services/location_service.dart';
import 'package:tripproject/services/prayer_service.dart';
import 'package:tripproject/services/weather_service.dart';
import 'package:tripproject/services/local_cache_service.dart';
import 'package:tripproject/services/photos_service.dart';
import 'package:tripproject/services/checklist_service.dart';
import 'package:tripproject/services/expenses_service.dart';
import 'package:tripproject/services/notification_service.dart';
import 'package:tripproject/services/ad_service.dart';
import 'package:tripproject/services/notification_log_service.dart';
import 'package:tripproject/core/utils/number_format.dart';

/// Centralised data provider. Call [refresh] after location permission is
/// granted. UI widgets listen via [ChangeNotifier].
class AppDataProvider extends ChangeNotifier {
  AppDataProvider._();
  static final AppDataProvider instance = AppDataProvider._();

  // ─── Services ───────────────────────────────────────────────────────────
  final _locationService = LocationService();
  final _weatherService = WeatherService();
  final _prayerService = PrayerService();
  final _cache = LocalCacheService.instance;
  SharedPreferences? _prefs;

  // ─── App Settings ───────────────────────────────────────────────────────
  // Defaults to following the device's system setting. If that can't be
  // determined for some reason, [AppTheme]/[MaterialApp] will simply fall
  // back to its own light theme, since ThemeMode.system resolves to light
  // whenever the platform brightness is unavailable or unspecified.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // ─── Notification Bar ───────────────────────────────────────────────────
  // Persistent notification showing the next prayer name/time with a live
  // countdown (see NotificationService). Defaults to ON.
  bool _showNotificationBar = true;
  bool get showNotificationBar => _showNotificationBar;

  // ─── Subscription & Credits System ──────────────────────────────────────────
  bool _isSubscribed = false;
  bool get isSubscribed {
    _checkSubscriptionExpiry();
    return _isSubscribed;
  }

  DateTime? _subscriptionStartDate;
  DateTime? get subscriptionStartDate => _subscriptionStartDate;

  DateTime? _subscriptionExpiryDate;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;

  // ─── Premium Settings (only surfaced in Settings while subscribed) ──────
  /// Whether the exclusive gold "Obsidian & Champagne" look is applied.
  /// Defaults to ON; a subscriber can switch back to the standard theme.
  bool _premiumLookEnabled = true;
  bool get premiumLookEnabled => _premiumLookEnabled;

  /// Opt-in gate for features still being tested. Defaults to OFF.
  bool _experimentalFeaturesEnabled = false;
  bool get experimentalFeaturesEnabled => _experimentalFeaturesEnabled;

  /// True only when the user is subscribed AND chose to keep the premium
  /// look — the single flag every premium-styled surface should consult.
  bool get premiumThemeActive {
    final subscribed = isSubscribed;
    return subscribed && _premiumLookEnabled;
  }

  void setPremiumLookEnabled(bool value) {
    _premiumLookEnabled = value;
    _prefs?.setBool('premium_look_enabled', value);
    notifyListeners();
  }

  void setExperimentalFeaturesEnabled(bool value) {
    _experimentalFeaturesEnabled = value;
    _prefs?.setBool('experimental_features_enabled', value);
    notifyListeners();
  }

  int _credits = 100;
  int get maxCredits => _isSubscribed ? 2000 : 100;
  int get credits {
    _checkCreditRefill();
    return _credits;
  }

  DateTime? _lastCreditRefillTime;
  DateTime? get lastCreditRefillTime => _lastCreditRefillTime;

  DateTime? _subscriptionFirstRefillDate;
  DateTime? get subscriptionFirstRefillDate => _subscriptionFirstRefillDate;

  int _tripStatsCountInPeriod = 0;
  int get tripStatsCountInPeriod => _tripStatsCountInPeriod;

  // ─── Reward System ───────────────────────────────────────────────────────
  // User's reward points/coins
  int _rewardPoints = 0;
  int get rewardPoints => _rewardPoints;

  // Last time user watched a rewarded ad (for cooldown)
  DateTime? _lastAdWatchTime;
  DateTime? get lastAdWatchTime => _lastAdWatchTime;

  // Cooldown duration for rewarded ads (3.5 minutes)
  static const Duration _adCooldown = Duration(minutes: 3, seconds: 30);

  // ─── Per-Prayer Reminder Mutes ──────────────────────────────────────────
  // Names (e.g. "Fajr", "Asr") the user has muted from the notification
  // bar via the bell toggle on each prayer row. When the "next" prayer for
  // the bar would be a muted one, we skip it and show the next
  // non-muted prayer instead (wrapping to tomorrow's Fajr if needed).
  Set<String> _mutedPrayers = {};
  Set<String> get mutedPrayers => Set.unmodifiable(_mutedPrayers);

  bool isPrayerReminderEnabled(String prayerName) =>
      !_mutedPrayers.contains(prayerName);

  String _language = 'en'; // 'en' or 'ar'
  String get language => _language;

  bool _useArabicNumbers = false;
  bool get useArabicNumbers => _useArabicNumbers;

  bool _hasCompletedSetup = false;
  bool get hasCompletedSetup => _hasCompletedSetup;

  bool _hasChosenDestination = false;
  bool get hasChosenDestination => _hasChosenDestination;

  bool _isManualLocation = false;
  bool get isManualLocation => _isManualLocation;

  double? _manualLat;
  double? get manualLat => _manualLat;

  double? _manualLon;
  double? get manualLon => _manualLon;

  String? _manualCityName;
  String? get manualCityName => _manualCityName;

  String? _manualCountryName;
  String? get manualCountryName => _manualCountryName;

  // ─── Default Location Fallback ──────────────────────────────────────────
  // Used whenever the user hasn't granted GPS access and hasn't set a
  // manual location, so the app still has a sensible, useful default
  // instead of showing an error/empty state. Riyadh is used as a
  // central, well-covered reference point for Saudi Arabia.
  static const String defaultCountryName = 'Saudi Arabia';
  static const double defaultCountryLat = 24.7136;
  static const double defaultCountryLon = 46.6753;

  bool _isDefaultLocation = false;
  /// True when the current [location] is the Saudi Arabia fallback rather
  /// than a real GPS fix or manually-chosen location.
  bool get isDefaultLocation => _isDefaultLocation;

  // ─── Destination Settings ───────────────────────────────────────────────
  // Defaults to Makkah (Mecca) so a fresh install already has a
  // meaningful route destination set up.
  String _destinationCityName = 'Makkah';
  String get destinationCityName => _destinationCityName;

  double _destinationLat = 21.4225;
  double get destinationLat => _destinationLat;

  double _destinationLon = 39.8262;
  double get destinationLon => _destinationLon;

  // ─── Trip Statistics ─────────────────────────────────────────────────────
  // Starting location for trip progress calculation
  double? _tripStartLat;
  double? get tripStartLat => _tripStartLat;

  double? _tripStartLon;
  double? get tripStartLon => _tripStartLon;

  // Total trip distance (from start to destination)
  double? _totalTripDistanceKm;
  double? get totalTripDistanceKm => _totalTripDistanceKm;

  // When the trip started
  DateTime? _tripStartTime;
  DateTime? get tripStartTime => _tripStartTime;

  // Whether a trip is currently active
  bool _isTripActive = false;
  bool get isTripActive => _isTripActive;

  // ─── State ──────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  LocationData? _location;
  LocationData? get location => _location;

  WeatherData? _weather;
  WeatherData? get weather => _weather;

  PrayerTimesData? _prayerTimes;
  PrayerTimesData? get prayerTimes => _prayerTimes;

  /// Reverse-geocoded name of the CURRENT location, resolved once per
  /// refresh in the app language ('ar' → Arabic names, 'en' → English).
  /// Shared by the location chip, weather card, and prayer card so all
  /// three always display the exact same place. Null until the first
  /// successful refresh (UI falls back to the weather card's city name).
  String? _currentCityName;
  String? get currentCityName => _currentCityName;

  DateTime? _lastRefresh;
  DateTime? get lastRefresh => _lastRefresh;

  bool get hasData => _weather != null || _prayerTimes != null;

  /// Whether the data was loaded from local cache (offline mode indicator)
  bool _isOfflineData = false;
  bool get isOfflineData => _isOfflineData;

  // Every refresh() call is tagged with the value of this counter at the
  // moment it starts. If a newer call starts before an older one finishes
  // (e.g. you pick a new location while a previous refresh is still
  // resolving), the older call's results are discarded instead of being
  // written over the newer state - this is what actually prevents "the
  // data flips back to the old location for a moment" or, in bad timing,
  // stays on the old location indefinitely.
  int _refreshGeneration = 0;

  // Ensures only one refresh() call is ever doing actual network/cache
  // work at a time. Without this, two calls (e.g. the app's initial GPS
  // refresh and a location change moments later) could both hit the local
  // cache file and network concurrently - which is what was throwing the
  // "Failed to load data" exception you saw.
  Future<void>? _runningRefresh;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Initialise provider: load preferences + cached data from disk.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Load Local Cache (rain or shine)
      await _cache.init();
      await _cache.reload();

      // Initialize other services to load persisted data
      await PhotosService.instance.init();
      await ChecklistService.instance.init();
      await ExpensesService.instance.init();
      await NotificationLogService.instance.init();

      // Load Theme (defaults to system if nothing saved yet)
      final themeStr = _prefs?.getString('theme_mode');
      switch (themeStr) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        default:
        // Nothing saved yet (fresh install) -> system by default.
          _themeMode = ThemeMode.system;
      }

      // Load Subscription state
      _isSubscribed = _prefs?.getBool('is_subscribed') ?? false;
      final subStartTs = _prefs?.getInt('subscription_start_date');
      if (subStartTs != null) {
        _subscriptionStartDate = DateTime.fromMillisecondsSinceEpoch(subStartTs);
      }
      final subExpiryTs = _prefs?.getInt('subscription_expiry_date');
      if (subExpiryTs != null) {
        _subscriptionExpiryDate = DateTime.fromMillisecondsSinceEpoch(subExpiryTs);
      }
      _checkSubscriptionExpiry();

      // Load premium-only preferences
      _premiumLookEnabled = _prefs?.getBool('premium_look_enabled') ?? true;
      _experimentalFeaturesEnabled =
          _prefs?.getBool('experimental_features_enabled') ?? false;

      // Load credits system data
      _credits = _prefs?.getInt('user_credits') ?? 100;
      _tripStatsCountInPeriod = _prefs?.getInt('trip_stats_count_period') ?? 0;
      final refillTs = _prefs?.getInt('last_credit_refill_time');
      if (refillTs != null) {
        _lastCreditRefillTime = DateTime.fromMillisecondsSinceEpoch(refillTs);
      }
      final firstRefillTs = _prefs?.getInt('subscription_first_refill_date');
      if (firstRefillTs != null) {
        _subscriptionFirstRefillDate = DateTime.fromMillisecondsSinceEpoch(firstRefillTs);
      }
      _checkCreditRefill();

      // Load notification bar preference (defaults to ON)
      _showNotificationBar = _prefs?.getBool('show_notification_bar') ?? true;

      // Load reward points
      _rewardPoints = _prefs?.getInt('reward_points') ?? 0;

      // Load last ad watch time
      final lastAdTimestamp = _prefs?.getInt('last_ad_watch_time');
      if (lastAdTimestamp != null) {
        _lastAdWatchTime = DateTime.fromMillisecondsSinceEpoch(lastAdTimestamp);
      }

      // Load per-prayer muted reminders (defaults to none muted)
      _mutedPrayers =
          (_prefs?.getStringList('muted_prayers') ?? const <String>[]).toSet();

      // Load Language - default to device language
      final deviceLanguageCode = PlatformDispatcher.instance.locale.languageCode;
      _language = _prefs?.getString('language') ?? (deviceLanguageCode == 'ar' ? 'ar' : 'en');

      // Load Number Format
      _useArabicNumbers = _prefs?.getBool('use_arabic_numbers') ?? (_language == 'ar');

      // Load one-time setup state
      _hasCompletedSetup = _prefs?.getBool('setup_complete') ?? false;

      // Load destination choice state
      _hasChosenDestination = _prefs?.getBool('has_chosen_destination') ?? false;

      // Load Location settings
      _isManualLocation = _prefs?.getBool('is_manual_location') ?? false;
      _manualLat = _prefs?.getDouble('manual_lat');
      _manualLon = _prefs?.getDouble('manual_lon');
      _manualCityName = _prefs?.getString('manual_city_name');
      _manualCountryName = _prefs?.getString('manual_country_name');

      // Load Destination settings (defaults to Makkah / the Kaaba)
      _destinationCityName =
          _prefs?.getString('destination_city_name') ?? 'Makkah';
      _destinationLat = _prefs?.getDouble('destination_lat') ?? 21.4225;
      _destinationLon = _prefs?.getDouble('destination_lon') ?? 39.8262;

      // Load trip statistics
      _isTripActive = _prefs?.getBool('is_trip_active') ?? false;
      _tripStartLat = _prefs?.getDouble('trip_start_lat');
      _tripStartLon = _prefs?.getDouble('trip_start_lon');
      _totalTripDistanceKm = _prefs?.getDouble('total_trip_distance_km');
      final tripStartTimestamp = _prefs?.getInt('trip_start_time');
      if (tripStartTimestamp != null) {
        _tripStartTime = DateTime.fromMillisecondsSinceEpoch(tripStartTimestamp);
      }

      // ── Load cached API data so the app has something immediately ──
      final cachedWeather = _cache.loadWeather();
      var cachedPrayer = _cache.loadPrayerTimes();
      final cachedLocation = _cache.loadLocation();

      if (cachedPrayer != null &&
          !_isSameDay(cachedPrayer.date, DateTime.now())) {
        cachedPrayer = null;
      }

      if (cachedPrayer == null && cachedLocation != null) {
        cachedPrayer = _prayerService.computeLocalFallback(
          cachedLocation.latitude,
          cachedLocation.longitude,
          lang: _language,
        );
        await _cache.savePrayerTimes(cachedPrayer);
      }

      if (cachedWeather != null || cachedPrayer != null) {
        _weather = cachedWeather;
        _prayerTimes = cachedPrayer;
        _location = cachedLocation;
        _lastRefresh = _cache.loadLastRefresh();
        _isOfflineData = true;
      }

      // Set up the persistent notification bar (Android). Safe to call even
      // if the user has it disabled - init() just prepares the plugin/
      // channel, it doesn't show anything by itself.
      await NotificationService.instance.init();
      if (_showNotificationBar) {
        _updateNotificationBar();
      }
    } catch (_) {
      // Fallback to defaults on error
    }
    notifyListeners();

    // Try to fetch fresh data in the background
    if (_location != null || _isManualLocation) {
      refresh();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  /// Cycles System -> Light -> Dark -> System.
  void toggleTheme() {
    switch (_themeMode) {
      case ThemeMode.system:
        setTheme(ThemeMode.light);
        break;
      case ThemeMode.light:
        setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setTheme(ThemeMode.system);
        break;
    }
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    final modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    _prefs?.setString('theme_mode', modeStr);
    notifyListeners();
  }

  /// Enables/disables the persistent next-prayer countdown notification.
  /// Defaults to enabled; the user can turn it off from Settings.
  ///
  /// When turning it ON, we first request the Android 13+ runtime
  /// notification permission (per NotificationService.requestPermission's
  /// own guidance to call it "right before first enabling the
  /// notification bar"). If the user declines, we revert the setting back
  /// off rather than silently leaving it "on" with nothing actually
  /// showing.
  void setShowNotificationBar(bool value) {
    _showNotificationBar = value;
    _prefs?.setBool('show_notification_bar', value);
    notifyListeners();

    if (value) {
      NotificationService.instance.requestPermission().then((granted) {
        if (granted) {
          _updateNotificationBar();
        } else {
          _showNotificationBar = false;
          _prefs?.setBool('show_notification_bar', false);
          notifyListeners();
        }
      });
    } else {
      NotificationService.instance.cancel();
    }
  }

  /// Mutes/unmutes a single prayer (e.g. "Fajr", "Asr") from ever being
  /// shown as the "next prayer" in the notification bar. If the currently
  /// displayed prayer is the one being muted, the bar immediately updates
  /// to show the next non-muted prayer instead.
  void setPrayerReminderEnabled(String prayerName, bool enabled) {
    if (enabled) {
      _mutedPrayers.remove(prayerName);
    } else {
      _mutedPrayers.add(prayerName);
    }
    _prefs?.setStringList('muted_prayers', _mutedPrayers.toList());
    notifyListeners();

    if (_showNotificationBar) {
      _updateNotificationBar();
    }
  }

  static const Map<String, String> _prayerNameAr = {
    'Fajr': 'الفجر',
    'Sunrise': 'الشروق',
    'Dhuhr': 'الظهر',
    'Asr': 'العصر',
    'Maghrib': 'المغرب',
    'Isha': 'العشاء',
  };

  void _updateNotificationBar() {
    if (!_showNotificationBar) return;
    final prayers = _prayerTimes;
    if (prayers == null) return;

    try {
      // Walk today's remaining prayers (in Adhan order: Fajr, Dhuhr, Asr,
      // Maghrib, Isha - PrayerTimesData.allPrayers already excludes
      // Sunrise, which has no Adhan), skipping any the user has muted via
      // the per-prayer bell toggle. If every remaining prayer today is
      // either past or muted, fall back to tomorrow's Fajr - unless Fajr
      // itself is muted, in which case there's nothing left to show.
      PrayerTime? target;
      var isTomorrow = false;

      for (final p in prayers.allPrayers) {
        if (!p.isPast && !_mutedPrayers.contains(p.name)) {
          target = p;
          break;
        }
      }

      if (target == null) {
        if (!_mutedPrayers.contains(prayers.fajr.name)) {
          target = prayers.fajr;
          isTomorrow = true;
        } else {
          NotificationService.instance.cancel();
          return;
        }
      }

      final targetTime =
      isTomorrow ? target.timeToday.add(const Duration(days: 1)) : target.timeToday;

      final displayName =
      _language == 'ar' ? (_prayerNameAr[target.name] ?? target.name) : target.name;

      final title = _language == 'ar'
          ? '$displayName في ${target.formattedTime}'
          : '$displayName at ${target.formattedTime}';

      NotificationService.instance.showPrayerCountdown(
        title: title,
        prayerTime: targetTime,
      );
    } catch (e) {
      debugPrint('AppDataProvider: failed to update notification bar: $e');
    }
  }

  void setLanguage(String lang) {
    if (_language != lang) {
      _language = lang;
      _prefs?.setString('language', lang);
      notifyListeners();
      // Re-fetch weather/names with the new language setting
      refresh();
    }
  }

  void setUseArabicNumbers(bool value) {
    _useArabicNumbers = value;
    _prefs?.setBool('use_arabic_numbers', value);
    notifyListeners();
  }

  Future<void> completeSetup() async {
    _hasCompletedSetup = true;
    await _prefs?.setBool('setup_complete', true);
    notifyListeners();
  }

  void enableAutoLocation() {
    _isManualLocation = false;
    _manualLat = null;
    _manualLon = null;
    _manualCityName = null;
    _manualCountryName = null;
    _currentCityName = null;

    _prefs?.setBool('is_manual_location', false);
    _prefs?.remove('manual_lat');
    _prefs?.remove('manual_lon');
    _prefs?.remove('manual_city_name');
    _prefs?.remove('manual_country_name');

    // Clear stale data immediately so UI shows loading
    _weather = null;
    _prayerTimes = null;
    _location = null;

    notifyListeners();
    refresh();
  }

  void setManualLocation({
    required double latitude,
    required double longitude,
    required String cityName,
    required String countryName,
  }) {
    _isManualLocation = true;
    _isDefaultLocation = false;
    _manualLat = latitude;
    _manualLon = longitude;
    _manualCityName = cityName;
    _manualCountryName = countryName;

    _prefs?.setBool('is_manual_location', true);
    _prefs?.setDouble('manual_lat', latitude);
    _prefs?.setDouble('manual_lon', longitude);
    _prefs?.setString('manual_city_name', cityName);
    _prefs?.setString('manual_country_name', countryName);

    // Update location object immediately for UI chips
    _location = LocationData(
      latitude: latitude,
      longitude: longitude,
      accuracy: 0.0,
      timestamp: DateTime.now(),
    );

    // Clear stale data so UI shows loading for new location
    _weather = null;
    _prayerTimes = null;

    notifyListeners();
    refresh();
  }

  void setDestination({
    required String cityName,
    required double latitude,
    required double longitude,
  }) {
    _destinationCityName = cityName;
    _destinationLat = latitude;
    _destinationLon = longitude;
    _hasChosenDestination = true;

    _prefs?.setString('destination_city_name', cityName);
    _prefs?.setDouble('destination_lat', latitude);
    _prefs?.setDouble('destination_lon', longitude);
    _prefs?.setBool('has_chosen_destination', true);

    // Also persist destination to local cache for offline use
    _cache.saveDestination(
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
    );

    notifyListeners();
  }

  /// Start a new trip from current location to destination
  void startTrip() {
    if (_location == null) return;

    _tripStartLat = _location!.latitude;
    _tripStartLon = _location!.longitude;
    _tripStartTime = DateTime.now();
    _isTripActive = true;

    // Calculate total distance from start to destination
    final distanceInMeters = Geolocator.distanceBetween(
      _tripStartLat!,
      _tripStartLon!,
      _destinationLat,
      _destinationLon,
    );
    _totalTripDistanceKm = distanceInMeters / 1000;

    // Save to preferences
    _prefs?.setBool('is_trip_active', true);
    _prefs?.setDouble('trip_start_lat', _tripStartLat!);
    _prefs?.setDouble('trip_start_lon', _tripStartLon!);
    _prefs?.setDouble('total_trip_distance_km', _totalTripDistanceKm!);
    _prefs?.setInt('trip_start_time', _tripStartTime!.millisecondsSinceEpoch);

    NotificationLogService.instance.logTripStarted(
      _destinationCityName,
      _totalTripDistanceKm!,
    );

    notifyListeners();
  }

  /// Reset/clear trip statistics
  void resetTrip() {
    if (_isTripActive && _totalTripDistanceKm != null) {
      NotificationLogService.instance.logTripCompleted(
        _destinationCityName,
        _totalTripDistanceKm!,
      );
    }
    
    _isTripActive = false;
    _tripStartLat = null;
    _tripStartLon = null;
    _totalTripDistanceKm = null;
    _tripStartTime = null;

    _prefs?.remove('is_trip_active');
    _prefs?.remove('trip_start_lat');
    _prefs?.remove('trip_start_lon');
    _prefs?.remove('total_trip_distance_km');
    _prefs?.remove('trip_start_time');

    notifyListeners();
  }

  /// Calculate remaining distance to destination
  double? get remainingDistanceKm {
    if (_location == null || !_isTripActive) return null;

    final distanceInMeters = Geolocator.distanceBetween(
      _location!.latitude,
      _location!.longitude,
      _destinationLat,
      _destinationLon,
    );
    return distanceInMeters / 1000;
  }

  /// Calculate trip completion percentage
  int get tripCompletionPercent {
    if (!_isTripActive || _totalTripDistanceKm == null || _totalTripDistanceKm == 0) return 0;

    final remaining = remainingDistanceKm ?? _totalTripDistanceKm!;
    final traveled = _totalTripDistanceKm! - remaining;
    final percent = (traveled / _totalTripDistanceKm! * 100).round();
    return percent.clamp(0, 100);
  }

  /// Fetch location, weather and prayer times. Safe to call multiple times,
  /// including while a previous call is still running: each call is tagged
  /// with a generation number, and only ever writes its results to state if
  /// no newer call has started in the meantime. This means a location
  /// change always "wins" - an older, still-resolving refresh for the
  /// previous location can no longer clobber the new location's cleared
  /// state right before the new refresh's own results land.
  Future<void> refresh() async {
    final int myGeneration = ++_refreshGeneration;

    // If a refresh is already running, wait for it to finish before doing
    // any work ourselves - this is what prevents two calls from touching
    // the network/local cache file at the same time.
    final previousRun = _runningRefresh;
    final myCompleter = Completer<void>();
    _runningRefresh = myCompleter.future;

    if (previousRun != null) {
      await previousRun;

      // While we were waiting our turn, an even newer refresh may have
      // started (e.g. the user changed location again). If so, there's no
      // point doing our own fetch - it would just be discarded anyway.
      // Let the newest one be the one that actually runs.
      if (myGeneration != _refreshGeneration) {
        myCompleter.complete();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    double lat = 0;
    double lon = 0;
    bool haveLocation = true;

    try {
      if (_isManualLocation && _manualLat != null && _manualLon != null) {
        lat = _manualLat!;
        lon = _manualLon!;
        final loc = LocationData(
          latitude: lat,
          longitude: lon,
          accuracy: 0.0,
          timestamp: DateTime.now(),
        );
        if (myGeneration == _refreshGeneration) _location = loc;
        await _cache.saveLocation(loc);
      } else {
        // Get current position
        final loc = await _locationService.getCurrentLocation();

        if (myGeneration != _refreshGeneration) return;

        if (loc == null) {
          // GPS unavailable – keep cached data if we have it
          if (_weather != null || _prayerTimes != null) {
            haveLocation = false;
            _isOfflineData = true;
          } else {
            // No GPS, no manual location, and nothing cached: rather than
            // surfacing an error and an empty app, fall back to a
            // sensible default location (Saudi Arabia) so weather,
            // prayer times, and emergency numbers all have something
            // useful to show. This is clearly flagged via
            // [isDefaultLocation] so the UI can tell the user.
            lat = defaultCountryLat;
            lon = defaultCountryLon;
            _isDefaultLocation = true;
            final defaultLoc = LocationData(
              latitude: lat,
              longitude: lon,
              accuracy: 0.0,
              timestamp: DateTime.now(),
            );
            if (myGeneration == _refreshGeneration) _location = defaultLoc;
          }
        } else {
          _location = loc;
          _isDefaultLocation = false;
          lat = loc.latitude;
          lon = loc.longitude;
          // Persist location to cache
          _cache.saveLocation(loc);
        }
      }

      if (haveLocation) {
        WeatherData? freshWeather;
        PrayerTimesData? freshPrayerTimes;

        // ── Resolve the city name ONCE, in the app language ──
        // This single reverse-geocoding result is shared by the weather
        // card, prayer card, and location chip so all three always show
        // the exact same place, localized ('ar' → Arabic, 'en' → English).
        // The lookup also returns the ARABIC name (namedetails), so the UI
        // can localize instantly even when the app language is English.
        // Manual locations already carry a user-chosen name.
        (String, String, String, String)? cityInfo;
        if (_isManualLocation && _manualCityName != null) {
          cityInfo = (
            _manualCityName!,
            '',
            _manualCountryName ?? '',
            '',
          );
        } else {
          cityInfo = await _weatherService.fetchCityName(lat, lon, lang: _language);
        }
        if (myGeneration != _refreshGeneration) return;
        _currentCityName = cityInfo.$1;

        // Fetch weather + prayer times concurrently
        try {
          final results = await Future.wait([
            _weatherService.fetchWeather(lat, lon, lang: _language, cityInfo: cityInfo),
            _prayerService.fetchPrayerTimes(
              lat,
              lon,
              cityName: cityInfo.$1,
              cityNameAr: cityInfo.$4,
              lang: _language,
            ),
          ]);
          freshWeather = results[0] as WeatherData?;
          freshPrayerTimes = results[1] as PrayerTimesData?;
        } catch (e) {
          debugPrint('AppDataProvider: API fetch failed: $e');
          // If the parallel fetch fails, we continue and try fallbacks
        }

        if (myGeneration != _refreshGeneration) return;

        // Fallback: compute prayer times locally if API failed. Always
        // uses the CURRENT lat/lon captured at the top of this call, so it
        // correctly reflects whichever location this refresh is for.
        freshPrayerTimes ??= _prayerService.computeLocalFallback(lat, lon, lang: _language);

        // Fallback: keep cached weather if the API call failed, but only
        // if it's plausibly for the same place - otherwise leave weather
        // null rather than silently showing another location's weather.
        if (freshWeather == null) {
          final cached = _cache.loadWeather();
          if (cached != null) {
            if (_manualCityName == null || cached.cityName == _manualCityName) {
              freshWeather = cached;
            }
          }
        }

        _weather = freshWeather;
        _prayerTimes = freshPrayerTimes;
        _lastRefresh = DateTime.now();
        _isOfflineData = _weather == null && _prayerTimes == null;

        // ── Auto-save everything to local cache ──
        if (_weather != null) _cache.saveWeather(_weather!);
        if (_prayerTimes != null) _cache.savePrayerTimes(_prayerTimes!);
        _cache.saveLastRefresh(_lastRefresh!);

        // If we have at least prayer times, don't show an error banner
        if (_prayerTimes == null && _weather == null) {
          _error = _language == 'ar'
              ? 'فشل في تحميل البيانات. يرجى التحقق من الاتصال.'
              : 'Failed to load data. Please check your connection.';
        }

        if (myGeneration == _refreshGeneration && _showNotificationBar) {
          _updateNotificationBar();
        }
      }
    } catch (e) {
      debugPrint('AppDataProvider: Refresh fatal error: $e');
      if (myGeneration == _refreshGeneration) {
        // Network or other error – keep cached data if we have it
        if (_weather != null || _prayerTimes != null) {
          _isOfflineData = true;
        } else {
          _error = _language == 'ar'
              ? 'فشل في تحميل البيانات. يرجى المحاولة مرة أخرى.'
              : 'Failed to load data. Please try again.';
        }
      }
    } finally {
      if (myGeneration == _refreshGeneration) {
        _isLoading = false;
      }
      notifyListeners();
      myCompleter.complete();
    }
  }

  /// Call this after location permission is granted so data loads immediately.
  Future<void> initAfterPermission() => refresh();

  // ─── Number Formatting Helpers ──────────────────────────────────────────

  /// Formats a numeric string to Arabic or English digits based on user preference.
  String nf(String input) => NumberFormatUtil.format(input, useArabicNumbers: _useArabicNumbers);

  /// Formats an [int] to the desired digit system.
  String nfi(int value) => NumberFormatUtil.formatInt(value, useArabicNumbers: _useArabicNumbers);

  /// Formats a [double] with the given number of decimal places.
  String nfd(double value, {int decimals = 1}) =>
      NumberFormatUtil.formatDouble(value, useArabicNumbers: _useArabicNumbers, decimals: decimals);

  /// Formats a whole number (rounded) from a [double].
  String nfw(double value) => NumberFormatUtil.formatWhole(value, useArabicNumbers: _useArabicNumbers);

  // ─── Subscription & Credits Methods ─────────────────────────────────────
  DateTime? _lastLowCreditLogTime; // throttle low-credit spam

  /// Check if credits should be refilled based on subscription schedule:
  /// - First week of subscription: refill every 2 days (48 hours)
  /// - After first week: refill every 6 days (144 hours)
  /// Also fixes: ensure subscriptionFirstRefillDate is set even for late subscribers,
  /// and throttle low-credit notification.
  void _checkCreditRefill() {
    final now = DateTime.now();
    final cap = maxCredits;

    // FIX: if user subscribed late, _subscriptionFirstRefillDate may still be null
    // while _lastCreditRefillTime is already set from free tier. Ensure it is initialized.
    if (_isSubscribed && _subscriptionFirstRefillDate == null) {
      _subscriptionFirstRefillDate = _subscriptionStartDate ?? now;
      _prefs?.setInt('subscription_first_refill_date', _subscriptionFirstRefillDate!.millisecondsSinceEpoch);
    }

    if (_lastCreditRefillTime == null) {
      _lastCreditRefillTime = now;
      if (_isSubscribed && _subscriptionFirstRefillDate == null) {
        _subscriptionFirstRefillDate = now;
        _prefs?.setInt('subscription_first_refill_date', now.millisecondsSinceEpoch);
      }
      _prefs?.setInt('last_credit_refill_time', now.millisecondsSinceEpoch);
      _prefs?.setInt('user_credits', _credits);
    } else {
      Duration refillInterval;
      if (_isSubscribed && _subscriptionFirstRefillDate != null) {
        final subscriptionAge = now.difference(_subscriptionFirstRefillDate!);
        refillInterval = subscriptionAge.inDays < 7 ? const Duration(hours: 48) : const Duration(hours: 144);
      } else {
        refillInterval = const Duration(hours: 48);
      }

      final elapsed = now.difference(_lastCreditRefillTime!);
      if (elapsed >= refillInterval) {
        _credits = cap;
        _lastCreditRefillTime = now;
        _tripStatsCountInPeriod = 0;
        _prefs?.setInt('last_credit_refill_time', now.millisecondsSinceEpoch);
        _prefs?.setInt('user_credits', cap);
        _prefs?.setInt('trip_stats_count_period', 0);

        final intervalText = refillInterval.inDays >= 1 ? '${refillInterval.inDays} days' : '${refillInterval.inHours} hours';
        NotificationLogService.instance.log(
          type: NotificationType.creditsRefilled,
          title: 'Credits Refilled',
          message: 'Your credits have been refilled to $cap/$maxCredits (every $intervalText)',
          metadata: {'amount': cap, 'maxCredits': maxCredits, 'interval': intervalText},
        );
      }
    }

    // Throttle low-credit warning: at most once per 12h to avoid spam on every getter
    if (_credits <= 20 && _isSubscribed) {
      final shouldLog = _lastLowCreditLogTime == null || now.difference(_lastLowCreditLogTime!) >= const Duration(hours: 12);
      if (shouldLog) {
        _lastLowCreditLogTime = now;
        NotificationLogService.instance.logCreditsLow(_credits);
      }
    }
  }

  /// Check if subscription has expired (30 days from start)
  void _checkSubscriptionExpiry() {
    if (_isSubscribed && _subscriptionExpiryDate != null) {
      final now = DateTime.now();
      if (now.isAfter(_subscriptionExpiryDate!)) {
        _isSubscribed = false;
        _subscriptionStartDate = null;
        _subscriptionExpiryDate = null;
        _subscriptionFirstRefillDate = null;
        _credits = 100;
        _tripStatsCountInPeriod = 0;
        _prefs?.setBool('is_subscribed', false);
        _prefs?.remove('subscription_start_date');
        _prefs?.remove('subscription_expiry_date');
        _prefs?.remove('subscription_first_refill_date');
        _prefs?.setInt('user_credits', _credits);
        _prefs?.setInt('trip_stats_count_period', 0);
        NotificationLogService.instance.logSubscriptionExpired();
        notifyListeners();
      }
    }
  }

  void setSubscribed(bool value) {
    final now = DateTime.now();
    if (value && !_isSubscribed) {
      _subscriptionStartDate = now;
      _subscriptionExpiryDate = now.add(const Duration(days: 30));
      _subscriptionFirstRefillDate = now;
      _lastCreditRefillTime = now;
      _tripStatsCountInPeriod = 0;
      _prefs?.setInt('subscription_start_date', _subscriptionStartDate!.millisecondsSinceEpoch);
      _prefs?.setInt('subscription_expiry_date', _subscriptionExpiryDate!.millisecondsSinceEpoch);
      _prefs?.setInt('subscription_first_refill_date', now.millisecondsSinceEpoch);
      _prefs?.setInt('last_credit_refill_time', now.millisecondsSinceEpoch);
      _prefs?.setInt('trip_stats_count_period', 0);
    } else if (!value && _isSubscribed) {
      _subscriptionStartDate = null;
      _subscriptionExpiryDate = null;
      _subscriptionFirstRefillDate = null;
      _prefs?.remove('subscription_start_date');
      _prefs?.remove('subscription_expiry_date');
      _prefs?.remove('subscription_first_refill_date');
      // keep lastCreditRefillTime for free tier refill cycle
    }
    _isSubscribed = value;
    _prefs?.setBool('is_subscribed', value);
    _credits = value ? 2000 : 100;
    _prefs?.setInt('user_credits', _credits);
    notifyListeners();
  }

  /// Spend credits if available. Returns true if successful.
  bool useCredits(int cost) {
    _checkCreditRefill();
    if (_credits >= cost) {
      _credits -= cost;
      _prefs?.setInt('user_credits', _credits);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Calculates cost for next trip statistics action (25 for 1st make, 35 for subsequent).
  int getNextTripStatCost() {
    return _tripStatsCountInPeriod == 0 ? 25 : 35;
  }

  /// Deducts credits for trip statistics action. Returns true if allowed/deducted.
  bool consumeTripStatCredits() {
    final cost = getNextTripStatCost();
    if (useCredits(cost)) {
      _tripStatsCountInPeriod++;
      _prefs?.setInt('trip_stats_count_period', _tripStatsCountInPeriod);
      return true;
    }
    return false;
  }

  /// Deducts 10 credits for Qibla check. Returns true if allowed/deducted.
  bool consumeQiblaCredits() {
    return useCredits(10);
  }

  // ─── Reward System Methods ───────────────────────────────────────────────

  /// Check if ad can be shown (not on cooldown)
  bool get canShowAd {
    if (_lastAdWatchTime == null) return true;
    return DateTime.now().difference(_lastAdWatchTime!) >= _adCooldown;
  }

  /// Get remaining cooldown time for ad
  Duration? get adCooldownRemaining {
    if (_lastAdWatchTime == null) return null;
    final elapsed = DateTime.now().difference(_lastAdWatchTime!);
    final remaining = _adCooldown - elapsed;
    return remaining.isNegative ? null : remaining;
  }

  /// Add reward points
  void addRewardPoints(int points) {
    _rewardPoints += points;
    _prefs?.setInt('reward_points', _rewardPoints);
    notifyListeners();
  }

  /// Record that user watched an ad
  void recordAdWatch() {
    _lastAdWatchTime = DateTime.now();
    _prefs?.setInt('last_ad_watch_time', _lastAdWatchTime!.millisecondsSinceEpoch);
    notifyListeners();
  }

  /// Show rewarded ad and handle reward
  Future<bool> showRewardedAd() async {
    if (!canShowAd) return false;

    final adService = AdService();
    
    // Load ad with timeout
    final loaded = await adService.loadRewardedInterstitialAd().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('Ad loading timed out');
        return false;
      },
    );

    if (!loaded) {
      debugPrint('Ad failed to load');
      return false;
    }

    final shown = await adService.showRewardedInterstitialAd(
      onUserEarnedReward: (reward) {
        addRewardPoints(reward.amount.toInt());
      },
    );

    // Only record ad watch time after ad is successfully shown
    if (shown) {
      recordAdWatch();
    }

    return shown;
  }
}