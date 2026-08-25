import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TurnInstruction {
  final String instruction;
  final double distance;
  final LatLng? position;

  TurnInstruction({
    required this.instruction,
    required this.distance,
    this.position,
  });

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'distance': distance,
    'position': position == null
        ? null
        : {'latitude': position!.latitude, 'longitude': position!.longitude},
  };

  factory TurnInstruction.fromJson(Map<String, dynamic> json) {
    final positionMap = json['position'] as Map<String, dynamic>?;
    return TurnInstruction(
      instruction: json['instruction'] as String? ?? 'Continue',
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      position: positionMap == null
          ? null
          : LatLng(
              (positionMap['latitude'] as num).toDouble(),
              (positionMap['longitude'] as num).toDouble(),
            ),
    );
  }
}

class RouteData {
  final List<LatLng> points;
  final List<TurnInstruction> instructions;
  final double totalDistance; // meters
  final double estimatedDuration; // seconds

  RouteData({
    required this.points,
    required this.instructions,
    required this.totalDistance,
    required this.estimatedDuration,
  });

  Map<String, dynamic> toJson() => {
    'points': points
        .map(
          (point) => {'latitude': point.latitude, 'longitude': point.longitude},
        )
        .toList(),
    'instructions': instructions.map((item) => item.toJson()).toList(),
    'totalDistance': totalDistance,
    'estimatedDuration': estimatedDuration,
  };

  factory RouteData.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    final rawInstructions = json['instructions'] as List<dynamic>? ?? const [];
    return RouteData(
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(
            (point) => LatLng(
              (point['latitude'] as num).toDouble(),
              (point['longitude'] as num).toDouble(),
            ),
          )
          .toList(),
      instructions: rawInstructions
          .whereType<Map<String, dynamic>>()
          .map(TurnInstruction.fromJson)
          .toList(),
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0,
      estimatedDuration: (json['estimatedDuration'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Distance in meters from [point] to the closest point on the route path.
  /// Used to detect if the user has drifted off the route and needs a
  /// recalculation.
  double distanceFromRoute(LatLng point) {
    const distanceCalc = Distance();
    if (points.length < 2) {
      if (points.isEmpty) return double.infinity;
      return distanceCalc.as(LengthUnit.Meter, point, points.first);
    }
    double minDist = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToSegment(
        distanceCalc,
        point,
        points[i],
        points[i + 1],
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  static double _distanceToSegment(
    Distance calc,
    LatLng p,
    LatLng a,
    LatLng b,
  ) {
    // Local equirectangular projection - accurate enough at road-segment
    // scale and much cheaper than an iterative geodesic search.
    final lat0 = a.latitudeInRad;
    double x(LatLng q) => q.longitudeInRad * math.cos(lat0);
    double y(LatLng q) => q.latitudeInRad;

    final ax = x(a), ay = y(a);
    final bx = x(b), by = y(b);
    final px = x(p), py = y(p);

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSq = dx * dx + dy * dy;

    double t = lengthSq == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);

    final closestLat = a.latitude + t * (b.latitude - a.latitude);
    final closestLng = a.longitude + t * (b.longitude - a.longitude);

    return calc.as(LengthUnit.Meter, p, LatLng(closestLat, closestLng));
  }
}

/// Outcome of the last [RoutingService.getRoutes] call — lets the UI tell
/// "there is genuinely no route between these points" (e.g. UAE → New York
/// by car, which Google Maps also can't route) apart from a network or
/// server failure, where an offline fallback still makes sense.
enum RoutingStatus {
  /// A route was found (or nothing was queried yet).
  ok,

  /// The router explicitly answered that no route exists.
  noRoute,

  /// Network/server failure — offline fallback is still reasonable.
  error,
}

class RoutingService {
  RoutingService();

  // Free public OSRM demo server - no API key required. It's rate-limited
  // and meant for light/demo use; for production traffic, self-host OSRM
  // (also free, just needs your own server) - see http://project-osrm.org/.
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Status of the most recent [getRoutes] call.
  RoutingStatus lastStatus = RoutingStatus.ok;

  Future<RouteData?> getRoute(LatLng origin, LatLng destination) async {
    final routes = await getRoutes(origin, destination, alternatives: false);
    return routes.isEmpty ? null : routes.first;
  }

  Future<List<RouteData>> getRoutes(
    LatLng origin,
    LatLng destination, {
    bool alternatives = true,
  }) async {
    try {
      final alternativesParam = alternatives ? 'true' : 'false';
      final url =
          '$_osrmBaseUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson&steps=true&alternatives=$alternativesParam';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final code = data['code'] as String? ?? '';

        // The router explicitly says these points cannot be connected by
        // road (e.g. intercontinental trips) — not an error, a real answer.
        if (code == 'NoRoute') {
          lastStatus = RoutingStatus.noRoute;
          return const [];
        }

        if (code == 'Ok' && (data['routes'] as List?)?.isNotEmpty == true) {
          lastStatus = RoutingStatus.ok;
          final routes = data['routes'] as List;
          return routes.map((rawRoute) {
            final route = rawRoute as Map<String, dynamic>;
            final geometry = route['geometry']['coordinates'] as List;
            final legs = route['legs'] as List;

            final points = geometry.map((coord) {
              final pair = coord as List;
              return LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              );
            }).toList();

            final instructions = <TurnInstruction>[];
            for (var leg in legs) {
              final steps = leg['steps'] as List;
              for (var step in steps) {
                final stepMap = step as Map<String, dynamic>;
                final maneuver = stepMap['maneuver'] as Map<String, dynamic>;
                final distance = (stepMap['distance'] as num).toDouble();
                final instruction = _parseManeuver(maneuver, distance);
                final location = maneuver['location'] as List;
                final stepLocation = LatLng(
                  (location[1] as num).toDouble(),
                  (location[0] as num).toDouble(),
                );

                instructions.add(
                  TurnInstruction(
                    instruction: instruction,
                    distance: distance,
                    position: stepLocation,
                  ),
                );
              }
            }

            return RouteData(
              points: points,
              instructions: instructions,
              totalDistance: (route['distance'] as num).toDouble(),
              estimatedDuration: (route['duration'] as num).toDouble(),
            );
          }).toList();
        }
      }
      // Non-200 or an unexpected code — treat as a service failure rather
      // than "no route exists".
      lastStatus = RoutingStatus.error;
      return const [];
    } catch (e) {
      debugPrint('RoutingService error: $e');
      lastStatus = RoutingStatus.error;
      return const [];
    }
  }

  String _parseManeuver(Map<String, dynamic> maneuver, double distance) {
    final type = maneuver['type'] as String? ?? 'continue';
    final modifier = maneuver['modifier'] as String?;

    String instruction;

    switch (type) {
      case 'turn':
        instruction = _getTurnInstruction(modifier, 'Turn');
        break;
      case 'new name':
        instruction = _getTurnInstruction(modifier, 'Continue on');
        break;
      case 'depart':
        instruction = 'Start';
        break;
      case 'arrive':
        instruction = 'Arrive at destination';
        break;
      case 'merge':
        instruction = 'Merge';
        break;
      case 'on ramp':
        instruction = 'Take ramp';
        break;
      case 'off ramp':
        instruction = 'Take exit';
        break;
      case 'fork':
        instruction = _getTurnInstruction(modifier, 'At fork, take');
        break;
      case 'end of road':
        instruction = _getTurnInstruction(modifier, 'At end of road, turn');
        break;
      case 'use lane':
        instruction = 'Use lane';
        break;
      case 'roundabout':
        final exit = maneuver['exit'] as int?;
        instruction = 'Take roundabout exit ${exit ?? 1}';
        break;
      default:
        instruction = 'Continue';
    }

    return '$instruction (${_formatDistance(distance)})';
  }

  String _getTurnInstruction(String? modifier, String prefix) {
    switch (modifier) {
      case 'left':
        return '$prefix left';
      case 'right':
        return '$prefix right';
      case 'slight left':
        return '$prefix slight left';
      case 'slight right':
        return '$prefix slight right';
      case 'sharp left':
        return '$prefix sharp left';
      case 'sharp right':
        return '$prefix sharp right';
      case 'uturn':
        return 'Make U-turn';
      default:
        return prefix;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
