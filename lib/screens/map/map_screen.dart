import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/local_cache_service.dart';
import 'package:tripproject/services/location_service.dart';
import 'package:tripproject/services/routing_service.dart';
import 'package:tripproject/screens/subscription/subscription_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _RouteOption {
  final String badgeTextAr;
  final String badgeTextEn;
  final Color badgeColor;
  final Color lineColor;
  final String durationAr;
  final String durationEn;
  final String distanceAr;
  final String distanceEn;
  final String descriptionAr;
  final String descriptionEn;
  final String trafficAr;
  final String trafficEn;

  const _RouteOption({
    required this.badgeTextAr,
    required this.badgeTextEn,
    required this.badgeColor,
    required this.lineColor,
    required this.durationAr,
    required this.durationEn,
    required this.distanceAr,
    required this.distanceEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.trafficAr,
    required this.trafficEn,
  });
}

class _GuideStop {
  final String titleEn;
  final String titleAr;
  final String noteEn;
  final String noteAr;
  final String query;

  /// True for border crossings. Navigation waypoints are cut at the LAST
  /// border crossing of the corridor (the entry into the destination
  /// country) — after it, Google Maps routes normally to the destination
  /// city without stations, so the route never detours through corridor
  /// cities that aren't on the way (e.g. Amman when the destination is
  /// Aqaba).
  final bool isBorderCrossing;

  const _GuideStop({
    required this.titleEn,
    required this.titleAr,
    required this.noteEn,
    required this.noteAr,
    required this.query,
    this.isBorderCrossing = false,
  });
}

class _RouteGuidePlan {
  final String titleEn;
  final String titleAr;
  final String summaryEn;
  final String summaryAr;
  final List<_GuideStop> stops;

  const _RouteGuidePlan({
    required this.titleEn,
    required this.titleAr,
    required this.summaryEn,
    required this.summaryAr,
    required this.stops,
  });

  /// Waypoints handed to Google Maps when the user launches navigation —
  /// the exact stations of this guide in order.
  List<String> get waypointQueries => stops.map((s) => s.query).toList();
}

/// Countries the curated route-guide system knows about.
enum _Country { uae, qatar, kuwait, iraq, bahrain, jordan, syria, palestine, saudi, oman, other }

/// Saudi Arabia is far too large for one fixed corridor — the start point
/// completely changes the best route. West (Makkah/Jeddah/Madinah/Tabuk)
/// exits via Al-Mudawwara, central (Riyadh/Qassim) via the classic
/// Qassim–Hail–Qurayyat line, and the Eastern Province via Hafr Al-Batin.
enum _SaudiRegion { west, central, east }

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  final LocalCacheService _cache = LocalCacheService.instance;
  final LocationService _locationService = LocationService(
    speedSampleWindow: 5,
  );

  int _selectedTransportMode =
  0; // 0: Car, 1: Motorcycle, 2: Walking, 3: Bicycle
  int _selectedRouteIndex =
  0; // Index into the current route options (curated named routes for known corridors, or Easiest/Fastest/Fuel Saver/Alternative elsewhere)
  String? _savedCorridorKey; // corridor the persisted route index belongs to

  RouteData? _routeData;
  List<RouteData> _routeAlternatives = const [];
  LatLng? _routeOrigin;
  LatLng? _routeDestination;
  double _currentSpeed = 0.0;
  LatLng? _liveLocation;
  double _heading = 0.0;

  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _periodicRerouteTimer;
  DateTime? _lastRouteFetch;
  bool _isFetchingRoute = false;
  bool _followMe = true;
  bool _routeSetupStarted = false;

  /// True only while the interactive-map modal (the only place a
  /// FlutterMap is rendered) is open — guards all MapController access.
  bool _mapModalOpen = false;

  /// True when the router confirmed no drivable route exists to the
  /// selected destination (e.g. intercontinental trips). The UI then shows
  /// a "no route" message instead of route cards.
  bool _noRouteFound = false;

  static const double _rerouteDeviationMeters = 40.0;
  static const Duration _rerouteInterval = Duration(seconds: 25);
  // =========================================================================
  // COUNTRY-AWARE CURATED ROUTE GUIDES
  //
  // Hand-built, real-world route guides for the corridors people actually
  // drive in this region:
  //   • UAE / Qatar / Kuwait / Iraq / Bahrain → Jordan (and back)
  //   • UAE / Qatar / Kuwait / Iraq / Bahrain → Syria or Palestine (and back)
  //   • Iraq ↔ Syria directly
  // Every other destination still gets a usable plan from live turn-by-turn
  // routing data — so route guides effectively cover all countries.
  //
  // Corridors are composed from shared stop chains (entry border → Saudi
  // core → exit leg) and reversed for the opposite direction. Stops are
  // ordered from ORIGIN to DESTINATION and are handed to Google Maps as
  // literal waypoints when the user launches navigation.
  // =========================================================================

  // ── Country detection (coordinate boxes; small countries checked first).
  // Boxes are tuned so neighbouring capitals resolve correctly: Amman →
  // Jordan, Jerusalem/Ramallah/Jericho → Palestine, Daraa → Syria, Irbid →
  // Jordan. The Jordan–Syria border needs a special rule: everything south
  // of ~32.7°N west of ~36.0°E is Jordan (Irbid/Mafraq side), everything
  // north-east of that is Syria (Daraa side).
  static _Country _countryOfPoint(double lat, double lon) {
    if (lat >= 25.5 && lat <= 26.8 && lon >= 50.2 && lon <= 50.9) {
      return _Country.bahrain;
    }
    if (lat >= 24.4 && lat <= 26.3 && lon >= 50.6 && lon <= 51.8) {
      return _Country.qatar;
    }
    if (lat >= 28.4 && lat <= 30.3 && lon >= 46.4 && lon <= 48.6) {
      return _Country.kuwait;
    }
    if (lat >= 22.5 && lat <= 26.6 && lon >= 51.3 && lon <= 56.7) {
      return _Country.uae;
    }
    // Palestine (Gaza + West Bank) — checked before Jordan: it sits inside
    // Jordan's bounding box, hugging its western edge.
    if (lat >= 31.2 && lat <= 32.65 && lon >= 34.15 && lon <= 35.55) {
      return _Country.palestine;
    }
    // Syria — checked before Jordan for the shared north; the strip rule
    // keeps Jordanian cities (Irbid, Umm Qais) out of Syria.
    if (lat >= 32.5 &&
        lat <= 37.4 &&
        lon >= 35.5 &&
        lon <= 42.5 &&
        !(lat < 32.7 && lon < 36.0)) {
      return _Country.syria;
    }
    if (lat >= 29.1 && lat <= 33.4 && lon >= 34.9 && lon <= 39.35) {
      return _Country.jordan;
    }
    if (lat >= 29.0 && lat <= 37.5 && lon >= 38.6 && lon <= 48.9) {
      return _Country.iraq;
    }
    if (lat >= 16.0 && lat <= 32.3 && lon >= 34.4 && lon <= 56.0) {
      return _Country.saudi;
    }
    if (lat >= 16.5 && lat <= 26.6 && lon >= 51.8 && lon <= 60.1) {
      return _Country.oman;
    }
    return _Country.other;
  }

  /// Broad landmass classification used to detect road-disconnected trips
  /// (intercontinental = undrivable, exactly like Google Maps refuses
  /// them). The Americas are treated as one landmass (the Pan-American
  /// road network), everything in Africa+Europe+Asia is connected by road,
  /// and Australia/Oceania is isolated.
  static String _landmassOf(double lat, double lon) {
    if (lon < -30) return 'americas';
    if (lon >= 110 && lat < -10) return 'oceania';
    return 'afroEurasia';
  }

  static const Set<_Country> _gulfCountries = {
    _Country.uae,
    _Country.qatar,
    _Country.kuwait,
    _Country.iraq,
    _Country.bahrain,
  };

  /// Picks the Saudi corridor region from a point inside Saudi Arabia:
  ///   • west — Hijaz / Red Sea coast (Makkah, Jeddah, Madinah, Tabuk)
  ///   • east — Eastern Province & the far north (Dammam, Hafr Al-Batin)
  ///   • central — Riyadh, Qassim and everything in between
  static _SaudiRegion _saudiRegionOf(double lat, double lon) {
    if (lon < 42.0 && lat < 29.5) return _SaudiRegion.west;
    if (lon >= 47.0 || (lon >= 46.0 && lat >= 28.0)) return _SaudiRegion.east;
    return _SaudiRegion.central;
  }

  /// The relevant Saudi region for this trip: where the driver STARTS when
  /// Saudi is the origin, or where they're HEADING when it's the
  /// destination (reverse trips).
  _SaudiRegion _saudiRegionFor(AppDataProvider provider) {
    final origin = _resolveCurrentLocation(provider);
    if (_originCountry(provider) == _Country.saudi && origin != null) {
      return _saudiRegionOf(origin.latitude, origin.longitude);
    }
    return _saudiRegionOf(provider.destinationLat, provider.destinationLon);
  }

  _Country _originCountry(AppDataProvider provider) {
    final loc = _resolveCurrentLocation(provider);
    if (loc != null) return _countryOfPoint(loc.latitude, loc.longitude);
    return _Country.other;
  }

  _Country _destinationCountry(AppDataProvider provider) {
    // Name hints first — the most reliable signal for well-known cities
    // (guards against any bounding-box imprecision near borders).
    final name = provider.destinationCityName.toLowerCase();
    if (name.contains('amman') ||
        name.contains('عمّان') ||
        name.contains('الأردن') ||
        name.contains('الاردن')) {
      return _Country.jordan;
    }
    if (name.contains('damascus') || name.contains('دمشق')) {
      return _Country.syria;
    }
    if (name.contains('gaza') ||
        name.contains('غزة') ||
        name.contains('غزه') ||
        name.contains('jerusalem') ||
        name.contains('القدس') ||
        name.contains('ramallah') ||
        name.contains('رام الله')) {
      return _Country.palestine;
    }

    final byPoint = _countryOfPoint(
      provider.destinationLat,
      provider.destinationLon,
    );
    if (byPoint != _Country.other) return byPoint;
    return byPoint;
  }

  // Approximate coordinates for every station query — used to trim the
  // corridor from the user's start point ("closest station first") so the
  // route never moves BACKWARDS through stations it already passed.
  static const Map<String, List<double>> _stopCoords = {
    // Borders
    'Salwa Border Crossing Qatar Saudi Arabia': [24.66, 50.79],
    'King Fahd Causeway Bahrain Saudi Arabia': [26.17, 50.53],
    'Al Ghuwaifat Border Crossing UAE Saudi Arabia': [24.06, 51.58],
    'Al Nuqheb Border Crossing Kuwait Saudi Arabia': [28.55, 47.47],
    'Abdali Border Crossing Kuwait Iraq': [30.06, 47.98],
    'Al Omari Border Crossing Jordan': [29.85, 37.53],
    'Al Mudawwara Border Crossing Saudi Jordan': [29.93, 36.30],
    'Trebil Al Karamah Border Crossing Iraq Jordan': [32.16, 37.20],
    'Al Tanf Border Crossing Iraq Syria': [33.50, 38.32],
    'Nasib Jaber Border Crossing Jordan Syria': [32.61, 36.05],
    'King Hussein Bridge Allenby Crossing': [31.84, 35.54],
    // Saudi cities
    'Al Ahsa Hofuf Saudi Arabia': [25.38, 49.59],
    'Qaysumah Saudi Arabia': [28.28, 46.11],
    'Rafha Saudi Arabia': [29.62, 43.49],
    'Al Majmaah Saudi Arabia': [25.90, 45.35],
    'Hail Saudi Arabia': [27.52, 41.69],
    'Sakakah Al Jouf Saudi Arabia': [29.97, 40.20],
    'Qurayyat Saudi Arabia': [31.33, 37.35],
    'Riyadh Saudi Arabia': [24.71, 46.68],
    'Buraydah Qassim Saudi Arabia': [26.33, 43.97],
    'Hafr Al-Batin Saudi Arabia': [28.43, 46.97],
    'Arar Saudi Arabia': [30.98, 41.04],
    'Turaif Saudi Arabia': [31.68, 38.66],
    'Dammam Saudi Arabia': [26.42, 50.10],
    'Jubail Saudi Arabia': [27.00, 49.66],
    'Madinah Saudi Arabia': [24.47, 39.61],
    'Tabuk Saudi Arabia': [28.38, 36.57],
    // Iraq / Kuwait / Levant cities
    'Baghdad Iraq': [33.31, 44.36],
    'Ramadi Iraq': [33.42, 43.31],
    'Rutba Iraq': [32.04, 39.95],
    'Basra Iraq': [30.51, 47.81],
    'Amman Jordan': [31.95, 35.91],
    'Daraa Syria': [32.62, 36.10],
    'Damascus Syria': [33.51, 36.29],
    'Jericho Palestine': [31.86, 35.46],
    'Ramallah Palestine': [31.90, 35.20],
  };

  LatLng? _stopPosition(_GuideStop stop) {
    final c = _stopCoords[stop.query];
    if (c == null) return null;
    return LatLng(c[0], c[1]);
  }

  // ── Shared stops ────────────────────────────────────────────────────────

  static _GuideStop _stop(
    String en,
    String ar,
    String noteEn,
    String noteAr,
    String query, {
    bool isBorder = false,
  }) =>
      _GuideStop(
        titleEn: en,
        titleAr: ar,
        noteEn: noteEn,
        noteAr: noteAr,
        query: query,
        isBorderCrossing: isBorder,
      );

  /// Entry border into Saudi Arabia per Gulf origin (Iraq bypasses Saudi).
  static List<_GuideStop> _saudiEntryStops(_Country origin) {
    switch (origin) {
      case _Country.qatar:
        return [
          _stop(
            'Salwa border crossing',
            'منفذ سلوى',
            'Border crossing — complete exit and entry procedures.',
            'معبر حدودي — أنجز إجراءات الخروج والدخول.',
            'Salwa Border Crossing Qatar Saudi Arabia',
            isBorder: true,
          ),
        ];
      case _Country.bahrain:
        return [
          _stop(
            'King Fahd Causeway',
            'جسر الملك فهد',
            'Cross the causeway and finish passport procedures.',
            'اعبر الجسر وأنجز إجراءات الجوازات.',
            'King Fahd Causeway Bahrain Saudi Arabia',
            isBorder: true,
          ),
        ];
      case _Country.uae:
        return [
          _stop(
            'Al Ghuwaifat border',
            'منفذ الغويفات',
            'Saudi entry border — arrive with fuel topped up.',
            'منفذ الدخول إلى السعودية — املأ الوقود قبل الوصول.',
            'Al Ghuwaifat Border Crossing UAE Saudi Arabia',
            isBorder: true,
          ),
        ];
      case _Country.kuwait:
        return [
          _stop(
            'Al-Nuqheb border',
            'منفذ النقيب',
            'Saudi entry — the inland crossing leading straight to Hafr Al-Batin.',
            'منفذ الدخول إلى السعودية — المعبر الداخلي المؤدي مباشرة إلى حفر الباطن.',
            'Al Nuqheb Border Crossing Kuwait Saudi Arabia',
            isBorder: true,
          ),
        ];
      default:
        return const [];
    }
  }

  // Saudi cores — start AFTER the entry border. Notes are direction-neutral
  // so the same chains read correctly in both travel directions.
  //
  // ── The PRO/best route: the northern express. This is the alignment
  // Google Maps itself picks as fastest for Gulf → Jordan (Al Ahsa →
  // Qaysumah → Hafr Al-Batin → Rafha → Arar → Turaif → Al Omari).
  static final List<_GuideStop> _coreNorthernExpress = [
    _stop(
      'Al Ahsa / Hofuf',
      'الأحساء / الهفوف',
      'Major services and fuel stop.',
      'منطقة خدمات ووقود رئيسية.',
      'Al Ahsa Hofuf Saudi Arabia',
    ),
    _stop(
      'Qaysumah',
      'القيصومة',
      'Junction town — turn north toward Hafr Al-Batin.',
      'مدينة المفترق — التوجه شمالاً نحو حفر الباطن.',
      'Qaysumah Saudi Arabia',
    ),
    _stop(
      'Hafr Al-Batin',
      'حفر الباطن',
      'Key northern hub with full services.',
      'محطة شمالية رئيسية بخدمات كاملة.',
      'Hafr Al-Batin Saudi Arabia',
    ),
    _stop(
      'Rafha',
      'رفحاء',
      'Fuel and rest stop on the Arar highway.',
      'محطة وقود واستراحة على طريق عرعر.',
      'Rafha Saudi Arabia',
    ),
    _stop(
      'Arar',
      'عرعر',
      'Good stop before the final stretch to the border.',
      'نقطة توقف جيدة قبل المرحلة الأخيرة نحو الحدود.',
      'Arar Saudi Arabia',
    ),
    _stop(
      'Turaif',
      'طريف',
      'Last services before crossing toward Jordan.',
      'آخر نقطة خدمات قبل العبور نحو الأردن.',
      'Turaif Saudi Arabia',
    ),
  ];

  // ── The famous Route 65: Riyadh → Sudair/Majma'ah → Buraydah (Qassim) →
  // Hail → Sakakah → Qurayyat → Al Omari. (This is the highway's real
  // alignment — it does NOT run through Al Ahsa or a Riyadh bypass.)
  static final List<_GuideStop> _coreGolden = [
    _stop(
      'Al Ahsa / Hofuf',
      'الأحساء / الهفوف',
      'Major services and fuel stop.',
      'منطقة خدمات ووقود رئيسية.',
      'Al Ahsa Hofuf Saudi Arabia',
    ),
    _stop(
      'Riyadh',
      'الرياض',
      'Join Highway 65 north from the capital.',
      'الالتحاق بالطريق 65 شمالاً من العاصمة.',
      'Riyadh Saudi Arabia',
    ),
    _stop(
      'Al Majmaah',
      'المجمعة',
      'Sudair stop on Highway 65 northwest of Riyadh.',
      'محطة السدير على الطريق 65 شمال غرب الرياض.',
      'Al Majmaah Saudi Arabia',
    ),
    _stop(
      'Buraydah / Qassim',
      'بريدة / القصيم',
      'Midway rest stop with full services.',
      'نقطة استراحة في منتصف الطريق بخدمات كاملة.',
      'Buraydah Qassim Saudi Arabia',
    ),
    _stop(
      'Hail',
      'حائل',
      'Strong rest or overnight stop on Highway 65.',
      'نقطة مبيت أو استراحة قوية على الطريق 65.',
      'Hail Saudi Arabia',
    ),
    _stop(
      'Al Jouf / Sakakah',
      'الجوف / سكاكا',
      'Full services after the long desert stretch.',
      'خدمات كاملة بعد المقطع الصحراوي الطويل.',
      'Sakakah Al Jouf Saudi Arabia',
    ),
    _stop(
      'Qurayyat',
      'القريات',
      'Full preparation point near the border.',
      'نقطة تجهيز كامل قرب الحدود.',
      'Qurayyat Saudi Arabia',
    ),
  ];

  static final List<_GuideStop> _coreClassic = [
    _stop(
      'Riyadh',
      'الرياض',
      'Passes through the capital — expect city traffic.',
      'يمر عبر العاصمة — توقع ازدحاماً داخلياً.',
      'Riyadh Saudi Arabia',
    ),
    _stop(
      'Buraydah / Qassim',
      'بريدة / القصيم',
      'Midway rest stop with full services.',
      'نقطة استراحة في منتصف الطريق بخدمات كاملة.',
      'Buraydah Qassim Saudi Arabia',
    ),
    _stop(
      'Hail',
      'حائل',
      'Strong rest or overnight stop.',
      'نقطة مبيت أو استراحة قوية.',
      'Hail Saudi Arabia',
    ),
    _stop(
      'Al Jouf / Sakakah',
      'الجوف / سكاكا',
      'Full services after the long desert stretch.',
      'خدمات كاملة بعد المقطع الصحراوي الطويل.',
      'Sakakah Al Jouf Saudi Arabia',
    ),
    _stop(
      'Qurayyat',
      'القريات',
      'Full preparation point near the border.',
      'نقطة تجهيز كامل قرب الحدود.',
      'Qurayyat Saudi Arabia',
    ),
  ];

  static final List<_GuideStop> _coreDirect = [
    _stop(
      'Hafr Al-Batin',
      'حفر الباطن',
      'Key northern hub with full services — bypasses Riyadh.',
      'محطة شمالية رئيسية بخدمات كاملة — تتجاوز الرياض.',
      'Hafr Al-Batin Saudi Arabia',
    ),
    _stop(
      'Arar',
      'عرعر',
      'Good stop before the final stretch to the border.',
      'نقطة توقف جيدة قبل المرحلة الأخيرة نحو الحدود.',
      'Arar Saudi Arabia',
    ),
    _stop(
      'Turaif',
      'طريف',
      'Last services before crossing toward Jordan.',
      'آخر نقطة خدمات قبل العبور نحو الأردن.',
      'Turaif Saudi Arabia',
    ),
  ];

  static final List<_GuideStop> _coreCoastal = [
    _stop(
      'Dammam',
      'الدمام',
      'Coastal city with full services and fuel.',
      'مدينة ساحلية بخدمات ومحطات وقود كاملة.',
      'Dammam Saudi Arabia',
    ),
    _stop(
      'Jubail',
      'الجبيل',
      'Coastal stop before turning inland north.',
      'محطة ساحلية قبل التوجه شمالاً للداخل.',
      'Jubail Saudi Arabia',
    ),
    _stop(
      'Hafr Al-Batin',
      'حفر الباطن',
      'Key northern hub — join the direct northern route.',
      'محطة شمالية رئيسية — الالتحاق بالمسار الشمالي المباشر.',
      'Hafr Al-Batin Saudi Arabia',
    ),
    _stop(
      'Arar',
      'عرعر',
      'Good stop before the final stretch to the border.',
      'نقطة توقف جيدة قبل المرحلة الأخيرة نحو الحدود.',
      'Arar Saudi Arabia',
    ),
  ];

  // ── Exit legs ───────────────────────────────────────────────────────────
  static final List<_GuideStop> _legJordan = [
    _stop(
      'Al Omari border',
      'حدود العمري',
      'Saudi exit / Jordan entry crossing.',
      'منفذ الخروج من السعودية والدخول إلى الأردن.',
      'Al Omari Border Crossing Jordan',
      isBorder: true,
    ),
    _stop(
      'Amman',
      'عمّان',
      'Capital of Jordan — the corridor arrival hub.',
      'عاصمة الأردن — نقطة الوصول الرئيسية للمسار.',
      'Amman Jordan',
    ),
  ];

  static final List<_GuideStop> _legSyria = [
    _stop(
      'Jaber / Nasib border',
      'معبر جابر / نصيب',
      'Jordan exit / Syria entry crossing.',
      'منفذ الخروج من الأردن والدخول إلى سوريا.',
      'Nasib Jaber Border Crossing Jordan Syria',
      isBorder: true,
    ),
    _stop(
      'Daraa',
      'درعا',
      'First Syrian city after the border.',
      'أول مدينة سورية بعد المعبر.',
      'Daraa Syria',
    ),
    _stop(
      'Damascus',
      'دمشق',
      'Capital of Syria — end of the corridor.',
      'عاصمة سوريا — نهاية المسار.',
      'Damascus Syria',
    ),
  ];

  static final List<_GuideStop> _legPalestine = [
    _stop(
      'King Hussein Bridge (Allenby)',
      'جسر الملك حسين (الكرامة)',
      'Jordan exit / Palestine entry crossing.',
      'منفذ الخروج من الأردن والدخول إلى فلسطين.',
      'King Hussein Bridge Allenby Crossing',
      isBorder: true,
    ),
    _stop(
      'Jericho',
      'أريحا',
      'First Palestinian city after the bridge.',
      'أول مدينة فلسطينية بعد الجسر.',
      'Jericho Palestine',
    ),
    _stop(
      'Jerusalem / Ramallah',
      'القدس / رام الله',
      'Central Palestinian hubs — end of the corridor.',
      'المحاور الفلسطينية المركزية — نهاية المسار.',
      'Ramallah Palestine',
    ),
  ];

  // Iraq chains — direct corridors (Saudi Arabia is not on these routes).
  static final List<_GuideStop> _iraqDirectChain = [
    _stop(
      'Baghdad',
      'بغداد',
      'Start of the western desert highway (Route 1).',
      'بداية طريق الصحراء الغربي (الطريق 1).',
      'Baghdad Iraq',
    ),
    _stop(
      'Ramadi',
      'الرمادي',
      'Last major city services before the desert stretch.',
      'آخر خدمات مدينة رئيسية قبل المقطع الصحراوي.',
      'Ramadi Iraq',
    ),
    _stop(
      'Rutba',
      'الرطبة',
      'Fuel and rest stop mid-desert.',
      'محطة وقود واستراحة في منتصف الصحراء.',
      'Rutba Iraq',
    ),
    _stop(
      'Trebil / Al-Karamah border',
      'معبر الطريبيل / الكرامة',
      'Iraq exit / Jordan entry crossing.',
      'منفذ الخروج من العراق والدخول إلى الأردن.',
      'Trebil Al Karamah Border Crossing Iraq Jordan',
      isBorder: true,
    ),
  ];

  static final List<_GuideStop> _iraqSyriaChain = [
    _stop(
      'Baghdad',
      'بغداد',
      'Start of the Baghdad–Damascus international highway.',
      'بداية الطريق الدولي بغداد–دمشق.',
      'Baghdad Iraq',
    ),
    _stop(
      'Ramadi',
      'الرمادي',
      'Last major services before the western desert.',
      'آخر خدمات رئيسية قبل الصحراء الغربية.',
      'Ramadi Iraq',
    ),
    _stop(
      'Al-Tanf border area',
      'منطقة معبر التنف',
      'Direct Iraq–Syria crossing — check its operating status first.',
      'المعبر المباشر بين العراق وسوريا — تحقق من حالته أولاً.',
      'Al Tanf Border Crossing Iraq Syria',
      isBorder: true,
    ),
    _stop(
      'Damascus',
      'دمشق',
      'Capital of Syria — end of the corridor.',
      'عاصمة سوريا — نهاية المسار.',
      'Damascus Syria',
    ),
  ];

  // Kuwait → Syria direct chain — through Iraq. Going via Amman would be a
  // huge detour; this is the natural corridor between the two countries.
  // Starts at the border: the trip itself always begins at the user's live
  // current location (Google Maps origin), never at a fixed city point.
  static final List<_GuideStop> _kuwaitIraqChain = [
    _stop(
      'Abdali border (Kuwait–Iraq)',
      'منفذ العبدلي (الكويت–العراق)',
      'Kuwait exit / Iraq entry crossing.',
      'منفذ الخروج من الكويت والدخول إلى العراق.',
      'Abdali Border Crossing Kuwait Iraq',
      isBorder: true,
    ),
    _stop(
      'Basra',
      'البصرة',
      'First major Iraqi city — last full services in the south.',
      'أول مدينة عراقية رئيسية — آخر خدمات كاملة في الجنوب.',
      'Basra Iraq',
    ),
    _stop(
      'Baghdad',
      'بغداد',
      'Capital — rest and resupply before the western desert.',
      'العاصمة — استراحة وتجهيز قبل الصحراء الغربية.',
      'Baghdad Iraq',
    ),
    _stop(
      'Ramadi',
      'الرمادي',
      'Last major services before the western desert.',
      'آخر خدمات رئيسية قبل الصحراء الغربية.',
      'Ramadi Iraq',
    ),
    _stop(
      'Al-Tanf border',
      'معبر التنف',
      'Iraq exit / Syria entry — check its operating status first.',
      'منفذ الخروج من العراق والدخول إلى سوريا — تحقق من حالته أولاً.',
      'Al Tanf Border Crossing Iraq Syria',
      isBorder: true,
    ),
    _stop(
      'Damascus',
      'دمشق',
      'Capital of Syria — end of the corridor.',
      'عاصمة سوريا — نهاية المسار.',
      'Damascus Syria',
    ),
  ];

  // West Saudi (Hijaz) chain — Makkah/Jeddah/Madinah/Tabuk exit Jordan-ward
  // through the Al-Mudawwara crossing on the Amman–Jeddah highway, NOT via
  // Riyadh or Al Omari.
  static final List<_GuideStop> _westSaudiChain = [
    _stop(
      'Madinah',
      'المدينة المنورة',
      'Main Hijaz hub — fuel and rest on the northern highway.',
      'محور الحجاز الرئيسي — وقود واستراحة على الطريق الشمالي.',
      'Madinah Saudi Arabia',
    ),
    _stop(
      'Tabuk',
      'تبوك',
      'Last major city before the Jordan border.',
      'آخر مدينة رئيسية قبل الحدود الأردنية.',
      'Tabuk Saudi Arabia',
    ),
    _stop(
      'Al Mudawwara border',
      'حدود المضوّرة',
      'Saudi exit / Jordan entry crossing (western crossing).',
      'منفذ الخروج من السعودية والدخول إلى الأردن (المعبر الغربي).',
      'Al Mudawwara Border Crossing Saudi Jordan',
      isBorder: true,
    ),
  ];

  // ── Corridor plan builders ──────────────────────────────────────────────

  static String _countryNameAr(_Country c) => switch (c) {
        _Country.uae => 'الإمارات',
        _Country.qatar => 'قطر',
        _Country.kuwait => 'الكويت',
        _Country.iraq => 'العراق',
        _Country.bahrain => 'البحرين',
        _Country.jordan => 'الأردن',
        _Country.syria => 'سوريا',
        _Country.palestine => 'فلسطين',
        _Country.saudi => 'السعودية',
        _Country.oman => 'عُمان',
        _Country.other => 'وجهتك',
      };

  static String _countryNameEn(_Country c) => switch (c) {
        _Country.uae => 'the UAE',
        _Country.qatar => 'Qatar',
        _Country.kuwait => 'Kuwait',
        _Country.iraq => 'Iraq',
        _Country.bahrain => 'Bahrain',
        _Country.jordan => 'Jordan',
        _Country.syria => 'Syria',
        _Country.palestine => 'Palestine',
        _Country.saudi => 'Saudi Arabia',
        _Country.oman => 'Oman',
        _Country.other => 'your destination',
      };

  /// Curated plans for Gulf → Jordan, stops ordered origin → Amman.
  static List<_RouteGuidePlan> _gulfToJordanCorridor(_Country origin) {
    final entry = _saudiEntryStops(origin);
    final plans = <_RouteGuidePlan>[];

    void add(
      String tEn,
      String tAr,
      String sEn,
      String sAr,
      List<_GuideStop> core,
    ) =>
        plans.add(
          _RouteGuidePlan(
            titleEn: tEn,
            titleAr: tAr,
            summaryEn: sEn,
            summaryAr: sAr,
            stops: [...entry, ...core, ..._legJordan],
          ),
        );

    if (origin == _Country.kuwait) {
      // Kuwait sits right on top of the Saudi northern border — the direct
      // corridor (Al-Nuqheb → Hafr Al-Batin → Arar → Turaif) is by far the
      // closest. Riyadh variants would add 600+ km for nothing, so only
      // northern routes are offered here.
      add(
        'Best route: Northern Direct Route',
        'أفضل مسار: الطريق الشمالي المباشر',
        'The natural Kuwait route: enter at Al-Nuqheb, then Hafr Al-Batin, Arar and Turaif straight to Al Omari border and Amman — the shortest way, no Riyadh detour.',
        'المسار الطبيعي من الكويت: الدخول من النقيب ثم حفر الباطن وعرعر وطريف مباشرة إلى حدود العمري وعمّان — أقصر طريق وبدون المرور بالرياض.',
        _coreDirect,
      );
      plans.add(
        _RouteGuidePlan(
          titleEn: 'Northern Route with rest stop',
          titleAr: 'المسار الشمالي مع استراحة',
          summaryEn:
              'The same direct northern corridor paced with an overnight stop at Arar before the final border stretch.',
          summaryAr:
              'نفس المسار الشمالي المباشر مع مبيت في عرعر قبل المرحلة الأخيرة نحو الحدود.',
          stops: [
            ...entry,
            _coreDirect[0], // Hafr Al-Batin
            _stop(
              'Arar (overnight)',
              'عرعر (مبيت)',
              'Overnight stop — hotels and rest houses near the highway.',
              'مبيت ليلة — فنادق واستراحات قرب الطريق.',
              'Arar Saudi Arabia',
            ),
            _coreDirect[2], // Turaif
            ..._legJordan,
          ],
        ),
      );
      return plans;
    }

    if (origin == _Country.iraq) {
      plans.add(
        _RouteGuidePlan(
          titleEn: 'Best route: Western Desert Highway',
          titleAr: 'أفضل مسار: طريق الصحراء الغربي',
          summaryEn:
              'Direct Iraq–Jordan route: Baghdad, Ramadi, Rutba, then the Trebil/Al-Karamah border straight into Amman.',
          summaryAr:
              'المسار المباشر بين العراق والأردن: بغداد والرمادي والرطبة ثم معبر الطريبيل/الكرامة وصولاً إلى عمّان.',
          // Trebil is the Jordan entry — Al Omari (Saudi border) is NOT on
          // this corridor, so only Amman follows the chain.
          stops: [..._iraqDirectChain, _legJordan[1]],
        ),
      );
      plans.add(
        _RouteGuidePlan(
          titleEn: 'Route with desert overnight stop',
          titleAr: 'مسار مع مبيت صحراوي',
          summaryEn:
              'The same western highway paced with an overnight stop at Rutba before the border — a relaxed two-day drive.',
          summaryAr:
              'نفس الطريق الغربي لكن بإيقاع مريح مع مبيت في الرطبة قبل الحدود — مناسب لرحلة يومين مرتاحة.',
          stops: [
            _iraqDirectChain[0],
            _iraqDirectChain[1],
            _stop(
              'Rutba (overnight)',
              'الرطبة (مبيت)',
              'Overnight stop — hotels and rest houses near the highway.',
              'مبيت ليلة — فنادق واستراحات قرب الطريق.',
              'Rutba Iraq',
            ),
            ..._iraqDirectChain.sublist(3),
            _legJordan[1],
          ],
        ),
      );
      return plans;
    }

    // Qatar / Bahrain / UAE share the entry borders and cores. The PRO
    // route is the genuinely FASTEST one (northern express via Hafr
    // Al-Batin, Rafha & Arar — the alignment Google Maps picks), followed
    // by the famous Route 65 and a coastal/central alternative.
    add(
      'Best route: Northern Express via Arar',
      'أفضل مسار: الطريق السريع الشمالي عبر عرعر',
      'The fastest Gulf–Jordan corridor: Al Ahsa, Qaysumah, Hafr Al-Batin, Rafha and Arar, then Turaif straight to Al Omari border — the alignment Google Maps itself picks as fastest.',
      'أسرع مسار بين الخليج والأردن: الأحساء والقيصومة وحفر الباطن ورفحاء وعرعر ثم طريف مباشرة إلى حدود العمري — نفس المسار الذي يختاره خرائط Google كأسرع طريق.',
      _coreNorthernExpress,
    );
    add(
      'Route 65 Golden Route',
      'طريق 65 الذهبي',
      'The famous Highway 65: Riyadh, Al Majmaah (Sudair), Buraydah in Qassim, then Hail, Al Jouf and Qurayyat to Al Omari border.',
      'الطريق 65 الشهير: الرياض والمجمعة (السدير) وبريدة في القصيم ثم حائل والجوف والقريات وصولاً إلى حدود العمري.',
      _coreGolden,
    );
    add(
      origin == _Country.uae
          ? 'Coastal Route via Dammam'
          : 'Riyadh Classic Route',
      origin == _Country.uae
          ? 'المسار الساحلي عبر الدمام'
          : 'مسار الرياض الكلاسيكي',
      origin == _Country.uae
          ? 'Enter Saudi at Al Ghuwaifat, hug the Gulf coast through Dammam and Jubail, then turn inland via Hafr Al-Batin and Arar to the border.'
          : 'The familiar route through central Riyadh, then north via Qassim, Hail, Al Jouf and Qurayyat to Al Omari border.',
      origin == _Country.uae
          ? 'الدخول من الغويفات ثم محاذاة ساحل الخليج عبر الدمام والجبيل، ثم التوجه داخلياً عبر حفر الباطن وعرعر نحو الحدود.'
          : 'المسار المعروف عبر قلب الرياض، ثم شمالاً عبر القصيم وحائل والجوف والقريات وصولاً إلى حدود العمري.',
      origin == _Country.uae ? _coreCoastal : _coreClassic,
    );
    return plans;
  }

  /// Jordan → Gulf: the same chains reversed, with direction-aware titles.
  static List<_RouteGuidePlan> _jordanToGulfCorridor(_Country dest) {
    final forward = _gulfToJordanCorridor(dest);
    final destAr = _countryNameAr(dest);
    final destEn = _countryNameEn(dest);
    return forward
        .map(
          (p) => _RouteGuidePlan(
            titleEn: '${p.titleEn} to $destEn',
            titleAr: '${p.titleAr} نحو $destAr',
            summaryEn: 'From Amman (Jordan) to $destEn. ${p.summaryEn}',
            summaryAr: 'من عمّان (الأردن) إلى $destAr. ${p.summaryAr}',
            stops: p.stops.reversed.toList(),
          ),
        )
        .toList();
  }

  /// Gulf (or Iraq) → Syria or Palestine. Stops ordered origin → final city:
  ///   • Kuwait → Syria: DIRECT through Iraq (Abdali → Basra → Baghdad →
  ///     Ramadi → Al-Tanf → Damascus) — no Amman transit.
  ///   • Kuwait → Palestine: the northern Saudi core (never via Riyadh),
  ///     then Jordan and the Allenby bridge.
  ///   • Iraq: its own direct chain (no Saudi), then Jordan transit.
  ///   • Qatar / Bahrain / UAE: Saudi cores + Jordan transit.
  static List<_RouteGuidePlan> _gulfToLevantCorridor(
    _Country origin,
    _Country dest,
  ) {
    final destAr = _countryNameAr(dest);
    final destEn = _countryNameEn(dest);
    final leg = dest == _Country.syria ? _legSyria : _legPalestine;

    // Kuwait → Syria: the direct corridor runs straight through Iraq —
    // routing it via Amman would be a detour of hundreds of kilometres.
    if (origin == _Country.kuwait && dest == _Country.syria) {
      return [
        _RouteGuidePlan(
          titleEn: 'Best route: Direct through Iraq',
          titleAr: 'أفضل مسار: مباشر عبر العراق',
          summaryEn:
              'The natural Kuwait–Syria corridor: Abdali border, Basra, Baghdad, Ramadi, then the Al-Tanf crossing straight into Damascus — no Saudi, no Amman detour.',
          summaryAr:
              'المسار الطبيعي بين الكويت وسوريا: منفذ العبدلي ثم البصرة وبغداد والرمادي ثم معبر التنف مباشرة إلى دمشق — بدون السعودية وبدون المرور بعمّان.',
          stops: _kuwaitIraqChain,
        ),
      ];
    }

    // Kuwait → Palestine: the northern Saudi core (closest route), then the
    // Jordan transit and the Allenby bridge. (Palestine is unreachable
    // through Iraq, so the Jordan transit is required here.)
    if (origin == _Country.kuwait) {
      return [
        _RouteGuidePlan(
          titleEn: 'Best route: Northern Route to Palestine',
          titleAr: 'أفضل مسار: الطريق الشمالي إلى فلسطين',
          summaryEn:
              'Enter Saudi at Al-Nuqheb, then Hafr Al-Batin, Arar and Turaif to Al Omari border, Amman, and on to Palestine — the closest corridor, no Riyadh.',
          summaryAr:
              'الدخول من النقيب ثم حفر الباطن وعرعر وطريف إلى حدود العمري وعمّان والمتابعة إلى فلسطين — أقرب مسار وبدون الرياض.',
          stops: [
            ..._saudiEntryStops(origin),
            ..._coreDirect,
            ..._legJordan,
            ...leg,
          ],
        ),
      ];
    }

    // Iraq reaches Jordan directly via the Trebil border — no Saudi core.
    final List<_GuideStop> Function(List<_GuideStop> core) chain =
        origin == _Country.iraq
            ? (core) => [
                ..._iraqDirectChain,
                _legJordan[1], // Amman (Trebil border already in the chain)
                ...leg,
              ]
            : (core) => [
                ..._saudiEntryStops(origin),
                ...core,
                ..._legJordan,
                ...leg,
              ];

    _RouteGuidePlan build(
      String tEn,
      String tAr,
      String sEn,
      String sAr,
      List<_GuideStop> core,
    ) =>
        _RouteGuidePlan(
          titleEn: tEn,
          titleAr: tAr,
          summaryEn: sEn,
          summaryAr: sAr,
          stops: chain(core),
        );

    return [
      build(
        'Best route: Golden Route to $destEn',
        'أفضل مسار: الطريق الذهبي إلى $destAr',
        'Border entry, the comfortable Route 65 core via Hail and Al Jouf, Al Omari border, Amman, then on to $destEn.',
        'الدخول من المنفذ، ثم الطريق الذهبي المريح عبر حائل والجوف، وحدود العمري، وعمّان، ثم المتابعة إلى $destAr.',
        _coreGolden,
      ),
      build(
        'Direct Route via Hafr Al-Batin to $destEn',
        'المسار المباشر عبر حفر الباطن إلى $destAr',
        'Northern route via Hafr Al-Batin, Arar and Turaif, then the border, Amman and on to $destEn — skips Riyadh.',
        'المسار الشمالي عبر حفر الباطن وعرعر وطريف، ثم الحدود وعمّان والمتابعة إلى $destAr — بدون الرياض.',
        _coreDirect,
      ),
    ];
  }

  /// Syria/Palestine → Gulf: reversed Levant corridors.
  static List<_RouteGuidePlan> _levantToGulfCorridor(
    _Country origin,
    _Country dest,
  ) {
    final originAr = _countryNameAr(origin);
    final originEn = _countryNameEn(origin);
    final destAr = _countryNameAr(dest);
    final destEn = _countryNameEn(dest);
    return _gulfToLevantCorridor(dest, origin)
        .map(
          (p) => _RouteGuidePlan(
            titleEn: '${p.titleEn.replaceAll(' to ${_countryNameEn(origin)}', '')} to $destEn',
            titleAr: '${p.titleAr.replaceAll(' إلى $originAr', '')} نحو $destAr',
            summaryEn: 'From $originEn to $destEn. ${p.summaryEn}',
            summaryAr: 'من $originAr إلى $destAr. ${p.summaryAr}',
            stops: p.stops.reversed.toList(),
          ),
        )
        .toList();
  }

  /// Iraq ↔ Syria direct corridor (no Saudi, no Jordan).
  static List<_RouteGuidePlan> _iraqSyriaCorridor(_Country dest) {
    final toSyria = dest == _Country.syria;
    final stopsTo = toSyria
        ? _iraqSyriaChain
        : _iraqSyriaChain.reversed.toList();
    return [
      _RouteGuidePlan(
        titleEn: 'Best route: Baghdad–Damascus Highway',
        titleAr: 'أفضل مسار: طريق بغداد–دمشق',
        summaryEn:
            'Direct Iraq–Syria international highway. The Al-Tanf crossing status can change — verify before departure.',
        summaryAr:
            'الطريق الدولي المباشر بين العراق وسوريا. قد يتغير وضع معبر التنف — تحقق منه قبل الانطلاق.',
        stops: stopsTo,
      ),
    ];
  }

  /// Saudi → Jordan / Syria / Palestine. The variant is chosen by WHERE IN
  /// SAUDI the trip starts — the country is too large for one fixed route:
  ///   • west (Makkah/Jeddah/Madinah/Tabuk): Al-Mudawwara crossing — the
  ///     direct western road to Amman, no Riyadh, no Al Omari.
  ///   • central (Riyadh/Qassim): the classic Qassim–Hail–Qurayyat line.
  ///   • east (Dammam/Hafr Al-Batin): the Hafr Al-Batin northern corridors.
  static List<_RouteGuidePlan> _saudiCorridor(_SaudiRegion region, _Country dest) {
    final toJordan = dest == _Country.jordan;
    final leg = toJordan
        ? _legJordan
        : (dest == _Country.syria ? _legSyria : _legPalestine);
    // For Syria/Palestine the Jordan transit (Al Omari + Amman) is required.
    final List<_GuideStop> transit = toJordan
        ? const []
        : [..._legJordan, ...leg];

    if (region == _SaudiRegion.west) {
      // Mudawwara corridor. For Jordan, Amman follows the border directly —
      // Al Omari (the north-eastern crossing) is not on this road.
      final stops = [
        ..._westSaudiChain,
        _legJordan[1], // Amman
        if (!toJordan) ...leg,
      ];
      return [
        _RouteGuidePlan(
          titleEn: 'Best route: Al-Mudawwara Route (West)',
          titleAr: 'أفضل مسار: طريق المضوّرة (الغرب)',
          summaryEn:
              'The direct western road: Madinah, Tabuk, then the Al-Mudawwara crossing into Jordan — much closer than crossing via Qurayyat or Riyadh.',
          summaryAr:
              'الطريق الغربي المباشر: المدينة المنورة وتبوك ثم معبر المضوّرة إلى الأردن — أقرب بكثير من المرور عبر القريات أو الرياض.',
          stops: stops,
        ),
      ];
    }

    if (region == _SaudiRegion.east) {
      return [
        _RouteGuidePlan(
          titleEn: 'Best route: Hafr Al-Batin Route (East)',
          titleAr: 'أفضل مسار: طريق حفر الباطن (الشرق)',
          summaryEn:
              'From the Eastern Province north via Hafr Al-Batin and Al-Jouf to Al Omari border — the closest line to Jordan.',
          summaryAr:
              'من المنطقة الشرقية شمالاً عبر حفر الباطن والجوف إلى حدود العمري — أقرب خط إلى الأردن.',
          stops: [
            _coreDirect[0], // Hafr Al-Batin
            _coreGolden[3], // Sakakah / Al Jouf
            _coreGolden[4], // Qurayyat
            ..._legJordan,
            ...transit,
          ],
        ),
        _RouteGuidePlan(
          titleEn: 'Northern Route via Arar',
          titleAr: 'المسار الشمالي عبر عرعر',
          summaryEn:
              'Hafr Al-Batin, then the Arar–Turaif desert highway before joining the border road to Jordan.',
          summaryAr:
              'حفر الباطن ثم طريق عرعر–طريف الصحراوي قبل الالتحاق بطريق الحدود نحو الأردن.',
          stops: [..._coreDirect, ..._legJordan, ...transit],
        ),
      ];
    }

    // Central — Riyadh / Qassim: the classic corridor.
    return [
      _RouteGuidePlan(
        titleEn: 'Best route: Qassim–Hail Route (Central)',
        titleAr: 'أفضل مسار: طريق القصيم وحائل (الوسط)',
        summaryEn:
            'The classic central corridor: Riyadh or Qassim, then Hail, Al Jouf and Qurayyat to Al Omari border.',
        summaryAr:
            'المسار الوسطي الكلاسيكي: الرياض أو القصيم ثم حائل والجوف والقريات إلى حدود العمري.',
        stops: [..._coreClassic, ..._legJordan, ...transit],
      ),
      _RouteGuidePlan(
        titleEn: 'Route 65 Golden Route',
        titleAr: 'طريق 65 الذهبي',
        summaryEn:
            'The comfortable Route 65 line via the Riyadh bypass, Hail and Al Jouf to the border.',
        summaryAr:
            'خط طريق 65 المريح عبر الالتفاف حول الرياض وحائل والجوف إلى الحدود.',
        stops: [..._coreGolden, ..._legJordan, ...transit],
      ),
    ];
  }

  /// Reverse (Jordan/Syria/Palestine → Saudi): the same region chains
  /// reversed — the Saudi-side region is picked from the Saudi DESTINATION.
  static List<_RouteGuidePlan> _saudiReverseCorridor(
    _SaudiRegion region,
    _Country origin,
  ) {
    final originAr = _countryNameAr(origin);
    final originEn = _countryNameEn(origin);
    return _saudiCorridor(region, origin)
        .map(
          (p) => _RouteGuidePlan(
            titleEn: '${p.titleEn} to Saudi Arabia',
            titleAr: '${p.titleAr} إلى السعودية',
            summaryEn: 'From $originEn into Saudi Arabia. ${p.summaryEn}',
            summaryAr: 'من $originAr إلى السعودية. ${p.summaryAr}',
            stops: p.stops.reversed.toList(),
          ),
        )
        .toList();
  }

  /// Resolves the curated plan set for the current trip, or an empty list
  /// when the trip is outside every known corridor (generic live routes
  /// are used instead — so all countries remain covered).
  ///
  /// The corridor is LOCKED to the trip: it is decided by where the trip
  /// STARTED and never re-evaluated from the driver's live position.
  /// Driving UAE → Jordan means entering Saudi Arabia mid-trip — without
  /// the lock the origin country would flip to Saudi and the selected
  /// route cards would swap while driving.
  List<_RouteGuidePlan> _curatedGuidePlans(AppDataProvider provider) {
    final dest = _destinationCountry(provider);

    // Adopt the corridor persisted from a previous session (app restart
    // mid-trip) — only when the destination is still the same trip.
    if (_lockedCorridorKey == null &&
        _savedCorridorKey != null &&
        _savedDestCountry == dest.name) {
      _lockedCorridorKey = _savedCorridorKey;
    }

    // Lock the corridor once, on the first resolution of this trip.
    _lockedCorridorKey ??= () {
      final key = _corridorKey(provider, _originCountry(provider), dest);
      if (key != null) _persistState();
      return key;
    }();

    final key = _lockedCorridorKey;
    if (key == null) return const [];
    _activeCorridorKey = key;
    return _corridorPlansForKey(key);
  }

  String? _activeCorridorKey;

  /// The corridor locked for the current trip (never changes while
  /// driving through intermediate countries).
  String? _lockedCorridorKey;

  /// Destination country the saved corridor/selection belongs to.
  String? _savedDestCountry;

  String? _corridorKey(
    AppDataProvider provider,
    _Country origin,
    _Country dest,
  ) {
    const jordan = _Country.jordan;
    const saudi = _Country.saudi;
    final levantOrigin = _levantCountriesContains(origin);
    final levantDest = _levantCountriesContains(dest);

    // Saudi is region-aware — the key embeds WHICH part of Saudi the trip
    // starts from (or heads to), because the best corridor differs.
    if (origin == saudi && (dest == jordan || levantDest)) {
      return 'saudi-${_saudiRegionFor(provider).name}-${dest.name}';
    }
    if (dest == saudi && (origin == jordan || levantOrigin)) {
      return '${origin.name}-saudi-${_saudiRegionFor(provider).name}';
    }

    // Direct Iraq ↔ Syria corridor (checked first — Iraq is also in the
    // Gulf set, and this corridor skips both Saudi and Jordan).
    if (origin == _Country.iraq && dest == _Country.syria) {
      return 'iraq-syria';
    }
    if (origin == _Country.syria && dest == _Country.iraq) {
      return 'syria-iraq';
    }
    // Keys are built purely from enum names so [_corridorPlansForKey] can
    // look both parts back up by name.
    if (_gulfCountries.contains(origin) && dest == jordan) {
      return '${origin.name}-${jordan.name}';
    }
    if (origin == jordan && _gulfCountries.contains(dest)) {
      return '${jordan.name}-${dest.name}';
    }
    if (_gulfCountries.contains(origin) && levantDest) {
      return '${origin.name}-${dest.name}';
    }
    if (levantOrigin && _gulfCountries.contains(dest)) {
      return '${origin.name}-${dest.name}';
    }
    return null;
  }

  static bool _levantCountriesContains(_Country c) =>
      c == _Country.syria || c == _Country.palestine;

  List<_RouteGuidePlan> _corridorPlansForKey(String key) {
    // Cache composed corridors so the same list instance is reused across
    // rebuilds (keeps card identity stable and avoids rebuilding data).
    return _corridorCache.putIfAbsent(key, () {
      final parts = key.split('-');

      // Saudi keys carry a region: 'saudi-west-jordan' or 'jordan-saudi-west'
      if (parts.length == 3 && parts[0] == 'saudi') {
        final region = _SaudiRegion.values.firstWhere(
          (r) => r.name == parts[1],
          orElse: () => _SaudiRegion.central,
        );
        final b = _Country.values.firstWhere(
          (c) => c.name == parts[2],
          orElse: () => _Country.other,
        );
        return _saudiCorridor(region, b);
      }
      if (parts.length == 3 && parts[1] == 'saudi') {
        final a = _Country.values.firstWhere(
          (c) => c.name == parts[0],
          orElse: () => _Country.other,
        );
        final region = _SaudiRegion.values.firstWhere(
          (r) => r.name == parts[2],
          orElse: () => _SaudiRegion.central,
        );
        return _saudiReverseCorridor(region, a);
      }

      final a = _Country.values.firstWhere(
        (c) => c.name == parts[0],
        orElse: () => _Country.other,
      );
      final b = _Country.values.firstWhere(
        (c) => c.name == parts[1],
        orElse: () => _Country.other,
      );
      if (b == _Country.jordan) return _gulfToJordanCorridor(a);
      if (a == _Country.jordan) return _jordanToGulfCorridor(b);
      if (a == _Country.iraq && b == _Country.syria) {
        return _iraqSyriaCorridor(_Country.syria);
      }
      if (a == _Country.syria && b == _Country.iraq) {
        return _iraqSyriaCorridor(_Country.iraq);
      }
      if (_gulfCountries.contains(a) && _levantCountriesContains(b)) {
        return _gulfToLevantCorridor(a, b);
      }
      if (_levantCountriesContains(a) && _gulfCountries.contains(b)) {
        return _levantToGulfCorridor(a, b);
      }
      return const [];
    });
  }

  final Map<String, List<_RouteGuidePlan>> _corridorCache = {};

  @override
  void initState() {
    super.initState();
    _restoreSavedState();
    _maybeInitRoute();
  }

  /// Restores the persisted Routes-screen state (transport mode + selected
  /// route card + the trip's corridor) so the screen looks exactly like the
  /// user left it — even mid-trip after an app restart.
  void _restoreSavedState() {
    final prefs = _cache.loadMapPrefs();
    if (prefs == null) return;
    final mode = (prefs['transportMode'] as num?)?.toInt() ?? 0;
    _selectedTransportMode = mode.clamp(0, 3);
    _savedCorridorKey = prefs['corridor'] as String?;
    _savedDestCountry = prefs['destCountry'] as String?;
    final route = (prefs['selectedRoute'] as num?)?.toInt();
    if (route != null && route >= 0) {
      _pendingSavedRouteIndex = route;
    }
  }

  int? _pendingSavedRouteIndex;

  /// Applies the persisted route-card selection once the corridor plans for
  /// this trip are known (only if the saved corridor still matches). Runs
  /// after the current frame — never calls setState during build.
  void _applySavedRouteSelection(List<_RouteOption> options) {
    if (_pendingSavedRouteIndex == null) return;
    final idx = _pendingSavedRouteIndex!;
    _pendingSavedRouteIndex = null;
    if (_savedCorridorKey != null && _savedCorridorKey != _activeCorridorKey) {
      return;
    }
    if (idx < options.length && idx != _selectedRouteIndex && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedRouteIndex = idx);
        }
      });
    }
  }

  /// Persists the current screen state (including the locked corridor and
  /// the trip's destination country, so a mid-trip app restart restores
  /// the exact same route selection instead of re-detecting the country
  /// the driver happens to be in right now).
  Future<void> _persistState() async {
    await _cache.saveMapPrefs({
      'transportMode': _selectedTransportMode,
      'selectedRoute': _selectedRouteIndex,
      'corridor': _activeCorridorKey ?? _lockedCorridorKey,
      'destCountry': _destinationCountry(AppDataProvider.instance).name,
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _periodicRerouteTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndRoute() async {
    final provider = AppDataProvider.instance;
    await _loadRoute(initial: true);

    if (!provider.isManualLocation) {
      final started = await _locationService.startTracking(
        distanceFilterMeters: 8,
      );
      if (started) {
        _locationSubscription = _locationService.locationStream.listen(
          _onLocationUpdate,
        );
      }
    }

    _periodicRerouteTimer = Timer.periodic(_rerouteInterval, (_) {
      _maybeReroute(force: false);
    });
  }

  void _maybeInitRoute() {
    final provider = AppDataProvider.instance;
    if (_routeSetupStarted || !provider.hasChosenDestination) return;
    _routeSetupStarted = true;
    _initLocationAndRoute();
  }

  void _onLocationUpdate(LocationData data) {
    if (!mounted) return;
    final newLatLng = LatLng(data.latitude, data.longitude);
    setState(() {
      _liveLocation = newLatLng;
      _currentSpeed = data.speedKmh;
      _heading = data.heading;
    });

    // The FlutterMap only exists inside the modal bottom sheet. Touching
    // the MapController before it has rendered at least once throws —
    // so follow-me only runs while the map is actually on screen.
    if (_followMe && _mapModalOpen) {
      try {
        _mapController.move(newLatLng, _mapController.camera.zoom);
      } catch (_) {
        // Map not ready yet — skip this follow-me tick.
      }
    }
    _maybeReroute(force: false, currentPosition: newLatLng);
  }

  void _maybeReroute({required bool force, LatLng? currentPosition}) {
    if (_isFetchingRoute) return;
    final provider = AppDataProvider.instance;
    final position = currentPosition ?? _resolveCurrentLocation(provider);
    if (position == null) return;

    final elapsedEnough =
        _lastRouteFetch == null ||
            DateTime.now().difference(_lastRouteFetch!) >= _rerouteInterval;
    final driftedOff =
        _routeData != null &&
            _routeData!.distanceFromRoute(position) > _rerouteDeviationMeters;

    if (force || driftedOff || (elapsedEnough && _routeData != null)) {
      _loadRoute();
    }
  }

  LatLng? _resolveCurrentLocation(AppDataProvider provider) {
    if (_liveLocation != null) return _liveLocation;
    if (provider.location != null) {
      return LatLng(provider.location!.latitude, provider.location!.longitude);
    }
    if (provider.isManualLocation &&
        provider.manualLat != null &&
        provider.manualLon != null) {
      return LatLng(provider.manualLat!, provider.manualLon!);
    }
    return null;
  }

  Future<void> _loadRoute({bool initial = false}) async {
    final provider = AppDataProvider.instance;
    final currentLocation = _resolveCurrentLocation(provider);
    if (currentLocation == null) return;

    final destinationLocation = LatLng(
      provider.destinationLat,
      provider.destinationLon,
    );

    // ── Landmass sanity check ──
    // Trips between disconnected landmasses (e.g. New York → Amman) can
    // never be driven — Google Maps refuses them too. Detect this
    // client-side so the "no route" message shows INSTANTLY and the
    // misleading straight-line "estimate" cards never appear, even when
    // the routing service is unreachable.
    if (_landmassOf(currentLocation.latitude, currentLocation.longitude) !=
        _landmassOf(
          destinationLocation.latitude,
          destinationLocation.longitude,
        )) {
      if (mounted) setState(() => _noRouteFound = true);
      return;
    }

    if (initial) {
      final cachedRoute = _cache.loadRoute();
      if (cachedRoute != null &&
          _routeMatchesEndpoints(
            cachedRoute,
            currentLocation,
            destinationLocation,
          ) &&
          mounted) {
        setState(() {
          _routeData = cachedRoute;
          _routeAlternatives = [cachedRoute];
          _routeOrigin = currentLocation;
          _routeDestination = destinationLocation;
        });
      }
    }

    _isFetchingRoute = true;
    final routes = await _routingService.getRoutes(
      currentLocation,
      destinationLocation,
    );
    _isFetchingRoute = false;
    _lastRouteFetch = DateTime.now();

    if (!mounted) return;

    if (routes.isNotEmpty) {
      final rankedRoutes = _rankRoutes(routes);
      final route = rankedRoutes.first;
      await _cache.saveRoute(route);
      setState(() {
        _noRouteFound = false;
        _routeData = route;
        _routeAlternatives = rankedRoutes;
        _routeOrigin = currentLocation;
        _routeDestination = destinationLocation;
      });
      return;
    }

    // The router explicitly answered that no drivable route exists between
    // these points (e.g. UAE → New York). Show the "no route" message
    // instead of a meaningless straight-line fallback.
    if (_routingService.lastStatus == RoutingStatus.noRoute) {
      setState(() => _noRouteFound = true);
      return;
    }

    if (_routeData == null) {
      final cachedRoute = _cache.loadRoute();
      final matchingCachedRoute =
      cachedRoute != null &&
          _routeMatchesEndpoints(
            cachedRoute,
            currentLocation,
            destinationLocation,
          )
          ? cachedRoute
          : null;
      final fallbackRoute =
          matchingCachedRoute ??
              _buildStraightLineRoute(currentLocation, destinationLocation);
      setState(() {
        _routeData = fallbackRoute;
        _routeAlternatives = [fallbackRoute];
        _routeOrigin = currentLocation;
        _routeDestination = destinationLocation;
      });
    }
  }

  RouteData _buildStraightLineRoute(LatLng origin, LatLng destination) {
    final distance = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    return RouteData(
      points: [origin, destination],
      instructions: [
        TurnInstruction(
          instruction: 'Offline route preview (${_formatDistance(distance)})',
          distance: distance,
          position: origin,
        ),
      ],
      totalDistance: distance,
      estimatedDuration: distance / 22.22,
    );
  }

  bool _routeMatchesEndpoints(
      RouteData route,
      LatLng origin,
      LatLng destination,
      ) {
    if (route.points.length < 2) return false;
    final startDistance = Geolocator.distanceBetween(
      route.points.first.latitude,
      route.points.first.longitude,
      origin.latitude,
      origin.longitude,
    );
    final endDistance = Geolocator.distanceBetween(
      route.points.last.latitude,
      route.points.last.longitude,
      destination.latitude,
      destination.longitude,
    );
    return startDistance < 1500 && endDistance < 1500;
  }

  List<RouteData> _rankRoutes(List<RouteData> routes) {
    final ranked = _dedupeRoutes(routes);
    if (ranked.length < 2) return ranked;

    final fastest = ranked
        .map((route) => route.estimatedDuration)
        .reduce((a, b) => a < b ? a : b);
    final shortest = ranked
        .map((route) => route.totalDistance)
        .reduce((a, b) => a < b ? a : b);

    ranked.sort((a, b) {
      final aScore =
          (a.estimatedDuration / fastest * 0.62) +
              (a.totalDistance / shortest * 0.28) +
              (a.instructions.length * 0.01);
      final bScore =
          (b.estimatedDuration / fastest * 0.62) +
              (b.totalDistance / shortest * 0.28) +
              (b.instructions.length * 0.01);
      return aScore.compareTo(bScore);
    });
    return ranked;
  }

  List<RouteData> _dedupeRoutes(List<RouteData> routes) {
    final unique = <RouteData>[];
    for (final route in routes) {
      final duplicate = unique.any((existing) {
        final distanceDelta =
            (existing.totalDistance - route.totalDistance).abs();
        final durationDelta =
            (existing.estimatedDuration - route.estimatedDuration).abs();
        final similarTotals =
            distanceDelta < 1500 && durationDelta < 180;

        if (similarTotals) return true;
        if (existing.points.isEmpty || route.points.isEmpty) return false;

        final sampleA = existing.points[existing.points.length ~/ 2];
        final sampleB = route.points[route.points.length ~/ 2];
        final midpointDelta = Geolocator.distanceBetween(
          sampleA.latitude,
          sampleA.longitude,
          sampleB.latitude,
          sampleB.longitude,
        );
        return midpointDelta < 1200 && distanceDelta < 5000;
      });
      if (!duplicate) unique.add(route);
    }
    return unique;
  }

  // ── Premium gating for route cards ──────────────────────────────────────
  // The BEST route (first card) is premium-only whenever there is more than
  // one option: 1 route → all free; 2 → 1 pro + 1 free; 3 → 1 pro + 2 free…
  bool _isRouteLocked(int index, int total) =>
      index == 0 && total > 1 && !AppDataProvider.instance.isSubscribed;

  /// The route index actually used for guidance/navigation: when the user's
  /// selection is the locked premium route, everything falls back to the
  /// best FREE route instead.
  int _effectiveRouteIndex(int total) {
    if (_selectedRouteIndex == 0 && _isRouteLocked(0, total) && total > 1) {
      return 1;
    }
    return _selectedRouteIndex.clamp(0, total - 1);
  }

  /// The single curated plan matching the user's current selection.
  _RouteGuidePlan? _curatedGuidePlan(AppDataProvider provider) {
    final plans = _curatedGuidePlans(provider);
    if (plans.isEmpty) return null;
    final idx = _effectiveRouteIndex(plans.length);
    return plans[idx];
  }

  /// Stations to actually NAVIGATE through: everything up to and including
  /// the LAST border crossing of the corridor — the entry into the
  /// destination country. After that border Google Maps routes normally to
  /// the destination city with no stations, so the route never detours
  /// through corridor cities that aren't on the way (e.g. UAE → Aqaba must
  /// NOT be forced through Amman).
  ///
  /// Leading stations that sit BEHIND the user are also dropped, so the
  /// route starts at the station closest to them and never moves backwards
  /// (critical inside Saudi Arabia, where the corridor differs completely
  /// between Makkah, Riyadh and Dammam starts).
  List<_GuideStop> _navigationStops(_RouteGuidePlan plan, LatLng? user) {
    var stops = plan.stops;

    var lastBorder = -1;
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].isBorderCrossing) lastBorder = i;
    }
    if (lastBorder >= 0) stops = stops.sublist(0, lastBorder + 1);

    return _trimStopsToNearest(stops, user);
  }

  /// Drops leading stations that would force a backwards detour: a station
  /// is kept only if reaching it is (nearly) on the way to the corridor's
  /// destination-entry border.
  List<_GuideStop> _trimStopsToNearest(List<_GuideStop> stops, LatLng? user) {
    if (user == null || stops.isEmpty) return stops;

    LatLng? anchor;
    for (final s in stops) {
      if (s.isBorderCrossing) anchor = _stopPosition(s);
    }
    anchor ??= _stopPosition(stops.last);
    if (anchor == null) return stops;

    double d(LatLng a, LatLng b) => Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        );

    final direct = d(user, anchor);
    var list = stops;
    while (list.length > 1) {
      final firstPos = _stopPosition(list.first);
      if (firstPos == null) break;
      final via = d(user, firstPos) + d(firstPos, anchor);
      // Keep the station only when going through it adds no meaningful
      // detour compared to heading to the border directly.
      if (via <= direct * 1.15 + 15000) break;
      list = list.sublist(1);
    }
    return list;
  }

  /// Launches Google Maps with origin, destination, the selected travel
  /// mode, and — when a curated guide is active — the corridor stations as
  /// waypoints UP TO the destination country's entry border. After that
  /// border Google Maps routes normally (no stations) straight to the
  /// destination city. Google's URL API accepts up to 9 waypoints.
  Future<void> _launchGoogleMapsRoute() async {
    final provider = AppDataProvider.instance;
    final loc = _resolveCurrentLocation(provider);
    final origin = loc != null ? '${loc.latitude},${loc.longitude}' : '';
    final destLat = provider.destinationLat;
    final destLon = provider.destinationLon;
    final destination = '$destLat,$destLon';
    final guidePlan = _curatedGuidePlan(provider);

    final modeStr = switch (_selectedTransportMode) {
      1 => 'two-wheeler',
      2 => 'walking',
      3 => 'bicycling',
      _ => 'driving',
    };

    final waypoints = guidePlan == null
        ? ''
        : _navigationStops(guidePlan, loc)
            .map((s) => s.query)
            .take(9)
            .join('|');

    final uri = origin.isNotEmpty
        ? Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'origin': origin,
            'destination': destination,
            'travelmode': modeStr,
            if (waypoints.isNotEmpty) 'waypoints': waypoints,
          })
        : Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': destination,
          });

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch Google Maps: $e');
    }
  }

  /// Generates distinct intermediate points for Route 0, Route 1, and Route 2
  /// so that each selected route shows a visually distinct line on the map.
  List<LatLng> _getDistinctRoutePoints(
      LatLng start,
      LatLng end,
      int routeIndex,
      ) {
    final points = <LatLng>[start];

    final dLat = end.latitude - start.latitude;
    final dLon = end.longitude - start.longitude;
    final midLat = (start.latitude + end.latitude) / 2;
    final midLon = (start.longitude + end.longitude) / 2;

    if (routeIndex == 0) {
      // Route 0: Main Expressway (Slight curve right)
      points.add(
        LatLng(
          start.latitude + dLat * 0.3,
          start.longitude + dLon * 0.25 + 0.08,
        ),
      );
      points.add(LatLng(midLat + 0.04, midLon + 0.12));
      points.add(
        LatLng(
          start.latitude + dLat * 0.75,
          start.longitude + dLon * 0.7 + 0.06,
        ),
      );
    } else if (routeIndex == 1) {
      // Route 1: Direct Bypass (Slight curve left)
      points.add(
        LatLng(
          start.latitude + dLat * 0.25,
          start.longitude + dLon * 0.2 - 0.07,
        ),
      );
      points.add(LatLng(midLat - 0.04, midLon - 0.09));
      points.add(
        LatLng(
          start.latitude + dLat * 0.8,
          start.longitude + dLon * 0.8 - 0.05,
        ),
      );
    } else if (routeIndex == 2) {
      // Route 2: Scenic Secondary Road (Wider curve)
      points.add(
        LatLng(
          start.latitude + dLat * 0.2,
          start.longitude + dLon * 0.15 + 0.15,
        ),
      );
      points.add(LatLng(midLat + 0.1, midLon - 0.1));
      points.add(
        LatLng(
          start.latitude + dLat * 0.65,
          start.longitude + dLon * 0.6 + 0.12,
        ),
      );
    } else {
      // Route 3: Alternative Corridor (Opposite wide curve)
      points.add(
        LatLng(
          start.latitude + dLat * 0.22,
          start.longitude + dLon * 0.18 - 0.14,
        ),
      );
      points.add(LatLng(midLat - 0.09, midLon + 0.11));
      points.add(
        LatLng(
          start.latitude + dLat * 0.7,
          start.longitude + dLon * 0.65 - 0.1,
        ),
      );
    }

    points.add(end);
    return points;
  }

  String _formatDynamicDistance(double meters, bool isAr) {
    final p = AppDataProvider.instance;
    if (meters >= 1000) {
      final km = meters / 1000;
      final val = p.nfd(km, decimals: km >= 100 ? 0 : 1);
      return isAr ? '$val كم' : '$val km';
    }
    final m = p.nfw(meters);
    return isAr ? '$m م' : '$m m';
  }

  String _formatDynamicDuration(double seconds, bool isAr) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      final m = AppDataProvider.instance.nfi(minutes);
      return isAr ? '$m د' : '$m min';
    }
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    final h = AppDataProvider.instance.nfi(hours);
    final m = AppDataProvider.instance.nfi(remMinutes);
    if (remMinutes == 0) {
      return isAr ? '$h س' : '${hours}h';
    }
    return isAr ? '$h س $m د' : '${hours}h ${remMinutes}m';
  }

  /// Computes 3 completely distinct route options dynamically based on the REAL
  /// distance and duration between the user's location and their selected destination!
  List<_RouteOption> _computeDynamicRoutes(BuildContext context, bool isAr) {
    final provider = AppDataProvider.instance;
    final currentLocation = _resolveCurrentLocation(provider);
    final destinationLocation = LatLng(
      provider.destinationLat,
      provider.destinationLon,
    );

    if (currentLocation == null) {
      final pendingDistance = isAr ? '--- ÙƒÙ…' : '-- km';
      final pendingDuration = isAr ? '---' : '--';
      return [
        _RouteOption(
          badgeTextAr: 'Ø§Ù„Ø£Ø³Ù‡Ù„ ÙˆØ§Ù„Ø£ÙØ¶Ù„',
          badgeTextEn: 'Easiest & Best',
          badgeColor: const Color(0xFF6C63E5),
          lineColor: const Color(0xFF8B5CF6),
          durationAr: pendingDuration,
          durationEn: pendingDuration,
          distanceAr: pendingDistance,
          distanceEn: pendingDistance,
          descriptionAr: 'Ø¬Ø§Ø±ÙŠ ØªØ­Ø¯ÙŠØ¯ Ù…ÙˆÙ‚Ø¹Ùƒ',
          descriptionEn: 'Locating your current position',
          trafficAr: 'Ø³ÙŠØªÙ… ØªØ­Ø¯ÙŠØ« Ø§Ù„Ù…Ø³Ø§Ø± ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹',
          trafficEn: 'Route will update automatically',
        ),
        _RouteOption(
          badgeTextAr: 'Ø£Ø³Ø±Ø¹ ÙˆÙ‚Øª',
          badgeTextEn: 'Fastest Time',
          badgeColor: const Color(0xFF3B82F6),
          lineColor: const Color(0xFF3B82F6),
          durationAr: pendingDuration,
          durationEn: pendingDuration,
          distanceAr: pendingDistance,
          distanceEn: pendingDistance,
          descriptionAr: 'Ø¬Ø§Ø±ÙŠ ØªØ­Ø¯ÙŠØ¯ Ù…ÙˆÙ‚Ø¹Ùƒ',
          descriptionEn: 'Locating your current position',
          trafficAr: 'Ø³ÙŠØªÙ… ØªØ­Ø¯ÙŠØ« Ø§Ù„Ù…Ø³Ø§Ø± ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹',
          trafficEn: 'Route will update automatically',
        ),
        _RouteOption(
          badgeTextAr: 'Ø£ÙˆÙØ± ÙˆÙ‚ÙˆØ¯',
          badgeTextEn: 'Fuel Saver',
          badgeColor: const Color(0xFF10B981),
          lineColor: const Color(0xFF10B981),
          durationAr: pendingDuration,
          durationEn: pendingDuration,
          distanceAr: pendingDistance,
          distanceEn: pendingDistance,
          descriptionAr: 'Ø¬Ø§Ø±ÙŠ ØªØ­Ø¯ÙŠØ¯ Ù…ÙˆÙ‚Ø¹Ùƒ',
          descriptionEn: 'Locating your current position',
          trafficAr: 'Ø³ÙŠØªÙ… ØªØ­Ø¯ÙŠØ« Ø§Ù„Ù…Ø³Ø§Ø± ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹',
          trafficEn: 'Route will update automatically',
        ),
        _RouteOption(
          badgeTextAr: 'Ù…Ø³Ø§Ø± Ø¨Ø¯ÙŠÙ„',
          badgeTextEn: 'Alternative',
          badgeColor: const Color(0xFFF59E0B),
          lineColor: const Color(0xFFF59E0B),
          durationAr: pendingDuration,
          durationEn: pendingDuration,
          distanceAr: pendingDistance,
          distanceEn: pendingDistance,
          descriptionAr: 'Ø¬Ø§Ø±ÙŠ ØªØ­Ø¯ÙŠØ¯ Ù…ÙˆÙ‚Ø¹Ùƒ',
          descriptionEn: 'Locating your current position',
          trafficAr: 'Ø³ÙŠØªÙ… ØªØ­Ø¯ÙŠØ« Ø§Ù„Ù…Ø³Ø§Ø± ØªÙ„Ù‚Ø§Ø¦ÙŠØ§Ù‹',
          trafficEn: 'Route will update automatically',
        ),
      ];
    }
    final hasCurrentRoute =
        _routeData != null &&
            _routeOrigin != null &&
            _routeDestination != null &&
            Geolocator.distanceBetween(
              _routeOrigin!.latitude,
              _routeOrigin!.longitude,
              currentLocation.latitude,
              currentLocation.longitude,
            ) <
                1500 &&
            Geolocator.distanceBetween(
              _routeDestination!.latitude,
              _routeDestination!.longitude,
              destinationLocation.latitude,
              destinationLocation.longitude,
            ) <
                1500;

    final baseDistance = hasCurrentRoute
        ? _routeData!.totalDistance
        : Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      destinationLocation.latitude,
      destinationLocation.longitude,
    ) *
        1.3;
    final baseDuration = hasCurrentRoute
        ? _routeData!.estimatedDuration
        : (baseDistance / (80 * 1000 / 3600));

    // Colors and traffic labels shared by both curated and generic route
    // sets, indexed by route slot (0..3).
    const badgeColors = [
      Color(0xFF6C63E5),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    const lineColors = [
      Color(0xFF8B5CF6),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    const trafficAr = [
      'حركة مرور خفيفة',
      'حركة مرور متوسطة',
      'حركة مرور خفيفة جداً',
      'حركة مرور متغيرة',
    ];
    const trafficEn = [
      'Light Traffic',
      'Moderate Traffic',
      'Very Light Traffic',
      'Variable Traffic',
    ];

    // A curated corridor (e.g. Gulf -> Jordan) gives us 4 real, named route
    // strategies with known waypoints. Any other destination falls back to
    // whatever real alternative routes the routing service returned, so
    // every destination still gets the best available plan to get there.
    final curatedPlans = _curatedGuidePlans(provider);
    if (curatedPlans.isNotEmpty) {
      // Distribute the best-known real total across the curated legs with
      // gentle variance so each plan still reflects genuine trip scale.
      final variance = [1.0, 0.95, 0.9, 1.08];
      return List.generate(curatedPlans.length, (i) {
        final plan = curatedPlans[i];
        final routeForSlot = hasCurrentRoute && i < _routeAlternatives.length
            ? _routeAlternatives[i]
            : null;
        final dist =
            routeForSlot?.totalDistance ?? (baseDistance * variance[i]);
        final durSec =
            routeForSlot?.estimatedDuration ?? (baseDuration * variance[i]);
        return _RouteOption(
          badgeTextAr: plan.titleAr,
          badgeTextEn: plan.titleEn,
          badgeColor: badgeColors[i % badgeColors.length],
          lineColor: lineColors[i % lineColors.length],
          durationAr: _formatDynamicDuration(durSec, true),
          durationEn: _formatDynamicDuration(durSec, false),
          distanceAr: _formatDynamicDistance(dist, true),
          distanceEn: _formatDynamicDistance(dist, false),
          descriptionAr: plan.summaryAr,
          descriptionEn: plan.summaryEn,
          trafficAr: trafficAr[i % trafficAr.length],
          trafficEn: trafficEn[i % trafficEn.length],
        );
      });
    }

    final genericBadgeTextAr = [
      'الأسهل والأفضل',
      'أسرع وقت',
      'أوفر وقود',
      'مسار بديل',
    ];
    final genericBadgeTextEn = [
      'Easiest & Best',
      'Fastest Time',
      'Fuel Saver',
      'Alternative',
    ];
    final genericDescAr = _selectedTransportMode == 2
        ? ['مسار المشاة الرئيسي الآمن', 'المسار المباشر المختصر', 'مسار الطبيعة والمنتزهات', 'مسار مشاة بديل']
        : (_selectedTransportMode == 3
        ? ['مسار الدراجات المخصص', 'طريق الدراجات السريع', 'المسار الريفي المنبسط', 'مسار دراجات بديل']
        : ['طريق سريع ومباشر', 'طريق الالتفاف السريع', 'طريق فرعي ريفي هادئ', 'طريق بديل']);
    final genericDescEn = _selectedTransportMode == 2
        ? ['Main Safe Pedestrian Route', 'Direct Shortcut Trail', 'Scenic Nature Pathway', 'Alternate Walking Route']
        : (_selectedTransportMode == 3
        ? ['Dedicated Cycling Route', 'Express Bike Corridor', 'Flat Countryside Path', 'Alternate Bike Route']
        : ['Direct Highway Route', 'Express Highway Bypass', 'Quiet Secondary Scenic Road', 'Alternate Road Route']);

    final variances = [1.0, 0.92, 1.06, 1.14];
    final slotCount = hasCurrentRoute
        ? (_routeAlternatives.isEmpty
              ? 1
              : (_routeAlternatives.length > 4 ? 4 : _routeAlternatives.length))
        : 3;

    return List.generate(slotCount, (i) {
      final routeForSlot = hasCurrentRoute && i < _routeAlternatives.length
          ? _routeAlternatives[i]
          : null;
      final dist = routeForSlot?.totalDistance ?? (baseDistance * variances[i]);
      final durSec =
          routeForSlot?.estimatedDuration ?? (baseDuration * variances[i]);
      return _RouteOption(
        badgeTextAr: genericBadgeTextAr[i],
        badgeTextEn: genericBadgeTextEn[i],
        badgeColor: badgeColors[i % badgeColors.length],
        lineColor: lineColors[i % lineColors.length],
        durationAr: _formatDynamicDuration(durSec, true),
        durationEn: _formatDynamicDuration(durSec, false),
        distanceAr: _formatDynamicDistance(dist, true),
        distanceEn: _formatDynamicDistance(dist, false),
        descriptionAr: genericDescAr[i],
        descriptionEn: genericDescEn[i],
        trafficAr: trafficAr[i % trafficAr.length],
        trafficEn: trafficEn[i % trafficEn.length],
      );
    });
  }

  TextStyle _uiFont(
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

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final isAr = provider.language == 'ar';
    final colorScheme = Theme.of(context).colorScheme;

    if (provider.hasChosenDestination && !_routeSetupStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeInitRoute();
      });
    }
    if (provider.hasChosenDestination &&
        _routeDestination != null &&
        Geolocator.distanceBetween(
          _routeDestination!.latitude,
          _routeDestination!.longitude,
          provider.destinationLat,
          provider.destinationLon,
        ) >=
            1500) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _routeData = null;
            _routeAlternatives = const [];
            _routeOrigin = null;
            _routeDestination = null;
            _selectedRouteIndex = 0;
            _noRouteFound = false;
            // New trip: release the old corridor lock and its saved
            // selection — the new destination may belong to a completely
            // different corridor.
            _lockedCorridorKey = null;
            _savedCorridorKey = null;
            _savedDestCountry = null;
            _pendingSavedRouteIndex = null;
          });
          _loadRoute(initial: true);
        }
      });
    }

    final currentOptions = _computeDynamicRoutes(context, isAr);
    _applySavedRouteSelection(currentOptions);
    // The navigation buttons are disabled ONLY while the locked premium
    // route is the active selection — picking any free route enables them.
    final navigationLocked =
        _isRouteLocked(_selectedRouteIndex, currentOptions.length);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            isAr ? 'المسارات' : 'Routes',
            style: _uiFont(
              isAr,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle header displaying actual destination city name
                      Text(
                        isAr
                            ? 'من موقعك إلى ${provider.destinationCityName}'
                            : 'From your location to ${provider.destinationCityName}',
                        style: _uiFont(
                          isAr,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Transport modes selector
                      _buildTransportModes(context, isAr),
                      const SizedBox(height: 24),

                      // No drivable route to this destination (confirmed by
                      // the routing service — same answer Google Maps gives).
                      if (_noRouteFound)
                        _buildNoRouteCard(context, isAr)
                      else ...[
                        // Section Title: Best Routes
                        Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: const Color(0xFF6C63E5),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAr ? 'أفضل المسارات' : 'Best Routes',
                              style: _uiFont(
                                isAr,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 3 Distinct Dynamic Route Cards
                        for (int idx = 0; idx < currentOptions.length; idx++) ...[
                          _buildRouteCard(
                            context: context,
                            isAr: isAr,
                            index: idx,
                            total: currentOptions.length,
                            option: currentOptions[idx],
                          ),
                          if (idx < currentOptions.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 24),

                        _buildTravelGuideSection(
                          context: context,
                          isAr: isAr,
                          options: currentOptions,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Travel Safely Card
                      _buildSafetyCard(context, isAr),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar: Google Maps Button + In-App Map Button.
              // Both are DISABLED while the best route is premium-locked —
              // navigation unlocks with a subscription.
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Open in Google Maps Button
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: navigationLocked
                              ? () {
                                  HapticFeedback.selectionClick();
                                  showSubscriptionSheet(context, isAr: isAr)
                                      .whenComplete(() {
                                    if (mounted) setState(() {});
                                  });
                                }
                              : _launchGoogleMapsRoute,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: navigationLocked
                                ? colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.2)
                                : colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            foregroundColor: navigationLocked
                                ? colorScheme.onSurface.withValues(alpha: 0.35)
                                : colorScheme.onSurface,
                            side: BorderSide(
                              color: colorScheme.onSurface.withValues(
                                alpha: navigationLocked ? 0.08 : 0.15,
                              ),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            navigationLocked
                                ? Icons.lock_rounded
                                : Icons.map_outlined,
                            color: navigationLocked
                                ? colorScheme.onSurface.withValues(alpha: 0.35)
                                : const Color(
                                    0xFFEA4335,
                                  ), // Google Maps Red Pin color
                            size: 20,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isAr
                                  ? 'فتح في خرائط Google'
                                  : 'Open in Google Maps',
                              style: _uiFont(
                                isAr,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: navigationLocked
                                    ? colorScheme.onSurface
                                        .withValues(alpha: 0.35)
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // In-App Interactive Map Navigation Button
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: navigationLocked
                              ? () {
                                  HapticFeedback.selectionClick();
                                  showSubscriptionSheet(context, isAr: isAr)
                                      .whenComplete(() {
                                    if (mounted) setState(() {});
                                  });
                                }
                              : () =>
                                  _openInteractiveMapModal(context, isAr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navigationLocked
                                ? colorScheme.onSurface
                                    .withValues(alpha: 0.12)
                                : AppColors.primary,
                            foregroundColor: navigationLocked
                                ? colorScheme.onSurface.withValues(alpha: 0.35)
                                : Colors.white,
                            elevation: navigationLocked ? 0 : 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            navigationLocked
                                ? Icons.lock_rounded
                                : Icons.navigation_rounded,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isAr ? 'عرض الخريطة والتنقل' : 'View In-App Map',
                              style: _uiFont(
                                isAr,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      ),
    );
  }

  // -------------------------------------------------------------------
  // Transport Mode Selectors Row
  // -------------------------------------------------------------------
  Widget _buildTransportModes(BuildContext context, bool isAr) {
    final colorScheme = Theme.of(context).colorScheme;
    final modes = [
      (Icons.directions_car_rounded, isAr ? 'سيارة' : 'Car'),
      (Icons.two_wheeler_rounded, isAr ? 'دراجة نارية' : 'Motorcycle'),
      (Icons.directions_walk_rounded, isAr ? 'مشي' : 'Walking'),
      (Icons.directions_bike_rounded, isAr ? 'دراجة هوائية' : 'Bicycle'),
    ];

    return Row(
      children: List.generate(modes.length, (idx) {
        final selected = idx == _selectedTransportMode;
        final mode = modes[idx];
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: idx == modes.length - 1 ? 0 : 8,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedTransportMode = idx;
                  });
                  _persistState();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6C63E5)
                        : colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6C63E5)
                          : colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        mode.$1,
                        size: 18,
                        color: selected
                            ? Colors.white
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          mode.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _uiFont(
                            isAr,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // -------------------------------------------------------------------
  // Route Card Item
  // -------------------------------------------------------------------
  Widget _buildRouteCard({
    required BuildContext context,
    required bool isAr,
    required int index,
    required int total,
    required _RouteOption option,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final locked = _isRouteLocked(index, total);
    final selected = index == _selectedRouteIndex && !locked;

    final badgeText = isAr ? option.badgeTextAr : option.badgeTextEn;
    final duration = isAr ? option.durationAr : option.durationEn;
    final distance = isAr ? option.distanceAr : option.distanceEn;
    final routeDescription = isAr ? option.descriptionAr : option.descriptionEn;
    final trafficDescription = isAr ? option.trafficAr : option.trafficEn;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          if (locked) {
            // Premium route — open the subscription sheet, then refresh so
            // a successful subscribe unlocks the card immediately.
            showSubscriptionSheet(context, isAr: isAr).whenComplete(() {
              if (mounted) setState(() {});
            });
            return;
          }
          setState(() => _selectedRouteIndex = index);
          _persistState();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: locked
                ? AppColors.pGold.withValues(alpha: 0.05)
                : selected
                    ? option.badgeColor.withValues(alpha: 0.06)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: locked
                  ? AppColors.pGold.withValues(alpha: 0.45)
                  : selected
                      ? option.badgeColor
                      : colorScheme.onSurface.withValues(alpha: 0.08),
              width: selected || locked ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Mini Route Painter Box
              Container(
                width: 88,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _RoutePreviewPainter(
                        lineColor: locked ? AppColors.pGold : option.lineColor,
                        routeType: index,
                      ),
                    ),
                    if (locked)
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        end: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.pGoldDeep,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 10,
                            color: AppColors.pOnGold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Badge — flexible so a long curated route name can
                        // never push the duration off the card edge.
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: locked
                                  ? AppColors.pGoldDeep
                                  : option.badgeColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _uiFont(
                                isAr,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // PRO chip on the locked premium route.
                        if (locked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.pGoldSoft,
                                  AppColors.pGoldDeep,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 11,
                                  color: AppColors.pOnGold,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'PRO',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.pOnGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Duration — always fully visible.
                        Text(
                          _localizeDigits(duration),
                          style: _uiFont(
                            isAr,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: isAr
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Text(
                        _localizeDigits(distance),
                        style: _uiFont(
                          isAr,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Description + traffic — partly blurred while the
                    // premium route is locked (teaser, not readable).
                    if (locked)
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 2.6,
                          sigmaY: 2.6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routeDescription,
                              style: _uiFont(
                                isAr,
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              trafficDescription,
                              style: _uiFont(
                                isAr,
                                fontSize: 11,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text(
                        routeDescription,
                        style: _uiFont(
                          isAr,
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        trafficDescription,
                        style: _uiFont(
                          isAr,
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  RouteData? _selectedRouteData(int total) {
    final idx = _effectiveRouteIndex(total);
    if (idx < _routeAlternatives.length) {
      return _routeAlternatives[idx];
    }
    return _routeData;
  }

  String _routeSourceLabel(bool isAr) {
    if (_routeAlternatives.isEmpty) {
      return isAr ? 'تقدير مؤقت' : 'Temporary estimate';
    }
    if (_selectedRouteIndex < _routeAlternatives.length) {
      return isAr ? 'مسار فعلي' : 'Live road route';
    }
    return isAr ? 'مبني على المسار الفعلي' : 'Based on live route';
  }

  Future<void> _launchMapSearch(String query, {LatLng? near}) async {
    final suffix = near == null
        ? ''
        : ' near ${near.latitude.toStringAsFixed(5)},${near.longitude.toStringAsFixed(5)}';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$query$suffix',
    });

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch Google Maps search: $e');
    }
  }

  Widget _buildTravelGuideSection({
    required BuildContext context,
    required bool isAr,
    required List<_RouteOption> options,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = AppDataProvider.instance;
    final effectiveIndex = _effectiveRouteIndex(options.length);
    final selectedOption = options[effectiveIndex];
    final selectedRoute = _selectedRouteData(options.length);
    final currentLocation = _resolveCurrentLocation(provider);
    final destination = LatLng(
      provider.destinationLat,
      provider.destinationLon,
    );
    final instructions =
        selectedRoute?.instructions ?? const <TurnInstruction>[];
    final visibleInstructions = instructions.take(12).toList();
    final curatedPlan = _curatedGuidePlan(provider);
    // The timeline mirrors real navigation: stations up to the destination
    // country's entry border, starting from the station nearest the user.
    final curatedStops = curatedPlan == null
        ? const <_GuideStop>[]
        : _navigationStops(curatedPlan, currentLocation);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selectedOption.badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: selectedOption.badgeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr
                          ? 'دليل الطريق إلى ${provider.destinationCityName}'
                          : 'Road guide to ${provider.destinationCityName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _uiFont(
                        isAr,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${isAr ? selectedOption.badgeTextAr : selectedOption.badgeTextEn} • ${_routeSourceLabel(isAr)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _uiFont(
                        isAr,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildGuideStat(
                  context: context,
                  isAr: isAr,
                  icon: Icons.timer_rounded,
                  label: isAr ? 'الوقت' : 'Time',
                  value: isAr
                      ? selectedOption.durationAr
                      : selectedOption.durationEn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGuideStat(
                  context: context,
                  isAr: isAr,
                  icon: Icons.social_distance_rounded,
                  label: isAr ? 'المسافة' : 'Distance',
                  value: isAr
                      ? selectedOption.distanceAr
                      : selectedOption.distanceEn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGuideStat(
                  context: context,
                  isAr: isAr,
                  icon: Icons.alt_route_rounded,
                  label: isAr ? 'الخطوات' : 'Steps',
                  value: curatedPlan != null
                      ? provider.nfi(curatedStops.length)
                      : (selectedRoute == null
                      ? '--'
                      : provider.nfi(instructions.length)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'مراحل الطريق' : 'Route Stages',
            style: _uiFont(
              isAr,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          _buildTimelineItem(
            context: context,
            isAr: isAr,
            index: 1,
            title: isAr ? 'موقعك الحالي' : 'Your current location',
            subtitle: currentLocation == null
                ? (isAr ? 'بانتظار تحديد الموقع' : 'Waiting for location')
                : '${currentLocation.latitude.toStringAsFixed(4)}, ${currentLocation.longitude.toStringAsFixed(4)}',
            color: const Color(0xFF10B981),
            point: currentLocation,
          ),
          if (curatedStops.isNotEmpty)
            for (int idx = 0; idx < curatedStops.length; idx++)
              _buildTimelineItem(
                context: context,
                isAr: isAr,
                index: idx + 2,
                title: isAr ? curatedStops[idx].titleAr : curatedStops[idx].titleEn,
                subtitle: isAr ? curatedStops[idx].noteAr : curatedStops[idx].noteEn,
                color: selectedOption.lineColor,
                point: null,
                mapQuery: curatedStops[idx].query,
              )
          else if (visibleInstructions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _isFetchingRoute
                    ? (isAr
                    ? 'جاري تجهيز تفاصيل الطريق...'
                    : 'Preparing route details...')
                    : (isAr
                    ? 'افتح الخريطة لعرض المسار، وسيتم تحديث التفاصيل عند توفر الاتصال.'
                    : 'Open the map to view the route. Details update when routing is available.'),
                style: _uiFont(
                  isAr,
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            )
          else
            for (int idx = 0; idx < visibleInstructions.length; idx++)
              _buildTimelineItem(
                context: context,
                isAr: isAr,
                index: idx + 2,
                title: visibleInstructions[idx].instruction,
                subtitle: _formatDynamicDistance(
                  visibleInstructions[idx].distance,
                  isAr,
                ),
                color: selectedOption.lineColor,
                point: visibleInstructions[idx].position,
              ),
          _buildTimelineItem(
            context: context,
            isAr: isAr,
            index: (curatedStops.isNotEmpty ? curatedStops.length : visibleInstructions.length) + 2,
            title: provider.destinationCityName,
            subtitle: isAr ? 'الوجهة المختارة' : 'Selected destination',
            color: const Color(0xFFEF4444),
            point: destination,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildGuideActionChip(
                context: context,
                isAr: isAr,
                icon: Icons.local_gas_station_rounded,
                label: isAr ? 'وقود قريب' : 'Fuel nearby',
                onTap: () => _launchMapSearch('gas station', near: destination),
              ),
              _buildGuideActionChip(
                context: context,
                isAr: isAr,
                icon: Icons.hotel_rounded,
                label: isAr ? 'فنادق' : 'Hotels',
                onTap: () => _launchMapSearch('hotels', near: destination),
              ),
              _buildGuideActionChip(
                context: context,
                isAr: isAr,
                icon: Icons.restaurant_rounded,
                label: isAr ? 'مطاعم' : 'Food',
                onTap: () => _launchMapSearch('restaurants', near: destination),
              ),
              _buildGuideActionChip(
                context: context,
                isAr: isAr,
                icon: Icons.map_rounded,
                label: isAr ? 'افتح المسار' : 'Open route',
                onTap: _launchGoogleMapsRoute,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStat({
    required BuildContext context,
    required bool isAr,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF6C63E5)),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _uiFont(
              isAr,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _localizeDigits(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _uiFont(
              isAr,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required bool isAr,
    required int index,
    required String title,
    required String subtitle,
    required Color color,
    LatLng? point,
    String? mapQuery,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  _localizeDigits(AppDataProvider.instance.nfi(index)),
                  style: _uiFont(
                    isAr,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                width: 2,
                height: 28,
                color: color.withValues(alpha: 0.22),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _uiFont(
                            isAr,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _localizeDigits(subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _uiFont(
                            isAr,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (point != null || mapQuery != null)
                    IconButton(
                      tooltip: isAr ? 'فتح الخريطة' : 'Open map',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: color,
                      ),
                      onPressed: () => _launchMapSearch(
                        point != null
                            ? '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}'
                            : mapQuery!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideActionChip({
    required BuildContext context,
    required bool isAr,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: const Color(0xFF6C63E5)),
      label: Text(
        label,
        style: _uiFont(
          isAr,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      backgroundColor: colorScheme.surface.withValues(alpha: 0.84),
      side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      onPressed: onTap,
    );
  }

  // -------------------------------------------------------------------
  // "No route" message card — shown when the routing service confirms
  // there is no drivable route to the selected destination (e.g. from
  // the UAE to New York), the same answer Google Maps would give.
  // -------------------------------------------------------------------
  Widget _buildNoRouteCard(BuildContext context, bool isAr) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Color(0xFFEF4444),
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isAr
                ? 'لا يوجد مسار إلى الوجهة المحددة'
                : 'There is no route to the selected destination',
            textAlign: TextAlign.center,
            style: _uiFont(
              isAr,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? 'تأكد من الوجهة أو اختر وجهة يمكن الوصول إليها براً.'
                : 'Check the destination or pick one that can be reached by road.',
            textAlign: TextAlign.center,
            style: _uiFont(
              isAr,
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Safety Banner Card
  // -------------------------------------------------------------------
  Widget _buildSafetyCard(BuildContext context, bool isAr) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63E5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6C63E5).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'سافر بأمان' : 'Travel Safely',
                  style: _uiFont(
                    isAr,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? 'نحرص على توفير أفضل الطرق المحدثة لتصل إلى وجهتك بأمان وراحة'
                      : 'We ensure providing the best updated routes for you to reach your destination safely and comfortably',
                  style: _uiFont(
                    isAr,
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63E5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF6C63E5),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Interactive Map View Modal Sheet
  // -------------------------------------------------------------------
  void _openInteractiveMapModal(BuildContext context, bool isAr) {
    final provider = AppDataProvider.instance;
    final currentLocation = _resolveCurrentLocation(provider);
    final destinationLocation = LatLng(
      provider.destinationLat,
      provider.destinationLon,
    );

    final startLoc = currentLocation ?? const LatLng(24.7136, 46.6753);
    final endLoc = destinationLocation;

    final center = LatLng(
      (startLoc.latitude + endLoc.latitude) / 2,
      (startLoc.longitude + endLoc.longitude) / 2,
    );

    final distance = Geolocator.distanceBetween(
      startLoc.latitude,
      startLoc.longitude,
      endLoc.latitude,
      endLoc.longitude,
    );
    final zoom = _zoomForDistance(distance);

    final currentOptions = _computeDynamicRoutes(context, isAr);
    final safeRouteIndex = _effectiveRouteIndex(currentOptions.length);
    final selectedOption = currentOptions[safeRouteIndex];
    final hasLiveRoutes =
        _routeOrigin != null &&
        _routeDestination != null &&
        _routeAlternatives.isNotEmpty &&
        Geolocator.distanceBetween(
              _routeOrigin!.latitude,
              _routeOrigin!.longitude,
              startLoc.latitude,
              startLoc.longitude,
            ) <
            1500 &&
        Geolocator.distanceBetween(
              _routeDestination!.latitude,
              _routeDestination!.longitude,
              endLoc.latitude,
              endLoc.longitude,
            ) <
            1500;
    final routePointSets = List.generate(currentOptions.length, (idx) {
      if (hasLiveRoutes && idx < _routeAlternatives.length) {
        return _routeAlternatives[idx].points;
      }
      return _getDistinctRoutePoints(startLoc, endLoc, idx);
    });

    _mapModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = Theme.of(context).colorScheme.surface;

        // Themed raster basemap: CARTO Voyager (light) / Dark Matter (dark)
        // — far cleaner than raw OSM tiles and free with attribution.
        final tileUrl = isDark
            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
        // Casing under the route line so it pops against the basemap.
        final casingColor = isDark ? Colors.black87 : Colors.white;

        final alternativePolylines = <Polyline>[];
        for (var idx = 0; idx < routePointSets.length; idx++) {
          if (idx == safeRouteIndex) continue;
          alternativePolylines.add(
            Polyline(
              points: routePointSets[idx],
              strokeWidth: 7.5,
              color: casingColor.withValues(alpha: 0.85),
            ),
            );
          alternativePolylines.add(
            Polyline(
              points: routePointSets[idx],
              strokeWidth: 4,
              color: (isDark ? Colors.white54 : Colors.black45),
            ),
          );
        }

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: zoom,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: tileUrl,
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.wejhaty.app',
                        maxNativeZoom: 19,
                      ),
                      // Alternatives first (muted, under the selection).
                      PolylineLayer(polylines: alternativePolylines),
                      // Selected route: casing + colored line on top.
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePointSets[safeRouteIndex],
                            strokeWidth: 9.5,
                            color: casingColor,
                          ),
                          Polyline(
                            points: routePointSets[safeRouteIndex],
                            strokeWidth: 5.5,
                            color: selectedOption.lineColor,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: startLoc,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          Marker(
                            point: endLoc,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        alignment: AttributionAlignment.bottomLeft,
                        attributions: [
                          TextSourceAttribution('© OpenStreetMap'),
                          TextSourceAttribution('© CARTO'),
                        ],
                      ),
                    ],
                  ),

                  // Top Close & Badge Header Bar
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selectedOption.badgeColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              isAr
                                  ? selectedOption.badgeTextAr
                                  : selectedOption.badgeTextEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _uiFont(
                                isAr,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        FloatingActionButton.small(
                          backgroundColor: surface,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                          child: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _mapModalOpen = false;
    });
  }

  double _zoomForDistance(double distanceMeters) {
    if (distanceMeters > 2000000) return 3;
    if (distanceMeters > 1000000) return 4;
    if (distanceMeters > 500000) return 5;
    if (distanceMeters > 100000) return 6;
    if (distanceMeters > 50000) return 7;
    if (distanceMeters > 10000) return 8;
    if (distanceMeters > 5000) return 9;
    if (distanceMeters > 1000) return 10;
    return 12;
  }

  String _formatDistance(double meters) {
    final p = AppDataProvider.instance;
    if (meters >= 1000) {
      return '${p.nfd(meters / 1000)} km';
    }
    return '${p.nfw(meters)} m';
  }
}

// -------------------------------------------------------------------
// Mini Route Line Painter for Route Cards
// -------------------------------------------------------------------
class _RoutePreviewPainter extends CustomPainter {
  final Color lineColor;
  final int routeType;

  _RoutePreviewPainter({required this.lineColor, required this.routeType});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (routeType == 0) {
      path.moveTo(size.width * 0.15, size.height * 0.75);
      path.cubicTo(
        size.width * 0.35,
        size.height * 0.2,
        size.width * 0.65,
        size.height * 0.9,
        size.width * 0.85,
        size.height * 0.3,
      );
    } else if (routeType == 1) {
      path.moveTo(size.width * 0.15, size.height * 0.75);
      path.quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width * 0.85,
        size.height * 0.35,
      );
    } else if (routeType == 2) {
      path.moveTo(size.width * 0.15, size.height * 0.75);
      path.cubicTo(
        size.width * 0.4,
        size.height * 0.85,
        size.width * 0.6,
        size.height * 0.3,
        size.width * 0.85,
        size.height * 0.4,
      );
    } else {
      path.moveTo(size.width * 0.15, size.height * 0.75);
      path.cubicTo(
        size.width * 0.45,
        size.height * 0.15,
        size.width * 0.55,
        size.height * 0.85,
        size.width * 0.85,
        size.height * 0.45,
      );
    }

    final paintLine = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paintLine);

    final endY = switch (routeType) {
      0 => size.height * 0.3,
      1 => size.height * 0.35,
      2 => size.height * 0.4,
      _ => size.height * 0.45,
    };

    // Green start dot
    final greenDot = Paint()..color = const Color(0xFF10B981);
    final whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.75),
      5.0,
      greenDot,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.75),
      5.0,
      whiteBorder,
    );

    // Red destination dot
    final redDot = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(size.width * 0.85, endY), 5.0, redDot);
    canvas.drawCircle(Offset(size.width * 0.85, endY), 5.0, whiteBorder);
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.routeType != routeType;
}
