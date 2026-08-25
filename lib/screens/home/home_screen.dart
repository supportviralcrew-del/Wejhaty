import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/core/widgets/premium_effects.dart';
import 'package:tripproject/screens/home/widgets/service_card.dart';
import 'package:tripproject/screens/home/widgets/checklist_sheet.dart';
import 'package:tripproject/screens/home/widgets/expenses_sheet.dart';
import 'package:tripproject/screens/home/widgets/emergency_sheet.dart';
import 'package:tripproject/screens/home/widgets/trip_statistics_sheet.dart';
import 'package:tripproject/screens/photos/photos_screen.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/prayer_service.dart';
import 'package:tripproject/services/weather_service.dart';
import 'package:tripproject/services/trip_stats_service.dart';
import 'package:tripproject/services/trip_history_service.dart';
import 'package:tripproject/widgets/banner_ad_widget.dart';
import 'package:tripproject/widgets/native_ad_widget.dart';
import 'package:tripproject/screens/subscription/subscription_sheet.dart';

/// Converts Western digits (0-9) in [input] to Eastern Arabic-Indic digits
/// (٠-٩) whenever the "Arabic Numerals" setting is enabled. Non-digit
/// characters (colons, slashes, letters, spaces, %, °) pass through
/// unchanged, so it's safe to run over already-formatted strings such as
/// "5:32 AM" that come pre-built from services like PrayerService, which
/// always emit Western digits regardless of locale.
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

/// Pads a non-negative integer to two digits using the locale's own zero
/// glyph (Western or Arabic-Indic), and applies digit localization to the
/// whole result.
String _twoDigits(int n) => _localizeDigits(n.toString().padLeft(2, '0'));

// ─── Time-of-day prayer banner ─────────────────────────────────────────────
// Each banner covers the period *starting* at the named prayer and running
// until the next one:
//   Isha   -> Fajr   (wraps past midnight)
//   Fajr   -> Dhuhr
//   Dhuhr  -> Asr
//   Asr    -> Maghrib
//   Maghrib-> Isha
// Filenames match assets/PrayersBanner/ exactly (note: "Duhr" and "Magrib",
// not "Dhuhr"/"Maghrib" — matches the actual asset names).
const Map<String, String> _bannerAssetByPeriod = {
  'Fajr': 'assets/PrayersBanner/FajrBANNER.png',
  'Dhuhr': 'assets/PrayersBanner/DuhrBANNER.png',
  'Asr': 'assets/PrayersBanner/AsrBANNER.png',
  'Maghrib': 'assets/PrayersBanner/MagribBANNER.png',
  'Isha': 'assets/PrayersBanner/IshaBANNER.png',
};

String _currentPeriodName(PrayerTimesData times) {
  final now = times.fajr.locationNow;
  final fajr = times.fajr.timeToday;
  final dhuhr = times.dhuhr.timeToday;
  final asr = times.asr.timeToday;
  final maghrib = times.maghrib.timeToday;
  final isha = times.isha.timeToday;

  if (now.isBefore(fajr)) return 'Isha'; // still last night's Isha period
  if (now.isBefore(dhuhr)) return 'Fajr';
  if (now.isBefore(asr)) return 'Dhuhr';
  if (now.isBefore(maghrib)) return 'Asr';
  if (now.isBefore(isha)) return 'Maghrib';
  return 'Isha'; // past today's Isha, into tonight's period
}

// ─── Neutral, professional surface tokens ─────────────────────────────────
// Flat, low-saturation fills instead of tinted-color-on-everything. Accent
// color is reserved for icon glyphs and small indicators only.
Color _neutralFill(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035);
}

Color _neutralBorder(BuildContext context) {
  return Theme.of(context).colorScheme.outline.withValues(alpha: 0.15);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tracker = TripProgressService.instance;
  StreamSubscription<double>? _distanceSub;
  StreamSubscription<void>? _updateSub;

  @override
  void initState() {
    super.initState();
    // Initialize timezone database
    tz_data.initializeTimeZones();
    // If data hasn't been fetched yet, trigger it now
    final provider = AppDataProvider.instance;
    if (!provider.hasData && !provider.isLoading) {
      provider.refresh();
    }

    // Listen to trip progress updates
    _distanceSub = _tracker.onTraveledDistanceChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _updateSub = _tracker.onUpdate.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _distanceSub?.cancel();
    _updateSub?.cancel();
    super.dispose();
  }

  String _greeting(bool isAr) {
    final h = DateTime.now().hour;
    if (isAr) {
      if (h < 12) return 'صباح الخير';
      if (h < 17) return 'مساء الخير';
      return 'طاب مساؤكم';
    } else {
      if (h < 12) return 'Good morning';
      if (h < 17) return 'Good afternoon';
      return 'Good evening';
    }
  }

  List<({String title, String subtitle, IconData icon, Color color, String tag})>
  _getServices(bool isAr) {
    return [
      (
      title: isAr ? 'المسار' : 'Route',
      subtitle: isAr ? 'التوجيه إلى الوجهة' : 'Navigate to destination',
      icon: Icons.route_rounded,
      color: AppColors.routeCard,
      tag: 'service_route',
      ),
      (
      title: isAr ? 'محطات الوقود' : 'Fuel Stations',
      subtitle: isAr ? 'محطات قريبة' : 'Nearby stations',
      icon: Icons.local_gas_station_rounded,
      color: AppColors.fuelCard,
      tag: 'service_fuel',
      ),
      (
      title: isAr ? 'المطاعم' : 'Restaurants',
      subtitle: isAr ? 'أماكن لتناول الطعام' : 'Places to eat',
      icon: Icons.restaurant_rounded,
      color: AppColors.restaurantCard,
      tag: 'service_restaurant',
      ),
      (
      title: isAr ? 'قائمة التحقق' : 'Travel Checklist',
      subtitle: isAr ? 'تتبع احتياجاتك' : 'Track your needs',
      icon: Icons.checklist_rounded,
      color: AppColors.checklistCard,
      tag: 'service_checklist',
      ),
      (
      title: isAr ? 'المصاريف' : 'Expenses',
      subtitle: isAr ? 'إدارة الميزانية' : 'Manage budget',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.expensesCard,
      tag: 'service_expenses',
      ),
      (
      title: isAr ? 'الطوارئ' : 'Emergency',
      subtitle: isAr ? 'أرقام الطوارئ' : 'Emergency numbers',
      icon: Icons.emergency_rounded,
      color: AppColors.emergencyCard,
      tag: 'service_emergency',
      ),
      (
      title: isAr ? 'الصور' : 'Photos',
      subtitle: isAr ? 'معرض الصور' : 'Photo gallery',
      icon: Icons.photo_library_rounded,
      color: AppColors.photosCard,
      tag: 'service_photos',
      ),
      (
      title: isAr ? 'إحصائيات الرحلة' : 'Trip Statistics',
      subtitle: isAr ? 'معلومات الرحلة' : 'Trip info',
      icon: Icons.bar_chart_rounded,
      color: AppColors.statsCard,
      tag: 'service_stats',
      ),
    ];
  }

  void _showDestinationSettings(BuildContext context, bool isAr) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DestinationBottomSheet(
          isAr: isAr,
          weatherService: WeatherService(),
        );
      },
    );
  }

  Future<void> _openGoogleMapsRoute() async {
    final provider = AppDataProvider.instance;

    // Get current location, fallback to Riyadh (Saudi Arabia) if not available
    double currentLat = AppDataProvider.defaultCountryLat; // Riyadh coordinates
    double currentLon = AppDataProvider.defaultCountryLon;

    if (provider.location != null) {
      currentLat = provider.location!.latitude;
      currentLon = provider.location!.longitude;
    } else if (provider.isManualLocation && provider.manualLat != null && provider.manualLon != null) {
      currentLat = provider.manualLat!;
      currentLon = provider.manualLon!;
    }

    // Open Google Maps with directions from current location (or Riyadh) to destination
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$currentLat,$currentLon&destination=${provider.destinationLat},${provider.destinationLon}&travelmode=driving';

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Google Maps with a search for [query] (e.g. gas stations or
  /// restaurants) centered on the user's current location.
  Future<void> _openNearbyPlaces(String query) async {
    final provider = AppDataProvider.instance;

    double? lat;
    double? lon;
    if (provider.location != null) {
      lat = provider.location!.latitude;
      lon = provider.location!.longitude;
    } else if (provider.isManualLocation && provider.manualLat != null && provider.manualLon != null) {
      lat = provider.manualLat;
      lon = provider.manualLon;
    }

    final Uri uri;
    if (lat != null && lon != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}&query_place_id=&center=$lat,$lon',
      );
      // Fallback-friendly form: most Maps clients resolve "query near lat,lon" reliably.
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openFuelStations(bool isAr) =>
      _openNearbyPlaces(isAr ? 'محطات وقود قريبة' : 'gas stations near me');

  Future<void> _openRestaurants(bool isAr) =>
      _openNearbyPlaces(isAr ? 'مطاعم قريبة' : 'restaurants near me');

  void _openChecklist(BuildContext context, bool isAr) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChecklistSheet(isAr: isAr),
    );
  }

  void _openExpenses(BuildContext context, bool isAr) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpensesSheet(isAr: isAr),
    );
  }

  void _openEmergency(BuildContext context, bool isAr) {
    final provider = AppDataProvider.instance;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmergencySheet(
        isAr: isAr,
        countryName: provider.weather?.countryName,
      ),
    );
  }

  void _openPhotos(BuildContext context, bool isAr) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PhotosScreen(isAr: isAr)),
    );
  }

  void _openTripStatistics(BuildContext context, bool isAr) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripStatisticsSheet(isAr: isAr),
    );
  }

  Widget _buildCreditsBadge(BuildContext context, AppDataProvider provider, bool isAr) {
    final isSubscribed = provider.isSubscribed;
    final credits = provider.credits;

    if (!isSubscribed) {
      // Free tier — keep the standard blue credit chip.
      return InkWell(
        onTap: () => showSubscriptionSheet(context, isAr: isAr),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.primary.withValues(alpha: 0.08),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                isAr ? '${provider.nfi(credits)} رصيد' : '$credits credits',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Premium tier — gilded chip with a slow champagne sheen.
    return InkWell(
      onTap: () => showSubscriptionSheet(context, isAr: isAr),
      borderRadius: BorderRadius.circular(20),
      child: GoldSheen(
        borderRadius: BorderRadius.circular(20),
        opacity: 0.35,
        bandWidth: 34,
        period: const Duration(milliseconds: 3600),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppTheme.premiumGoldGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.pGoldSoft, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.pGoldDeep.withValues(alpha: 0.40),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: -1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 15,
                color: Colors.black,
              ),
              const SizedBox(width: 4),
              Text(
                isAr ? 'PRO (${provider.nfi(credits)} رصيد)' : 'PRO ($credits credits)',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isServiceDisabled(AppDataProvider provider, String tag) {
    switch (tag) {
      case 'service_route':
      case 'service_stats':
        return !provider.hasChosenDestination;
      default:
        return false;
    }
  }

  VoidCallback? _handlerFor(BuildContext context, String tag, bool isAr) {
    final provider = AppDataProvider.instance;
    switch (tag) {
      case 'service_route':
      // Disable route button until destination is chosen
        if (!provider.hasChosenDestination) return null;
        return _openGoogleMapsRoute;
      case 'service_fuel':
        return () => _openFuelStations(isAr);
      case 'service_restaurant':
        return () => _openRestaurants(isAr);
      case 'service_checklist':
        return () => _openChecklist(context, isAr);
      case 'service_expenses':
        return () => _openExpenses(context, isAr);
      case 'service_emergency':
        return () => _openEmergency(context, isAr);
      case 'service_photos':
        return () => _openPhotos(context, isAr);
      case 'service_stats':
        if (!provider.hasChosenDestination) return null;
        return () => _openTripStatistics(context, isAr);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.horizontalPadding(context);
    final crossAxisCount = Responsive.gridCrossAxisCount(context);
    final childAspectRatio = Responsive.gridChildAspectRatio(context);

    return ListenableBuilder(
      listenable: AppDataProvider.instance,
      builder: (context, _) {
        final provider = AppDataProvider.instance;
        final isAr = provider.language == 'ar';
        final services = _getServices(isAr);

        return ResponsiveCenter(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                  child: Column(
                    crossAxisAlignment:
                    isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // ── Compact Greeting & Credits Badge ──
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isAr
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(isAr),
                                  style: isAr
                                      ? GoogleFonts.tajawal(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        )
                                      : GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                ),
                                const SizedBox(height: AppTheme.spacingXs),
                                Text(
                                  provider.hasChosenDestination
                                      ? (isAr
                                      ? 'رحلتنا إلى ${provider.destinationCityName}'
                                      : 'Wejhaty to ${provider.destinationCityName}')
                                      : (isAr ? 'رحلتنا' : 'Wejhaty'),
                                  style: isAr
                                      ? GoogleFonts.tajawal(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        )
                                      : GoogleFonts.manrope(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          _buildCreditsBadge(context, provider, isAr),
                          const SizedBox(width: 8),
                          if (provider.isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            IconButton(
                              onPressed: provider.refresh,
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              tooltip: isAr ? 'تحديث' : 'Refresh',
                              padding: const EdgeInsets.all(AppTheme.spacingXs),
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),

                      // ── Location & Date Row ──
                      if (provider.location != null) ...[
                        Wrap(
                          spacing: AppTheme.spacingXs,
                          runSpacing: AppTheme.spacingXs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _LocationChip(
                              lat: provider.location!.latitude,
                              lon: provider.location!.longitude,
                              cityName: provider.weather?.cityName,
                              cityNameAr: provider.weather?.cityNameAr,
                              isAr: isAr,
                            ),
                            _DateTimeChip(isAr: isAr),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                      ],

                      // ── Error banner ──
                      if (provider.error != null && !provider.isLoading)
                        _ErrorBanner(
                          message: provider.error!,
                          onRetry: provider.refresh,
                          isAr: isAr,
                        ),

                      // ── Default-location notice ──
                      // Shown when no GPS/manual location is available and
                      // the app has fallen back to Saudi Arabia by default.
                      if (provider.isDefaultLocation && provider.error == null && !provider.isLoading)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                            vertical: AppTheme.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: AppTheme.spacingSm),
                              Expanded(
                                child: Text(
                                  isAr
                                      ? 'لم يتم تحديد موقعك — يتم عرض السعودية كموقع افتراضي.'
                                      : 'Location not detected — showing Saudi Arabia as the default.',
                                  style: isAr
                                      ? GoogleFonts.tajawal(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                        )
                                      : GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Weather & Prayer ──
                      if (provider.isLoading && !provider.hasData)
                        _LoadingSkeleton()
                      else ...[
                        if (provider.weather != null)
                          _WeatherCard(weather: provider.weather!, isAr: isAr),
                        if (provider.weather != null &&
                            provider.prayerTimes != null)
                          const SizedBox(height: AppTheme.spacingMd),
                        if (provider.prayerTimes != null)
                          _PrayerTimesCard(times: provider.prayerTimes!, isAr: isAr),
                      ],

                      const SizedBox(height: AppTheme.spacingLg),
                      // ── Trip Status ──
                      _buildTripStatusCard(provider, isAr),
                      const SizedBox(height: 24),

                      // ── Services Header ──
                      Text(
                        isAr ? 'الخدمات' : 'Services',
                        style: isAr
                            ? GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              )
                            : GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      // ── Banner Ad ──
                      const BannerAdWidget(),
                      const NativeAdWidget(),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: AppTheme.spacingMd,
                    crossAxisSpacing: AppTheme.spacingMd,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final service = services[index];
                      final provider = AppDataProvider.instance;
                      final isDisabled = _isServiceDisabled(provider, service.tag);

                      // A single, restrained fade-in on first build reads as
                      // a normal app loading its content — not a bouncy,
                      // "generated demo" entrance animation.
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 220 + index * 25),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: isDisabled ? 0.5 : value,
                            child: child,
                          );
                        },
                        child: ServiceCard(
                          title: service.title,
                          subtitle: isDisabled
                              ? (isAr ? 'اختر وجهة أولاً' : 'Choose destination first')
                              : service.subtitle,
                          icon: service.icon,
                          color: service.color,
                          heroTag: service.tag,
                          onTap: _handlerFor(context, service.tag, isAr),
                        ),
                      );
                    },
                    childCount: services.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripStatusCard(AppDataProvider provider, bool isAr) {
    // Show "Please choose your route location" if user hasn't chosen a destination yet
    if (!provider.hasChosenDestination) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1),
        ),
        child: InkWell(
          onTap: () => _showDestinationSettings(context, isAr),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'الرجاء اختيار موقع المسار' : 'Please choose your route location',
                      style: isAr
                          ? GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            )
                          : GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      isAr ? 'اضغط هنا لتحديد الوجهة' : 'Tap here to set your destination',
                      style: isAr
                          ? GoogleFonts.tajawal(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            )
                          : GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                    ),
                  ],
                ),
              ),
              if (isAr)
                const SizedBox(width: AppTheme.spacingMd),
              Icon(
                isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                size: 18,
              ),
            ],
          ),
        ),
      );
    }

    // Show regular trip status when destination is chosen
    String countryName = isAr ? 'الإمارات' : 'United Arab Emirates';
    int remainingKm = 2000;
    int completionPercent = 0;

    // Use TripProgressService for real-time tracking if active
    if (_tracker.isTracking) {
      // Use live GPS position from tracker for real-time remaining distance
      final currentLat = _tracker.currentPosition?.latitude ??
          provider.location?.latitude ??
          provider.manualLat ??
          provider.destinationLat;
      final currentLon = _tracker.currentPosition?.longitude ??
          provider.location?.longitude ??
          provider.manualLon ??
          provider.destinationLon;
      final distanceInMeters = Geolocator.distanceBetween(
        currentLat,
        currentLon,
        provider.destinationLat,
        provider.destinationLon,
      );
      remainingKm = (distanceInMeters / 1000).round();

      // Calculate completion based on total estimated distance
      final totalDistance = math.max(1.0, _tracker.traveledKm + remainingKm);
      completionPercent = ((_tracker.traveledKm / totalDistance) * 100).round();
    } else if (provider.isTripActive) {
      // Use saved trip statistics
      remainingKm = provider.remainingDistanceKm?.round() ?? 2000;
      completionPercent = provider.tripCompletionPercent;
    } else if (provider.location != null) {
      // Fallback to current location if trip not started
      final lat = provider.location!.latitude;
      final lon = provider.location!.longitude;
      final distanceInMeters = Geolocator.distanceBetween(
        lat,
        lon,
        provider.destinationLat,
        provider.destinationLon,
      );
      remainingKm = (distanceInMeters / 1000).round();
      final double baseDistance = math.max(2000.0, remainingKm.toDouble());
      completionPercent = math.max(0, math.min(100, ((baseDistance - remainingKm) / baseDistance * 100).round()));
    }

    if (provider.weather != null && provider.weather!.countryName.isNotEmpty) {
      countryName = provider.weather!.countryName;
    }

    final countryString = isAr ? 'متواجد حالياً في $countryName' : 'Currently in $countryName';
    final remainingString = isAr
        ? 'متبقي ${provider.nfi(remainingKm)} كم للوصول إلى ${provider.destinationCityName}'
        : '${provider.nfi(remainingKm)} km remaining to ${provider.destinationCityName}';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showDestinationSettings(context, isAr),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Row(
              children: [
                if (isAr) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.nfi(completionPercent)}%',
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        isAr ? 'مكتمل' : 'complete',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
                if (!isAr) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _neutralFill(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: _neutralBorder(context), width: 1),
                    ),
                    child: Icon(
                      Icons.navigation_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        countryString,
                        style: isAr
                            ? GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              )
                            : GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        remainingString,
                        style: isAr
                            ? GoogleFonts.tajawal(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              )
                            : GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                      ),
                    ],
                  ),
                ),
                if (isAr) ...[
                  const SizedBox(width: AppTheme.spacingMd),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _neutralFill(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: _neutralBorder(context), width: 1),
                    ),
                    child: Transform.rotate(
                      angle: -math.pi / 2,
                      child: Icon(
                        Icons.navigation_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
                if (!isAr) ...[
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${provider.nfi(completionPercent)}%',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'complete',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Trip control buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _tracker.isTracking ? null : () async {
                    final cost = provider.getNextTripStatCost();
                    if (provider.credits < cost) {
                      showSubscriptionSheet(context, isAr: isAr);
                      return;
                    }
                    provider.consumeTripStatCredits();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isAr
                              ? 'تم بدء الرحلة وخصم $cost رصيد (المتبقي: ${provider.credits})'
                              : 'Trip started! Used $cost credits (${provider.credits} remaining)',
                          style: isAr
                              ? GoogleFonts.tajawal(fontSize: 13)
                              : GoogleFonts.inter(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    _tracker.start(
                      destLat: provider.destinationLat,
                      destLon: provider.destinationLon,
                    );
                    provider.startTrip();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    isAr ? 'بدء الرحلة' : 'Start Trip',
                    style: isAr
                        ? GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600)
                        : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tracker.isTracking
                        ? Colors.grey.withValues(alpha: 0.3)
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
              if (_tracker.isTracking) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Stop tracking immediately
                      _tracker.stop();
                      _tracker.reset();

                      // Force an immediate rebuild so the UI (Start/Stop
                      // buttons, progress card, etc.) reflects the stopped
                      // state right away instead of waiting for the next
                      // stream event or screen change.
                      if (mounted) setState(() {});

                      // Show feedback immediately
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAr ? 'تم إيقاف الرحلة وحفظها في السجل' : 'Trip stopped and saved to history',
                            style: isAr
                                ? GoogleFonts.tajawal(fontSize: 13)
                                : GoogleFonts.inter(fontSize: 13),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      // Calculate stats and save to history in background
                      TripStatsService.instance.compute(
                        originLat: provider.location?.latitude ?? provider.manualLat ?? provider.destinationLat,
                        originLon: provider.location?.longitude ?? provider.manualLon ?? provider.destinationLon,
                        destLat: provider.destinationLat,
                        destLon: provider.destinationLon,
                      ).then((stats) {
                        TripHistoryService.instance.add(
                          name: provider.destinationCityName,
                          startedAt: _tracker.tripStartTime ?? DateTime.now(),
                          arrivedAt: DateTime.now(),
                          destinationCityName: provider.destinationCityName,
                          traveledKm: _tracker.traveledKm,
                          roadKm: stats.estimatedRoadKm,
                          fuelLiters: stats.fuelLiters,
                          fuelCost: stats.fuelCost,
                          fuelCurrency: stats.fuelCurrency,
                          fuelStationStops: stats.fuelStationStops,
                          drivingDuration: _tracker.drivingDuration,
                          restingDuration: _tracker.restingDuration,
                          averageSpeedKmh: _tracker.liveAverageSpeedKmh,
                          completed: false, // Manually stopped
                        );
                      });
                    },
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: Text(
                      isAr ? 'إيقاف' : 'Stop',
                      style: isAr
                          ? GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600)
                          : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Location Chip ────────────────────────────────────────────────────────────

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.lat,
    required this.lon,
    this.cityName,
    this.cityNameAr,
    required this.isAr,
  });

  final double lat;
  final double lon;
  final String? cityName;
  final String? cityNameAr;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final p = AppDataProvider.instance;
    final localized =
        (isAr && (cityNameAr?.isNotEmpty ?? false)) ? cityNameAr : cityName;
    final label = localized ??
        '${p.nfd(lat, decimals: 3)}°, ${p.nfd(lon, decimals: 3)}°';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
      decoration: BoxDecoration(
        color: _neutralFill(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: _neutralBorder(context), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded,
              size: 14, color: AppColors.primary),
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            label,
            style: isAr
                ? GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  )
                : GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Date & Time Chip (live clock, updates every second) ──────────────────────

class _DateTimeChip extends StatefulWidget {
  const _DateTimeChip({required this.isAr});

  final bool isAr;

  @override
  State<_DateTimeChip> createState() => _DateTimeChipState();
}

class _DateTimeChipState extends State<_DateTimeChip> {
  late DateTime _now;
  Timer? _ticker;
  String? _timezone;

  static const _hijriMonthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  static const _hijriMonthsEn = [
    'Muharram', 'Safar', "Rabi' I", "Rabi' II", 'Jumada I', 'Jumada II',
    'Rajab', "Sha'ban", 'Ramadan', 'Shawwal', "Dhu al-Qi'dah", 'Dhu al-Hijjah',
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _updateTimezone();
    // Tick every second so the seconds digits stay live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _updateTimezone() {
    final provider = AppDataProvider.instance;
    if (provider.prayerTimes != null && provider.prayerTimes!.timezone.isNotEmpty) {
      _timezone = provider.prayerTimes!.timezone;
    }
  }

  @override
  void didUpdateWidget(_DateTimeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTimezone();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Widget _buildPill(BuildContext context, IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
      decoration: BoxDecoration(
        color: _neutralFill(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: _neutralBorder(context), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              // Tabular figures keep the seconds from jittering the pill width.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final p = AppDataProvider.instance;

    // Get location-based time if timezone is available
    DateTime now = _now;
    if (_timezone != null) {
      try {
        final location = tz.getLocation(_timezone!);
        now = tz.TZDateTime.now(location);
      } catch (e) {
        // Fallback to local time if timezone lookup fails
        now = DateTime.now();
      }
    }

    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;

    final minute = _twoDigits(now.minute);
    final second = _twoDigits(now.second);

    final period = now.hour < 12
        ? (isAr ? 'ص' : 'AM')
        : (isAr ? 'م' : 'PM');
    final timeLabel = '${p.nfi(hour12)}:$minute:$second $period';

    final hijri = HijriCalendar.fromDate(now);
    final hijriLabel = isAr
        ? '${p.nfi(hijri.hDay)} ${_hijriMonthsAr[hijri.hMonth - 1]} ${p.nfi(hijri.hYear)}هـ'
        : '${p.nfi(hijri.hDay)} ${_hijriMonthsEn[hijri.hMonth - 1]} ${p.nfi(hijri.hYear)} AH';
    final gregorianLabel = isAr
        ? '${p.nfi(now.day)}/${p.nfi(now.month)}/${p.nfi(now.year)}م'
        : '${p.nfi(now.day)}/${p.nfi(now.month)}/${p.nfi(now.year)} AD';
    final dateLabel = '$gregorianLabel  •  $hijriLabel';

    return Wrap(
      spacing: AppTheme.spacingXs,
      runSpacing: AppTheme.spacingXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildPill(context, Icons.access_time_rounded, timeLabel, AppColors.warning),
        _buildPill(context, Icons.calendar_today_rounded, dateLabel, AppColors.primary),
      ],
    );
  }
}

// ─── Weather Card ─────────────────────────────────────────────────────────────

class _WeatherCard extends StatefulWidget {
  const _WeatherCard({required this.weather, required this.isAr});

  final WeatherData weather;
  final bool isAr;

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 950),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Staggered entrance for card sections: each [index] fades and slides in
  /// slightly after the previous one, giving the card a cascading reveal.
  Widget _stagger(int index, Widget child) {
    final start = (0.10 + index * 0.16).clamp(0.0, 0.85);
    final interval = Interval(
      start,
      (start + 0.40).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceController, curve: interval),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.22),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _entranceController, curve: interval)),
        child: child,
      ),
    );
  }

  String _translateCondition(String englishLabel) {
    if (!widget.isAr) return englishLabel;
    switch (englishLabel) {
      case 'Clear Sky': return 'صافٍ';
      case 'Partly Cloudy': return 'غائم جزئياً';
      case 'Overcast': return 'غائم كلياً';
      case 'Foggy': return 'ضبابي';
      case 'Drizzle': return 'رذاذ خفيف';
      case 'Rainy': return 'أمطار';
      case 'Snowy': return 'ثلوج';
      case 'Thunderstorm': return 'عواصف رعدية';
      default: return englishLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppDataProvider.instance;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Weather-condition background photo
                Positioned.fill(
                  child: Image.asset(
                    widget.weather.backgroundImagePath,
                    fit: BoxFit.cover,
                  ),
                ),
                // Cinematic gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                // Soft rim light along the top edge
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.18],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: _buildContent(context, p),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppDataProvider p) {
    // Explicit Directionality: every Row/Column inside mirrors naturally
    // (start = left in English, right in Arabic) with no per-child hacks.
    return Directionality(
      textDirection: widget.isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stagger(0, _buildHeader(context, p)),
          const SizedBox(height: 22),
          _stagger(1, _buildTemperatureSection(context, p)),
          const SizedBox(height: 22),
          _stagger(2, _buildDetailBoxes(context, p)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppDataProvider p) {
    return Row(
      children: [
        _AnimatedWeatherIcon(lottiePath: widget.weather.lottiePath),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            // `start` mirrors automatically under the card's Directionality
            // (left in English, right in Arabic) — title and city hug the
            // weather icon in both languages.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arabic must use the app's Arabic font — Inter/Manrope have
              // no Arabic glyphs and their fallback rendering (plus
              // letterSpacing) breaks the letter joining.
              Text(
                widget.isAr ? 'الطقس' : 'Weather',
                style: widget.isAr
                    ? GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      )
                    : GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 1.2,
                      ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      widget.weather.cityName.isNotEmpty
                          ? widget.weather.cityNameFor(widget.isAr)
                          : (widget.isAr ? 'الموقع الحالي' : 'Current Location'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.isAr
                          ? GoogleFonts.tajawal(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )
                          : GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureSection(BuildContext context, AppDataProvider p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _AnimatedTemperature(
          temperature: widget.weather.temperature,
          unit: widget.isAr ? 'م' : 'C',
          isAr: widget.isAr,
          formatter: (v) => p.nfi(v.round()),
        ),
        const Spacer(),
        _ConditionInfo(
          condition: _translateCondition(widget.weather.conditionLabel),
          feelsLike: widget.isAr
              ? 'الشعور ${p.nfi(widget.weather.feelsLike.round())}°م'
              : 'Feels like ${p.nfi(widget.weather.feelsLike.round())}°C',
          alignEnd: widget.isAr,
          isAr: widget.isAr,
        ),
      ],
    );
  }

  Widget _buildDetailBoxes(BuildContext context, AppDataProvider p) {
    final boxes = [
      (
        icon: Icons.water_drop_outlined,
        value: '${p.nfi(widget.weather.humidity)}%',
        label: widget.isAr ? 'الرطوبة' : 'Humidity',
        color: const Color(0xFF4FC3F7),
      ),
      (
        icon: Icons.air_rounded,
        value: widget.isAr
            ? '${p.nfw(widget.weather.windSpeed)} كم/س'
            : '${p.nfw(widget.weather.windSpeed)} km/h',
        label: widget.isAr ? 'الرياح' : 'Wind',
        color: const Color(0xFF81C784),
      ),
      (
        icon: Icons.cloud_outlined,
        value: '${p.nfi(widget.weather.cloudCover)}%',
        label: widget.isAr ? 'الغيوم' : 'Clouds',
        color: const Color(0xFF90CAF9),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < boxes.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _GlassBox(
              icon: boxes[i].icon,
              value: boxes[i].value,
              label: boxes[i].label,
              color: boxes[i].color,
              delayMs: 350 + i * 150,
              isAr: widget.isAr,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedWeatherIcon extends StatefulWidget {
  final String lottiePath;

  const _AnimatedWeatherIcon({required this.lottiePath});

  @override
  State<_AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<_AnimatedWeatherIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Lottie.asset(
          widget.lottiePath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _AnimatedTemperature extends StatefulWidget {
  final double temperature;
  final String unit;
  final bool isAr;
  final String Function(double value) formatter;

  const _AnimatedTemperature({
    required this.temperature,
    required this.unit,
    required this.isAr,
    required this.formatter,
  });

  @override
  State<_AnimatedTemperature> createState() => _AnimatedTemperatureState();
}

class _AnimatedTemperatureState extends State<_AnimatedTemperature>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _countAnimation = Tween<double>(
      begin: widget.temperature * 0.35,
      end: widget.temperature,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _countAnimation.value.round();
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            textDirection:
                widget.isAr ? TextDirection.rtl : TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.formatter(value.toDouble())}°',
                style: widget.isAr
                    ? GoogleFonts.tajawal(
                        fontSize: 58,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : GoogleFonts.manrope(
                        fontSize: 58,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: -2.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  widget.unit,
                  style: widget.isAr
                      ? GoogleFonts.tajawal(
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.75),
                        )
                      : GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConditionInfo extends StatelessWidget {
  final String condition;
  final String feelsLike;
  final bool alignEnd;
  final bool isAr;

  const _ConditionInfo({
    required this.condition,
    required this.feelsLike,
    this.alignEnd = false,
    this.isAr = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.20),
                Colors.white.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Text(
            condition,
            style: isAr
                ? GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )
                : GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          feelsLike,
          style: isAr
              ? GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                )
              : GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
        ),
      ],
    );
  }
}

class _GlassBox extends StatefulWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final int delayMs;
  final bool isAr;

  const _GlassBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.delayMs = 0,
    this.isAr = false,
  });

  @override
  State<_GlassBox> createState() => _GlassBoxState();
}

class _GlassBoxState extends State<_GlassBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(widget.icon, size: 16, color: widget.color),
              ),
              const SizedBox(height: 8),
              Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.isAr
                    ? GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )
                    : GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.isAr
                    ? GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.65),
                      )
                    : GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 0.3,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Prayer Times Card (live "next prayer in" countdown) ─────────────────────

class _PrayerTimesCard extends StatefulWidget {
  const _PrayerTimesCard({required this.times, required this.isAr});

  final PrayerTimesData times;
  final bool isAr;

  @override
  State<_PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<_PrayerTimesCard>
    with TickerProviderStateMixin {
  Timer? _ticker;
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Re-render every second so the "next prayer in" countdown stays live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Staggered entrance for card sections, matching the weather card.
  Widget _stagger(int index, Widget child) {
    final start = (0.10 + index * 0.16).clamp(0.0, 0.85);
    final interval = Interval(
      start,
      (start + 0.40).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceController, curve: interval),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.22),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _entranceController, curve: interval)),
        child: child,
      ),
    );
  }

  String _translatePrayerName(String name) {
    if (!widget.isAr) return name;
    switch (name) {
      case 'Fajr': return 'الفجر';
      case 'Sunrise': return 'الشروق';
      case 'Dhuhr': return 'الظهر';
      case 'Asr': return 'العصر';
      case 'Maghrib': return 'المغرب';
      case 'Isha': return 'العشاء';
      default: return name;
    }
  }

  /// Countdown to [next]'s prayer time, formatted "H:MM:SS" (or "MM:SS"
  /// once under an hour away).
  String? _countdownLabel(PrayerTime? next) {
    if (next == null) return null;
    // Use timeToday to get the prayer time adjusted to today's date in location timezone
    final DateTime target = next.timeToday;
    // Use the prayer's timezone-aware current time for accurate countdown
    final diff = target.difference(next.locationNow);
    if (diff.isNegative) return null;

    final p = AppDataProvider.instance;
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    if (h > 0) {
      return '${p.nfi(h)}:${_twoDigits(m)}:${_twoDigits(s)}';
    }
    return '${_twoDigits(m)}:${_twoDigits(s)}';
  }

  /// 0..1 progress through the current prayer period (from the last prayer
  /// that passed to the next upcoming one). Null when it can't be computed.
  double? _periodProgress(PrayerTimesData times) {
    final current = times.currentPrayer;
    final next = times.nextPrayer;
    if (current == null || next == null) return null;
    final start = current.timeToday.millisecondsSinceEpoch;
    final end = next.timeToday.millisecondsSinceEpoch;
    if (end <= start) return null;
    final now = current.locationNow.millisecondsSinceEpoch;
    return ((now - start) / (end - start)).clamp(0.0, 1.0);
  }

  static const Color _amber = Color(0xFFFFC96B);

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final times = widget.times;
    final next = times.nextPrayer;
    final progress = _periodProgress(times);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Time-of-day background photo — swaps automatically as each
                // prayer period starts, driven by the same 1-second ticker
                // that powers the "next prayer in" countdown below.
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Image.asset(
                      _bannerAssetByPeriod[_currentPeriodName(times)]!,
                      key: ValueKey(_currentPeriodName(times)),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      // If a banner file is missing/misnamed, fail quietly
                      // instead of taking the whole screen down.
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: AppColors.prayerCard.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
                // Darken for text contrast, regardless of app theme.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.70),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    // Explicit Directionality: rows/columns mirror
                    // naturally (start = right in Arabic).
                    child: Directionality(
                      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _stagger(0, _buildHeader(isAr, next)),
                          if (progress != null) ...[
                            const SizedBox(height: AppTheme.spacingMd),
                            _stagger(1, _buildPeriodProgress(isAr, times, progress)),
                          ],
                          const SizedBox(height: AppTheme.spacingMd),
                          _stagger(2, _buildPrayerList(isAr, times, next)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAr, PrayerTime? next) {
    final iconButton = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.mosque_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
    final titleCityColumn = Expanded(
      child: Column(
        // `start` mirrors automatically: hugs the icon in English, hugs the
        // next-prayer block in Arabic.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'أوقات الصلاة' : 'Prayer Times',
            style: isAr
                ? GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  )
                : GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 1.2,
                  ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  widget.times.cityNameFor(isAr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isAr
                      ? GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )
                      : GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Both languages: icon (left) - text (middle) - next-prayer (right)
    // Use LTR directionality for both to maintain consistent order
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          iconButton,
          const SizedBox(width: AppTheme.spacingMd),
          titleCityColumn,
          if (next != null) _buildNextPrayerBlock(isAr, next),
        ],
      ),
    );
  }

  Widget _buildNextPrayerBlock(bool isAr, PrayerTime next) {
    final countdown = _countdownLabel(next);
    return Column(
      // `start` mirrors: right-aligned in Arabic, left-aligned in English.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAr ? 'الصلاة القادمة' : 'NEXT PRAYER',
          style: isAr
              ? GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _amber,
                )
              : GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _amber,
                  letterSpacing: 1.0,
                ),
        ),
        const SizedBox(height: 2),
        Text(
          isAr ? _translatePrayerName(next.name) : next.name,
          style: isAr
              ? GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )
              : GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
        ),
        if (countdown != null) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live pulsing dot
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _amber.withValues(alpha: _pulseAnimation.value),
                      boxShadow: [
                        BoxShadow(
                          color: _amber.withValues(
                            alpha: 0.5 * _pulseAnimation.value,
                          ),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'خلال $countdown' : 'in $countdown',
                  style: isAr
                      ? GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )
                      : GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodProgress(bool isAr, PrayerTimesData times, double progress) {
    final current = times.currentPrayer!;
    final next = times.nextPrayer!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                _translatePrayerName(current.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isAr
                    ? GoogleFonts.tajawal(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                      )
                    : GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.4,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _translatePrayerName(next.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isAr
                  ? GoogleFonts.tajawal(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _amber,
                    )
                  : GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _amber,
                      letterSpacing: 0.4,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: Container(
            height: 4,
            color: Colors.white.withValues(alpha: 0.12),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                alignment:
                    isAr ? Alignment.centerRight : Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB74D), _amber],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _amber.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerList(bool isAr, PrayerTimesData times, PrayerTime? next) {
    return Row(
      children: times.allPrayers
          .map(
            (p) => Expanded(
              child: _PrayerItem(
                prayer: p,
                isNext: p == next,
                isAr: isAr,
                translatedName: _translatePrayerName(p.name),
                pulse: p == next ? _pulseAnimation : null,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PrayerItem extends StatelessWidget {
  const _PrayerItem({
    required this.prayer,
    required this.isNext,
    required this.isAr,
    required this.translatedName,
    this.pulse,
  });

  final PrayerTime prayer;
  final bool isNext;
  final bool isAr;
  final String translatedName;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final isPast = prayer.isPast;

    final iconColor = isNext
        ? const Color(0xFFFFC96B)
        : isPast
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.85);

    final nameColor = isNext
        ? Colors.white
        : isPast
            ? Colors.white.withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.80);

    Widget iconChip() {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isNext
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x59FFB74D), // amber 35%
                    Color(0x26FFB74D), // amber 15%
                  ],
                )
              : null,
          color: !isNext ? Colors.white.withValues(alpha: isPast ? 0.05 : 0.10) : null,
          border: Border.all(
            color: isNext
                ? const Color(0x80FFB74D) // amber 50%
                : Colors.white.withValues(alpha: isPast ? 0.10 : 0.16),
            width: isNext ? 1.4 : 1,
          ),
          boxShadow: isNext
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.30),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(prayer.icon, size: 19, color: iconColor),
      );
    }

    return Column(
      children: [
        if (pulse != null)
          AnimatedBuilder(
            animation: pulse!,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + 0.05 * pulse!.value,
              child: child,
            ),
            child: iconChip(),
          )
        else
          iconChip(),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          translatedName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isAr
              ? GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  color: nameColor,
                )
              : GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  color: nameColor,
                ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            gradient: isNext
                ? const LinearGradient(
                    colors: [Color(0x33FFB74D), Color(0x1AFFB74D)],
                  )
                : null,
            color: !isNext ? Colors.white.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: isNext
                ? Border.all(color: const Color(0x4DFFB74D), width: 1)
                : null,
          ),
          child: Text(
            // PrayerService always emits Western digits; localize here so it
            // respects the Arabic Numerals setting.
            _localizeDigits(prayer.formattedTime),
            style: isAr
                ? GoogleFonts.tajawal(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                  )
                : GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: nameColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
          ),
        ),
      ],
    );
  }
}

// ─── Loading Skeleton ─────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatefulWidget {
  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final opacity = 0.04 + _shimmer.value * 0.08;
        return Column(
          children: [
            _SkeletonBox(height: 100, opacity: opacity, radius: AppTheme.radiusLg),
            const SizedBox(height: AppTheme.spacingMd),
            _SkeletonBox(height: 100, opacity: opacity, radius: AppTheme.radiusLg),
          ],
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.opacity,
    required this.radius,
  });

  final double height;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: opacity)
            : Colors.black.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.isAr,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              message,
              style: isAr
                  ? GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    )
                  : GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isAr ? 'إعادة المحاولة' : 'Retry',
              style: isAr
                  ? GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    )
                  : GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Destination Bottom Sheet ─────────────────────────────────────────────────

class _DestinationBottomSheet extends StatefulWidget {
  const _DestinationBottomSheet({
    required this.isAr,
    required this.weatherService,
  });

  final bool isAr;
  final WeatherService weatherService;

  @override
  State<_DestinationBottomSheet> createState() => _DestinationBottomSheetState();
}

class _DestinationBottomSheetState extends State<_DestinationBottomSheet> {
  final _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;

  final List<({String name, String nameAr, double lat, double lon})> _suggestions = const [
    (name: 'Makkah', nameAr: 'مكة المكرمة', lat: 21.4225, lon: 39.8262),
    (name: 'Medina', nameAr: 'المدينة المنورة', lat: 24.4672, lon: 39.6111),
    (name: 'Riyadh', nameAr: 'الرياض', lat: 24.7136, lon: 46.6753),
    (name: 'Dubai', nameAr: 'دبي', lat: 25.2048, lon: 55.2708),
    (name: 'Amman', nameAr: 'عمان', lat: 31.9539, lon: 35.9106),
  ];

  void _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await widget.weatherService.searchCities(
      query,
      lang: widget.isAr ? 'ar' : 'en',
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
        widget.isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            widget.isAr ? 'اختر وجهة السفر' : 'Select Trip Destination',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),

          // Quick recommendations
          Text(
            widget.isAr ? 'الوجهات الشائعة' : 'Popular Destinations',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((city) {
              final name = widget.isAr ? city.nameAr : city.name;
              return ActionChip(
                label: Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                backgroundColor: _neutralFill(context),
                side: BorderSide(color: _neutralBorder(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                onPressed: () {
                  AppDataProvider.instance.setDestination(
                    cityName: name,
                    latitude: city.lat,
                    longitude: city.lon,
                  );
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  widget.isAr ? 'أو ابحث عن وجهة مخصصة' : 'Or Search Custom Destination',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.isAr ? 'ابحث بالإنجليزية أو العربية (مثال: مكة)' : 'Search city (e.g. Mecca, Amman)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                  });
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search Results
          if (_isSearching)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(Icons.location_city_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    title: Text(
                      result.name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      result.displayName,
                      style: GoogleFonts.inter(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      AppDataProvider.instance.setDestination(
                        cityName: result.name,
                        latitude: result.latitude,
                        longitude: result.longitude,
                      );
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            )
          else if (_searchController.text.trim().length >= 2)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.isAr ? 'لم يتم العثور على نتائج' : 'No destinations found',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}