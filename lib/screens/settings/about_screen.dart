import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripproject/core/app_info.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/screens/settings/widgets/settings_ui.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:flutter/foundation.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final url = defaultTargetPlatform == TargetPlatform.iOS ? AppInfo.iosStoreUrl : AppInfo.androidStoreUrl;
    await _launch(url);
  }

  Future<void> _shareApp(bool isAr) async {
    final text = isAr
        ? '${AppInfo.appNameAr} — رفيقك في كل رحلة على الطريق.\n${AppInfo.companyWebsite}'
        : '${AppInfo.appNameEn} — your companion for every road trip.\n${AppInfo.companyWebsite}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isAr ? 'حول التطبيق' : 'About App',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padding, 20, padding, 60),
          // Center + ConstrainedBox (not ConstrainedBox alone) so the
          // cap actually applies even when a parent up the tree has
          // already forced a tight/full-bleed width — Center relaxes
          // that before the width limit is enforced. Cards below use
          // CrossAxisAlignment.stretch so they fill this capped width
          // instead of shrink-wrapping to their content.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── App identity ──
                  Row(
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.asset(
                          AppInfo.appLogoAsset,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: AppTheme.heroGradient,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Icon(Icons.route_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? AppInfo.appNameAr : AppInfo.appNameEn,
                              style: GoogleFonts.manrope(fontSize: 19, fontWeight: FontWeight.w700, color: onSurface),
                              softWrap: true,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v${AppInfo.appVersion}',
                              style: GoogleFonts.inter(fontSize: 12.5, color: onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Company card ──
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
                      boxShadow: AppTheme.softShadow(isDark: Theme.of(context).brightness == Brightness.dark),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Banner: the company logo image itself, full-width
                        SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: Image.asset(
                            AppInfo.companyLogoAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(gradient: AppTheme.heroGradient),
                              alignment: Alignment.center,
                              child: const Icon(Icons.business_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                          child: Column(
                            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'من نحن؟' : 'Who\'s behind this app?',
                                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAr ? AppInfo.companyNameAr : AppInfo.companyNameEn,
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isAr ? AppInfo.companyDescriptionAr : AppInfo.companyDescriptionEn,
                                textAlign: isAr ? TextAlign.right : TextAlign.left,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  height: 1.6,
                                  color: onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)),
                        SettingsRow(
                          icon: Icons.public_rounded,
                          iconColor: AppColors.primary,
                          title: isAr ? 'زيارة موقعنا الإلكتروني' : 'Visit our website',
                          subtitle: AppInfo.companyWebsite.replaceFirst('https://', ''),
                          isAr: isAr,
                          onTap: () => _launch(AppInfo.companyWebsite),
                          trailing: SettingsChevron(isAr: isAr),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Rate / Share ──
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: Icons.star_rounded,
                        iconColor: AppColors.secondary,
                        title: isAr ? 'تقييم التطبيق' : 'Rate the App',
                        subtitle: isAr ? 'رأيك يساعدنا على التحسين' : 'Your feedback helps us improve',
                        isAr: isAr,
                        onTap: _rateApp,
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                      SettingsRow(
                        icon: Icons.ios_share_rounded,
                        iconColor: AppColors.checklistCard,
                        title: isAr ? 'شارك التطبيق' : 'Share the App',
                        subtitle: isAr ? 'أخبر أصدقاءك عنه' : 'Tell your friends about it',
                        isAr: isAr,
                        onTap: () => _shareApp(isAr),
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                      SettingsRow(
                        icon: Icons.email_rounded,
                        iconColor: AppColors.weatherCard,
                        title: isAr ? 'راسلنا بالإيميل' : 'Email us',
                        subtitle: AppInfo.supportEmail,
                        isAr: isAr,
                        onTap: _emailUs,
                        trailing: SettingsChevron(isAr: isAr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}