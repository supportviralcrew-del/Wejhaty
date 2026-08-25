import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/core/widgets/app_logo.dart';
import 'package:tripproject/screens/main/main_shell.dart';
import 'package:tripproject/screens/welcome/widgets/desert_illustration.dart';
import 'package:tripproject/screens/welcome/widgets/welcome_feature_card.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/weather_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _actionsController;
  late final Animation<Offset> _actionsSlide;
  late final Animation<double> _actionsFade;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _actionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _actionsSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(parent: _actionsController, curve: Curves.easeOutCubic),
    );
    _actionsFade = CurvedAnimation(parent: _actionsController, curve: Curves.easeOut);
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _actionsController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _actionsController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    // Permission is optional, continue regardless of result
  }

  Future<void> _navigateToHome() async {
    await _requestNotificationPermission();
    await AppDataProvider.instance.completeSetup();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const MainShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
              Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showDestinationPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final provider = AppDataProvider.instance;
        final isAr = provider.language == 'ar';
        return _DestinationPickerSheet(
          isAr: isAr,
          weatherService: _weatherService,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);
    final isCompact = Responsive.isCompactHeight(context);
    final padding = Responsive.horizontalPadding(context);

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
            child: isWide
                ? _buildWideLayout(padding, isAr)
                : _buildMobileLayout(padding, isCompact, isAr),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(double padding, bool isCompact, bool isAr) {
    final illustrationHeight = Responsive.illustrationHeight(context);
    final cardSpacing = isCompact ? 8.0 : 10.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
          child: Container(
            height: illustrationHeight,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: DesertIllustration()),
                Positioned(
                  top: 14,
                  left: isAr ? null : 14,
                  right: isAr ? 14 : null,
                  child: Hero(
                    tag: 'app_logo',
                    child: AppLogo(size: isCompact ? 38 : 44),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padding, 28, padding, 12),
                  child: Column(
                    crossAxisAlignment: isAr
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      WelcomeFeatureCard(
                        icon: Icons.route_rounded,
                        title: isAr
                            ? 'تتبع مباشر للمسار'
                            : 'Live Route Tracking',
                        color: AppColors.routeCard,
                        delay: 0,
                      ),
                      SizedBox(height: cardSpacing),
                      WelcomeFeatureCard(
                        icon: Icons.local_gas_station_rounded,
                        title: isAr
                            ? 'الوقود والاستراحات'
                            : 'Fuel & Rest Stops',
                        color: AppColors.fuelCard,
                        delay: 100,
                      ),
                      SizedBox(height: cardSpacing),
                      WelcomeFeatureCard(
                        icon: Icons.checklist_rounded,
                        title: isAr ? 'قائمة التحقق للسفر' : 'Travel Checklist',
                        color: AppColors.checklistCard,
                        delay: 200,
                      ),
                      SizedBox(height: cardSpacing),
                      WelcomeFeatureCard(
                        icon: Icons.notifications_rounded,
                        title: isAr ? 'إشعارات الرحلة' : 'Trip Notifications',
                        color: AppColors.primary,
                        delay: 300,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 8, padding, 12),
                child: _buildActions(isAr),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(double padding, bool isAr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ResponsiveCenter(
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: DesertIllustration()),
                  Positioned(
                    top: 22,
                    left: isAr ? null : 22,
                    right: isAr ? 22 : null,
                    child: Hero(tag: 'app_logo', child: AppLogo(size: 52)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: isAr
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: isAr
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        WelcomeFeatureCard(
                          icon: Icons.route_rounded,
                          title: isAr
                              ? 'تتبع مباشر للمسار'
                              : 'Live Route Tracking',
                          color: AppColors.routeCard,
                          delay: 0,
                        ),
                        const SizedBox(height: 12),
                        WelcomeFeatureCard(
                          icon: Icons.local_gas_station_rounded,
                          title: isAr
                              ? 'الوقود والاستراحات'
                              : 'Fuel & Rest Stops',
                          color: AppColors.fuelCard,
                          delay: 100,
                        ),
                        const SizedBox(height: 12),
                        WelcomeFeatureCard(
                          icon: Icons.checklist_rounded,
                          title: isAr
                              ? 'قائمة التحقق للسفر'
                              : 'Travel Checklist',
                          color: AppColors.checklistCard,
                          delay: 200,
                        ),
                        const SizedBox(height: 12),
                        WelcomeFeatureCard(
                          icon: Icons.notifications_rounded,
                          title: isAr ? 'إشعارات الرحلة' : 'Trip Notifications',
                          color: AppColors.primary,
                          delay: 300,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildActions(isAr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isAr) {
    final provider = AppDataProvider.instance;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _actionsSlide,
      child: FadeTransition(
        opacity: _actionsFade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary — glassy outline with icon bloom
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : colorScheme.primary.withValues(alpha: 0.18), width: 1.2),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showDestinationPicker,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.route_rounded, size: 16, color: colorScheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            provider.hasChosenDestination
                                ? (isAr ? 'تغيير الوجهة' : 'Change Destination')
                                : (isAr ? 'اختر وجهة (اختياري)' : 'Select Destination (Optional)'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white.withValues(alpha: 0.92) : colorScheme.primary,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white.withValues(alpha: 0.45) : colorScheme.primary.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Primary — premium gradient with glow
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFA726), Color(0xFFFF9800), Color(0xFFF57C00)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF9800).withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToHome,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isAr ? 'ابدأ الآن' : 'Get Started',
                          style: GoogleFonts.poppins(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 14, height: 1, color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'تطوير ViralScript Labs' : 'Developed by ViralScript Labs',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white.withValues(alpha: 0.38) : Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 14, height: 1, color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Destination Picker Sheet ─────────────────────────────────────────────────

class _DestinationPickerSheet extends StatefulWidget {
  const _DestinationPickerSheet({
    required this.isAr,
    required this.weatherService,
  });

  final bool isAr;
  final WeatherService weatherService;

  @override
  State<_DestinationPickerSheet> createState() => _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<_DestinationPickerSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  final List<({String name, String nameAr, double lat, double lon})> _suggestions = const [
    (name: 'Makkah', nameAr: 'مكة المكرمة', lat: 21.4225, lon: 39.8262),
    (name: 'Medina', nameAr: 'المدينة المنورة', lat: 24.4672, lon: 39.6111),
    (name: 'Riyadh', nameAr: 'الرياض', lat: 24.7136, lon: 46.6753),
    (name: 'Dubai', nameAr: 'دبي', lat: 25.2048, lon: 55.2708),
    (name: 'Amman', nameAr: 'عمان', lat: 31.9539, lon: 35.9106),
  ];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            widget.isAr ? 'اختر وجهة السفر' : 'Select Trip Destination',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAr ? '(اختياري - يمكنك تخطي هذا)' : '(Optional - you can skip this)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 18),

          // Quick recommendations
          Text(
            widget.isAr ? 'الوجهات الشائعة' : 'Popular Destinations',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((city) {
              final name = widget.isAr ? city.nameAr : city.name;
              return ActionChip(
                label: Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                backgroundColor: _neutralFill(context),
                side: BorderSide(color: _neutralBorder(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                onPressed: () {
                  AppDataProvider.instance.setDestination(
                    cityName: name,
                    latitude: city.lat,
                    longitude: city.lon,
                  );
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  widget.isAr ? 'أو ابحث عن وجهة مخصصة' : 'Or Search Custom Destination',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
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
              hintText: widget.isAr ? 'ابحث بالإنجليزية أو العربية (مثال: مكة)' : 'Search city (e.g. Mecca, Amman)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                  });
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search Results
          if (_isSearching)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(Icons.location_city_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    title: Text(
                      result.name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      result.displayName,
                      style: GoogleFonts.inter(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      AppDataProvider.instance.setDestination(
                        cityName: result.name,
                        latitude: result.latitude,
                        longitude: result.longitude,
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
                    widget.isAr ? 'لم يتم العثور على نتائج' : 'No destinations found',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

Color _neutralFill(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035);
}

Color _neutralBorder(BuildContext context) {
  return Theme.of(context).colorScheme.outline.withValues(alpha: 0.15);
}