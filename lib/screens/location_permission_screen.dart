import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/screens/welcome/welcome_screen.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/location_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with TickerProviderStateMixin {
  // ─── State ───────────────────────────────────────────────────────────────
  final LocationService _locationService = LocationService();
  _PermissionUiState _uiState = _PermissionUiState.explanation;
  bool _isLoading = false;

  // ─── Animations ──────────────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _orbitController;
  late final Animation<double> _orbitAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _orbitAnimation = Tween<double>(begin: 0, end: 1).animate(_orbitController);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  // ─── Navigation ──────────────────────────────────────────────────────────
  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ─── Permission Logic ────────────────────────────────────────────────────
  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);

    final status = await _locationService.requestPermission();

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (status) {
      case LocationPermissionStatus.granted:
        // Start fetching data immediately in background, then navigate
        unawaited(AppDataProvider.instance.initAfterPermission());
        if (mounted) _navigateToHome();

      case LocationPermissionStatus.denied:
        setState(() => _uiState = _PermissionUiState.denied);

      case LocationPermissionStatus.deniedForever:
        setState(() => _uiState = _PermissionUiState.deniedForever);

      case LocationPermissionStatus.serviceDisabled:
      case LocationPermissionStatus.unknown:
        setState(() => _uiState = _PermissionUiState.denied);
    }
  }

  Future<void> _openSettings() async {
    await _locationService.openAppSettings();
    if (!mounted) return;
    // After returning from settings, re-check permission
    setState(() => _isLoading = true);
    final status = await _locationService.checkPermissionStatus();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (status == LocationPermissionStatus.granted) {
      _navigateToHome();
    } else if (status == LocationPermissionStatus.deniedForever) {
      setState(() => _uiState = _PermissionUiState.deniedForever);
    } else {
      setState(() => _uiState = _PermissionUiState.denied);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final isAr = provider.language == 'ar';
    final direction = isAr ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              ),
              child: switch (_uiState) {
                _PermissionUiState.explanation => _ExplanationView(
                    key: const ValueKey('explanation'),
                    pulseAnimation: _pulseAnimation,
                    orbitAnimation: _orbitAnimation,
                    isLoading: _isLoading,
                    isAr: isAr,
                    onAllow: _requestPermission,
                    onSkip: _navigateToHome,
                  ),
                _PermissionUiState.denied => _DeniedView(
                    key: const ValueKey('denied'),
                    isLoading: _isLoading,
                    isAr: isAr,
                    onRetry: _requestPermission,
                    onSkip: _navigateToHome,
                  ),
                _PermissionUiState.deniedForever => _DeniedForeverView(
                    key: const ValueKey('deniedForever'),
                    isLoading: _isLoading,
                    isAr: isAr,
                    onOpenSettings: _openSettings,
                    onSkip: _navigateToHome,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── UI State Enum ────────────────────────────────────────────────────────────
enum _PermissionUiState { explanation, denied, deniedForever }

// ─── Explanation View ─────────────────────────────────────────────────────────
class _ExplanationView extends StatelessWidget {
  const _ExplanationView({
    super.key,
    required this.pulseAnimation,
    required this.orbitAnimation,
    required this.isLoading,
    required this.isAr,
    required this.onAllow,
    required this.onSkip,
  });

  final Animation<double> pulseAnimation;
  final Animation<double> orbitAnimation;
  final bool isLoading;
  final bool isAr;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // ── GPS Illustration ──
          SizedBox(
            width: 220,
            height: 220,
            child: _GpsIllustration(
              pulseAnimation: pulseAnimation,
              orbitAnimation: orbitAnimation,
            ),
          ),
          const Spacer(flex: 1),
          // ── Title ──
          Text(
            isAr ? 'تفعيل الوصول للموقع' : 'Enable Location Access',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // ── Description ──
          Text(
            isAr
                ? 'نحن نستخدم موقعك الجغرافي لتوفير تتبع مباشر للمسار، ومحطات الوقود القريبة، والمطاعم، وأوقات الصلاة، ومعلومات السفر.'
                : 'We use your location to provide live route tracking, nearby fuel stations, restaurants, prayer times, and travel information.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // ── Feature Pills ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _FeaturePill(
                icon: Icons.route_rounded,
                label: isAr ? 'تتبع المسار' : 'Route Tracking',
                color: AppColors.sunsetBlue,
              ),
              _FeaturePill(
                icon: Icons.local_gas_station_rounded,
                label: isAr ? 'محطات الوقود' : 'Fuel Stations',
                color: AppColors.fuelCard,
              ),
              _FeaturePill(
                icon: Icons.restaurant_rounded,
                label: isAr ? 'المطاعم' : 'Restaurants',
                color: AppColors.restaurantCard,
              ),
              _FeaturePill(
                icon: Icons.mosque_rounded,
                label: isAr ? 'أوقات الصلاة' : 'Prayer Times',
                color: AppColors.prayerCard,
              ),
            ],
          ),
          const Spacer(flex: 2),
          // ── Buttons ──
          _PrimaryButton(
            label: isAr ? 'السماح بالوصول' : 'Allow Location',
            icon: Icons.location_on_rounded,
            isLoading: isLoading,
            onPressed: onAllow,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: isAr ? 'ليس الآن' : 'Not Now',
            onPressed: onSkip,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Denied View ──────────────────────────────────────────────────────────────
class _DeniedView extends StatelessWidget {
  const _DeniedView({
    super.key,
    required this.isLoading,
    required this.isAr,
    required this.onRetry,
    required this.onSkip,
  });

  final bool isLoading;
  final bool isAr;
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // ── Icon ──
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sunsetOrange.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.sunsetOrange.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              size: 56,
              color: AppColors.sunsetOrange,
            ),
          ),
          const Spacer(flex: 1),
          Text(
            isAr ? 'تم رفض الوصول للموقع' : 'Location Access Denied',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.info_outline_rounded,
            color: AppColors.sunsetAmber,
            message: isAr
                ? 'بدون السماح بالوصول للموقع، لن تتمكن من استخدام مميزات مثل التتبع المباشر، ومحطات الوقود القريبة، ومعلومات السفر الفورية.'
                : 'Without location access, features like live route tracking, nearby fuel stations, and real-time travel info will not be available.',
          ),
          const Spacer(flex: 2),
          _PrimaryButton(
            label: isAr ? 'حاول مرة أخرى' : 'Try Again',
            icon: Icons.refresh_rounded,
            isLoading: isLoading,
            onPressed: onRetry,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: isAr ? 'المتابعة بدون تحديد موقع' : 'Continue Without Location',
            onPressed: onSkip,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Denied Forever View ──────────────────────────────────────────────────────
class _DeniedForeverView extends StatelessWidget {
  const _DeniedForeverView({
    super.key,
    required this.isLoading,
    required this.isAr,
    required this.onOpenSettings,
    required this.onSkip,
  });

  final bool isLoading;
  final bool isAr;
  final VoidCallback onOpenSettings;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // ── Icon ──
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emergencyCard.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.emergencyCard.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 56,
              color: AppColors.emergencyCard,
            ),
          ),
          const Spacer(flex: 1),
          Text(
            isAr ? 'تم حظر إذن الموقع' : 'Permission Blocked',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.settings_rounded,
            color: AppColors.sunsetBlue,
            message: isAr
                ? 'تم رفض إذن تحديد الموقع بشكل دائم. يرجى فتح إعدادات نظام التشغيل وتفعيل إذن الموقع لتطبيق وجهتي للاستفادة من كامل الميزات.'
                : 'Location permission has been permanently denied. Please open Android Settings and enable location access for Wejhaty to use all features.',
          ),
          const SizedBox(height: 16),
          // Step-by-step guide card
          _StepsCard(isAr: isAr),
          const Spacer(flex: 2),
          _PrimaryButton(
            label: isAr ? 'فتح إعدادات التطبيق' : 'Open App Settings',
            icon: Icons.settings_rounded,
            isLoading: isLoading,
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: isAr ? 'المتابعة بدون تحديد موقع' : 'Continue Without Location',
            onPressed: onSkip,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _GpsIllustration extends StatelessWidget {
  const _GpsIllustration({
    required this.pulseAnimation,
    required this.orbitAnimation,
  });

  final Animation<double> pulseAnimation;
  final Animation<double> orbitAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseAnimation, orbitAnimation]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outermost ring
            _Ring(size: 200, opacity: 0.06, color: AppColors.sunsetOrange),
            // Middle ring
            _Ring(size: 160, opacity: 0.12, color: AppColors.sunsetOrange),
            // Inner ring
            _Ring(size: 120, opacity: 0.18, color: AppColors.sunsetOrange),
            // Orbiting dot
            Transform.rotate(
              angle: orbitAnimation.value * 2 * 3.14159,
              child: Transform.translate(
                offset: const Offset(72, 0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sunsetAmber,
                  ),
                ),
              ),
            ),
            // Central pulsing location icon
            Transform.scale(
              scale: pulseAnimation.value,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.sunsetOrange, AppColors.sunsetAmber],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sunsetOrange.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.opacity,
    required this.color,
  });

  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.isAr});

  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final steps = isAr
        ? [
            'اضغط على "فتح إعدادات التطبيق" بالأسفل',
            'اختر الأذونات ← الموقع الجغرافي',
            'حدد "السماح عند استخدام التطبيق فقط"',
            'عد إلى تطبيق وجهتي',
          ]
        : [
            'Tap "Open App Settings" below',
            'Select Permissions → Location',
            'Choose "Allow only while using the app"',
            'Return to Wejhaty',
          ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'طريقة التفعيل:' : 'How to enable:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sunsetBlue.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.sunsetBlue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sunsetBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
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
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sunsetOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sunsetOrange.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            side: BorderSide(
              color: isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
