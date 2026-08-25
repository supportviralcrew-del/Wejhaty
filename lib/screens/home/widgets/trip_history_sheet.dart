import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/trip_history_service.dart';

/// Shows the list of previously completed trips (arrival date/time +
/// key stats). Each entry can be renamed or deleted.
class TripHistorySheet extends StatefulWidget {
  const TripHistorySheet({super.key, required this.isAr});

  final bool isAr;

  @override
  State<TripHistorySheet> createState() => _TripHistorySheetState();
}

class _TripHistorySheetState extends State<TripHistorySheet> {
  late Future<List<TripHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = TripHistoryService.instance.load();
  }

  void _reload() {
    setState(() {
      _future = TripHistoryService.instance.load();
    });
  }

  Future<void> _rename(TripHistoryEntry entry) async {
    final isAr = widget.isAr;
    final controller = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'إعادة تسمية الرحلة' : 'Rename Trip'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isAr ? 'اسم الرحلة' : 'Trip name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await TripHistoryService.instance.rename(entry.id, newName);
      _reload();
    }
  }

  Future<void> _delete(TripHistoryEntry entry) async {
    final isAr = widget.isAr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'حذف الرحلة' : 'Delete Trip'),
        content: Text(
          isAr ? 'هل تريد حذف هذه الرحلة من السجل؟' : 'Delete this trip from your history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TripHistoryService.instance.delete(entry.id);
      _reload();
    }
  }

  String _formatDateTime(DateTime dt, bool isAr) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final date = '${two(dt.day)}/${two(dt.month)}/${dt.year}';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? (isAr ? 'ص' : 'AM') : (isAr ? 'م' : 'PM');
    final time = '${two(hour12)}:${two(dt.minute)} $period';
    return isAr ? '$date - $time' : '$date · $time';
  }

  String _formatDuration(Duration d, bool isAr) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (isAr) return '${h}س ${m}د';
    return '${h}h ${m}m';
  }

  void _showTripDetails(TripHistoryEntry entry) {
    final isAr = widget.isAr;
    final provider = AppDataProvider.instance;
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.glassBorder 
                  : Colors.black.withValues(alpha: 0.1),
            ),
            boxShadow: AppTheme.cardShadow(isDark: Theme.of(context).brightness == Brightness.dark),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                    child: const Icon(Icons.info_rounded, color: AppColors.statsCard),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr ? 'تفاصيل الرحلة' : 'Trip Details',
                      style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Trip name and destination
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.statsCard.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                          border: Border.all(color: AppColors.statsCard.withValues(alpha: 0.18)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAr ? 'إلى ${entry.destinationCityName}' : 'To ${entry.destinationCityName}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date and time info
                      _DetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: isAr ? 'تاريخ البدء' : 'Start Date',
                        value: _formatDateTime(entry.startedAt, isAr),
                        isAr: isAr,
                      ),
                      _DetailRow(
                        icon: Icons.event_available_rounded,
                        label: isAr ? 'تاريخ الوصول' : 'Arrival Date',
                        value: _formatDateTime(entry.arrivedAt, isAr),
                        isAr: isAr,
                      ),
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: isAr ? 'مدة الرحلة' : 'Trip Duration',
                        value: _formatDuration(entry.totalDuration, isAr),
                        isAr: isAr,
                      ),
                      const SizedBox(height: 12),
                      // Distance stats
                      _SectionLabel(isAr ? 'المسافة' : 'Distance', isAr),
                      _DetailRow(
                        icon: Icons.route_rounded,
                        label: isAr ? 'المسافة المقطوعة' : 'Distance Traveled',
                        value: '${provider.nfi(entry.traveledKm.round())} km',
                        isAr: isAr,
                      ),
                      _DetailRow(
                        icon: Icons.straighten_rounded,
                        label: isAr ? 'المسافة المقدرة' : 'Estimated Distance',
                        value: '${provider.nfi(entry.roadKm.round())} km',
                        isAr: isAr,
                      ),
                      if (entry.averageSpeedKmh != null) ...[
                        const SizedBox(height: 12),
                        _SectionLabel(isAr ? 'السرعة والوقت' : 'Speed & Time', isAr),
                        _DetailRow(
                          icon: Icons.speed_rounded,
                          label: isAr ? 'متوسط السرعة' : 'Average Speed',
                          value: '${provider.nfi(entry.averageSpeedKmh!.round())} km/h',
                          isAr: isAr,
                        ),
                        if (entry.drivingDuration != null)
                          _DetailRow(
                            icon: Icons.drive_eta_rounded,
                            label: isAr ? 'وقت القيادة' : 'Driving Time',
                            value: _formatDuration(entry.drivingDuration!, isAr),
                            isAr: isAr,
                          ),
                        if (entry.restingDuration != null)
                          _DetailRow(
                            icon: Icons.free_breakfast_rounded,
                            label: isAr ? 'وقت الراحة' : 'Rest Time',
                            value: _formatDuration(entry.restingDuration!, isAr),
                            isAr: isAr,
                          ),
                      ],
                      const SizedBox(height: 12),
                      // Fuel stats
                      _SectionLabel(isAr ? 'الوقود' : 'Fuel', isAr),
                      _DetailRow(
                        icon: Icons.local_gas_station_rounded,
                        label: isAr ? 'الوقود المستهلك' : 'Fuel Consumed',
                        value: '${provider.nfd(entry.fuelLiters, decimals: 1)} L',
                        isAr: isAr,
                      ),
                      _DetailRow(
                        icon: Icons.payments_rounded,
                        label: isAr ? 'تكلفة الوقود' : 'Fuel Cost',
                        value: '${provider.nfd(entry.fuelCost, decimals: 2)} ${entry.fuelCurrency}',
                        isAr: isAr,
                      ),
                      _DetailRow(
                        icon: Icons.ev_station_rounded,
                        label: isAr ? 'محطات الوقود' : 'Fuel Stations',
                        value: provider.nfi(entry.fuelStationStops),
                        isAr: isAr,
                      ),
                      const SizedBox(height: 12),
                      // Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: entry.completed 
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                          border: Border.all(
                            color: entry.completed 
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.completed ? Icons.check_circle_rounded : Icons.info_rounded,
                              color: entry.completed ? AppColors.success : AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.completed
                                    ? (isAr ? 'اكتملت الرحلة' : 'Trip completed')
                                    : (isAr ? 'توقفت يدوياً' : 'Manually stopped'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: entry.completed ? AppColors.success : AppColors.warning,
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final provider = AppDataProvider.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(
            color: isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.1),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                  child: const Icon(Icons.history_rounded, color: AppColors.statsCard),
                ),
                const SizedBox(width: 12),
                Text(
                  isAr ? 'سجل الرحلات' : 'Trip History',
                  style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: FutureBuilder<List<TripHistoryEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.statsCard)),
                    );
                  }

                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          isAr ? 'لا توجد رحلات محفوظة بعد' : 'No trips saved yet',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return InkWell(
                        onTap: () => _showTripDetails(entry),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.statsCard.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                            border: Border.all(color: AppColors.statsCard.withValues(alpha: 0.18)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            entry.name,
                                            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!entry.completed) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isAr ? 'غير مكتملة' : 'Unfinished',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    onPressed: () => _rename(entry),
                                    tooltip: isAr ? 'إعادة تسمية' : 'Rename',
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                    onPressed: () => _delete(entry),
                                    tooltip: isAr ? 'حذف' : 'Delete',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAr
                                    ? 'وصل إلى ${entry.destinationCityName}'
                                    : 'Arrived at ${entry.destinationCityName}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                _formatDateTime(entry.arrivedAt, isAr),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  _miniStat(
                                    context,
                                    Icons.route_rounded,
                                    '${provider.nfi(entry.traveledKm.round())} km',
                                    isAr ? 'مقطوعة' : 'traveled',
                                  ),
                                  _miniStat(
                                    context,
                                    Icons.access_time_rounded,
                                    _formatDuration(entry.totalDuration, isAr),
                                    isAr ? 'المدة' : 'duration',
                                  ),
                                  _miniStat(
                                    context,
                                    Icons.local_gas_station_rounded,
                                    provider.nfi(entry.fuelStationStops),
                                    isAr ? 'محطات وقود' : 'fuel stops',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.statsCard),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isAr,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.statsCard),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.isAr);
  final String text;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}