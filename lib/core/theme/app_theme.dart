import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';

abstract final class AppTheme {
  // Material 3 Spacing System (8dp base)
  static const double spacingXxs = 4;
  static const double spacingXs = 8;
  static const double spacingSm = 12;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // Material 3 Border Radius
  static const double radiusXxs = 4;
  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // Legacy aliases for backward compatibility
  static const double borderRadius = radiusLg;
  static const double borderRadiusSmall = radiusSm;
  static const double borderRadiusLarge = radiusXl;

  // ── Typography pairing ────────────────────────────────────────────────
  // Display/headline copy uses Manrope: a geometric, confident face that
  // reads as a dedicated navigation/travel product rather than the
  // Inter-everywhere look common to generic AI chat interfaces. Inter is
  // kept for body copy where its neutrality and legibility at small sizes
  // still wins.
  static TextStyle display({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );

  // ── Elevation / shadows ────────────────────────────────────────────────
  static List<BoxShadow> cardShadow({bool isDark = true}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> softShadow({bool isDark = true}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ── Gradients ──────────────────────────────────────────────────────────
  static LinearGradient get heroGradient => const LinearGradient(
    colors: AppColors.heroGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get emergencyGradient => const LinearGradient(
    colors: AppColors.emergencyGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Signature champagne-gold gradient reserved for Premium surfaces.
  static LinearGradient get premiumGoldGradient => const LinearGradient(
    colors: [AppColors.pGoldSoft, AppColors.pGold, AppColors.pGoldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm golden glow used to make Premium cards and buttons feel lit.
  static List<BoxShadow> goldGlow({double strength = 1.0}) => [
    BoxShadow(
      color: AppColors.pGold.withValues(alpha: 0.22 * strength),
      blurRadius: 22 * strength,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.30),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        tertiary: AppColors.weatherCard,
        surface: AppColors.surface,
        surfaceContainer: AppColors.surfaceContainer,
        error: AppColors.error,
        onPrimary: AppColors.onPrimary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.outline,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: display(fontSize: 57, letterSpacing: -0.5),
        displayMedium: display(fontSize: 45, letterSpacing: -0.4),
        displaySmall: display(fontSize: 36, letterSpacing: -0.3),
        headlineLarge: display(fontSize: 32, letterSpacing: -0.4),
        headlineMedium: display(fontSize: 28, letterSpacing: -0.3),
        headlineSmall: display(fontSize: 24, letterSpacing: -0.2),
        titleLarge: display(fontSize: 22, letterSpacing: -0.2),
        titleMedium: display(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: display(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display(fontSize: 20, letterSpacing: -0.4, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingXs),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        side: const BorderSide(color: AppColors.border, width: 1),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXxs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        titleTextStyle: display(fontSize: 18, color: AppColors.textPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.primary : AppColors.textTertiary,
            size: 24,
          );
        }),
        height: 80,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// ── PREMIUM DARK — "Obsidian & Gold" ────────────────────────────────────
  /// Exclusive to subscribed users. Deep warm obsidian surfaces, champagne
  /// gold accents, gilded card edges and softly glowing gold buttons.
  static ThemeData get premiumDarkTheme {
    const bg = AppColors.pBackgroundDark;
    const surface = AppColors.pSurfaceDark;
    const surfaceVariant = AppColors.pSurfaceVariantDark;
    const surfaceContainer = AppColors.pSurfaceContainerDark;
    const border = AppColors.pBorderDark;
    const textPrimary = AppColors.pTextPrimaryDark;
    const textSecondary = AppColors.pTextSecondaryDark;
    const textTertiary = AppColors.pTextTertiaryDark;

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.pGold,
        primaryContainer: AppColors.pGoldContainer,
        secondary: AppColors.pBronze,
        secondaryContainer: AppColors.pBronzeContainer,
        tertiary: AppColors.pRoyal,
        surface: surface,
        surfaceContainer: surfaceContainer,
        error: AppColors.error,
        onPrimary: AppColors.pOnGold,
        onPrimaryContainer: AppColors.pOnGoldContainer,
        onSecondary: AppColors.pOnGold,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: border,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: display(fontSize: 57, letterSpacing: -0.5),
        displayMedium: display(fontSize: 45, letterSpacing: -0.4),
        displaySmall: display(fontSize: 36, letterSpacing: -0.3),
        headlineLarge: display(fontSize: 32, letterSpacing: -0.4),
        headlineMedium: display(fontSize: 28, letterSpacing: -0.3),
        headlineSmall: display(fontSize: 24, letterSpacing: -0.2),
        titleLarge: display(fontSize: 22, letterSpacing: -0.2),
        titleMedium: display(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: display(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display(fontSize: 20, letterSpacing: -0.4, color: textPrimary),
        iconTheme: const IconThemeData(color: AppColors.pGoldSoft, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pGold,
          foregroundColor: AppColors.pOnGold,
          elevation: 6,
          shadowColor: AppColors.pGold.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.pGoldDeep.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pGold,
          foregroundColor: AppColors.pOnGold,
          elevation: 4,
          shadowColor: AppColors.pGold.withValues(alpha: 0.30),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.pGoldSoft,
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingXs),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pGoldSoft,
          side: const BorderSide(color: AppColors.pGoldDeep, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: AppColors.pGold.withValues(alpha: 0.20),
        checkmarkColor: AppColors.pGoldSoft,
        side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.35), width: 1),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXxs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.pSurfaceContainerDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.25), width: 1),
        ),
        titleTextStyle: display(fontSize: 18, color: textPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.pSurfaceHighDark,
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.25), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.pNavBackgroundDark,
        indicatorColor: AppColors.pGold.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppColors.pNavActiveDark : textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.pNavActiveDark : textTertiary,
            size: 24,
          );
        }),
        height: 80,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.pGoldDeep.withValues(alpha: 0.14),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.pGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textTertiary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.pGold,
        foregroundColor: AppColors.pOnGold,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.pGold,
        linearTrackColor: surfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.pOnGold : textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pGold
              : surfaceVariant,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.pGoldSoft),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        subtitleTextStyle: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.pGoldSoft,
        unselectedLabelColor: textTertiary,
        indicatorColor: AppColors.pGold,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: border,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.pGold,
        inactiveTrackColor: surfaceVariant,
        thumbColor: AppColors.pGoldSoft,
        overlayColor: Color(0x29E8C15A),
        valueIndicatorColor: AppColors.pGoldContainer,
        valueIndicatorTextStyle: TextStyle(color: AppColors.pOnGoldContainer, fontSize: 12),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.dragged)
              ? AppColors.pGold
              : AppColors.pGoldDeep.withValues(alpha: 0.45),
        ),
        radius: const Radius.circular(radiusPill),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged) ? 6.0 : 4.0,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.pSurfaceHighDark,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: AppColors.pGoldDeep.withValues(alpha: 0.35)),
        ),
        textStyle: GoogleFonts.inter(fontSize: 12, color: textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.pSurfaceContainerDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.25), width: 1),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, color: textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.pSurfaceContainerDark),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
          ),
        ),
      ),
      menuTheme: MenuThemeData(style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.pSurfaceContainerDark),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.25)),
          ),
        ),
      )),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.pSurfaceContainerDark,
        dialBackgroundColor: surfaceVariant,
        dialHandColor: AppColors.pGold,
        hourMinuteTextColor: textPrimary,
        dayPeriodColor: AppColors.pGoldContainer,
        hourMinuteColor: surfaceVariant,
        entryModeIconColor: AppColors.pGoldSoft,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.pSurfaceContainerDark,
        headerBackgroundColor: AppColors.pGoldContainer,
        headerForegroundColor: AppColors.pOnGoldContainer,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.pOnGold : textPrimary,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pOnGold
              : AppColors.pGoldSoft,
        ),
        todayBorder: const BorderSide(color: AppColors.pGold, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.25), width: 1),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pGold
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(AppColors.pOnGold),
        side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.55), width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXxs)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pGold
              : AppColors.pGoldDeep.withValues(alpha: 0.55),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// ── PREMIUM LIGHT — "Champagne Ivory" ───────────────────────────────────
  /// Exclusive to subscribed users. Warm ivory surfaces with deep bronze-gold
  /// accents for a boutique, high-end feel in light mode.
  static ThemeData get premiumLightTheme {
    const bg = AppColors.pBackgroundLight;
    const surface = AppColors.pSurfaceLight;
    const surfaceVariant = AppColors.pSurfaceVariantLight;
    const border = AppColors.pBorderLight;
    const textPrimary = AppColors.pTextPrimaryLight;
    const textSecondary = AppColors.pTextSecondaryLight;
    const textTertiary = AppColors.pTextTertiaryLight;

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.pPrimaryLight,
        primaryContainer: Color(0xFFF3E9CE),
        secondary: Color(0xFF8A6512),
        secondaryContainer: Color(0xFFF3E9CE),
        tertiary: Color(0xFF6D5BD0),
        surface: surface,
        surfaceContainer: AppColors.pSurfaceContainerLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onPrimaryContainer: Color(0xFF3A2C05),
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: border,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: display(fontSize: 57, letterSpacing: -0.5, color: textPrimary),
        displayMedium: display(fontSize: 45, letterSpacing: -0.4, color: textPrimary),
        displaySmall: display(fontSize: 36, letterSpacing: -0.3, color: textPrimary),
        headlineLarge: display(fontSize: 32, letterSpacing: -0.4, color: textPrimary),
        headlineMedium: display(fontSize: 28, letterSpacing: -0.3, color: textPrimary),
        headlineSmall: display(fontSize: 24, letterSpacing: -0.2, color: textPrimary),
        titleLarge: display(fontSize: 22, letterSpacing: -0.2, color: textPrimary),
        titleMedium: display(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: display(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display(fontSize: 20, letterSpacing: -0.4, color: textPrimary),
        iconTheme: const IconThemeData(color: AppColors.pPrimaryLight, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pPrimaryLight,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.pGoldDeep.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pPrimaryLight,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.pGoldDeep.withValues(alpha: 0.30),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.pPrimaryLight,
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingXs),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: AppColors.pGoldDeep, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: AppColors.pGoldDeep.withValues(alpha: 0.18),
        checkmarkColor: AppColors.pPrimaryLight,
        side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.35), width: 1),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXxs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.30), width: 1),
        ),
        titleTextStyle: display(fontSize: 18, color: textPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.pGoldSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.pNavBackgroundLight,
        indicatorColor: AppColors.pGoldDeep.withValues(alpha: 0.20),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppColors.pNavActiveLight : textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.pNavActiveLight : textTertiary,
            size: 24,
          );
        }),
        height: 80,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.pGoldDeep.withValues(alpha: 0.22),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.pPrimaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textTertiary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.pPrimaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.pPrimaryLight,
        linearTrackColor: surfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pPrimaryLight
              : surfaceVariant,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.pPrimaryLight),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        subtitleTextStyle: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.pPrimaryLight,
        unselectedLabelColor: textTertiary,
        indicatorColor: AppColors.pPrimaryLight,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: border,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.pPrimaryLight,
        inactiveTrackColor: surfaceVariant,
        thumbColor: AppColors.pGoldDeep,
        overlayColor: Color(0x21D4AF37),
        valueIndicatorColor: AppColors.pTextPrimaryLight,
        valueIndicatorTextStyle: TextStyle(color: AppColors.pGoldSoft, fontSize: 12),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.dragged)
              ? AppColors.pPrimaryLight
              : AppColors.pGoldDeep.withValues(alpha: 0.50),
        ),
        radius: const Radius.circular(radiusPill),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged) ? 6.0 : 4.0,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.pTextPrimaryLight,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: AppColors.pGoldDeep.withValues(alpha: 0.45)),
        ),
        textStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.pGoldSoft),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.35), width: 1),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, color: textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
          ),
        ),
      ),
      menuTheme: MenuThemeData(style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(surface),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
            side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.35)),
          ),
        ),
      )),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: surfaceVariant,
        dialHandColor: AppColors.pPrimaryLight,
        hourMinuteTextColor: textPrimary,
        dayPeriodColor: const Color(0xFFF3E9CE),
        hourMinuteColor: surfaceVariant,
        entryModeIconColor: AppColors.pPrimaryLight,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerBackgroundColor: AppColors.pPrimaryLight,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : textPrimary,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.pPrimaryLight,
        ),
        todayBorder: const BorderSide(color: AppColors.pPrimaryLight, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.35), width: 1),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pPrimaryLight
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: AppColors.pGoldDeep.withValues(alpha: 0.65), width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXxs)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.pPrimaryLight
              : AppColors.pGoldDeep.withValues(alpha: 0.65),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme {
    const lightBg = Color(0xFFF6F8FA);
    const lightSurface = Color(0xFFFFFFFF);
    const lightSurfaceVariant = Color(0xFFEEF2F5);
    const lightBorder = Color(0xFFE1E7EC);
    const lightTextPrimary = Color(0xFF0E1A26);
    const lightTextSecondary = Color(0xFF4C5C6B);
    const lightTextTertiary = Color(0xFF8A99A6);

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: lightTextPrimary,
      displayColor: lightTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryDeep,
        primaryContainer: Color(0xFFCFF3EC),
        secondary: AppColors.secondary,
        tertiary: AppColors.weatherCard,
        surface: lightSurface,
        surfaceContainer: lightSurfaceVariant,
        error: AppColors.error,
        onPrimary: Colors.white,
        onPrimaryContainer: Color(0xFF0D4F49),
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
        outline: lightBorder,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: display(fontSize: 57, letterSpacing: -0.5, color: lightTextPrimary),
        displayMedium: display(fontSize: 45, letterSpacing: -0.4, color: lightTextPrimary),
        displaySmall: display(fontSize: 36, letterSpacing: -0.3, color: lightTextPrimary),
        headlineLarge: display(fontSize: 32, letterSpacing: -0.4, color: lightTextPrimary),
        headlineMedium: display(fontSize: 28, letterSpacing: -0.3, color: lightTextPrimary),
        headlineSmall: display(fontSize: 24, letterSpacing: -0.2, color: lightTextPrimary),
        titleLarge: display(fontSize: 22, letterSpacing: -0.2, color: lightTextPrimary),
        titleMedium: display(fontSize: 16, fontWeight: FontWeight.w600, color: lightTextPrimary),
        titleSmall: display(fontSize: 14, fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.15),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display(fontSize: 20, letterSpacing: -0.4, color: lightTextPrimary),
        iconTheme: const IconThemeData(color: lightTextPrimary, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDeep,
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingXs),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingSm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceVariant,
        selectedColor: AppColors.primaryDeep.withValues(alpha: 0.14),
        side: const BorderSide(color: lightBorder, width: 1),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXxs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        titleTextStyle: display(fontSize: 18, color: lightTextPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: lightTextSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightTextPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: AppColors.primaryDeep.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppColors.primaryDeep : lightTextTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.primaryDeep : lightTextTertiary,
            size: 24,
          );
        }),
        height: 80,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: lightTextTertiary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
