import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripproject/core/constants/app_constants.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/screens/splash/splash_screen.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/notification_service.dart';
import 'package:tripproject/services/subscription_service.dart';
import 'package:tripproject/services/trip_stats_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for mobile devices
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Enable edge-to-edge display on supported platforms
  if (!kIsWeb && Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Initialize persistent user settings
  await AppDataProvider.instance.init();
  await SubscriptionService.instance.init();

  // If the app process was killed while a trip was still being tracked
  // (the user exited the app), resume tracking automatically. The trip
  // only stops when the user stops it manually or arrives at the
  // destination — never just because the app was closed.
  if (!kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      AppDataProvider.instance.isTripActive) {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await TripProgressService.instance.resumeAfterRestart();
      }
    } catch (_) {
      // Never block startup because of a tracking-resume failure.
    }
  }

  // Ask for notification permission (Android 13+) since the persistent
  // prayer-countdown bar is on by default. If the user denies it, the
  // notification simply won't appear until they enable it manually in
  // system settings; the in-app toggle in Settings still works either way.
  if (!kIsWeb && Platform.isAndroid && AppDataProvider.instance.showNotificationBar) {
    await NotificationService.instance.requestPermission();
  }

  // Initialize Mobile Ads SDK (only on mobile platforms)
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  // Set system UI overlay style (will be updated by theme in main_shell)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const RoadTripApp());
}

class RoadTripApp extends StatelessWidget {
  const RoadTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppDataProvider.instance,
      builder: (context, _) {
        final provider = AppDataProvider.instance;
        final premiumTheme = provider.premiumThemeActive;
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          // Premium subscribers get the exclusive "Obsidian & Gold" theme
          // unless they turn it off in Settings → Premium Features.
          theme: premiumTheme ? AppTheme.premiumLightTheme : AppTheme.lightTheme,
          darkTheme: premiumTheme ? AppTheme.premiumDarkTheme : AppTheme.darkTheme,
          themeMode: provider.themeMode,
          locale: Locale(provider.language),
          home: const SplashScreen(),
        );
      },
    );
  }
}