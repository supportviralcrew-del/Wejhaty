import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/checklist_service.dart';
import 'package:tripproject/services/expenses_service.dart';
import 'package:tripproject/services/photos_service.dart';
import 'package:tripproject/services/trip_stats_service.dart';
import 'package:tripproject/services/trip_history_service.dart';
import 'package:tripproject/screens/home/widgets/trip_history_sheet.dart';
import 'package:tripproject/screens/subscription/subscription_sheet.dart';

class TripStatisticsSheet extends StatefulWidget {
  const TripStatisticsSheet({super.key, required this.isAr});

  final bool isAr;

  @override
  State<TripStatisticsSheet> createState() => _TripStatisticsSheetState();
}

class _TripStatisticsSheetState extends State<TripStatisticsSheet> {
  late Future<TripStatistics> _future;

  final _tracker = TripProgressService.instance;
  StreamSubscription<double>? _distanceSub;
  StreamSubscription<void>? _updateSub;
  StreamSubscription<void>? _arrivalSub;
  StreamSubscription<void>? _expiredSub;

  @override
  void initState() {
    super.initState();
    final provider = AppDataProvider.instance;
    final origin = provider.location;
    final originLat = origin?.latitude ?? provider.manualLat;
    final originLon = origin?.longitude ?? provider.manualLon;
    _future = TripStatsService.instance.compute(
      originLat: originLat ?? provider.destinationLat,
      originLon: originLon ?? provider.destinationLon,
      destLat: provider.destinationLat,
      destLon: provider.destinationLon,
    );

    // Live progress (distance traveled, driving/rest time, average
    // speed, stop count) only exists once the driver explicitly taps
    // "Create trip record" — see _startTripRecord. Until then every
    // one of those values reads 0 straight off the tracker.
    _distanceSub = _tracker.onTraveledDistanceChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _updateSub = _tracker.onUpdate.listen((_) {
      if (mounted) setState(() {});
    });
    _arrivalSub = _tracker.onArrival.listen(
      (_) => _onTripEnded(completed: true),
    );
    _expiredSub = _tracker.onExpired.listen(
      (_) => _onTripEnded(completed: false),
    );
  }

  void _startTripRecord() {
    final provider = AppDataProvider.instance;
    final isAr = widget.isAr;

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
              ? 'تم إنشاء سجل الرحلة وخصم $cost رصيد (المتبقي: ${provider.credits})'
              : 'Trip record started! Used $cost credits (${provider.credits} remaining)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _tracker.start(
        destLat: provider.destinationLat,
        destLon: provider.destinationLon,
      );
      provider.startTrip();
    });
  }

  Future<void> _onTripEnded({required bool completed}) async {
    final stats = await _future;
    final provider = AppDataProvider.instance;
    final isAr = widget.isAr;
    await TripHistoryService.instance.add(
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
      completed: completed,
    );
    _tracker.reset();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completed
                ? (isAr
                      ? 'وصلت إلى ${provider.destinationCityName} — تم حفظ الرحلة في السجل'
                      : 'Arrived at ${provider.destinationCityName} — trip saved to history')
                : (isAr
                      ? 'مرت أسبوعين على سجل الرحلة — تم إيقافه وحفظه في السجل'
                      : 'This trip record ran for 2 weeks — closed and saved to history'),
          ),
        ),
      );
    }
  }

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripHistorySheet(isAr: widget.isAr),
    );
  }

  @override
  void dispose() {
    _distanceSub?.cancel();
    _updateSub?.cancel();
    _arrivalSub?.cancel();
    _expiredSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final provider = AppDataProvider.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final checklistDone = ChecklistService.instance.doneCount;
    final checklistTotal = ChecklistService.instance.totalCount;
    final expensesTotals = ExpensesService.instance.totalsByCurrency;
    final photoCount = PhotosService.instance.photoPaths.length;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(
            color: isDark
                ? AppColors.glassBorder
                : Colors.black.withValues(alpha: 0.1),
          ),
          boxShadow: AppTheme.cardShadow(isDark: isDark),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.statsCard.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.statsCard,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAr ? 'إحصائيات الرحلة' : 'Trip Statistics',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history_rounded),
                  tooltip: isAr ? 'سجل الرحلات' : 'Trip history',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.statsCard.withValues(
                      alpha: 0.12,
                    ),
                    foregroundColor: AppColors.statsCard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: FutureBuilder<TripStatistics>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.statsCard,
                        ),
                      ),
                    );
                  }

                  final stats = snapshot.data;
                  final isLiveActive = _tracker.isTracking || provider.isTripActive;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isLiveActive)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.18)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAr ? 'ابدأ الرحلة لعرض الإحصائيات — جميع القيم 0 حتى البدء' : 'Start trip to see statistics — all values are 0 until started',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (stats?.dataNotice != null && isLiveActive)
                          _NoticeBanner(
                            text: isAr
                                ? 'بعض بيانات المسار (طقس/ارتفاع/موقع/توجيه) لم يتم تحميلها — يتم عرض القيم المتاحة فقط.'
                                : 'Some route data (weather/elevation/locality/routing) couldn\'t be loaded — showing what is available.',
                          ),
                        if (stats != null) ...[
                          _SectionLabel(
                            isAr ? 'المسار' : 'Route',
                            isAr,
                            trailing: _RoutingBadge(
                              isAr: isAr,
                              isLive: stats.isLiveRouting,
                            ),
                          ),
                          _TripRecordBanner(
                            isAr: isAr,
                            isActive: _tracker.isTracking,
                            startedAt: _tracker.tripStartTime,
                            onCreate: _startTripRecord,
                          ),
                          const SizedBox(height: 12),
                          _StatGrid(
                            isAr: isAr,
                            tiles: [
                              _StatTile(
                                icon: Icons.route_rounded,
                                label: stats.isLiveRouting
                                    ? (isAr ? 'المسافة' : 'Distance')
                                    : (isAr ? 'المسافة (تقديري)' : 'Distance (est.)'),
                                value: isLiveActive ? '${provider.nfi(stats.estimatedRoadKm.round())} km' : '0 km',
                                color: AppColors.routeCard,
                              ),
                              _StatTile(
                                icon: Icons.timeline_rounded,
                                label: isAr ? 'المسافة المقطوعة' : 'Distance traveled',
                                value: isLiveActive ? '${provider.nfd(_tracker.traveledKm, decimals: 1)} km' : '0.0 km',
                                color: AppColors.success,
                              ),
                              _StatTile(
                                icon: Icons.timer_rounded,
                                label: isAr ? 'وقت القيادة' : 'Driving time',
                                value: isLiveActive
                                    ? _formatHours(_tracker.drivingDuration.inMinutes / 60, isAr, provider)
                                    : (isAr ? '0 س 0 د' : '0h 0m'),
                                color: AppColors.routeCard,
                              ),
                              _StatTile(
                                icon: Icons.free_breakfast_rounded,
                                label: isAr ? 'وقت الراحة' : 'Rest time',
                                value: isLiveActive
                                    ? _formatHours(_tracker.restingDuration.inMinutes / 60, isAr, provider)
                                    : (isAr ? '0 س 0 د' : '0h 0m'),
                                color: AppColors.fuelCard,
                              ),
                              _StatTile(
                                icon: Icons.schedule_rounded,
                                label: isAr ? 'إجمالي وقت الرحلة' : 'Total trip time',
                                value: isLiveActive
                                    ? _formatHours(_tracker.totalTripDuration.inMinutes / 60, isAr, provider)
                                    : (isAr ? '0 س 0 د' : '0h 0m'),
                                color: AppColors.statsCard,
                              ),
                              _StatTile(
                                icon: Icons.speed_rounded,
                                label: isAr ? 'متوسط السرعة' : 'Average speed',
                                value: isLiveActive ? '${provider.nfi(_tracker.liveAverageSpeedKmh.round())} km/h' : '0 km/h',
                                color: AppColors.routeCard,
                              ),
                              _StatTile(
                                icon: Icons.ev_station_rounded,
                                label: isAr ? 'عدد التوقفات' : 'Stops',
                                value: isLiveActive ? provider.nfi(_tracker.liveStops) : '0',
                                color: AppColors.fuelCard,
                              ),
                            ],
                          ),
                          // ── PREMIUM: Live ETA + real-time speed (subscribed only) ──
                          const SizedBox(height: 16),
                          _PremiumLiveSection(
                            isAr: isAr,
                            provider: provider,
                            stats: stats,
                            tracker: _tracker,
                          ),
                          const SizedBox(height: 16),
                          _SectionLabel(
                            isAr ? 'الوقود والانبعاثات' : 'Fuel & Emissions',
                            isAr,
                          ),
                          _StatGrid(
                            isAr: isAr,
                            tiles: [
                              _StatTile(
                                icon: Icons.local_gas_station_rounded,
                                label: isAr ? 'استهلاك الوقود' : 'Fuel needed',
                                value: isLiveActive ? '${provider.nfd(stats.fuelLiters, decimals: 1)} L' : '0.0 L',
                                color: AppColors.fuelCard,
                              ),
                              _StatTile(
                                icon: Icons.payments_rounded,
                                label: isAr ? 'تكلفة الوقود (تقديري)' : 'Fuel cost (est.)',
                                value: isLiveActive ? '${provider.nfd(stats.fuelCost, decimals: 2)} ${stats.fuelCurrency}' : '0.00 ${stats.fuelCurrency}',
                                color: AppColors.fuelCard,
                              ),
                              _StatTile(
                                icon: Icons.local_gas_station_rounded,
                                label: isAr ? 'محطات الوقود' : 'Fuel stations',
                                value: isLiveActive ? provider.nfi(stats.fuelStationStops) : '0',
                                color: AppColors.fuelCard,
                              ),
                              _StatTile(
                                icon: Icons.eco_rounded,
                                label: isAr ? 'انبعاثات الكربون' : 'CO₂ emissions',
                                value: isLiveActive ? '${provider.nfd(stats.carbonKg, decimals: 1)} kg' : '0.0 kg',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionLabel(isAr ? 'التقييم' : 'Assessment', isAr),
                          _StatGrid(
                            isAr: isAr,
                            tiles: [
                              _StatTile(
                                icon: Icons.terrain_rounded,
                                label: isAr ? 'صعوبة الطريق' : 'Route difficulty',
                                value: isLiveActive ? _difficultyLabel(stats.difficulty, isAr) : '—',
                                color: isLiveActive ? _difficultyColor(stats.difficulty) : AppColors.statsCard.withValues(alpha: 0.4),
                              ),
                              _StatTile(
                                icon: Icons.shield_rounded,
                                label: isAr ? 'مؤشر السلامة' : 'Safety score',
                                value: isLiveActive ? '${provider.nfi(stats.safetyScore)}/100' : '0/100',
                                color: AppColors.success,
                              ),
                              _StatTile(
                                icon: Icons.trending_up_rounded,
                                label: isAr ? 'كفاءة الرحلة' : 'Efficiency score',
                                value: isLiveActive ? '${provider.nfi(stats.efficiencyScore)}/100' : '0/100',
                                color: AppColors.statsCard,
                              ),
                              _StatTile(
                                icon: Icons.height_rounded,
                                label: isAr ? 'فرق الارتفاع' : 'Elevation change',
                                value: isLiveActive
                                    ? (stats.elevationChangeM != null
                                        ? '${stats.elevationChangeM! >= 0 ? '+' : ''}${provider.nfi(stats.elevationChangeM!.round())} m'
                                        : (isAr ? 'غير متاح' : 'Unavailable'))
                                    : '0 m',
                                color: AppColors.checklistCard,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionLabel(
                            isAr ? 'الطريق والطقس' : 'Road & Weather',
                            isAr,
                          ),
                          _RouteBreakdownCard(isAr: isAr, stats: stats),
                          const SizedBox(height: 16),
                        ],
                        _SectionLabel(isAr ? 'رحلتك' : 'Your Trip', isAr),
                        _StatGrid(
                          isAr: isAr,
                          tiles: [
                            _StatTile(
                              icon: Icons.checklist_rounded,
                              label: isAr ? 'قائمة التحقق' : 'Checklist',
                              value:
                                  '${provider.nfi(checklistDone)}/${provider.nfi(checklistTotal)}',
                              color: AppColors.checklistCard,
                            ),
                            _StatTile(
                              icon: Icons.photo_library_rounded,
                              label: isAr ? 'الصور' : 'Photos',
                              value: provider.nfi(photoCount),
                              color: AppColors.photosCard,
                            ),
                            if (expensesTotals.isEmpty)
                              _StatTile(
                                icon: Icons.account_balance_wallet_rounded,
                                label: isAr ? 'المصاريف' : 'Expenses',
                                value: isAr ? 'لا يوجد' : 'None',
                                color: AppColors.expensesCard,
                              )
                            else
                              ...expensesTotals.entries.map(
                                (e) => _StatTile(
                                  icon: Icons.account_balance_wallet_rounded,
                                  label: isAr
                                      ? 'المصاريف (${e.key})'
                                      : 'Expenses (${e.key})',
                                  value: provider.nfd(e.value, decimals: 2),
                                  color: AppColors.expensesCard,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHours(double hours, bool isAr, AppDataProvider provider) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (isAr) return '${provider.nfi(h)} س ${provider.nfi(m)} د';
    return '${provider.nfi(h)}h ${provider.nfi(m)}m';
  }

  String _difficultyLabel(RouteDifficulty d, bool isAr) {
    switch (d) {
      case RouteDifficulty.easy:
        return isAr ? 'سهل' : 'Easy';
      case RouteDifficulty.moderate:
        return isAr ? 'متوسط' : 'Moderate';
      case RouteDifficulty.challenging:
        return isAr ? 'صعب' : 'Challenging';
    }
  }

  Color _difficultyColor(RouteDifficulty d) {
    switch (d) {
      case RouteDifficulty.easy:
        return AppColors.success;
      case RouteDifficulty.moderate:
        return AppColors.warning;
      case RouteDifficulty.challenging:
        return AppColors.error;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.isAr, {this.trailing});
  final String text;
  final bool isAr;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        children: [
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Prompts the driver to explicitly start a trip record ("إنشاء سجل
/// رحلة"). Live progress stats stay at 0 until this is tapped. Once
/// active, shows a small status chip instead.
class _TripRecordBanner extends StatelessWidget {
  const _TripRecordBanner({
    required this.isAr,
    required this.isActive,
    required this.startedAt,
    required this.onCreate,
  });

  final bool isAr;
  final bool isActive;
  final DateTime? startedAt;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final hasEnoughCredits = provider.isSubscribed || provider.credits >= provider.getNextTripStatCost();

    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr
                    ? 'سجل الرحلة نشط — يتم الحساب حتى الوصول'
                    : 'Trip record active — tracking until arrival',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!hasEnoughCredits) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isAr
                    ? 'رصيد غير كافٍ لإنشاء سجل رحلة. يمكنك عرض السجل فقط.'
                    : 'Not enough credits to create a trip record. You can view history.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => showSubscriptionSheet(context, isAr: isAr),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isAr ? 'احصل على رصيد' : 'Get Credits',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statsCard.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppColors.statsCard.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isAr
                  ? 'أنشئ سجل رحلة لبدء حساب وقت القيادة والمسافة المقطوعة فعلياً'
                  : 'Create a trip record to start tracking real driving time and distance',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statsCard,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isAr ? 'إنشاء سجل رحلة' : 'Create Trip Record',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small honest indicator of whether Route stats came from live road
/// routing or the offline distance heuristic — replaces the old
/// always-on "not configured" rows with something that reflects
/// what actually happened for *this* request.
class _RoutingBadge extends StatelessWidget {
  const _RoutingBadge({required this.isAr, required this.isLive});
  final bool isAr;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppColors.success : AppColors.warning;
    final label = isLive
        ? (isAr ? 'توجيه مباشر' : 'Live routing')
        : (isAr ? 'تقديري' : 'Estimated');
    final icon = isLive
        ? Icons.podcasts_rounded
        : Icons.signal_wifi_statusbar_null_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.isAr, required this.tiles});
  final bool isAr;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: tiles);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

class _RouteBreakdownCard extends StatelessWidget {
  const _RouteBreakdownCard({required this.isAr, required this.stats});
  final bool isAr;
  final TripStatistics stats;

  @override
  Widget build(BuildContext context) {
    final origin = stats.originPlace;
    final dest = stats.destinationPlace;
    final originW = stats.originWeather;
    final destW = stats.destinationWeather;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statsCard.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(color: AppColors.statsCard.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _placeRow(
            context,
            icon: Icons.trip_origin_rounded,
            title: isAr ? 'من' : 'From',
            place: origin,
            weather: originW,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _placeRow(
            context,
            icon: Icons.flag_rounded,
            title: isAr ? 'إلى' : 'To',
            place: dest,
            weather: destW,
          ),
        ],
      ),
    );
  }

  Widget _placeRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    RoutePlace? place,
    RouteWeatherSnapshot? weather,
  }) {
    final placeLabel = place != null
        ? place.label(isAr: isAr)
        : (isAr ? 'غير متاح' : 'Unavailable');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.statsCard),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              Text(
                placeLabel,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                softWrap: true,
              ),
              if (weather != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${weather.temperatureC.round()}°C · ${weather.description(isAr: isAr)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.weatherCard,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumLiveSection extends StatelessWidget {
  const _PremiumLiveSection({
    required this.isAr,
    required this.provider,
    required this.stats,
    required this.tracker,
  });

  final bool isAr;
  final AppDataProvider provider;
  final TripStatistics stats;
  final TripProgressService tracker;

  String _fmtEta(DateTime? eta) {
    if (eta == null) return isAr ? '—' : '--';
    final h = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final m = eta.minute.toString().padLeft(2, '0');
    final ap = eta.hour < 12 ? (isAr ? 'ص' : 'AM') : (isAr ? 'م' : 'PM');
    return '$h:$m $ap';
  }

  String _fmtDur(Duration? d) {
    if (d == null) return isAr ? '—' : '--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return isAr ? '${provider.nfi(m)} د' : '${provider.nfi(m)}m';
    return isAr ? '${provider.nfi(h)} س ${provider.nfi(m)} د' : '${provider.nfi(h)}h ${provider.nfi(m)}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = provider.isSubscribed;

    if (!isPremium) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A160B), const Color(0xFF2A2210)]
                : [const Color(0xFFFFFBF0), const Color(0xFFFFF3D6)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
          border: Border.all(color: AppColors.pGoldDeep.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.pGoldDeep.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, size: 18, color: AppColors.pGoldDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'ميزة بريميوم' : 'Premium feature',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.pGoldDeep),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? 'ETA مباشر + سرعة لحظية' : 'Live ETA + real-time speed',
                    style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => showSubscriptionSheet(context, isAr: isAr),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pGoldDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(isAr ? 'ترقية' : 'Upgrade', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final isTracking = tracker.isTracking;
    final isLiveActive = isTracking || provider.isTripActive;
    final remainingKm = tracker.remainingKm;
    final remainingDur = tracker.remainingDuration;
    final eta = tracker.eta;
    final curSpeed = tracker.currentSpeedKmh;
    final avgSpeed = tracker.liveAverageSpeedKmh;

    // When not active (not started) -> all 0 as requested
    if (!isLiveActive) {
      // still show premium card but with 0 values (or upsell already handled above)
    }
    final fallbackRemKm = stats.estimatedRoadKm;
    final fallbackHours = stats.drivingHours;
    final fallbackEta = DateTime.now().add(Duration(milliseconds: (fallbackHours * 3600000).round()));

    final displayRemKm = !isLiveActive ? 0.0 : (isTracking && remainingKm != null ? remainingKm : fallbackRemKm);
    final displayRemDur = !isLiveActive ? Duration.zero : (isTracking && remainingDur != null ? remainingDur : Duration(milliseconds: (fallbackHours * 3600000).round()));
    final displayEta = !isLiveActive ? null : (isTracking && eta != null ? eta : fallbackEta);
    final displayCurSpeed = !isLiveActive ? 0.0 : (isTracking ? curSpeed : 0.0);
    final displayAvgSpeed = !isLiveActive ? 0.0 : (isTracking && avgSpeed > 0 ? avgSpeed : stats.averageSpeedKmh);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pGoldDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 12, color: AppColors.pGoldDeep),
                  const SizedBox(width: 4),
                  Text(isAr ? 'بريميوم مباشر' : 'Premium Live', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.pGoldDeep)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isTracking)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(isAr ? 'تقديري' : 'Estimated', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(isAr ? 'مباشر' : 'Live', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.pGoldDeep.withValues(alpha: 0.14), AppColors.pGoldDeep.withValues(alpha: 0.04)]
                  : [const Color(0xFFFFFBF0), const Color(0xFFFFF8E1)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.pGoldDeep.withValues(alpha: 0.22)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.speed_rounded, color: AppColors.pGoldDeep, size: 20),
                        const SizedBox(height: 6),
                        Text('${provider.nfi(displayCurSpeed.round())}', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.pGoldDeep)),
                        Text('km/h', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.pGoldDeep.withValues(alpha: 0.7))),
                        const SizedBox(height: 4),
                        Text(isAr ? 'السرعة اللحظية' : 'Real-time', style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 70, color: AppColors.pGoldDeep.withValues(alpha: 0.15)),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.schedule_rounded, color: AppColors.pGoldDeep, size: 20),
                        const SizedBox(height: 6),
                        Text(_fmtDur(displayRemDur), style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.pGoldDeep), textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        Text(_fmtEta(displayEta), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.pGoldDeep)),
                        const SizedBox(height: 4),
                        Text(isAr ? 'الوصول المتوقع' : 'ETA', style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: AppColors.pGoldDeep.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniPremiumTile(
                      icon: Icons.route_rounded,
                      label: isAr ? 'المتبقي' : 'Remaining',
                      value: '${provider.nfd(displayRemKm, decimals: 1)} km',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniPremiumTile(
                      icon: Icons.timeline_rounded,
                      label: isAr ? 'متوسط' : 'Avg speed',
                      value: '${provider.nfi(displayAvgSpeed.round())} km/h',
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
}

class _MiniPremiumTile extends StatelessWidget {
  const _MiniPremiumTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.pGoldDeep.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.pGoldDeep),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.pGoldDeep)),
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.warning),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
