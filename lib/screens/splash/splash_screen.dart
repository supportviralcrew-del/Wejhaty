import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/constants/app_constants.dart';
import 'package:tripproject/screens/location_permission_screen.dart';
import 'package:tripproject/screens/main/main_shell.dart';
import 'package:tripproject/screens/welcome/welcome_screen.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/location_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _shineController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _shine;

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    // Shine — slow diagonal sweep every 2.2s, classic premium feel
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _shine = Tween<double>(begin: -1.4, end: 1.4).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );
    _determineNextScreen();
  }

  Future<void> _determineNextScreen() async {
    // App loads only after entrance animation + minimum splash time (both)
    await Future.wait([
      _controller.forward(),
      Future<void>.delayed(AppConstants.splashDuration),
    ]);
    if (!mounted) return;
    final provider = AppDataProvider.instance;
    final permissionStatus = await _locationService.checkPermissionStatus();
    if (!mounted) return;
    if (provider.hasCompletedSetup && permissionStatus == LocationPermissionStatus.granted) {
      unawaited(provider.initAfterPermission());
    }
    final Widget nextScreen = provider.hasCompletedSetup
        ? const MainShell()
        : permissionStatus == LocationPermissionStatus.granted
            ? const WelcomeScreen()
            : const LocationPermissionScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (c, a, s) => nextScreen,
        transitionsBuilder: (c, a, s, ch) => FadeTransition(opacity: a, child: ch),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).colorScheme.surface;
    final textColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/icon/RoadTripLogo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Ae-like silver foil sweep — sharp metallic highlight as in reference
                      AnimatedBuilder(
                        animation: _shine,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(170 * _shine.value, 0),
                          child: Transform.rotate(
                            angle: -0.42, // steeper diagonal like Ae sample
                            child: Container(
                              width: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.0),
                                    const Color(0xFFD1D1D1).withValues(alpha: 0.0),
                                    const Color(0xFFF2F2F2).withValues(alpha: 0.85),
                                    Colors.white.withValues(alpha: 1.0),
                                    const Color(0xFFE8E8E8).withValues(alpha: 0.9),
                                    const Color(0xFFB8B8B8).withValues(alpha: 0.0),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.22, 0.36, 0.44, 0.50, 0.56, 0.64, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'ViralScript Labs',
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
