import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/utils/responsive.dart';
import 'package:tripproject/core/widgets/glass_card.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/screens/trip/notes_screen.dart';
import 'package:tripproject/screens/trip/prayers_screen.dart';
import 'package:tripproject/screens/adhkar_screen.dart';
import 'package:tripproject/screens/trip/speed_screen.dart';
import 'package:tripproject/screens/trip/music_screen.dart';
import 'package:tripproject/screens/trip/games_screen.dart';
import 'package:tripproject/screens/trip/videos_screen.dart';

/// Layout constants for this screen. Centralized so spacing/radius stays
/// consistent and isn't repeated as magic numbers throughout the widget tree.
class _TripSpacing {
  static const double headerIconSize = 54;
  static const double cardIconSize = 52;
  static const double gridSpacing = 16;
  static const double cardPadding = 20;
  static const double headerToGrid = 28;
}

/// Static, immutable feature catalog for the trip grid. Declared once at
/// the top level (not rebuilt per [State.build]) since the entries
/// themselves don't depend on build-time state — only their localized
/// strings do, which are resolved lazily via the getters below.
class _FeatureItem {
  const _FeatureItem({
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.icon,
    required this.colorBuilder,
    required this.pageBuilder,
    required this.semanticLabelEn,
    required this.semanticLabelAr,
  });

  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final IconData icon;
  final Color Function() colorBuilder;
  final WidgetBuilder pageBuilder;
  final String semanticLabelEn;
  final String semanticLabelAr;

  String title(bool isAr) => isAr ? titleAr : titleEn;
  String subtitle(bool isAr) => isAr ? subtitleAr : subtitleEn;
  String semanticLabel(bool isAr) => isAr ? semanticLabelAr : semanticLabelEn;
  Color color() => colorBuilder();
}

final List<_FeatureItem> _tripFeatures = [
  _FeatureItem(
    titleEn: 'Prayers',
    titleAr: 'الصلاة',
    subtitleEn: 'Prayer times & Qibla',
    subtitleAr: 'أوقات الصلاة والقبلة',
    icon: Icons.mosque_rounded,
    colorBuilder: () => AppColors.prayerCard,
    pageBuilder: (_) => const PrayersScreen(),
    semanticLabelEn: 'Open prayer times and Qibla',
    semanticLabelAr: 'فتح أوقات الصلاة والقبلة',
  ),
  _FeatureItem(
    titleEn: 'Adhkar',
    titleAr: 'الأذكار',
    subtitleEn: 'Adhkar & Duas',
    subtitleAr: 'الأذكار والأدعية',
    icon: Icons.menu_book_rounded,
    colorBuilder: () => AppColors.sunsetOrange,
    pageBuilder: (_) => const AdhkarScreen(),
    semanticLabelEn: 'Open adkar and supplications',
    semanticLabelAr: 'فتح الأذكار والأدعية',
  ),
  _FeatureItem(
    titleEn: 'Notes',
    titleAr: 'ملاحظات',
    subtitleEn: 'Write your notes',
    subtitleAr: 'اكتب ملاحظاتك',
    icon: Icons.note_rounded,
    colorBuilder: () => AppColors.sunsetBlue,
    pageBuilder: (_) => const NotesScreen(),
    semanticLabelEn: 'Open notes',
    semanticLabelAr: 'فتح الملاحظات',
  ),
  _FeatureItem(
    titleEn: 'Speed',
    titleAr: 'السرعة',
    subtitleEn: 'Speed monitoring',
    subtitleAr: 'مراقبة السرعة',
    icon: Icons.speed_rounded,
    colorBuilder: () => AppColors.routeCard,
    pageBuilder: (_) => const SpeedScreen(),
    semanticLabelEn: 'Open speed monitoring',
    semanticLabelAr: 'فتح مراقبة السرعة',
  ),
  _FeatureItem(
    titleEn: 'Musics',
    titleAr: 'موسيقى',
    subtitleEn: 'MP3 files',
    subtitleAr: 'ملفات MP3',
    icon: Icons.music_note_rounded,
    colorBuilder: () => AppColors.restaurantCard,
    pageBuilder: (_) => const MusicScreen(),
    semanticLabelEn: 'Open music',
    semanticLabelAr: 'فتح الموسيقى',
  ),
  _FeatureItem(
    titleEn: 'Games',
    titleAr: 'ألعاب',
    subtitleEn: 'Simple games',
    subtitleAr: 'ألعاب بسيطة',
    icon: Icons.sports_esports_rounded,
    colorBuilder: () => AppColors.expensesCard,
    pageBuilder: (_) => const GamesScreen(),
    semanticLabelEn: 'Open games',
    semanticLabelAr: 'فتح الألعاب',
  ),
  _FeatureItem(
    titleEn: 'Videos',
    titleAr: 'الفيديوهات',
    subtitleEn: 'Watch your videos',
    subtitleAr: 'شاهد مقاطع الفيديو',
    icon: Icons.video_library_rounded,
    // TODO(design): move to AppColors.videoCard once added, to keep every
    // card color sourced from the theme rather than a local literal.
    colorBuilder: () => const Color(0xFFE85D75),
    pageBuilder: (_) => const VideosScreen(),
    semanticLabelEn: 'Open videos',
    semanticLabelAr: 'فتح الفيديوهات',
  ),
];

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _openFeature(_FeatureItem item) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(_FadeThroughRoute(builder: item.pageBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: 0.08),
                scheme.surface.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5],
            ),
          ),
          child: SafeArea(
            child: ResponsiveCenter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _EntryFade(
                      controller: _entryController,
                      index: 0,
                      itemCount: _tripFeatures.length + 1,
                      child: _Header(isAr: isAr, scheme: scheme),
                    ),
                    const SizedBox(height: _TripSpacing.headerToGrid),
                    Expanded(
                      child: Semantics(
                        container: true,
                        label: isAr ? 'أدوات الرحلة' : 'Trip tools',
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                            Responsive.gridCrossAxisCount(context),
                            mainAxisSpacing: _TripSpacing.gridSpacing,
                            crossAxisSpacing: _TripSpacing.gridSpacing,
                            childAspectRatio:
                            Responsive.gridChildAspectRatio(context),
                          ),
                          itemCount: _tripFeatures.length,
                          itemBuilder: (context, index) {
                            final item = _tripFeatures[index];
                            return _EntryFade(
                              controller: _entryController,
                              index: index + 1,
                              itemCount: _tripFeatures.length + 1,
                              child: _FeatureCard(
                                title: item.title(isAr),
                                subtitle: item.subtitle(isAr),
                                semanticLabel: item.semanticLabel(isAr),
                                icon: item.icon,
                                color: item.color(),
                                onTap: () => _openFeature(item),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A fade-through transition (Material's recommended pattern for peer-level
/// navigation, e.g. hub -> tool) rather than the default platform slide,
/// which reads as more deliberate for a grid of sibling destinations.
class _FadeThroughRoute<T> extends PageRouteBuilder<T> {
  _FadeThroughRoute({required WidgetBuilder builder})
      : super(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      );
      final scaleIn = Tween(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: fadeIn,
        child: ScaleTransition(scale: scaleIn, child: child),
      );
    },
  );
}

/// Fades and slides [child] into place on a staggered delay derived from
/// [index] / [itemCount], so the screen reveals sequentially rather than
/// popping in all at once. Respects the platform's reduced-motion setting.
class _EntryFade extends StatelessWidget {
  const _EntryFade({
    required this.controller,
    required this.index,
    required this.itemCount,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final int itemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final start = (index / itemCount) * 0.6;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isAr, required this.scheme});

  final bool isAr;
  final ColorScheme scheme;

  String get _greeting {
    final hour = TimeOfDay.now().hour;
    if (isAr) return hour < 12 ? 'صباح الخير' : 'مساء الخير';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: _TripSpacing.headerIconSize,
          height: _TripSpacing.headerIconSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.28),
                scheme.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(Icons.explore_rounded, color: scheme.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.primary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isAr ? 'الرحلة' : 'Trip',
              style: GoogleFonts.poppins(
                fontSize: Responsive.scaledFontSize(context, 28),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String semanticLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: ExcludeSemantics(
            // Semantics for this card are declared once, above, so the
            // GlassCard's own internal gesture/label handling (if any)
            // doesn't produce a duplicate announcement for screen readers.
            child: GlassCard(
              onTap: widget.onTap,
              padding: const EdgeInsets.all(_TripSpacing.cardPadding),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: _TripSpacing.cardIconSize,
                        height: _TripSpacing.cardIconSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.color.withValues(alpha: 0.38),
                              widget.color.withValues(alpha: 0.14),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child:
                        Icon(widget.icon, color: widget.color, size: 26),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // `Positioned.directional` mirrors automatically in RTL
                  // (lands top-left for Arabic instead of staying top-right),
                  // matching the enclosing Directionality.
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: 0,
                    end: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
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