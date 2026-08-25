import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/core/widgets/gradient_background.dart';
import 'package:tripproject/core/widgets/premium_effects.dart';
import 'package:tripproject/screens/home/home_screen.dart';
import 'package:tripproject/screens/map/map_screen.dart';
import 'package:tripproject/screens/settings/settings_screen.dart';
import 'package:tripproject/screens/trip/trip_screen.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/subscription_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Verify subscription status when app returns to foreground
    if (state == AppLifecycleState.resumed) {
      SubscriptionService.instance.verifySubscriptionStatus();
    }
  }

  late final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const TripScreen(),
    const SettingsScreen(),
  ];

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    
    // Prevent accessing map tab if no destination is selected
    if (index == 1) {
      final provider = AppDataProvider.instance;
      if (!provider.hasChosenDestination) {
        return;
      }
    }
    
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final provider = AppDataProvider.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final isAr = provider.language == 'ar';
        final direction = isAr ? TextDirection.rtl : TextDirection.ltr;
        final tabs = _tabs(isAr);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: provider.premiumThemeActive
                ? (isDark
                      ? AppColors.pNavBackgroundDark
                      : AppColors.pNavBackgroundLight)
                : isDark
                ? const Color(0xFF161616)
                : const Color(0xFFFFFFFF),
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true,
              body: GradientBackground(
                child: isDesktop
                    ? _buildDesktopLayout(_screens[_currentIndex], tabs, provider)
                    : _buildMobileLayout(_screens[_currentIndex], tabs, provider),
              ),
            ),
          ),
        );
      },
    );
  }

  List<_NavItem> _tabs(bool isAr) {
    return [
      _NavItem(
        Icons.home_outlined,
        Icons.home_rounded,
        isAr ? 'الرئيسية' : 'Home',
      ),
      _NavItem(
        Icons.map_outlined,
        Icons.map_rounded,
        isAr ? 'الخريطة' : 'Map',
      ),
      _NavItem(
        Icons.luggage_outlined,
        Icons.luggage_rounded,
        isAr ? 'الرحلة' : 'Trip',
      ),
      _NavItem(
        Icons.settings_outlined,
        Icons.settings_rounded,
        isAr ? 'الإعدادات' : 'Settings',
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Mobile layout
  // ---------------------------------------------------------------------

  Widget _buildMobileLayout(
      Widget activeScreen,
      List<_NavItem> tabs,
      AppDataProvider provider,
      ) {
    return Stack(
      children: [
        // ── Main content fills the full area ──
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: _bottomNavReservedHeight(context),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentIndex),
                  child: activeScreen,
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav(tabs, provider)),
      ],
    );
  }

  /// Height reserved above the tab bar so page content never sits behind it.
  /// The floating bar is compact: icon+label row (~60) plus margins.
  double _bottomNavReservedHeight(BuildContext context) {
    return 80.0;
  }

  /// Floating tab bar synced with app theme (Blue & White in light theme, Blue & Dark in dark theme).
  /// Premium subscribers get the exclusive champagne-gold treatment.
  Widget _buildBottomNav(List<_NavItem> tabs, AppDataProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = provider.premiumThemeActive;

    final Color bgColor;
    final Color borderColor;
    if (isPremium) {
      bgColor = isDark ? AppColors.pNavBackgroundDark : AppColors.pNavBackgroundLight;
      borderColor = isDark
          ? AppColors.pGoldDeep.withValues(alpha: 0.28)
          : AppColors.pGoldDeep.withValues(alpha: 0.35);
    } else {
      bgColor = isDark ? AppColors.navBackgroundDark : AppColors.navBackgroundLight;
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: (isPremium
            ? GoldSheen(
                borderRadius: BorderRadius.circular(22),
                opacity: isDark ? 0.10 : 0.16,
                child: _buildBottomNavContainer(tabs, provider, bgColor, borderColor, isDark),
              )
            : _buildBottomNavContainer(tabs, provider, bgColor, borderColor, isDark)),
      ),
    );
  }

  Widget _buildBottomNavContainer(
    List<_NavItem> tabs,
    AppDataProvider provider,
    Color bgColor,
    Color borderColor,
    bool isDark,
  ) {
    final isPremium = provider.premiumThemeActive;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isPremium
            ? [
                BoxShadow(
                  color: AppColors.pGoldDeep.withValues(alpha: isDark ? 0.22 : 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final item = tabs[i];
                final active = i == _currentIndex;
                // Disable map tab (index 1) if no destination is selected
                final isDisabled = i == 1 && !provider.hasChosenDestination;
                return Expanded(
                  child: _NavButton(
                    tab: item,
                    selected: active,
                    disabled: isDisabled,
                    premium: isPremium,
                    onTap: () => _selectTab(i),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Desktop layout
  // ---------------------------------------------------------------------

  Widget _buildDesktopLayout(
      Widget activeScreen,
      List<_NavItem> tabs,
      AppDataProvider provider,
      ) {
    return SafeArea(
      child: ResponsiveCenter(
        child: Row(
          children: [
            _buildSideNav(tabs, provider),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentIndex),
                  child: activeScreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNav(List<_NavItem> tabs, AppDataProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = provider.premiumThemeActive;
    final activeAccent = isPremium
        ? (isDark ? AppColors.pNavActiveDark : AppColors.pNavActiveLight)
        : AppColors.sunsetOrange;

    return Container(
      width: 96,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        border: Border.all(
          color: isPremium
              ? AppColors.pGoldDeep.withValues(alpha: 0.30)
              : isDark
              ? AppColors.glassBorder
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          if (isPremium)
            BoxShadow(
              color: AppColors.pGoldDeep.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: NavigationRail(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        backgroundColor: Colors.transparent,
        indicatorColor: activeAccent.withValues(alpha: 0.18),
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(
          color: activeAccent,
          size: 26,
        ),
        unselectedIconTheme: IconThemeData(
          color: isDark ? AppColors.textMuted : Colors.grey.shade500,
          size: 24,
        ),
        destinations: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final isDisabled = i == 1 && !provider.hasChosenDestination;
          return NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.activeIcon),
            label: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDisabled ? Colors.grey.withValues(alpha: 0.3) : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A single tab bar item with purple styling.
/// Selected item has a darker purple background highlight with underline.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.premium = false,
  });

  final _NavItem tab;
  final bool selected;
  final bool disabled;
  final bool premium;
  final VoidCallback onTap;

  Color _activeColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (premium) {
      return isDark ? AppColors.pNavActiveDark : AppColors.pNavActiveLight;
    }
    return isDark ? AppColors.navActiveDark : AppColors.navActiveLight;
  }

  Color _inactiveColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (premium) {
      return isDark ? AppColors.pNavInactiveDark : AppColors.pNavInactiveLight;
    }
    return isDark ? AppColors.navInactiveDark : AppColors.navInactiveLight;
  }

  Color _pillColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (premium) {
      return isDark ? AppColors.pNavPillDark : AppColors.pNavPillLight;
    }
    return isDark ? AppColors.navPillDark : AppColors.navPillLight;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _activeColor(context);
    final inactiveColor = _inactiveColor(context);
    final pillColor = _pillColor(context);
    final disabledColor = inactiveColor.withValues(alpha: 0.3);

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? pillColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? tab.activeIcon : tab.icon,
                  size: 22,
                  color: disabled ? disabledColor : (selected ? activeColor : inactiveColor),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: disabled ? disabledColor : (selected ? activeColor : inactiveColor),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 230),
                margin: const EdgeInsets.only(top: 3),
                width: selected ? 16 : 0,
                height: selected ? 2.5 : 0,
                decoration: BoxDecoration(
                  gradient: premium
                      ? const LinearGradient(
                          colors: [AppColors.pGoldSoft, AppColors.pGoldDeep],
                        )
                      : null,
                  color: premium ? null : (selected ? activeColor : null),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
