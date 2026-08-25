import 'package:flutter/material.dart';

/// ─── "Professional Dark" palette ───────────────────────────────────────
/// A sophisticated, enterprise-grade dark theme inspired by professional
/// navigation and travel apps. Features deep charcoal surfaces, refined blue
/// accent, and muted card colors for a cohesive, premium feel.
abstract final class AppColors {
  // ── Core Surfaces (Dark) ──────────────────────────────────────────────
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF121216);
  static const Color surfaceVariant = Color(0xFF1A1A1F);
  static const Color surfaceContainer = Color(0xFF16161B);
  static const Color surfaceContainerHigh = Color(0xFF222229);
  static const Color surfaceRaised = Color(0xFF1A1A1F);

  // ── Primary: Professional Blue ─────────────────────────────────────────
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDeep = Color(0xFF2563EB);
  static const Color primaryContainer = Color(0xFF1E3A8A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFDBEAFE);

  // ── Secondary: Muted Teal ─────────────────────────────────────────────
  static const Color secondary = Color(0xFF14B8A6);
  static const Color secondaryContainer = Color(0xFF134E4A);

  // ── Semantic Colors ────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0xFF064E3B);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFF78350F);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFF7F1D1D);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  // ── Border & Divider ───────────────────────────────────────────────────
  static const Color border = Color(0xFF27272A);
  static const Color divider = Color(0xFF1F1F23);
  static const Color outline = Color(0xFF3F3F46);

  // ── Service Card Accents (professional, muted palette) ────────────────
  static const Color routeCard = Color(0xFF3B82F6);
  static const Color fuelCard = Color(0xFF8B5CF6);
  static const Color restaurantCard = Color(0xFFEC4899);
  static const Color prayerCard = Color(0xFF6C63E5);
  static const Color weatherCard = Color(0xFF06B6D4);
  static const Color checklistCard = Color(0xFF6366F1);
  static const Color expensesCard = Color(0xFFF59E0B);
  static const Color emergencyCard = Color(0xFFEF4444);
  static const Color photosCard = Color(0xFF14B8A6);
  static const Color statsCard = Color(0xFF64748B);

  // ── Gradients (subtle, professional) ─────────────────────────────────
  static const List<Color> heroGradient = [Color(0xFF60A5FA), Color(0xFF2563EB)];
  static const List<Color> emergencyGradient = [Color(0xFFF87171), Color(0xFFDC2626)];
  static const List<Color> premiumSheen = [Color(0x1A3B82F6), Color(0x003B82F6)];

  // ── Premium Colors (Gold/Amber for subscribed users) ─────────────────
  static const Color premiumGold = Color(0xFFFFD700);
  static const Color premiumAmber = Color(0xFFFFA500);
  static const Color premiumOrange = Color(0xFFFF8C00);
  static const Color premiumGradientStart = Color(0xFFFFD700);
  static const Color premiumGradientEnd = Color(0xFFFFA500);
  static const List<Color> premiumGradient = [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFF8C00)];
  static const Color premiumBadge = Color(0xFFFFF3CD);
  static const Color premiumBadgeBorder = Color(0xFFD4AF37);

  // ── "Obsidian & Gold" — exclusive palette for Premium subscribers ──────
  // Dark: near-black warm obsidian surfaces with champagne-gold accents.
  // Light: warm ivory / champagne surfaces with deep bronze-gold accents.
  static const Color pBackgroundDark = Color(0xFF070709);
  static const Color pSurfaceDark = Color(0xFF101013);
  static const Color pSurfaceContainerDark = Color(0xFF14141A);
  static const Color pSurfaceVariantDark = Color(0xFF1B1B22);
  static const Color pSurfaceHighDark = Color(0xFF232329);
  static const Color pBorderDark = Color(0xFF2E2B22); // warm gilded edge

  static const Color pGold = Color(0xFFE8C15A); // bright champagne (dark mode primary)
  static const Color pGoldDeep = Color(0xFFD4AF37); // classic metallic gold
  static const Color pGoldSoft = Color(0xFFF5DC9A); // pale gold highlight
  static const Color pOnGold = Color(0xFF201805); // near-black warm text on gold
  static const Color pGoldContainer = Color(0xFF3A2F10);
  static const Color pOnGoldContainer = Color(0xFFF5E6B8);
  static const Color pBronze = Color(0xFFC89B4B); // secondary
  static const Color pBronzeContainer = Color(0xFF3D2E12);
  static const Color pRoyal = Color(0xFFA78BFA); // tertiary: royal amethyst
  static const Color pTextPrimaryDark = Color(0xFFFAF6EC); // warm white
  static const Color pTextSecondaryDark = Color(0xFFA8A091);
  static const Color pTextTertiaryDark = Color(0xFF736D5E);

  static const Color pBackgroundLight = Color(0xFFFAF6EE); // ivory
  static const Color pSurfaceLight = Color(0xFFFFFFFF);
  static const Color pSurfaceVariantLight = Color(0xFFF2ECDD);
  static const Color pSurfaceContainerLight = Color(0xFFF7F2E7);
  static const Color pBorderLight = Color(0xFFE5DCC6);
  static const Color pPrimaryLight = Color(0xFF8A6512); // deep bronze-gold (AA on white)
  static const Color pTextPrimaryLight = Color(0xFF231D10); // espresso
  static const Color pTextSecondaryLight = Color(0xFF5C5340);
  static const Color pTextTertiaryLight = Color(0xFF948A72);

  // Premium ambient gradients (exclusive backgrounds)
  static const List<Color> premiumAmbientDark = [
    Color(0xFF0B0A07),
    Color(0xFF17130B),
    Color(0xFF070709),
  ];
  static const List<Color> premiumAmbientLight = [
    Color(0xFFFDFBF5),
    Color(0xFFF8F0DC),
    Color(0xFFF0F2F6),
  ];

  // Premium navigation bar colors (dark + light)
  static const Color pNavBackgroundDark = Color(0xFF101014);
  static const Color pNavActiveDark = Color(0xFFEDCB6B);
  static const Color pNavInactiveDark = Color(0xFF8D8574);
  static const Color pNavPillDark = Color(0xFF2B2312);
  static const Color pNavBackgroundLight = Color(0xFFFFFBF2);
  static const Color pNavActiveLight = Color(0xFF8A6512);
  static const Color pNavInactiveLight = Color(0xFF9C917A);
  static const Color pNavPillLight = Color(0xFFF3E9CE);

  // ── Navigation Bar Colors (Primary Blue & White / Dark theme) ───────────────
  static const Color navBackgroundLight = Color(0xFFFFFFFF);
  static const Color navActiveLight = Color(0xFF2563EB); // Primary Blue
  static const Color navInactiveLight = Color(0xFF64748B); // Slate Muted
  static const Color navPillLight = Color(0xFFEFF6FF); // Soft Blue Tint

  // Dark theme navigation colors
  static const Color navBackgroundDark = Color(0xFF16161E); // Dark Surface
  static const Color navActiveDark = Color(0xFF3B82F6); // Vibrant Blue
  static const Color navInactiveDark = Color(0xFF94A3B8); // Muted Grey
  static const Color navPillDark = Color(0xFF1E293B); // Dark Slate Blue Pill

  // Legacy aliases for backward compatibility
  static const Color lightPurple = navBackgroundLight;
  static const Color darkPurple = navActiveLight;
  static const Color purpleAccent = navActiveLight;
  static const Color lightPurpleDark = navBackgroundDark;
  static const Color darkPurpleDark = navActiveDark;
  static const Color purpleAccentDark = navActiveDark;

  // ── Legacy aliases for backward compatibility ─────────────────────────
  static const Color sunsetOrange = Color(0xFFF59E0B);
  static const Color sunsetAmber = Color(0xFFFBBF24);
  static const Color sunsetBlue = primary;
  static const Color sunsetDeep = primaryDeep;
  static const Color surfaceLight = surfaceVariant;
  static const Color textMuted = textTertiary;
  static const Color glassBorder = border;
  static const Color glassFill = surfaceVariant;
  static const List<Color> desertGradient = [
    Color(0xFF121216),
    Color(0xFF1A1A1F),
    Color(0xFF222229),
  ];
}