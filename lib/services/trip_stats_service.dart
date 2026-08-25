import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A resolved place name at country / state / city granularity.
class RoutePlace {
  const RoutePlace({this.city, this.state, this.country});
  final String? city;
  final String? state;
  final String? country;

  String label({required bool isAr}) {
    final parts = [city, state, country].where((p) => p != null && p.isNotEmpty).toList();
    return parts.isEmpty ? (isAr ? 'غير معروف' : 'Unknown') : parts.join(', ');
  }
}

/// Snapshot of live weather conditions at a single point along the route.
class RouteWeatherSnapshot {
  const RouteWeatherSnapshot({required this.temperatureC, required this.weatherCode, required this.windKph});
  final double temperatureC;
  final int weatherCode;
  final double windKph;

  /// Rough WMO weather-code → human description mapping.
  String description({required bool isAr}) {
    if (weatherCode == 0) return isAr ? 'صافٍ' : 'Clear sky';
    if (weatherCode <= 3) return isAr ? 'غائم جزئياً' : 'Partly cloudy';
    if (weatherCode <= 48) return isAr ? 'ضباب' : 'Fog';
    if (weatherCode <= 57) return isAr ? 'رذاذ' : 'Drizzle';
    if (weatherCode <= 67) return isAr ? 'أمطار' : 'Rain';
    if (weatherCode <= 77) return isAr ? 'ثلوج' : 'Snow';
    if (weatherCode <= 82) return isAr ? 'زخات أمطار' : 'Rain showers';
    if (weatherCode <= 99) return isAr ? 'عواصف رعدية' : 'Thunderstorms';
    return isAr ? 'غير معروف' : 'Unknown';
  }

  bool get isHazardous => weatherCode >= 65 && weatherCode <= 99;
}

enum RouteDifficulty { easy, moderate, challenging }

/// Result of a real road-routing lookup (distance + duration along
/// actual roads, as opposed to the great-circle heuristic).
class _RouteResult {
  const _RouteResult({required this.distanceKm, required this.durationHours});
  final double distanceKm;
  final double durationHours;
}

class TripStatistics {
  TripStatistics({
    required this.straightLineKm,
    required this.estimatedRoadKm,
    required this.averageSpeedKmh,
    required this.drivingHours,
    required this.restHours,
    required this.totalTripHours,
    required this.numberOfStops,
    required this.fuelStationStops,
    required this.fuelLiters,
    required this.fuelCost,
    required this.fuelCurrency,
    required this.carbonKg,
    required this.difficulty,
    required this.safetyScore,
    required this.efficiencyScore,
    required this.isLiveRouting,
    this.originPlace,
    this.destinationPlace,
    this.originWeather,
    this.destinationWeather,
    this.originElevationM,
    this.destinationElevationM,
    this.dataNotice,
  });

  final double straightLineKm;
  final double estimatedRoadKm;
  final double averageSpeedKmh;
  final double drivingHours;
  final double restHours;
  final double totalTripHours;
  final int numberOfStops;

  /// Estimated number of times the driver needs to stop at a fuel
  /// station along the road, based on tank capacity vs. fuel needed.
  final int fuelStationStops;
  final double fuelLiters;
  final double fuelCost;
  final String fuelCurrency;
  final double carbonKg;
  final RouteDifficulty difficulty;
  final int safetyScore; // 0-100
  final int efficiencyScore; // 0-100

  /// True when [estimatedRoadKm] / [drivingHours] came from a real
  /// road-routing lookup (OSRM) rather than the straight-line heuristic.
  final bool isLiveRouting;

  final RoutePlace? originPlace;
  final RoutePlace? destinationPlace;
  final RouteWeatherSnapshot? originWeather;
  final RouteWeatherSnapshot? destinationWeather;
  final double? originElevationM;
  final double? destinationElevationM;

  /// Set when one or more live lookups failed, so the UI can disclose
  /// which parts of the report are best-effort estimates.
  final String? dataNotice;

  double? get elevationChangeM {
    if (originElevationM == null || destinationElevationM == null) return null;
    return destinationElevationM! - originElevationM!;
  }
}

class TripStatsService {
  TripStatsService._();
  static final TripStatsService instance = TripStatsService._();

  static const _timeout = Duration(seconds: 6);

  Future<TripStatistics> compute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String? fuelCurrency,
    double? fuelPricePerLiter,
  }) async {
    final straightKm = Geolocator.distanceBetween(originLat, originLon, destLat, destLon) / 1000;

    final notices = <String>[];

    double roadKm;
    double drivingHours;
    bool isLiveRouting = false;

    // Prefer real road-routing (actual roads, turns, and drive time) over
    // the straight-line heuristic. Falls back gracefully if the routing
    // service is unreachable or the trip crosses water/no-road areas.
    try {
      final route = await _fetchRoute(originLat, originLon, destLat, destLon);
      roadKm = route.distanceKm;
      drivingHours = route.durationHours;
      isLiveRouting = true;
    } catch (e) {
      notices.add('live routing unavailable — showing an estimated distance');
      debugPrint('TripStatsService: routing lookup failed, using heuristic: $e');
      // Straight-line distance under-counts real road distance; ~1.3x is a
      // widely-used rule-of-thumb multiplier for road vs great-circle
      // distance on regional/highway trips. This is a heuristic fallback.
      roadKm = straightKm * 1.3;
      final avgSpeed = roadKm > 400 ? 90.0 : (roadKm > 100 ? 80.0 : 60.0);
      drivingHours = roadKm / avgSpeed;
    }

    final avgSpeed = drivingHours > 0 ? roadKm / drivingHours : 0.0;

    // A rest stop roughly every 2 hours of driving, ~15 minutes each —
    // a common road-safety guideline, not a measured figure.
    final stops = (drivingHours / 2).floor();
    final restHours = stops * (15 / 60);
    final totalHours = drivingHours + restHours;

    // Fuel: ~8 L/100km average sedan consumption heuristic.
    final fuelLiters = roadKm / 100 * 8;
    final price = fuelPricePerLiter ?? 2.18; // approx. Saudi 91-octane price, SAR
    final currency = fuelCurrency ?? 'SAR';
    final fuelCost = fuelLiters * price;

    // Fuel station stops: assumes the driver starts with a full ~50L
    // tank (average sedan capacity). A refuel stop is only needed once
    // the accumulated fuel need exceeds what's already in the tank.
    // Heuristic only.
    const tankCapacityLiters = 50.0;
    final fuelStationStops = fuelLiters > tankCapacityLiters
        ? (fuelLiters / tankCapacityLiters).ceil() - 1
        : 0;

    // ~2.31 kg CO2 per liter of petrol burned.
    final carbonKg = fuelLiters * 2.31;

    RouteDifficulty difficulty;
    if (roadKm < 150) {
      difficulty = RouteDifficulty.easy;
    } else if (roadKm < 500) {
      difficulty = RouteDifficulty.moderate;
    } else {
      difficulty = RouteDifficulty.challenging;
    }

    RoutePlace? originPlace;
    RoutePlace? destPlace;
    RouteWeatherSnapshot? originWeather;
    RouteWeatherSnapshot? destWeather;
    double? originElevation;
    double? destElevation;

    try {
      originPlace = await _reverseGeocode(originLat, originLon);
    } catch (e) {
      notices.add('origin locality lookup failed');
      debugPrint('TripStatsService: origin reverse geocode failed: $e');
    }
    try {
      destPlace = await _reverseGeocode(destLat, destLon);
    } catch (e) {
      notices.add('destination locality lookup failed');
      debugPrint('TripStatsService: destination reverse geocode failed: $e');
    }
    try {
      originWeather = await _fetchWeather(originLat, originLon);
    } catch (e) {
      notices.add('origin weather lookup failed');
    }
    try {
      destWeather = await _fetchWeather(destLat, destLon);
    } catch (e) {
      notices.add('destination weather lookup failed');
    }
    try {
      final elevations = await _fetchElevations([
        [originLat, originLon],
        [destLat, destLon],
      ]);
      if (elevations.length == 2) {
        originElevation = elevations[0];
        destElevation = elevations[1];
      }
    } catch (e) {
      notices.add('elevation lookup failed');
    }

    // Safety score: starts high, docked for long distance, bad weather,
    // and a long single push without enough rest stops. Heuristic only.
    int safety = 90;
    if (roadKm > 500) safety -= 10;
    if (drivingHours > 6) safety -= 10;
    if ((originWeather?.isHazardous ?? false) || (destWeather?.isHazardous ?? false)) safety -= 15;
    safety = safety.clamp(0, 100);

    // Efficiency score: rewards shorter, more direct trips with fewer
    // stops relative to distance. Heuristic only.
    int efficiency = 100 - (stops * 3) - (roadKm > 600 ? 10 : 0);
    efficiency = efficiency.clamp(0, 100);

    return TripStatistics(
      straightLineKm: straightKm,
      estimatedRoadKm: roadKm,
      averageSpeedKmh: avgSpeed,
      drivingHours: drivingHours,
      restHours: restHours,
      totalTripHours: totalHours,
      numberOfStops: stops,
      fuelStationStops: fuelStationStops,
      fuelLiters: fuelLiters,
      fuelCost: fuelCost,
      fuelCurrency: currency,
      carbonKg: carbonKg,
      difficulty: difficulty,
      safetyScore: safety,
      efficiencyScore: efficiency,
      isLiveRouting: isLiveRouting,
      originPlace: originPlace,
      destinationPlace: destPlace,
      originWeather: originWeather,
      destinationWeather: destWeather,
      originElevationM: originElevation,
      destinationElevationM: destElevation,
      dataNotice: notices.isEmpty ? null : notices.join('; '),
    );
  }

  /// Real road-routing via OSRM's free public demo server (no API key).
  /// Note coordinates are passed as lon,lat per OSRM convention.
  Future<_RouteResult> _fetchRoute(double oLat, double oLon, double dLat, double dLon) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$oLon,$oLat;$dLon,$dLat?overview=false',
    );
    final res = await http.get(uri).timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') {
      throw Exception('OSRM returned ${body['code']}');
    }
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('OSRM returned no routes');
    }
    final route = routes.first as Map<String, dynamic>;
    return _RouteResult(
      distanceKm: (route['distance'] as num) / 1000,
      durationHours: (route['duration'] as num) / 3600,
    );
  }

  Future<RoutePlace> _reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
    );
    final res = await http.get(uri).timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return RoutePlace(
      city: (body['city'] as String?)?.trim().isNotEmpty == true ? body['city'] as String : null,
      state: (body['principalSubdivision'] as String?),
      country: (body['countryName'] as String?),
    );
  }

  Future<RouteWeatherSnapshot> _fetchWeather(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m',
    );
    final res = await http.get(uri).timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>;
    return RouteWeatherSnapshot(
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      windKph: (current['wind_speed_10m'] as num).toDouble(),
    );
  }

  Future<List<double>> _fetchElevations(List<List<double>> points) async {
    final lats = points.map((p) => p[0].toString()).join(',');
    final lons = points.map((p) => p[1].toString()).join(',');
    final uri = Uri.parse('https://api.open-meteo.com/v1/elevation?latitude=$lats&longitude=$lons');
    final res = await http.get(uri).timeout(_timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final elevation = (body['elevation'] as List).map((e) => (e as num).toDouble()).toList();
    return elevation;
  }
}

/// Tracks the driver's real, cumulative distance traveled for the
/// current trip (starts at 0 the moment a trip begins) and detects
/// arrival as soon as the user crosses into the destination city's
/// border — i.e. within [arrivalRadiusKm] of the destination point —
/// rather than requiring the exact pin to be reached.
class TripProgressService {
  TripProgressService._();
  static final TripProgressService instance = TripProgressService._();

  /// Treat the user as "arrived" once within this radius of the
  /// destination — approximates entering the city's border.
  static const double arrivalRadiusKm = 5.0;

  /// GPS points closer together than this are ignored as jitter/noise
  /// rather than counted as real movement.
  static const double _minMovementKm = 0.03;

  /// Below this speed the driver is considered stopped rather than
  /// driving (used to split elapsed time into driving vs. resting).
  static const double _movingSpeedThresholdKmh = 5.0;

  /// A stop only counts once the driver has been under the speed
  /// threshold continuously for this long — filters out traffic
  /// lights / short slow-downs.
  static const Duration _stopConfirmDuration = Duration(minutes: 3);

  /// A trip record that's never arrived is auto-closed after this
  /// long and moved into trip history.
  static const Duration maxTripDuration = Duration(days: 14);

  // SharedPreferences keys used to persist the live trip state so a
  // trip survives the app process being killed (user exits the app,
  // swipe-away, memory pressure). On the next launch the tracker
  // resumes automatically via [resumeAfterRestart].
  static const _kDestLat = 'trip_dest_lat';
  static const _kDestLon = 'trip_dest_lon';
  static const _kTraveledKm = 'trip_traveled_km';
  static const _kDrivingMs = 'trip_driving_ms';
  static const _kRestingMs = 'trip_resting_ms';
  static const _kLiveStops = 'trip_live_stops';
  static const _kStartedAtMs = 'trip_started_at_ms';

  StreamSubscription<Position>? _sub;
  Timer? _expiryTimer;
  Position? _lastPosition;
  DateTime? _lastSampleTime;

  double _traveledKm = 0;
  Duration _drivingDuration = Duration.zero;
  Duration _restingDuration = Duration.zero;
  int _liveStops = 0;
  DateTime? _stoppedSince;
  bool _countedCurrentStop = false;

  DateTime? _tripStartTime;
  bool _arrived = false;
  bool _expired = false;
  double? _destLat;
  double? _destLon;

  double _lastSpeedKmh = 0; // real-time instantaneous speed

  final _distanceController = StreamController<double>.broadcast();
  final _updateController = StreamController<void>.broadcast();
  final _arrivalController = StreamController<void>.broadcast();
  final _expiredController = StreamController<void>.broadcast();

  /// Distance actually traveled so far this trip, in km. 0 until a
  /// trip is started.
  double get traveledKm => _traveledKm;

  /// Real time spent actually driving (speed above the moving
  /// threshold) since the trip started. 0 until a trip is started.
  Duration get drivingDuration => _drivingDuration;

  /// Real time spent stopped since the trip started. 0 until a trip
  /// is started.
  Duration get restingDuration => _restingDuration;

  /// Total elapsed time for the current trip record (driving + rest).
  Duration get totalTripDuration => _drivingDuration + _restingDuration;

  /// Number of confirmed stops (stopped for 3+ minutes) so far.
  int get liveStops => _liveStops;

  /// Live average speed = distance actually traveled / time actually
  /// spent driving. 0 until the driver has moved.
  double get liveAverageSpeedKmh {
    final hours = _drivingDuration.inSeconds / 3600;
    return hours > 0 ? _traveledKm / hours : 0;
  }

  /// Real-time instantaneous speed from last GPS sample (km/h). 0 if stopped.
  double get currentSpeedKmh => _lastSpeedKmh;

  /// Remaining straight-line distance to destination from current GPS fix.
  double? get remainingKm {
    if (_lastPosition == null || _destLat == null || _destLon == null) return null;
    return Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          _destLat!,
          _destLon!,
        ) /
        1000;
  }

  /// Predicted remaining driving time based on live speed if moving,
  /// otherwise on live average, otherwise fallback 70 km/h heuristic.
  Duration? get remainingDuration {
    final rem = remainingKm;
    if (rem == null) return null;
    double speed = _lastSpeedKmh;
    if (speed < _movingSpeedThresholdKmh) speed = liveAverageSpeedKmh;
    if (speed < 5) speed = 70; // fallback highway avg
    final hours = rem / speed;
    return Duration(milliseconds: (hours * 3600000).round());
  }

  /// Predicted clock time of arrival (now + remainingDuration).
  DateTime? get eta {
    final rem = remainingDuration;
    if (rem == null) return null;
    return DateTime.now().add(rem);
  }

  bool get isTracking => _sub != null;
  bool get hasArrived => _arrived;
  DateTime? get tripStartTime => _tripStartTime;
  
  /// Current GPS position during tracking, or null if not tracking
  Position? get currentPosition => _lastPosition;

  /// Whether there's a trip record currently open (tracking or
  /// arrived-but-not-yet-cleared) for [lat]/[lon].
  bool isActiveFor(double lat, double lon) {
    if (_destLat == null || _destLon == null) return false;
    if (!isTracking) return false;
    return (Geolocator.distanceBetween(_destLat!, _destLon!, lat, lon)) < 100;
  }

  /// Emits the updated traveled distance (km) whenever it changes.
  Stream<double> get onTraveledDistanceChanged => _distanceController.stream;

  /// Fires on every GPS sample — use to refresh driving/rest time,
  /// stop count, and live average speed in the UI.
  Stream<void> get onUpdate => _updateController.stream;

  /// Fires once, the moment the user crosses into the destination
  /// city's border.
  Stream<void> get onArrival => _arrivalController.stream;

  /// Fires once if the trip record has been open for longer than
  /// [maxTripDuration] without arriving — it is auto-closed and
  /// should be filed into trip history as an unfinished record.
  Stream<void> get onExpired => _expiredController.stream;

  /// Begins tracking a fresh trip record toward [destLat]/[destLon].
  /// Every live stat resets to 0/zero.
  void start({required double destLat, required double destLon}) {
    stop();
    _traveledKm = 0;
    _drivingDuration = Duration.zero;
    _restingDuration = Duration.zero;
    _liveStops = 0;
    _stoppedSince = null;
    _countedCurrentStop = false;
    _lastPosition = null;
    _lastSampleTime = null;
    _arrived = false;
    _expired = false;
    _tripStartTime = DateTime.now();
    _destLat = destLat;
    _destLon = destLon;
    _distanceController.add(0);

    _persistState();
    _startStream();

    _expiryTimer = Timer(maxTripDuration, _onExpired);
  }

  /// Restarts tracking after the app process was killed while a trip
  /// was still active (user exited/swiped the app away). Restores the
  /// persisted destination and live stats and re-attaches the GPS
  /// stream + Android foreground service so the trip keeps running
  /// until the user stops it manually or arrives at the destination.
  ///
  /// Returns true if a trip was actually resumed.
  Future<bool> resumeAfterRestart() async {
    if (isTracking || _arrived || _expired) return false;
    final prefs = await SharedPreferences.getInstance();
    final destLat = prefs.getDouble(_kDestLat);
    final destLon = prefs.getDouble(_kDestLon);
    if (destLat == null || destLon == null) return false;

    final startedAtMs = prefs.getInt(_kStartedAtMs);
    if (startedAtMs == null) return false;

    // If the trip record somehow outlived its maximum duration, don't
    // resume it — let it be closed through the normal UI flow.
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(startedAtMs),
    );
    if (elapsed >= maxTripDuration) return false;

    stop();
    _traveledKm = prefs.getDouble(_kTraveledKm) ?? 0;
    _drivingDuration = Duration(milliseconds: prefs.getInt(_kDrivingMs) ?? 0);
    _restingDuration = Duration(milliseconds: prefs.getInt(_kRestingMs) ?? 0);
    _liveStops = prefs.getInt(_kLiveStops) ?? 0;
    _stoppedSince = null;
    _countedCurrentStop = true; // don't double-count an unknown old stop
    _lastPosition = null;
    _lastSampleTime = null;
    _arrived = false;
    _expired = false;
    _tripStartTime = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
    _destLat = destLat;
    _destLon = destLon;

    _startStream();
    _expiryTimer = Timer(maxTripDuration - elapsed, _onExpired);
    debugPrint('TripProgressService: resumed trip after app restart');
    return true;
  }

  /// Location-stream settings. On Android the stream runs inside a
  /// foreground service (persistent notification) so the OS keeps the
  /// process alive — and the trip tracking continues — while the user
  /// has the app in the background or the screen off.
  LocationSettings _streamSettings() {
    const baseAccuracy = LocationAccuracy.high;
    const baseFilter = 30;
    if (kIsWeb) {
      return const LocationSettings(accuracy: baseAccuracy, distanceFilter: baseFilter);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: baseAccuracy,
          distanceFilter: baseFilter,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Wejhaty • Trip in progress',
            notificationText:
                'Tracking your trip until arrival — you can close the app.',
            notificationChannelName: 'Trip Tracking',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      default:
        return const LocationSettings(accuracy: baseAccuracy, distanceFilter: baseFilter);
    }
  }

  void _startStream() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: _streamSettings())
        .listen(_onPosition, onError: (_) {});
  }

  /// Saves the live trip state so [resumeAfterRestart] can pick the
  /// trip back up even if the whole process is killed.
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setDouble(_kDestLat, _destLat!),
        prefs.setDouble(_kDestLon, _destLon!),
        prefs.setDouble(_kTraveledKm, _traveledKm),
        prefs.setInt(_kDrivingMs, _drivingDuration.inMilliseconds),
        prefs.setInt(_kRestingMs, _restingDuration.inMilliseconds),
        prefs.setInt(_kLiveStops, _liveStops),
        prefs.setInt(
          _kStartedAtMs,
          _tripStartTime?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      ]);
    } catch (_) {
      // Persistence is best-effort; tracking must never crash.
    }
  }

  /// Removes the persisted trip state once the trip record has been
  /// fully closed (saved to history / reset).
  Future<void> _clearPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kDestLat),
        prefs.remove(_kDestLon),
        prefs.remove(_kTraveledKm),
        prefs.remove(_kDrivingMs),
        prefs.remove(_kRestingMs),
        prefs.remove(_kLiveStops),
        prefs.remove(_kStartedAtMs),
      ]);
    } catch (_) {}
  }

  void _onPosition(Position pos) {
    final now = pos.timestamp;
    if (_lastPosition != null && _lastSampleTime != null) {
      final deltaKm = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      ) / 1000;
      final elapsed = now.difference(_lastSampleTime!);
      final hours = elapsed.inMilliseconds / 3600000;
      final speedKmh = hours > 0 ? deltaKm / hours : 0.0;
      _lastSpeedKmh = speedKmh.clamp(0.0, 220.0).toDouble();

      if (deltaKm >= _minMovementKm && speedKmh >= _movingSpeedThresholdKmh) {
        _traveledKm += deltaKm;
        _drivingDuration += elapsed;
        _stoppedSince = null;
        _countedCurrentStop = false;
        _distanceController.add(_traveledKm);
      } else {
        // Keep last speed for a moment, decay to 0 if fully stopped
        if (speedKmh < 1) _lastSpeedKmh = 0;
        _restingDuration += elapsed;
        _stoppedSince ??= _lastSampleTime;
        if (!_countedCurrentStop && now.difference(_stoppedSince!) >= _stopConfirmDuration) {
          _liveStops++;
          _countedCurrentStop = true;
        }
      }
      _updateController.add(null);
    } else {
      // First fix — init speed from GPS speed if available
      try {
        _lastSpeedKmh = (pos.speed * 3.6).clamp(0.0, 220.0).toDouble();
      } catch (_) {}
    }
    _lastPosition = pos;
    _lastSampleTime = now;

    if (!_arrived && _destLat != null && _destLon != null) {
      final remainingKm = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        _destLat!,
        _destLon!,
      ) / 1000;
      if (remainingKm <= arrivalRadiusKm) {
        _arrived = true;
        _arrivalController.add(null);
        stop();
        return;
      }
    }

    // Keep the persisted snapshot fresh so an unexpected process kill
    // (user exits the app, swipe-away) loses at most the last sample.
    _persistState();
  }

  void _onExpired() {
    if (_arrived || !isTracking) return;
    _expired = true;
    _expiredController.add(null);
    stop();
  }

  /// Stops listening for location updates. Does not reset the live
  /// stats so a paused trip's progress isn't lost; call [reset] (or
  /// [start] again) to clear them.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  /// Fully clears the current trip record (after it's been saved to
  /// history) so the UI goes back to the "create trip record" state.
  void reset() {
    stop();
    _traveledKm = 0;
    _drivingDuration = Duration.zero;
    _restingDuration = Duration.zero;
    _liveStops = 0;
    _stoppedSince = null;
    _countedCurrentStop = false;
    _lastPosition = null;
    _lastSampleTime = null;
    _tripStartTime = null;
    _arrived = false;
    _expired = false;
    _destLat = null;
    _destLon = null;
    // The record is closed — nothing left to resume after a restart.
    _clearPersistedState();
  }
}