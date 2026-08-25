import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/data/emergency_numbers.dart';
import 'package:tripproject/services/emergency_service.dart';

class EmergencySheet extends StatefulWidget {
  const EmergencySheet({
    super.key,
    required this.isAr,
    required this.countryName,
  });

  final bool isAr;
  final String? countryName;

  @override
  State<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<EmergencySheet> {
  late Future<EmergencyLookupResult> _future;

  @override
  void initState() {
    super.initState();
    _future = EmergencyService.instance.fetchFor(widget.countryName);
  }

  Future<void> _call(String rawNumber) async {
    // Strip anything but digits/+ so numbers with spaces/dashes still dial.
    final cleaned = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'medical':
        return Icons.medical_services_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'shield':
        return Icons.local_police_rounded;
      case 'traffic':
        return Icons.directions_car_filled_rounded;
      case 'travel':
        return Icons.travel_explore_rounded;
      default:
        return Icons.call_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDirection = isAr ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
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
                    gradient: AppTheme.emergencyGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.emergency_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'الطوارئ' : 'Emergency',
                        style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
                        softWrap: true,
                      ),
                      if (widget.countryName != null)
                        Text(
                          widget.countryName!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          softWrap: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: FutureBuilder<EmergencyLookupResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator(color: AppColors.emergencyCard)),
                    );
                  }

                  final result = snapshot.data;
                  final numbers = result?.numbers ?? genericFallbackNumbers(null);

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (result != null && result.isBestEffortGuess)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'تعذر الاتصال بالخادم — يتم عرض أرقام افتراضية عامة قد لا تكون دقيقة لهذه الدولة.'
                                        : 'Couldn\'t reach the live directory — showing a generic guess that may not be accurate for this country.',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.warning),
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...numbers.map((n) => _EmergencyTile(
                          number: n,
                          isAr: isAr,
                          icon: _iconFor(n.icon),
                          onCall: _call,
                        )),
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
}

class _EmergencyTile extends StatelessWidget {
  const _EmergencyTile({
    required this.number,
    required this.isAr,
    required this.icon,
    required this.onCall,
  });

  final EmergencyNumber number;
  final bool isAr;
  final IconData icon;
  final Future<void> Function(String) onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.emergencyCard.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(color: AppColors.emergencyCard.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.emergencyCard),
              const SizedBox(width: 8),
              // Flexible + softWrap so long Arabic labels wrap onto a
              // second line instead of being clipped — this, together
              // with the isolated LTR directionality on the phone
              // numbers below, is what fixes the Arabic truncation bug.
              Flexible(
                child: Text(
                  isAr ? number.labelAr : number.labelEn,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: number.numbers
                .map(
                  (n) => _CallChip(number: n, onTap: () => onCall(n)),
            )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// A phone-number chip. Phone numbers are always rendered with an
/// explicit LTR sub-directionality — even inside an Arabic RTL sheet —
/// because digit strings run through the Unicode bidi algorithm when a
/// surrounding context is RTL, which is what caused numbers to appear
/// reordered/truncated in Arabic mode. Isolating direction here fixes
/// that regardless of the ambient locale.
class _CallChip extends StatelessWidget {
  const _CallChip({required this.number, required this.onTap});

  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.emergencyCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  number,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}