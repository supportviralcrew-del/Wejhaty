import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single completed trip, saved once the driver arrives at their
/// destination (i.e. crosses into the destination city's border).
class TripHistoryEntry {
  TripHistoryEntry({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.arrivedAt,
    required this.destinationCityName,
    required this.traveledKm,
    required this.roadKm,
    required this.fuelLiters,
    required this.fuelCost,
    required this.fuelCurrency,
    required this.fuelStationStops,
    this.drivingDuration,
    this.restingDuration,
    this.averageSpeedKmh,
    this.completed = true,
  });

  final String id;
  String name;
  final DateTime startedAt;
  final DateTime arrivedAt;
  final String destinationCityName;
  final double traveledKm;
  final double roadKm;
  final double fuelLiters;
  final double fuelCost;
  final String fuelCurrency;
  final int fuelStationStops;

  /// Actual time spent driving (if tracked)
  final Duration? drivingDuration;

  /// Time spent resting (if tracked)
  final Duration? restingDuration;

  /// Average speed during the trip (if tracked)
  final double? averageSpeedKmh;

  /// True if the trip ended because the driver actually arrived.
  /// False if it was auto-closed after 2 weeks without arriving.
  final bool completed;

  /// Total trip duration from start to arrival
  Duration get totalDuration => arrivedAt.difference(startedAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    'arrivedAt': arrivedAt.toIso8601String(),
    'destinationCityName': destinationCityName,
    'traveledKm': traveledKm,
    'roadKm': roadKm,
    'fuelLiters': fuelLiters,
    'fuelCost': fuelCost,
    'fuelCurrency': fuelCurrency,
    'fuelStationStops': fuelStationStops,
    'drivingDuration': drivingDuration?.inSeconds,
    'restingDuration': restingDuration?.inSeconds,
    'averageSpeedKmh': averageSpeedKmh,
    'completed': completed,
  };

  factory TripHistoryEntry.fromJson(Map<String, dynamic> json) => TripHistoryEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    startedAt: json.containsKey('startedAt') 
        ? DateTime.parse(json['startedAt'] as String)
        : DateTime.parse(json['arrivedAt'] as String), // Fallback for old entries
    arrivedAt: DateTime.parse(json['arrivedAt'] as String),
    destinationCityName: json['destinationCityName'] as String,
    traveledKm: (json['traveledKm'] as num).toDouble(),
    roadKm: (json['roadKm'] as num).toDouble(),
    fuelLiters: (json['fuelLiters'] as num).toDouble(),
    fuelCost: (json['fuelCost'] as num).toDouble(),
    fuelCurrency: json['fuelCurrency'] as String,
    fuelStationStops: (json['fuelStationStops'] as num).toInt(),
    drivingDuration: json['drivingDuration'] != null 
        ? Duration(seconds: json['drivingDuration'] as int) 
        : null,
    restingDuration: json['restingDuration'] != null 
        ? Duration(seconds: json['restingDuration'] as int) 
        : null,
    averageSpeedKmh: json['averageSpeedKmh'] as double?,
    completed: json['completed'] as bool? ?? true,
  );
}

/// Persists the list of completed trips (arrival date/time + stats)
/// to disk, and allows renaming or deleting individual entries.
class TripHistoryService {
  TripHistoryService._();
  static final TripHistoryService instance = TripHistoryService._();

  static const _storageKey = 'trip_history_entries';

  List<TripHistoryEntry> _entries = [];
  bool _loaded = false;

  List<TripHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _entries = list
            .map((e) => TripHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _entries.sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
      } catch (_) {
        _entries = [];
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<List<TripHistoryEntry>> load() async {
    await _ensureLoaded();
    return entries;
  }

  Future<TripHistoryEntry> add({
    required String name,
    required DateTime startedAt,
    required DateTime arrivedAt,
    required String destinationCityName,
    required double traveledKm,
    required double roadKm,
    required double fuelLiters,
    required double fuelCost,
    required String fuelCurrency,
    required int fuelStationStops,
    Duration? drivingDuration,
    Duration? restingDuration,
    double? averageSpeedKmh,
    bool completed = true,
  }) async {
    await _ensureLoaded();
    final entry = TripHistoryEntry(
      id: '${arrivedAt.microsecondsSinceEpoch}',
      name: name,
      startedAt: startedAt,
      arrivedAt: arrivedAt,
      destinationCityName: destinationCityName,
      traveledKm: traveledKm,
      roadKm: roadKm,
      fuelLiters: fuelLiters,
      fuelCost: fuelCost,
      fuelCurrency: fuelCurrency,
      fuelStationStops: fuelStationStops,
      drivingDuration: drivingDuration,
      restingDuration: restingDuration,
      averageSpeedKmh: averageSpeedKmh,
      completed: completed,
    );
    _entries.insert(0, entry);
    await _persist();
    return entry;
  }

  Future<void> rename(String id, String newName) async {
    await _ensureLoaded();
    final entry = _entries.where((e) => e.id == id).firstOrNull;
    if (entry == null) return;
    entry.name = newName;
    await _persist();
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();
    _entries.removeWhere((e) => e.id == id);
    await _persist();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}