import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/screens/settings/about_screen.dart';
import 'package:tripproject/screens/settings/faq_screen.dart';
import 'package:tripproject/screens/settings/widgets/settings_ui.dart';
import 'package:tripproject/screens/notifications/notifications_screen.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/notification_log_service.dart';
import 'package:tripproject/services/weather_service.dart';
import 'package:tripproject/core/app_info.dart';
import 'package:tripproject/core/widgets/premium_effects.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tripproject/screens/subscription/subscription_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _weatherService = WeatherService();

  void _showLocationSettings(BuildContext context, bool isAr) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LocationBottomSheet(
          isAr: isAr,
          weatherService: _weatherService,
        );
      },
    );
  }

  Future<void> _emailUs() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppInfo.supportEmail,
      query: 'subject=${Uri.encodeComponent('${AppInfo.appNameEn} — Support')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _rateApp() async {
    final isAr = AppDataProvider.instance.language == 'ar';
    final inAppReview = InAppReview.instance;

    // 1) Google Play In-App Review API — dialog appears ABOVE the app (no redirect)
    // This is the recommended Play policy compliant way.
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          return;
        }
        // isAvailable false = quota exceeded or not yet published — fallback to store listing
        // openStoreListing also uses native flow (Play/ App Store app) when possible
        try {
          await inAppReview.openStoreListing(
            appStoreId: AppInfo.iosAppId == '0000000000' ? null : AppInfo.iosAppId,
          );
          return;
        } catch (_) {
          // fall through to url_launcher
        }
      }
    } catch (_) {
      // fall through
    }

    // 2) Fallback: url_launcher with market:// + https (handles web/desktop, iOS placeholder, Android 11+ queries)
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || isIOS)) {
      final uri = Uri.parse(AppInfo.androidStoreUrl);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'تعذر فتح المتجر — ${AppInfo.androidStoreUrl}' : 'Could not open store — ${AppInfo.androidStoreUrl}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!isIOS) {
      final marketUri = Uri.parse('market://details?id=${AppInfo.androidPackageName}');
      try {
        final launchedMarket = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        if (launchedMarket) return;
      } catch (_) {}
      try {
        if (await canLaunchUrl(marketUri)) {
          if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) return;
        }
      } catch (_) {}
    }

    final webUri = Uri.parse(isIOS ? AppInfo.iosStoreUrl : AppInfo.androidStoreUrl);
    if (isIOS && AppInfo.iosAppId == '0000000000') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'المتجر غير متاح حالياً على iOS' : 'Store not available on iOS yet'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      bool launched = false;
      try {
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!launched) {
        if (await canLaunchUrl(webUri)) {
          launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'تعذر فتح صفحة التقييم' : 'Could not open rating page'),
            action: SnackBarAction(
              label: isAr ? 'نسخ الرابط' : 'Copy link',
              onPressed: () => Clipboard.setData(ClipboardData(text: webUri.toString())),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'خطأ: $e' : 'Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.horizontalPadding(context);
    final isAr = AppDataProvider.instance.language == 'ar';
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: AppDataProvider.instance,
        builder: (context, _) {
          final provider = AppDataProvider.instance;

          return ResponsiveCenter(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(padding, 72, padding, 100),
              child: Column(
                crossAxisAlignment:
                isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Text(
                    isAr ? 'الإعدادات' : 'Settings',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.scaledFontSize(context, 26),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr
                        ? 'إدارة تفضيلات التطبيق والموقع'
                        : 'Manage your app preferences and location',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  // ─── Premium Subscription ───
                  SettingsSectionLabel(
                    text: isAr ? 'الاشتراك الممتاز' : 'PREMIUM SUBSCRIPTION',
                    isAr: isAr,
                  ),
                  const SizedBox(height: 10),
                  if (provider.isSubscribed)
                    _PremiumMembershipCard(isAr: isAr, expiry: provider.subscriptionExpiryDate)
                  else
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFFFA500),
                          title: isAr ? 'اشتراك Wejhaty Premium 👑' : 'Wejhaty Premium 👑',
                          subtitle: (isAr ? 'الرصيد الحالي: ${provider.nfi(provider.credits)} رصيد' : 'Current credits: ${provider.credits}'),
                          isAr: isAr,
                          onTap: () => showSubscriptionSheet(context, isAr: isAr),
                          trailing: SettingsChevron(isAr: isAr),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),

                  // ─── Premium Features (subscribers only) ───
                  if (provider.isSubscribed) ...[
                    SettingsSectionLabel(
                      text: isAr ? 'الميزات المميزة' : 'PREMIUM FEATURES',
                      isAr: isAr,
                    ),
                    const SizedBox(height: 10),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          icon: Icons.notifications_rounded,
                          iconColor: AppColors.pGoldDeep,
                          title: isAr ? 'سجل الإشعارات' : 'Notification Log',
                          subtitle: isAr
                              ? 'تتبع أحداث التطبيق: الاشتراك، الرحلات، الرصيد والمزيد'
                              : 'Track app events: subscription, trips, credits & more',
                          isAr: isAr,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          ),
                          trailing: ListenableBuilder(
                            listenable: NotificationLogService.instance,
                            builder: (context, _) {
                              final unread = NotificationLogService.instance.unreadCount;
                              if (unread == 0) return SettingsChevron(isAr: isAr);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SettingsChevron(isAr: isAr),
                                ],
                              );
                            },
                          ),
                        ),
                        SettingsRow(
                          icon: Icons.auto_awesome_rounded,
                          iconColor: AppColors.pGoldDeep,
                          title: isAr ? 'المظهر الذهبي المميز' : 'Premium Look',
                          subtitle: isAr
                              ? 'السمة الحصرية باللون الذهبي لعملاء البريميوم'
                              : 'The exclusive gold theme reserved for members',
                          isAr: isAr,
                          trailing: SettingsSwitch(
                            value: provider.premiumLookEnabled,
                            onChanged: provider.setPremiumLookEnabled,
                          ),
                        ),
                        SettingsRow(
                          icon: Icons.science_rounded,
                          iconColor: AppColors.secondary,
                          title: isAr ? 'الميزات التجريبية' : 'Experimental Features',
                          subtitle: isAr
                              ? 'جرّب الميزات الجديدة قبل إطلاقها للجميع'
                              : 'Try features still in testing before public release',
                          isAr: isAr,
                          trailing: SettingsSwitch(
                            value: provider.experimentalFeaturesEnabled,
                            onChanged: provider.setExperimentalFeaturesEnabled,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ─── Notification Log (shown to all, premium-only feature) ───
                  // Hidden for premium users to avoid duplicate entry
                  // (they already have it under PREMIUM FEATURES above).
                  if (!provider.isSubscribed) ...[
                    SettingsSectionLabel(
                      text: isAr ? 'السجل والإحصائيات' : 'LOGS & STATS',
                      isAr: isAr,
                    ),
                    const SizedBox(height: 10),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          icon: Icons.notifications_rounded,
                          iconColor: Colors.grey,
                          title: isAr ? 'سجل الإشعارات' : 'Notification Log',
                          subtitle: isAr
                              ? 'ميزة بريميوم - تتبع أحداث التطبيق بالتفصيل'
                              : 'Premium feature - Track detailed app events',
                          isAr: isAr,
                          onTap: () => showSubscriptionSheet(context, isAr: isAr),
                          trailing: Icon(
                            Icons.lock_rounded,
                            color: Colors.grey.withValues(alpha: 0.5),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ─── Appearance ───
                  SettingsSectionLabel(
                    text: isAr ? 'المظهر' : 'APPEARANCE',
                    isAr: isAr,
                  ),
                  const SizedBox(height: 10),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: switch (provider.themeMode) {
                          ThemeMode.dark => Icons.dark_mode_rounded,
                          ThemeMode.light => Icons.light_mode_rounded,
                          ThemeMode.system => Icons.brightness_auto_rounded,
                        },
                        iconColor: AppColors.primary,
                        title: isAr ? 'المظهر' : 'Theme',
                        subtitle: isAr
                            ? 'اختر المظهر الفاتح أو الداكن أو مطابقة النظام'
                            : 'Follow your device, or pick light/dark',
                        isAr: isAr,
                        trailing: _ThemeSwitcher(
                          value: provider.themeMode,
                          onChanged: provider.setTheme,
                        ),
                        stacked: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Notifications ───
                  SettingsSectionLabel(
                    text: isAr ? 'الإشعارات' : 'NOTIFICATIONS',
                    isAr: isAr,
                  ),
                  const SizedBox(height: 10),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.notifications_active_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'شريط الإشعار' : 'Notification Bar',
                        subtitle: isAr
                            ? 'إشعار دائم يعرض الصلاة القادمة والعد التنازلي'
                            : 'Persistent notification with next prayer & countdown',
                        isAr: isAr,
                        trailing: SettingsSwitch(
                          value: provider.showNotificationBar,
                          onChanged: provider.setShowNotificationBar,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Language & Region ───
                  SettingsSectionLabel(
                    text: isAr ? 'اللغة والأرقام' : 'LANGUAGE & REGION',
                    isAr: isAr,
                  ),
                  const SizedBox(height: 10),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.translate_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'لغة التطبيق' : 'App Language',
                        subtitle: null,
                        isAr: isAr,
                        trailing: _LanguageSwitcher(
                          value: provider.language,
                          onChanged: provider.setLanguage,
                        ),
                        stacked: true,
                      ),
                      SettingsRow(
                        icon: Icons.filter_1_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'الأرقام العربية' : 'Arabic Numerals',
                        subtitle: isAr
                            ? 'عرض الأرقام بالصيغة العربية (٠١٢٣)'
                            : 'Display numbers as ٠١٢٣ instead of 0123',
                        isAr: isAr,
                        trailing: SettingsSwitch(
                          value: provider.useArabicNumbers,
                          onChanged: provider.setUseArabicNumbers,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Location ───
                  SettingsSectionLabel(
                    text: isAr ? 'الموقع' : 'LOCATION',
                    isAr: isAr,
                  ),
                  const SizedBox(height: 10),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'موقع التطبيق' : 'App Location',
                        subtitle: provider.isManualLocation
                            ? '${provider.manualCityName ?? ''}, ${provider.manualCountryName ?? ''}'
                            : (isAr
                            ? 'تحديد تلقائي عبر GPS'
                            : 'Auto-detected via GPS'),
                        isAr: isAr,
                        onTap: () => _showLocationSettings(context, isAr),
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Support & About ───
                  SettingsSectionLabel(
                    text: isAr ? 'الدعم والمعلومات' : 'SUPPORT & INFO',
                    isAr: isAr,
                  ),
                  const SizedBox(height: 10),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'حول التطبيق' : 'About App',
                        isAr: isAr,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        ),
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                      SettingsRow(
                        icon: Icons.help_outline_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'الأسئلة الشائعة' : 'FAQ',
                        isAr: isAr,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FaqScreen()),
                        ),
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                      SettingsRow(
                        icon: Icons.email_outlined,
                        iconColor: AppColors.primary,
                        title: isAr ? 'راسلنا بالإيميل' : 'Email us',
                        subtitle: AppInfo.supportEmail,
                        isAr: isAr,
                        onTap: _emailUs,
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                      SettingsRow(
                        icon: Icons.star_outline_rounded,
                        iconColor: AppColors.primary,
                        title: isAr ? 'تقييم التطبيق' : 'Rate the App',
                        isAr: isAr,
                        onTap: _rateApp,
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Language Segmented Switcher ───────────────────────────────────────────

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget option(String code, String label) {
      final selected = value == code;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          option('en', 'English'),
          option('ar', 'العربية'),
        ],
      ),
    );
  }
}

// ─── Theme Segmented Switcher ───────────────────────────────────────────────

class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isAr = AppDataProvider.instance.language == 'ar';

    Widget option(ThemeMode mode, IconData icon, String label) {
      final selected = value == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          option(ThemeMode.system, Icons.brightness_auto_rounded,
              isAr ? 'النظام' : 'System'),
          option(ThemeMode.light, Icons.light_mode_rounded,
              isAr ? 'فاتح' : 'Light'),
          option(ThemeMode.dark, Icons.dark_mode_rounded,
              isAr ? 'داكن' : 'Dark'),
        ],
      ),
    );
  }
}

// ─── Location Selection Bottom Sheet ──────────────────────────────────────────

class _LocationBottomSheet extends StatefulWidget {
  const _LocationBottomSheet({
    required this.isAr,
    required this.weatherService,
  });

  final bool isAr;
  final WeatherService weatherService;

  @override
  State<_LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<_LocationBottomSheet> {
  final _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;

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
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
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
                color: onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            widget.isAr ? 'اختر طريقة تحديد الموقع' : 'Choose Location Method',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Auto Detect Option Card
          InkWell(
            onTap: () {
              AppDataProvider.instance.enableAutoLocation();
              Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                textDirection: widget.isAr ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.gps_fixed_rounded,
                        color: AppColors.primary, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: widget.isAr
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isAr ? 'تحديد تلقائي' : 'Auto Detect Location',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isAr
                              ? 'استخدم الـ GPS للحصول على إحداثياتك الحالية تلقائياً'
                              : 'Use device GPS to track weather & prayer times',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: onSurface.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  widget.isAr ? 'أو ابحث عن مدينة' : 'Or search manually',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(child: Divider(color: onSurface.withValues(alpha: 0.1))),
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
              hintText: widget.isAr ? 'ابحث بالإنجليزية أو العربية (مثال: دبي)' : 'Search city (e.g. Dubai, Amman)',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(Icons.search_rounded, color: onSurface.withValues(alpha: 0.5)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear_rounded, color: onSurface.withValues(alpha: 0.5)),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: onSurface.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                borderSide: BorderSide(color: onSurface.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                borderSide: BorderSide(color: onSurface.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Search Results / Loader
          if (_isSearching)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: onSurface.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    dense: true,
                    leading: Icon(Icons.location_city_rounded,
                        color: onSurface.withValues(alpha: 0.45), size: 20),
                    title: Text(
                      result.name,
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      result.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      AppDataProvider.instance.setManualLocation(
                        latitude: result.latitude,
                        longitude: result.longitude,
                        cityName: result.name,
                        countryName: result.country,
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
                    widget.isAr ? 'لا توجد مدن مطابقة لبحثك' : 'No cities found',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// ─── Premium membership card ─────────────────────────────────────────────
/// Gilded, sheen-animated membership card shown in Settings while the user
/// has an active subscription. Purely a perk of the premium theme.
class _PremiumMembershipCard extends StatelessWidget {
  const _PremiumMembershipCard({required this.isAr, this.expiry});

  final bool isAr;
  final DateTime? expiry;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.pTextSecondaryDark : AppColors.pTextSecondaryLight;

    return GildedCard(
      sheen: true,
      padding: const EdgeInsets.all(16),
      onTap: () => showSubscriptionSheet(context, isAr: isAr),
      child: Row(
        children: [
          // Gold medallion with crown
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.premiumGoldGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pGoldDeep.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.black,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GoldText(
                  'Wejhaty Premium',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  expiry != null
                      ? (isAr
                          ? 'مفعّل حتى ${_formatDate(expiry!)}'
                          : 'Active until ${_formatDate(expiry!)}')
                      : (isAr
                          ? 'حسابك مشترك بالفئة الممتازة'
                          : 'Your membership is active'),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: sub,
                  ),
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.premiumGoldGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pGoldDeep.withValues(alpha: 0.40),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Text(
              'PRO',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}