import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/widgets/premium_effects.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/subscription_service.dart';

/// Presents the premium subscription sheet as a modal bottom sheet.
/// Returns (as a Future) when the sheet is closed, so callers can refresh
/// their UI right after a possible subscription.
Future<void> showSubscriptionSheet(BuildContext context, {required bool isAr}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (context) => SubscriptionSheet(isAr: isAr),
  );
}

/// A single row describing one premium benefit.
class _Feature {
  const _Feature({
    required this.icon,
    required this.color,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
  });

  final IconData icon;
  final Color color;
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
}

// ── Price: 2.99 USD base, auto-converted to local currency ───────────────
String _resolveCountryCode() {
  final weatherCode = AppDataProvider.instance.weather?.countryCode;
  if (weatherCode != null && weatherCode.length == 2) return weatherCode.toUpperCase();
  final manual = AppDataProvider.instance.manualCountryName;
  if (manual != null && manual.isNotEmpty) {
    final code = _countryNameToCode[manual.toLowerCase().trim()];
    if (code != null) return code;
  }
  try {
    final localeCode = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (localeCode != null && localeCode.length == 2) return localeCode.toUpperCase();
  } catch (_) {}
  return 'US';
}

const Map<String, String> _countryNameToCode = {
  'saudi arabia': 'SA', 'السعودية': 'SA',
  'united arab emirates': 'AE', 'الإمارات': 'AE',
  'qatar': 'QA', 'قطر': 'QA',
  'kuwait': 'KW', 'الكويت': 'KW',
  'bahrain': 'BH', 'البحرين': 'BH',
  'oman': 'OM', 'عمان': 'OM',
  'egypt': 'EG', 'مصر': 'EG',
  'jordan': 'JO', 'الأردن': 'JO',
  'lebanon': 'LB', 'لبنان': 'LB',
  'turkey': 'TR', 'تركيا': 'TR',
  'united kingdom': 'GB', 'المملكة المتحدة': 'GB',
  'united states': 'US', 'الولايات المتحدة': 'US',
  'germany': 'DE', 'ألمانيا': 'DE',
  'france': 'FR', 'فرنسا': 'FR',
  'italy': 'IT', 'إيطاليا': 'IT',
  'spain': 'ES', 'إسبانيا': 'ES',
  'india': 'IN', 'الهند': 'IN',
  'pakistan': 'PK', 'باكستان': 'PK',
  'morocco': 'MA', 'المغرب': 'MA',
  'algeria': 'DZ', 'الجزائر': 'DZ',
  'tunisia': 'TN', 'تونس': 'TN',
  'japan': 'JP', 'اليابان': 'JP',
};

String _currencySymbol(String code, bool isAr) {
  switch (code) {
    case 'SA': return isAr ? 'ر.س' : 'SAR';
    case 'AE': return isAr ? 'د.إ' : 'AED';
    case 'QA': return isAr ? 'ر.ق' : 'QAR';
    case 'KW': return isAr ? 'د.ك' : 'KWD';
    case 'BH': return isAr ? 'د.ب' : 'BHD';
    case 'OM': return isAr ? 'ر.ع' : 'OMR';
    case 'EG': return isAr ? 'ج.م' : 'EGP';
    case 'JO': return isAr ? 'د.أ' : 'JOD';
    case 'LB': return isAr ? 'ل.ل' : 'LBP';
    case 'GB': return '£';
    case 'TR': return '₺';
    case 'IN': return '₹';
    case 'PK': return '₨';
    case 'JP': return '¥';
    case 'MA': return isAr ? 'د.م' : 'MAD';
    case 'DZ': return isAr ? 'د.ج' : 'DZD';
    case 'TN': return isAr ? 'د.ت' : 'TND';
    case 'DE': case 'FR': case 'IT': case 'ES': case 'NL': case 'BE': case 'PT': case 'GR': case 'IE': case 'AT':
      return '€';
    default: return '\$';
  }
}

/// USD → local FX (approx mid-market, 2025-2026). Used to convert 2.99 USD.
const Map<String, double> _usdToLocalRate = {
  'US': 1.0,
  'SA': 3.75,      // 2.99*3.75 = 11.21 SAR
  'AE': 3.6725,    // 2.99*3.6725 = 10.98 ≈ 10 AED (your example)
  'QA': 3.64,
  'KW': 0.305,     // 0.91 KWD
  'BH': 0.376,     // 1.12 BHD
  'OM': 0.384,     // 1.15 OMR
  'EG': 50.5,      // 151.00 EGP (volatile)
  'JO': 0.709,     // 2.12 JOD
  'LB': 89500,     // handled specially (fallback to USD)
  'TR': 34.0,      // 101.66 TRY
  'GB': 0.79,      // 2.36 GBP
  'DE': 0.92, 'FR': 0.92, 'IT': 0.92, 'ES': 0.92, 'NL': 0.92, 'BE': 0.92, 'PT': 0.92, 'GR': 0.92, 'IE': 0.92, 'AT': 0.92,
  'IN': 83.5,      // 249.67 INR
  'PK': 278.0,     // 831.22 PKR
  'MA': 10.05,     // 30.05 MAD
  'DZ': 135.0,     // 403.65 DZD
  'TN': 3.10,      // 9.27 TND
  'JP': 149.5,     // 447 JPY
};

String _fallbackPrice(bool isAr) {
  final code = _resolveCountryCode();
  final symbol = _currencySymbol(code, isAr);
  // LB hyper-inflation would show 267k LBP — not useful, keep USD
  if (code == 'LB') return isAr ? '2.99\$/شهر' : '2.99\$/month';
  final rate = _usdToLocalRate[code] ?? 1.0;
  final converted = 2.99 * rate;
  final String amount;
  if (code == 'JP') {
    amount = converted.round().toString(); // no decimals for JPY
  } else if (['KW','BH','OM','JO'].contains(code)) {
    amount = converted.toStringAsFixed(3); // 3 decimals for Gulf dinars
  } else {
    amount = converted.toStringAsFixed(2);
  }
  final suffix = isAr ? '/شهر' : '/month';
  final needsSpace = symbol.length > 1;
  final sep = needsSpace ? ' ' : '';
  return '$amount$sep$symbol$suffix';
}

String _getPriceText(bool isAr) {
  // Use converted USD price; if Play store product exists prefer it
  // but fix the "2.99 AED" bug — if store returns 2.99 AED we would still
  // show wrong value, so we always prefer our correctly converted price
  // when code is known. If product price looks already correctly converted
  // (contains converted amount) we could use it, but safest is converted.
  final product = SubscriptionService.instance.premiumProduct;
  if (product != null) {
    // If store already gives a non-USD price that is NOT 2.99 with local symbol
    // (e.g. Google already converted), respect it — it is the source of truth
    // for billing. Only fix the obvious bug "2.99 AED".
    final raw = product.price.trim();
    if (raw.startsWith('2.99') && (raw.contains('AED') || raw.contains('د.إ'))) {
      return _fallbackPrice(isAr); // fix 2.99 AED → 10.98 AED
    }
    final suffix = isAr ? '/شهر' : '/month';
    if (raw.contains('شهر') || raw.toLowerCase().contains('month') || raw.contains('/')) return raw;
    return '$raw$suffix';
  }
  return _fallbackPrice(isAr);
}

const List<_Feature> _kFeatures = [
  _Feature(
    icon: Icons.bolt_rounded,
    color: Color(0xFFF59E0B),
    titleEn: '2,000 Credits Every 2 / 6 Days',
    titleAr: '2,000 رصيد كل 2 / 6 أيام',
    subtitleEn: 'Auto-refills every 2 days in your first week, then every 6 days — 20× free',
    subtitleAr: 'يتجدد تلقائياً كل يومين في أول أسبوع، ثم كل 6 أيام — 20 ضعف المجاني',
  ),
  _Feature(
    icon: Icons.insights_rounded,
    color: Color(0xFF3B82F6),
    titleEn: 'Advanced Trip Analytics',
    titleAr: 'تحليلات الرحلات المتقدمة',
    subtitleEn: 'Total distance, trip duration, trip count, and average distance — all in one view',
    subtitleAr: 'إجمالي المسافة، مدة الرحلة، عدد الرحلات، ومتوسط المسافة — في مكان واحد',
  ),
  _Feature(
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF10B981),
    titleEn: 'Advanced Expense Analytics',
    titleAr: 'تحليلات المصروفات المتقدمة',
    subtitleEn: 'Track total spend, average cost per trip, and a full expense breakdown',
    subtitleAr: 'تتبّع إجمالي المصروفات، متوسط التكلفة لكل رحلة، وتفاصيل دقيقة للإنفاق',
  ),
  _Feature(
    icon: Icons.directions_car_filled_rounded,
    color: Color(0xFF8B5CF6),
    titleEn: 'Smarter Trip Tools',
    titleAr: 'أدوات رحلات أذكى',
    subtitleEn: 'Precision tracking, complete trip history, and richer stats for every drive',
    subtitleAr: 'تتبّع دقيق، سجل كامل للرحلات، وإحصائيات أوسع لكل رحلة',
  ),
  _Feature(
    icon: Icons.block_rounded,
    color: Color(0xFFEF4444),
    titleEn: '100% Ad-Free',
    titleAr: 'خالٍ تماماً من الإعلانات',
    subtitleEn: 'No banner, native, or rewarded ads — just a clean, uninterrupted experience',
    subtitleAr: 'بدون إعلانات بانر أو مدمجة أو مكافآت — تجربة نظيفة وسلسة',
  ),
  _Feature(
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFEC4899),
    titleEn: 'Future-Proof Access',
    titleAr: 'وصول دائم لكل جديد',
    subtitleEn: 'Every premium feature we launch next is unlocked automatically, at no extra cost',
    subtitleAr: 'أي ميزة مميزة نطلقها مستقبلاً تُفتح لك تلقائياً دون أي تكلفة إضافية',
  ),
];

class SubscriptionSheet extends StatefulWidget {
  const SubscriptionSheet({super.key, required this.isAr});

  final bool isAr;

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet>
    with TickerProviderStateMixin {
  static const double _step = 0.055;

  bool _isSubscribing = false;
  bool _pressed = false;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  bool get _isBusy => _isSubscribing;

  @override
  void dispose() {
    _entry.dispose();
    _float.dispose();
    _sweep.dispose();
    super.dispose();
  }

  Future<void> _handleSubscribe() async {
    if (_isBusy) return;
    HapticFeedback.selectionClick();
    setState(() => _isSubscribing = true);

    try {
      final launched = await SubscriptionService.instance.subscribe();
      if (!mounted) return;
      if (!launched) {
        _showSnack(
          message: widget.isAr
              ? 'تعذّر إتمام عملية الاشتراك. حاول مرة أخرى.'
              : "We couldn't complete your subscription. Please try again.",
          isError: true,
        );
        return;
      }

      // Wait for the actual store outcome (purchased / cancelled / error).
      // Resolves immediately for the dev/web fallback.
      final success = await SubscriptionService.instance.pendingPurchaseResult
          .timeout(
        const Duration(minutes: 5),
        onTimeout: () => false,
      );
      if (!mounted) return;

      if (success) {
        // Keep "Loading premium..." visible for 2s after pay as requested
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pop();
        _showSnack(
          message: widget.isAr
              ? 'مرحباً بك في Wejhaty Premium! تم تفعيل جميع الميزات المتقدمة الآن.'
              : 'Welcome to Wejhaty Premium! Every advanced feature is unlocked.',
          isError: false,
        );
      } else {
        _showSnack(
          message: widget.isAr
              ? 'تعذّر إتمام عملية الاشتراك. حاول مرة أخرى.'
              : "We couldn't complete your subscription. Please try again.",
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        message: widget.isAr
            ? 'حدث خطأ غير متوقع أثناء الاشتراك. حاول لاحقاً.'
            : 'Something went wrong while subscribing. Please try again in a moment.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }


  void _showSnack({required String message, required bool isError}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
  }

  Interval _interval(int slot, {double bias = 0.5}) {
    final start = (slot * _step).clamp(0.0, 0.62);
    return Interval(start, math.min(start + bias, 1.0), curve: Curves.easeOutCubic);
  }

  Widget _slideIn(int slot, Widget child) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final t = _interval(slot).transform(_entry.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }

  Widget _popIn(int slot, Widget child) {
    final pop = Interval(
      (slot * _step).clamp(0.0, 0.62),
      math.min((slot * _step).clamp(0.0, 0.62) + 0.6, 1.0),
      curve: Curves.easeOutBack,
    );
    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final s = (0.5 + 0.5 * pop.transform(_entry.value)).clamp(0.0, 1.0);
        return Transform.scale(scale: s, child: child);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isSubscribed = AppDataProvider.instance.isSubscribed;

    final priceText = _getPriceText(isAr);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: !_isSubscribing,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.border : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
              blurRadius: 48,
              offset: const Offset(0, 20),
            ),
            if (isDark)
              BoxShadow(
                color: AppColors.pGold.withValues(alpha: 0.05),
                blurRadius: 70,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -150,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 1.1,
                      colors: [
                        AppColors.pGold.withValues(alpha: isDark ? 0.12 : 0.20),
                        AppColors.pGold.withValues(alpha: 0),
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopBar(onSurface, isAr),
                Flexible(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 88),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _slideIn(0, _buildHero(isAr, isDark, onSurface, reduceMotion)),
                            const SizedBox(height: 20),
                            for (var i = 0; i < _kFeatures.length; i++) ...[
                              _buildFeatureRow(
                                i,
                                slot: i + 1,
                                isAr: isAr,
                                isDark: isDark,
                                onSurface: onSurface,
                                reduceMotion: reduceMotion,
                              ),
                              if (i < _kFeatures.length - 1) const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 16),
                            _slideIn(7, _buildInstantChip(isAr)),
                            const SizedBox(height: 12),
                            _slideIn(8, _buildPlanCard(isAr, isDark, onSurface, priceText)),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  surface.withValues(alpha: 0),
                                  surface,
                                ],
                                stops: const [0, 0.85],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionArea(
                  isAr: isAr,
                  isDark: isDark,
                  onSurface: onSurface,
                  reduceMotion: reduceMotion,
                  isSubscribed: isSubscribed,
                ),
              ],
            ),
            // ── Pro loading overlay — like App Store / RevenueCat ──
            if (_isSubscribing)
              Positioned.fill(
                child: AbsorbPointer(
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) {
                      final pulse = 0.85 + 0.15 * Curves.easeInOut.transform(_float.value);
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.black.withValues(alpha: 0.18),
                            child: Container(
                              width: 300,
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.pGold.withValues(alpha: 0.28),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.pGoldDeep.withValues(alpha: 0.18 * pulse),
                                    blurRadius: 28 * pulse,
                                    spreadRadius: -4,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Animated premium emblem with rotating progress ring
                                  Transform.scale(
                                    scale: pulse,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          height: 64,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.pGold.withValues(alpha: 0.95),
                                            ),
                                            backgroundColor: AppColors.pGold.withValues(alpha: 0.12),
                                          ),
                                        ),
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [AppColors.pGoldSoft, AppColors.pGold, AppColors.pGoldDeep],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.pGoldDeep.withValues(alpha: 0.35),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.workspace_premium_rounded, color: AppColors.pOnGold, size: 26),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isAr ? 'جاري تحميل البريميوم...' : 'Loading premium...',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: onSurface,
                                      letterSpacing: isAr ? 0 : -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedBuilder(
                                    animation: _sweep,
                                    builder: (_, __) {
                                      final dots = '.' * ((_sweep.value * 3).floor() + 1);
                                      return Text(
                                        isAr ? 'التواصل مع Google Play$dots' : 'Contacting Google Play$dots',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: onSurface.withValues(alpha: 0.58),
                                          height: 1.4,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  // Step dots
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(3, (i) {
                                      final active = (_sweep.value * 3).floor() % 3 == i;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 280),
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        width: active ? 22 : 8,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: active ? AppColors.pGold : onSurface.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_rounded, size: 12, color: AppColors.success),
                                        const SizedBox(width: 6),
                                        Text(
                                          isAr ? 'دفع آمن عبر Google Play' : 'Secure payment via Google Play',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTopBar(Color onSurface, bool isAr) {
    return SizedBox(
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Positioned.directional(
            textDirection: Directionality.of(context),
            end: 6,
            top: 2,
            child: Semantics(
              button: true,
              label: isAr ? 'إغلاق' : 'Close',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: onSurface.withValues(alpha: 0.45), size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isAr, bool isDark, Color onSurface, bool reduceMotion) {
    final accent = isDark ? AppColors.pGold : AppColors.pPrimaryLight;

    return Column(
      children: [
        Center(child: _buildEmblem(reduceMotion)),
        const SizedBox(height: 16),
        Text(
          isAr ? 'وجهتي بريميوم' : 'WEJHATY PREMIUM',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: isAr ? 0 : 2.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isAr ? 'كل شيء. باشتراك واحد.' : 'Everything. One membership.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.18,
            color: onSurface,
            letterSpacing: isAr ? 0 : -0.9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isAr
              ? 'تحليلات متقدمة، أدوات رحلات أذكى، 2,000 رصيد يتجدد كل 2-6 أيام، وتجربة خالية من الإعلانات.'
              : 'Advanced analytics, smarter trip tools, 2,000 credits refilled every 2–6 days, and zero ads.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildEmblem(bool reduceMotion) {
    Widget emblem(double lift, double glow) {
      return Container(
        width: 74,
        height: 74,
        transform: Matrix4.translationValues(0, lift, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.pGoldSoft, AppColors.pGold, AppColors.pGoldDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pGoldDeep.withValues(alpha: 0.32 + 0.22 * glow),
              blurRadius: 20 + 14 * glow,
              offset: const Offset(0, 8),
              spreadRadius: -3,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.workspace_premium_rounded,
          size: 38,
          color: AppColors.pOnGold,
        ),
      );
    }

    if (reduceMotion) return emblem(0, 0);

    return AnimatedBuilder(
      animation: _float,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_float.value);
        return emblem(-3 + 6 * v, v);
      },
    );
  }

  Widget _buildFeatureRow(
    int index, {
    required int slot,
    required bool isAr,
    required bool isDark,
    required Color onSurface,
    required bool reduceMotion,
  }) {
    final feature = _kFeatures[index];
    final title = isAr ? feature.titleAr : feature.titleEn;
    final subtitle = isAr ? feature.subtitleAr : feature.subtitleEn;

    Widget row() {
      return Semantics(
        label: '$title. $subtitle',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: isDark ? 0.045 : 0.032),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: onSurface.withValues(alpha: isDark ? 0.05 : 0.045)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _popIn(
                slot,
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: feature.color.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                        letterSpacing: isAr ? 0 : -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.4,
                        color: onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (reduceMotion) return row();
    return _slideIn(slot, row());
  }

  Widget _buildInstantChip(bool isAr) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.success, size: 15),
            const SizedBox(width: 5),
            Text(
              isAr ? 'تفعيل فوري عند الاشتراك' : 'Activates instantly',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
                letterSpacing: isAr ? 0 : 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(bool isAr, bool isDark, Color onSurface, String priceText) {
    final priceStyle = GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800);

    return GildedCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(13),
      sheen: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.pGoldSoft, AppColors.pGoldDeep],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pGoldDeep.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.pOnGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'الاشتراك المميز' : 'Premium Membership',
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: isAr ? 0 : -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isAr ? 'رصيد 2,000 يتجدد كل 2-6 أيام • إلغاء في أي وقت' : '2,000 credits refilled every 2–6 days · Cancel anytime',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDark)
            GoldText(priceText, style: priceStyle, textAlign: TextAlign.end)
          else
            Text(priceText, style: priceStyle.copyWith(color: AppColors.pPrimaryLight), textAlign: TextAlign.end),
        ],
      ),
    );
  }

  Widget _buildActionArea({
    required bool isAr,
    required bool isDark,
    required Color onSurface,
    required bool reduceMotion,
    required bool isSubscribed,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _slideIn(9, _buildSubscribeButton(isAr, isDark, reduceMotion, isSubscribed)),
          const SizedBox(height: 4),
          _slideIn(10, _buildLegalFootnote(onSurface, isAr)),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(bool isAr, bool isDark, bool reduceMotion, bool isSubscribed) {
    final enabled = !_isBusy && !isSubscribed;
    final foreground = isSubscribed && !isDark ? Colors.white : AppColors.pOnGold;

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isSubscribing
          ? SizedBox(
              key: const ValueKey('busy'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSubscribed ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                  size: 19,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Text(
                  isSubscribed
                      ? (isAr ? 'أنت عضو مميز' : "You're Premium")
                      : (isAr ? 'ابدأ الاشتراك' : 'Start Premium'),
                  style: GoogleFonts.manrope(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                    letterSpacing: isAr ? 0 : 0.1,
                  ),
                ),
              ],
            ),
    );

    final button = AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) {
        final sweeping = enabled && !reduceMotion;
        // Soft diagonal light band — the gradient axis itself slides, so
        // there is never a rotated rectangle with hard edges.
        final shift = sweeping ? -1.8 + 3.6 * _sweep.value : -3.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              child!,
              if (sweeping)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.2 + shift, -1.2),
                          end: Alignment(1.2 + shift, 1.2),
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.40, 0.5, 0.60],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isSubscribed
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [AppColors.pGoldSoft, AppColors.pGold, AppColors.pGoldDeep]
                      : const [AppColors.pGold, AppColors.pGoldDeep, AppColors.pBronze],
                ),
          color: isSubscribed ? (isDark ? AppColors.pGoldDeep : AppColors.pPrimaryLight) : null,
          boxShadow: enabled || isSubscribed
              ? AppTheme.goldGlow(strength: isDark ? 1.0 : 0.8)
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: isAr ? 'ابدأ الاشتراك' : 'Start Premium',
      child: GestureDetector(
        onTapDown: enabled
            ? (_) {
                setState(() => _pressed = true);
                HapticFeedback.mediumImpact();
              }
            : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                _handleSubscribe();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: button,
        ),
      ),
    );
  }


  Widget _buildLegalFootnote(Color onSurface, bool isAr) {
    return Text(
      isAr
          ? 'يتجدّد الاشتراك تلقائياً ما لم يتم إلغاؤه قبل 24 ساعة على الأقل من نهاية الفترة الحالية.'
          : 'Subscription renews automatically unless cancelled at least 24 hours before the current period ends.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10.5,
        height: 1.4,
        color: onSurface.withValues(alpha: 0.4),
      ),
    );
  }
}
