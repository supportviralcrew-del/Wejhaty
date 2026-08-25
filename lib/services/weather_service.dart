import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Weather Condition ────────────────────────────────────────────────────────

enum WeatherCondition {
  clearSky,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown,
}

// ─── Search Result Model ──────────────────────────────────────────────────────

class SearchResult {
  const SearchResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.country,
  });

  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String country;
}

// ─── Weather Data Model ───────────────────────────────────────────────────────

class WeatherData {
  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.weatherCode,
    required this.cloudCover,
    required this.isDay,
    required this.cityName,
    required this.countryCode,
    required this.countryName,
    required this.fetchedAt,
    this.cityNameAr = '',
  });

  final double temperature;   // °C
  final double feelsLike;     // °C
  final int humidity;          // %
  final double windSpeed;      // km/h
  final WeatherCondition condition;
  final int weatherCode;       // raw WMO code, used for icon selection
  final int cloudCover;        // %, used for icon selection
  final bool isDay;            // used for icon selection (day/night variants)
  final String cityName;
  final String cityNameAr;
  final String countryCode;
  final String countryName;
  final DateTime fetchedAt;

  /// Localized city name for the given app language — Arabic when [isAr]
  /// and an Arabic name is available, otherwise the primary name.
  String cityNameFor(bool isAr) =>
      isAr && cityNameAr.isNotEmpty ? cityNameAr : cityName;

  String get conditionLabel {
    switch (condition) {
      case WeatherCondition.clearSky: return 'Clear Sky';
      case WeatherCondition.partlyCloudy: return 'Partly Cloudy';
      case WeatherCondition.overcast: return 'Overcast';
      case WeatherCondition.fog: return 'Foggy';
      case WeatherCondition.drizzle: return 'Drizzle';
      case WeatherCondition.rain: return 'Rainy';
      case WeatherCondition.snow: return 'Snowy';
      case WeatherCondition.thunderstorm: return 'Thunderstorm';
      case WeatherCondition.unknown: return 'Unknown';
    }
  }

  /// Path to the SVG icon matching this weather, under assets/weather_icons/.
  /// Includes the 'assets/' prefix — Flutter does NOT add this for you, the
  /// path passed to SvgPicture.asset/Image.asset/Lottie.asset must match the
  /// path declared under `flutter: assets:` in pubspec.yaml exactly.
  /// Used for both the small inline icon and the large header icon (render
  /// at whatever size the widget needs — same file, no separate "large" set).
  String get iconPath => _iconPathFor(weatherCode, cloudCover, isDay);

  /// Path to the Lottie animation matching this weather, under assets/weather_icons/lottie/.
  /// Includes the 'assets/' prefix — see note on [iconPath] above.
  String get lottiePath => _lottiePathFor(weatherCode, cloudCover, isDay);

  /// Path to the full-bleed background image matching this weather, under
  /// assets/WeatherBackgroundImages/. Day/night and cloud-cover aware, same
  /// selection logic as the reference weather app.
  String get backgroundImagePath => _backgroundImagePathFor(weatherCode, cloudCover, isDay);

  static String _backgroundImagePathFor(int weatherCode, int cloudCover, bool isDay) {
    const base = 'assets/WeatherBackgroundImages';
    final isNight = !isDay;

    if (isNight) {
      if (weatherCode >= 95) return '$base/NightThunderstorm.png';
      if (weatherCode >= 71 && weatherCode <= 77) return '$base/NightSnowing.png';
      if (weatherCode >= 80 && weatherCode <= 82) return '$base/RainNIGHT.png';
      if (weatherCode >= 51 && weatherCode <= 57) return '$base/NightTime-Drizzle.jpg';
      if (weatherCode >= 58 && weatherCode <= 79) return '$base/NightRain.png';
      if (weatherCode >= 45 && weatherCode <= 48) return '$base/NightFog.png';

      // Cloud-based conditions - check cloud cover first
      if (cloudCover > 85 || weatherCode == 3) return '$base/NightCloudy.png';
      if (cloudCover > 65) return '$base/NightMostlyCloudy.png';
      if (cloudCover > 20) return '$base/NightPartlyCloudy.png';

      return '$base/NightClear.png';
    }

    if (weatherCode >= 95) return '$base/ThunderstormDAY.png';
    if (weatherCode >= 71 && weatherCode <= 77) return '$base/DaySnowing.png';
    if (weatherCode >= 65 && weatherCode <= 67) return '$base/HeavyRainDAY.png';
    if (weatherCode >= 61 && weatherCode <= 82) return '$base/RainDAY.png';
    if (weatherCode >= 51 && weatherCode <= 57) return '$base/DayTime-Drizzle.jpg';
    if (weatherCode >= 45 && weatherCode <= 48) return '$base/DayFog.png';

    // Cloud-based conditions - check cloud cover first
    if (cloudCover > 85 || weatherCode == 3) return '$base/DayCloudy.png';
    if (cloudCover > 65) return '$base/DayMostlyCloudy.png';
    if (cloudCover > 20) return '$base/DayPartlyCloudy.png';

    return '$base/DayClear.png';
  }

  static String _iconPathFor(int weatherCode, int cloudCover, bool isDay) {
    const base = 'assets/weather_icons';

    // Tornado
    if (weatherCode == 99) return '$base/tornado.svg';

    // Thunderstorms
    if (weatherCode >= 95) {
      return isDay ? '$base/thunderstorms-day.svg' : '$base/thunderstorms-night.svg';
    }

    // Heavy snow / blizzard
    if (weatherCode >= 75 && weatherCode <= 77) return '$base/wind-snow.svg';

    // Snow
    if (weatherCode >= 71 && weatherCode <= 74) return '$base/snow.svg';

    // Freezing rain / sleet
    if (weatherCode >= 66 && weatherCode <= 67) return '$base/sleet.svg';

    // Heavy rain
    if (weatherCode >= 63 && weatherCode <= 65) return '$base/overcast-rain.svg';

    // Rain showers
    if (weatherCode >= 80 && weatherCode <= 82) {
      return isDay ? '$base/partly-cloudy-day-rain.svg' : '$base/partly-cloudy-night-rain.svg';
    }

    // Light/moderate rain
    if (weatherCode >= 61 && weatherCode <= 62) {
      return isDay ? '$base/overcast-day-rain.svg' : '$base/overcast-night-rain.svg';
    }

    // Drizzle
    if (weatherCode >= 51 && weatherCode <= 57) {
      return isDay ? '$base/partly-cloudy-day-drizzle.svg' : '$base/partly-cloudy-night-drizzle.svg';
    }

    // Fog
    if (weatherCode >= 45 && weatherCode <= 48) return '$base/fog.svg';

    // Overcast
    if (weatherCode == 3 || cloudCover > 85) return '$base/cloudy.svg';

    // Mostly cloudy
    if (cloudCover > 65) {
      return isDay ? '$base/overcast-day.svg' : '$base/overcast-night.svg';
    }

    // Partly cloudy
    if (weatherCode <= 2 && cloudCover > 30) {
      return isDay ? '$base/partly-cloudy-day.svg' : '$base/partly-cloudy-night.svg';
    }

    // Clear
    return isDay ? '$base/clear-day.svg' : '$base/clear-night.svg';
  }

  static String _lottiePathFor(int weatherCode, int cloudCover, bool isDay) {
    const base = 'assets/weather_icons/lottie';

    // Thunderstorms
    if (weatherCode >= 95) {
      return isDay ? '$base/extreme-day-rain.json' : '$base/extreme-night-rain.json';
    }

    // Heavy snow / blizzard
    if (weatherCode >= 75 && weatherCode <= 77) return '$base/extreme-snow.json';

    // Snow
    if (weatherCode >= 71 && weatherCode <= 74) return '$base/extreme-snow.json';

    // Freezing rain / sleet
    if (weatherCode >= 66 && weatherCode <= 67) return '$base/extreme-sleet.json';

    // Heavy rain
    if (weatherCode >= 63 && weatherCode <= 65) return '$base/extreme-rain.json';

    // Rain showers
    if (weatherCode >= 80 && weatherCode <= 82) {
      return isDay ? '$base/extreme-day-rain.json' : '$base/extreme-night-rain.json';
    }

    // Light/moderate rain
    if (weatherCode >= 61 && weatherCode <= 62) {
      return isDay ? '$base/extreme-day-rain.json' : '$base/extreme-night-rain.json';
    }

    // Drizzle
    if (weatherCode >= 51 && weatherCode <= 57) {
      return isDay ? '$base/extreme-day-drizzle.json' : '$base/extreme-night-drizzle.json';
    }

    // Fog
    if (weatherCode >= 45 && weatherCode <= 48) return '$base/extreme-fog.json';

    // Overcast
    if (weatherCode == 3 || cloudCover > 85) return '$base/cloudy.json';

    // Mostly cloudy
    if (cloudCover > 65) {
      return isDay ? '$base/extreme-day.json' : '$base/extreme-night.json';
    }

    // Partly cloudy
    if (weatherCode <= 2 && cloudCover > 30) {
      return isDay ? '$base/extreme-day.json' : '$base/extreme-night.json';
    }

    // Clear
    return isDay ? '$base/clear-day.json' : '$base/clear-night.json';
  }
}

// ─── Weather Service ──────────────────────────────────────────────────────────

class WeatherService {
  static const _timeout = Duration(seconds: 10);
  static const _geocodeBase = 'https://nominatim.openstreetmap.org';
  static const _weatherBase = 'https://api.open-meteo.com/v1';

  /// Fetch current weather + reverse-geocoded city name for [lat]/[lon].
  ///
  /// Pass [cityInfo] (from [fetchCityName]) to reuse an already-resolved
  /// city lookup — this guarantees weather, prayer times and the location
  /// chip all display the exact same city, and saves a redundant request.
  Future<WeatherData?> fetchWeather(
    double lat,
    double lon, {
    String lang = 'en',
    (String, String, String, String)? cityInfo,
  }) async {
    try {
      // Run both requests in parallel (geocoding is skipped when the
      // caller already resolved the city name).
      final results = await Future.wait([
        cityInfo != null
            ? Future<(String, String, String, String)>.value(cityInfo)
            : _fetchCityName(lat, lon, lang: lang),
        _fetchWeatherData(lat, lon),
      ]);

      final cityInfoResolved = results[0] as (String, String, String, String);
      final weather = results[1] as _RawWeather?;

      if (weather == null) return null;

      final cityName = cityInfoResolved.$1.isNotEmpty
          ? cityInfoResolved.$1
          : 'Unknown City';
      final countryCode = cityInfoResolved.$2;
      final countryName = cityInfoResolved.$3.isNotEmpty
          ? cityInfoResolved.$3
          : 'Unknown Country';
      final cityNameAr = cityInfoResolved.$4;

      return WeatherData(
        temperature: weather.temperature,
        feelsLike: weather.feelsLike,
        humidity: weather.humidity,
        windSpeed: weather.windSpeed,
        condition: weather.condition,
        weatherCode: weather.weatherCode,
        cloudCover: weather.cloudCover,
        isDay: weather.isDay,
        cityName: cityName,
        cityNameAr: cityNameAr,
        countryCode: countryCode,
        countryName: countryName,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Search for a city name in Arabic or English
  Future<List<SearchResult>> searchCities(String query, {String lang = 'en'}) async {
    if (query.trim().isEmpty) return const [];
    try {
      final uri = Uri.parse(
        '$_geocodeBase/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept-Language': lang,
          'User-Agent': 'WejhatyApp/1.0',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) return const [];

      final list = jsonDecode(response.body) as List<dynamic>;
      final List<SearchResult> results = [];

      for (final item in list) {
        final Map<String, dynamic> itemMap = item as Map<String, dynamic>;
        final address = itemMap['address'] as Map<String, dynamic>? ?? {};

        final name = (address['city'] as String?) ??
            (address['town'] as String?) ??
            (address['village'] as String?) ??
            (address['county'] as String?) ??
            (address['suburb'] as String?) ??
            itemMap['name'] as String? ??
            '';

        final country = address['country'] as String? ?? '';
        final displayName = itemMap['display_name'] as String? ?? '';
        final lat = double.tryParse(itemMap['lat'] as String? ?? '') ?? 0.0;
        final lon = double.tryParse(itemMap['lon'] as String? ?? '') ?? 0.0;

        if (name.isNotEmpty && lat != 0.0 && lon != 0.0) {
          results.add(SearchResult(
            name: name,
            displayName: displayName,
            latitude: lat,
            longitude: lon,
            country: country,
          ));
        }
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  /// Reverse-geocode [lat]/[lon] into (city, countryCode, countryName,
  /// cityArabic).
  ///
  /// The [lang] code is sent as `Accept-Language`, so Nominatim returns the
  /// place names localized — 'ar' yields Arabic names, 'en' English ones.
  /// `namedetails=1` additionally returns ALL name variants, from which we
  /// also extract the Arabic name — so the UI can show a localized city
  /// name instantly when the app language is Arabic, even if this lookup
  /// ran in English.
  /// Public so [AppDataProvider] can resolve the city ONCE and share it
  /// across weather, prayer times, and the location chip.
  Future<(String, String, String, String)> fetchCityName(
    double lat,
    double lon, {
    String lang = 'en',
  }) async {
    return _fetchCityName(lat, lon, lang: lang);
  }

  Future<(String, String, String, String)> _fetchCityName(
    double lat,
    double lon, {
    String lang = 'en',
  }) async {
    try {
      final uri = Uri.parse(
        '$_geocodeBase/reverse?lat=$lat&lon=$lon&format=json&zoom=10&namedetails=1',
      );
      final response = await http
          .get(uri, headers: {
        'Accept-Language': lang,
        'User-Agent': 'RoadTripJordanApp/1.0',
      })
          .timeout(_timeout);

      if (response.statusCode != 200) return ('', '', '', '');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>? ?? {};
      final namedetails = data['namedetails'] as Map<String, dynamic>? ?? {};

      final city = (address['city'] as String?) ??
          (address['town'] as String?) ??
          (address['village'] as String?) ??
          (address['county'] as String?) ??
          'Unknown';
      final countryCode = (address['country_code'] as String? ?? '').toUpperCase();
      final countryName = address['country'] as String? ?? 'Unknown';

      // Arabic name for the same place (falls back to the primary name
      // when OSM has no Arabic variant).
      final cityAr = (namedetails['name:ar'] as String?) ??
          (namedetails['name_ar'] as String?) ??
          city;

      return (city, countryCode, countryName, cityAr);
    } catch (_) {
      return ('', '', '', '');
    }
  }

  Future<_RawWeather?> _fetchWeatherData(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        '$_weatherBase/forecast?latitude=$lat&longitude=$lon'
            '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
            'wind_speed_10m,weather_code,cloud_cover,is_day'
            '&wind_speed_unit=kmh&timezone=auto',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null || !data.containsKey('current')) return null;

      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return null;

      final code = (current['weather_code'] as num?)?.toInt() ?? -1;
      return _RawWeather(
        temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
        feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
        humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
        windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
        condition: _wmoToCondition(code),
        weatherCode: code,
        cloudCover: (current['cloud_cover'] as num?)?.toInt() ?? 0,
        isDay: ((current['is_day'] as num?)?.toInt() ?? 1) == 1,
      );
    } catch (_) {
      return null;
    }
  }

  /// Map WMO weather code → [WeatherCondition].
  WeatherCondition _wmoToCondition(int code) {
    if (code == 0) return WeatherCondition.clearSky;
    if (code <= 2) return WeatherCondition.partlyCloudy;
    if (code == 3) return WeatherCondition.overcast;
    if (code <= 49) return WeatherCondition.fog;
    if (code <= 67) return WeatherCondition.drizzle;
    if (code <= 77) return WeatherCondition.snow;
    if (code <= 82) return WeatherCondition.rain;
    if (code <= 99) return WeatherCondition.thunderstorm;
    return WeatherCondition.unknown;
  }
}

class _RawWeather {
  const _RawWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.weatherCode,
    required this.cloudCover,
    required this.isDay,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final WeatherCondition condition;
  final int weatherCode;
  final int cloudCover;
  final bool isDay;
}