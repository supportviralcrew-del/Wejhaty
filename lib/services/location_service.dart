import 'dart:async';
import 'dart:collection';

import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}

class LocationData {
  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.speedKmh = 0.0,
    this.heading = 0.0,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  /// Smoothed speed in km/h (rolling average, see [LocationService]).
  final double speedKmh;

  /// Compass heading in degrees (0-360), useful to rotate the map/marker.
  final double heading;

  factory LocationData.fromPosition(Position position, {double smoothedSpeedKmh = 0}) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      speedKmh: smoothedSpeedKmh,
      heading: position.heading,
    );
  }
}

class LocationService {
  LocationService({this.speedSampleWindow = 5});

  /// Number of recent speed samples averaged to smooth out GPS jitter.
  final int speedSampleWindow;

  final Queue<double> _recentSpeeds = Queue<double>();

  LocationData? _lastKnownLocation;
  LocationData? get lastKnownLocation => _lastKnownLocation;

  StreamSubscription<Position>? _subscription;
  final StreamController<LocationData> _controller =
  StreamController<LocationData>.broadcast();

  /// Emits smoothed location + speed updates. Call [startTracking] first.
  Stream<LocationData> get locationStream => _controller.stream;

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermissionStatus> checkPermissionStatus() async {
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  Future<LocationPermissionStatus> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  Future<LocationData?> getCurrentLocation() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final status = await checkPermissionStatus();
    if (status != LocationPermissionStatus.granted) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // Reduced slightly for better responsiveness
        ),
      );
      final data = _register(position);
      return data;
    } catch (e) {
      // Catch all exceptions: timeout, permission, service disabled, etc.
      // We return null and let AppDataProvider handle the fallback.
      return null;
    }
  }

  /// Starts a continuous position stream and pushes smoothed updates to
  /// [locationStream]. Safe to call multiple times; restarts the stream.
  Future<bool> startTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 5,
  }) async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final status = await checkPermissionStatus();
    if (status != LocationPermissionStatus.granted) return false;

    await _subscription?.cancel();
    _recentSpeeds.clear();

    _subscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    ).listen((position) {
      final data = _register(position);
      if (!_controller.isClosed) _controller.add(data);
    });

    return true;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  LocationData _register(Position position) {
    // Guard against negative/garbage speed values some devices report.
    final rawSpeedKmh = (position.speed.isNaN || position.speed < 0)
        ? 0.0
        : position.speed * 3.6;

    _recentSpeeds.addLast(rawSpeedKmh);
    while (_recentSpeeds.length > speedSampleWindow) {
      _recentSpeeds.removeFirst();
    }
    final smoothed = _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;

    final data = LocationData.fromPosition(position, smoothedSpeedKmh: smoothed);
    _lastKnownLocation = data;
    return data;
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  void dispose() {
    stopTracking();
    _controller.close();
  }
}