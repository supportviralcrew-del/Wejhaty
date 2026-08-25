import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/widgets/glass_card.dart';
import 'package:tripproject/services/app_data_provider.dart';

enum _TrackingStatus {
  checking,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  tracking,
}

enum _SpeedZone { safe, moderate, high }

/// Regular UI text uses Poppins for Latin script and Tajawal for Arabic,
/// since Poppins doesn't render Arabic glyphs well.
TextStyle _uiFont(
    bool isAr, {
      required double fontSize,
      FontWeight fontWeight = FontWeight.w400,
      Color? color,
      double? height,
      FontStyle? fontStyle,
    }) {
  return isAr
      ? GoogleFonts.tajawal(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    fontStyle: fontStyle,
  )
      : GoogleFonts.poppins(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    fontStyle: fontStyle,
  );
}

class SpeedScreen extends StatefulWidget {
  const SpeedScreen({super.key});

  @override
  State<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends State<SpeedScreen>
    with SingleTickerProviderStateMixin {
  static const double _speedLimitKmh = 120;
  static const double _moderateThresholdKmh = 80;
  static const double _gaugeMaxKmh = 180;

  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _averageSpeed = 0.0;
  double _accuracy = 0.0;
  int _speedReadings = 0;
  _TrackingStatus _status = _TrackingStatus.checking;
  StreamSubscription<Position>? _positionSubscription;

  // Used for the manual distance/time fallback speed calculation.
  Position? _lastPosition;
  DateTime? _lastTimestamp;

  // Smoothing buffer for speed readings (like speedometer apps)
  final List<double> _speedBuffer = [];
  static const int _bufferSize = 5;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _initTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initTracking() async {
    setState(() => _status = _TrackingStatus.checking);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = _TrackingStatus.serviceDisabled);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = _TrackingStatus.permissionDenied);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = _TrackingStatus.permissionDeniedForever);
      return;
    }

    setState(() => _status = _TrackingStatus.tracking);
    _startSpeedTracking();
  }

  /// Builds platform-tuned settings, requesting the fastest fix rate each
  /// platform allows for a driving/navigation use case. On Android we ask
  /// for updates as often as every 500ms (down from 1s) — most GPS chips
  /// won't exceed ~1Hz regardless, but this removes any artificial
  /// throttling on devices that can go faster, and distanceFilter stays at
  /// 0 so no fix is ever skipped for being "too small" a movement.
  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
        forceLocationManager: false,
      );
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  void _startSpeedTracking() {
    _positionSubscription?.cancel();
    _lastPosition = null;
    _lastTimestamp = null;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      _handleNewPosition,
      onError: (_) {
        if (mounted) setState(() => _status = _TrackingStatus.serviceDisabled);
      },
    );
  }

  void _handleNewPosition(Position position) {
    if (!mounted) return;

    double speedKmh = position.speed * 3.6;
    if (speedKmh.isNaN || speedKmh < 0) speedKmh = 0;

    // Fallback: some devices report speed as 0/unreliable from the GPS chip
    // even while clearly moving. Cross-check against a manual distance/time
    // calculation between consecutive fixes and prefer it when it disagrees
    // strongly with a "not moving" reading and the fix quality is decent.
    final now = DateTime.now();
    if (_lastPosition != null && _lastTimestamp != null) {
      final elapsedSeconds =
          now.difference(_lastTimestamp!).inMilliseconds / 1000.0;
      if (elapsedSeconds > 0.3) {
        final distanceMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        final manualSpeedKmh = (distanceMeters / elapsedSeconds) * 3.6;
        // Improved fallback: use manual speed when GPS speed is unreliable
        // or when the difference is significant and accuracy is good
        if ((speedKmh < 2 && manualSpeedKmh > 5) ||
            (position.accuracy <= 20 && (speedKmh - manualSpeedKmh).abs() > 10)) {
          speedKmh = manualSpeedKmh;
        }
      }
    }
    _lastPosition = position;
    _lastTimestamp = now;

    speedKmh = speedKmh.clamp(0.0, 300.0);

    // Add to smoothing buffer
    _speedBuffer.add(speedKmh);
    if (_speedBuffer.length > _bufferSize) {
      _speedBuffer.removeAt(0);
    }

    // Calculate smoothed speed (average of buffer)
    final smoothedSpeed = _speedBuffer.isEmpty
        ? speedKmh
        : _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;

    // Setting state immediately with the smoothed reading
    setState(() {
      _currentSpeed = smoothedSpeed;
      _accuracy = position.accuracy;
      if (smoothedSpeed > _maxSpeed) _maxSpeed = smoothedSpeed;
      _speedReadings++;
      _averageSpeed =
          ((_averageSpeed * (_speedReadings - 1)) + smoothedSpeed) / _speedReadings;
    });
  }

  void _resetStats() {
    setState(() {
      _maxSpeed = 0.0;
      _averageSpeed = 0.0;
      _speedReadings = 0;
      _speedBuffer.clear();
    });
  }

  bool _isArabic() => AppDataProvider.instance.language == 'ar';
  AppDataProvider get _provider => AppDataProvider.instance;

  _SpeedZone get _zone {
    if (_currentSpeed > _speedLimitKmh) return _SpeedZone.high;
    if (_currentSpeed > _moderateThresholdKmh) return _SpeedZone.moderate;
    return _SpeedZone.safe;
  }

  Color _zoneColor(_SpeedZone zone) {
    switch (zone) {
      case _SpeedZone.safe:
        return AppColors.success;
      case _SpeedZone.moderate:
        return AppColors.warning;
      case _SpeedZone.high:
        return AppColors.error;
    }
  }

  String _zoneLabel(_SpeedZone zone, bool isAr) {
    switch (zone) {
      case _SpeedZone.safe:
        return isAr ? 'آمن' : 'Safe';
      case _SpeedZone.moderate:
        return isAr ? 'متوسط' : 'Moderate';
      case _SpeedZone.high:
        return isAr ? 'مرتفع' : 'High';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isArabic();
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            isAr ? 'السرعة' : 'Speed',
            style: _uiFont(isAr, fontWeight: FontWeight.w700, fontSize: 20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            if (_status == _TrackingStatus.tracking)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: isAr ? 'إعادة تعيين' : 'Reset stats',
                onPressed: _resetStats,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _zoneColor(_zone).withValues(alpha: 0.07),
                  colorScheme.surface,
                ],
              ),
            ),
            child: _buildBody(isAr, colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isAr, ColorScheme colorScheme) {
    switch (_status) {
      case _TrackingStatus.checking:
        return Center(
          child: CircularProgressIndicator(color: AppColors.sunsetOrange),
        );
      case _TrackingStatus.serviceDisabled:
        return _buildIssueState(
          isAr: isAr,
          colorScheme: colorScheme,
          icon: Icons.location_disabled_rounded,
          title: isAr ? 'خدمة الموقع غير مفعّلة' : 'Location services are off',
          message: isAr
              ? 'يرجى تفعيل خدمة الموقع لتتبع سرعتك.'
              : 'Please enable location services to track your speed.',
          buttonLabel: isAr ? 'فتح الإعدادات' : 'Open Settings',
          onPressed: () async {
            await Geolocator.openLocationSettings();
            _initTracking();
          },
        );
      case _TrackingStatus.permissionDenied:
        return _buildIssueState(
          isAr: isAr,
          colorScheme: colorScheme,
          icon: Icons.location_off_rounded,
          title: isAr ? 'إذن الموقع مرفوض' : 'Location permission denied',
          message: isAr
              ? 'نحتاج إلى إذن الوصول للموقع لعرض سرعتك.'
              : 'We need location access to show your speed.',
          buttonLabel: isAr ? 'إعادة المحاولة' : 'Try Again',
          onPressed: _initTracking,
        );
      case _TrackingStatus.permissionDeniedForever:
        return _buildIssueState(
          isAr: isAr,
          colorScheme: colorScheme,
          icon: Icons.location_off_rounded,
          title: isAr ? 'تم رفض الإذن بشكل دائم' : 'Permission permanently denied',
          message: isAr
              ? 'يرجى تفعيل إذن الموقع يدويًا من إعدادات التطبيق.'
              : 'Please enable location permission from app settings.',
          buttonLabel: isAr ? 'فتح إعدادات التطبيق' : 'Open App Settings',
          onPressed: () async {
            await Geolocator.openAppSettings();
            _initTracking();
          },
        );
      case _TrackingStatus.tracking:
        return _buildTrackingView(isAr, colorScheme);
    }
  }

  Widget _buildIssueState({
    required bool isAr,
    required ColorScheme colorScheme,
    required IconData icon,
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: colorScheme.error.withValues(alpha: 0.8)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _uiFont(isAr, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _uiFont(
                isAr,
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sunsetOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                buttonLabel,
                style: _uiFont(isAr, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingView(bool isAr, ColorScheme colorScheme) {
    final zone = _zone;
    final isOverLimit = zone == _SpeedZone.high;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _buildGauge(isAr, colorScheme, zone),
          const SizedBox(height: 12),
          _buildZoneChip(isAr, zone),
          const SizedBox(height: 10),
          _buildAccuracyBadge(isAr, colorScheme),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    isAr,
                    isAr ? 'السرعة القصوى' : 'Max Speed',
                    _provider.nfd(_maxSpeed),
                    'km/h',
                    Icons.speed_rounded,
                    AppColors.routeCard,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    isAr,
                    isAr ? 'متوسط السرعة' : 'Avg Speed',
                    _provider.nfd(_averageSpeed),
                    'km/h',
                    Icons.show_chart_rounded,
                    AppColors.prayerCard,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: isOverLimit
                ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _buildWarningBanner(isAr, colorScheme),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneChip(bool isAr, _SpeedZone zone) {
    final color = _zoneColor(zone);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _zoneLabel(zone, isAr),
              key: ValueKey(zone),
              style: _uiFont(
                isAr,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge(bool isAr, ColorScheme colorScheme, _SpeedZone zone) {
    // The value passed to the progress ring and the number is the raw,
    // un-smoothed reading — no TweenAnimationBuilder wraps the speed value
    // itself anymore, so the display snaps to each new GPS fix immediately.
    // Only the *color* of the ring/number eases between zones, which reads
    // as polish rather than lag since the position/number never lingers
    // behind reality.
    final progress = (_currentSpeed / _gaugeMaxKmh).clamp(0.0, 1.0);
    final gaugeColor = _zoneColor(zone);

    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tick marks around the dial.
          CustomPaint(
            size: const Size(270, 270),
            painter: _GaugeTicksPainter(
              maxSpeed: _gaugeMaxKmh,
              speedLimit: _speedLimitKmh,
              baseColor: colorScheme.onSurface.withValues(alpha: 0.18),
              limitColor: AppColors.error.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(
            width: 232,
            height: 232,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(begin: gaugeColor, end: gaugeColor),
              duration: const Duration(milliseconds: 250),
              builder: (context, color, _) => CircularProgressIndicator(
                value: progress,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(color ?? gaugeColor),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isHigh = zone == _SpeedZone.high;
              final glow = isHigh ? 0.18 + (_pulseController.value * 0.14) : 0.16;
              return Container(
                width: 182,
                height: 182,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      gaugeColor.withValues(alpha: 0.16),
                      gaugeColor.withValues(alpha: 0.03),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gaugeColor.withValues(alpha: glow),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: GoogleFonts.poppins(
                      fontSize: 54,
                      fontWeight: FontWeight.w700,
                      color: gaugeColor,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: Text(_provider.nfd(_currentSpeed)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr ? 'كم/س' : 'km/h',
                    style: _uiFont(
                      isAr,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
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

  Widget _buildAccuracyBadge(bool isAr, ColorScheme colorScheme) {
    final isGoodSignal = _accuracy > 0 && _accuracy <= 15;
    final isOkSignal = _accuracy > 15 && _accuracy <= 35;
    final dotColor = _accuracy <= 0
        ? colorScheme.onSurface.withValues(alpha: 0.35)
        : isGoodSignal
        ? const Color(0xFF2ECC71)
        : isOkSignal
        ? const Color(0xFFF5A623)
        : const Color(0xFFE74C3C);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        Icon(
          Icons.gps_fixed_rounded,
          size: 13,
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Text(
          _accuracy > 0
              ? (isAr
              ? 'دقة الإشارة: ±${_provider.nfw(_accuracy)} م'
              : 'Signal accuracy: ±${_provider.nfw(_accuracy)} m')
              : (isAr ? 'جاري تحديد الموقع...' : 'Locating...'),
          style: _uiFont(
            isAr,
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(bool isAr, ColorScheme colorScheme) {
    const errorColor = Color(0xFFE74C3C);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: errorColor.withValues(
                  alpha: 0.1 + (_pulseController.value * 0.08),
                ),
                shape: BoxShape.circle,
              ),
              child: child,
            ),
            child: const Icon(Icons.warning_rounded, color: errorColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'تجاوزت الحد المسموح!' : 'Speed limit exceeded!',
                  style: _uiFont(
                    isAr,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: errorColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAr
                      ? 'الحد ${_provider.nfi(_speedLimitKmh.round())} كم/س'
                      : 'Limit is ${_provider.nfi(_speedLimitKmh.round())} km/h',
                  style: _uiFont(
                    isAr,
                    fontSize: 12,
                    color: errorColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, bool isAr, String label,
      String value, String unit, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: _uiFont(
              isAr,
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints minute/major tick marks around the speed dial, highlighting the
/// tick nearest the configured speed limit in red.
class _GaugeTicksPainter extends CustomPainter {
  final double maxSpeed;
  final double speedLimit;
  final Color baseColor;
  final Color limitColor;

  _GaugeTicksPainter({
    required this.maxSpeed,
    required this.speedLimit,
    required this.baseColor,
    required this.limitColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 2;
    const tickCount = 36; // every 5 km/h if max is 180
    final limitFraction = (speedLimit / maxSpeed).clamp(0.0, 1.0);
    final limitTickIndex = (limitFraction * tickCount).round();

    for (int i = 0; i <= tickCount; i++) {
      final isMajor = i % 6 == 0;
      final isLimit = i == limitTickIndex;
      final angle = -math.pi / 2 + (2 * math.pi * i / tickCount);
      final tickLength = isLimit ? 12.0 : (isMajor ? 9.0 : 5.0);
      final innerRadius = outerRadius - tickLength;

      final p1 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      final paint = Paint()
        ..color = isLimit ? limitColor : baseColor
        ..strokeWidth = isLimit ? 2.6 : (isMajor ? 2.0 : 1.2)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeTicksPainter oldDelegate) {
    return oldDelegate.speedLimit != speedLimit || oldDelegate.maxSpeed != maxSpeed;
  }
}