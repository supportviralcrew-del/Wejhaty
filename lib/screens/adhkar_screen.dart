import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/local_cache_service.dart';

// ---------------------------------------------------------------------------
// Adhkar — browsable list (banner + tap-to-read cards), the tasbih tally
// counters, and the Duas browser (all moved here from PrayersScreen, since
// this is all Adhkar content and shouldn't be split across two screens).
// ---------------------------------------------------------------------------

class _AdhkarItem {
  final String titleAr;
  final String titleEn;
  final String arabicText;
  final String translationEn;
  final IconData icon;
  final Color color;

  const _AdhkarItem({
    required this.titleAr,
    required this.titleEn,
    required this.arabicText,
    required this.translationEn,
    required this.icon,
    required this.color,
  });
}

/// The fixed/featured dhikr shown in the banner every time this screen is
/// opened — matches the quote card at the top of the reference design.
const _AdhkarItem _featuredAdhkar = _AdhkarItem(
  titleAr: 'حصن نفسك بذكر الله أينما كنت',
  titleEn: 'Guard yourself with the remembrance of Allah, wherever you are',
  arabicText:
  'وَإِذَا اسْتَوَيْتُمْ عَلَى بَعِيرِهِ فَكَبِّرُوا ثَلَاثًا',
  translationEn:
  'When you mount your riding animal, say "Allahu Akbar" three times.',
  icon: Icons.format_quote_rounded,
  color: AppColors.prayerCard,
);

const List<_AdhkarItem> _adhkarList = [
  _AdhkarItem(
    titleAr: 'عند الخروج للسفر',
    titleEn: 'Leaving for a Trip',
    arabicText:
    'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، '
        'وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ',
    translationEn:
    'Glory to Him Who has made this possible for us, for we could never '
        'have done it ourselves. And to our Lord we shall surely return.',
    icon: Icons.directions_car_filled_rounded,
    color: Color(0xFF2E9E6D),
  ),
  _AdhkarItem(
    titleAr: 'عند ركوب المواصلة',
    titleEn: 'Boarding Transport',
    arabicText:
    'اللَّهُمَّ إِنِّي أَسْأَلُكَ فِي سَفَرِي هَذَا الْبِرَّ وَالتَّقْوَى، '
        'وَمِنَ الْعَمَلِ مَا تَرْضَى',
    translationEn:
    'O Allah, I ask You for righteousness and piety in this journey of '
        'mine, and for deeds that please You.',
    icon: Icons.directions_bus_filled_rounded,
    color: Color(0xFF6C63E5),
  ),
  _AdhkarItem(
    titleAr: 'عند الخوف أو مواجهة صعوبة',
    titleEn: 'Facing Fear or Hardship',
    arabicText:
    'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ وَعْثَاءِ السَّفَرِ، وَكَآبَةِ الْمَنْظَرِ، '
        'وَسُوءِ الْمُنْقَلَبِ فِي الْمَالِ وَالْأَهْلِ',
    translationEn:
    'O Allah, I seek refuge in You from the hardships of travel, from a '
        'distressing sight, and from an evil return in wealth and family.',
    icon: Icons.shield_rounded,
    color: Color(0xFFF2A93B),
  ),
];

/// Secondary "browse more" shortcuts, matching the grid of cards below the
/// main list in the reference design. Not wired to real screens yet — each
/// just surfaces a snackbar, same placeholder pattern used elsewhere in the
/// app (e.g. "Calendar view not wired up yet").
const List<Map<String, dynamic>> _otherAdhkarLinks = [
  {'ar': 'أذكار الصباح والمساء', 'en': 'Morning & Evening Adhkar', 'icon': Icons.wb_sunny_rounded, 'color': Color(0xFF2E9E6D)},
  {'ar': 'أذكار النوم', 'en': 'Sleep Adhkar', 'icon': Icons.nightlight_round, 'color': Color(0xFF3B82C4)},
  {'ar': 'أدعية عامة', 'en': 'General Duas', 'icon': Icons.volunteer_activism_rounded, 'color': Color(0xFFE0558F)},
  {'ar': 'التسبيح والتهليل', 'en': 'Tasbih & Tahlil', 'icon': Icons.auto_awesome_rounded, 'color': Color(0xFFB98A2E)},
];

// ---------------------------------------------------------------------------
// Duas (full texts, opened in a preview dialog) — moved here from
// PrayersScreen.
// ---------------------------------------------------------------------------

enum _DuaCategory { travel, umrahHajj, rain, rizq, child }

class _CategoryMeta {
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final Color color;

  const _CategoryMeta({
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    required this.color,
  });
}

const Map<_DuaCategory, _CategoryMeta> _categoryMeta = {
  _DuaCategory.travel: _CategoryMeta(
    labelAr: 'سفر',
    labelEn: 'Travel',
    icon: Icons.flight_rounded,
    color: AppColors.sunsetOrange,
  ),
  _DuaCategory.umrahHajj: _CategoryMeta(
    labelAr: 'حج وعمرة',
    labelEn: 'Hajj & Umrah',
    icon: Icons.mosque_rounded,
    color: Color(0xFF2E9E6D),
  ),
  _DuaCategory.rain: _CategoryMeta(
    labelAr: 'المطر',
    labelEn: 'Rain',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF3B82C4),
  ),
  _DuaCategory.rizq: _CategoryMeta(
    labelAr: 'الرزق',
    labelEn: 'Sustenance',
    icon: Icons.spa_rounded,
    color: Color(0xFFB98A2E),
  ),
  _DuaCategory.child: _CategoryMeta(
    labelAr: 'الذرية',
    labelEn: 'Children',
    icon: Icons.family_restroom_rounded,
    color: Color(0xFFA0559C),
  ),
};

class _DuaItem {
  final String titleAr;
  final String titleEn;
  final String arabicText;
  final String translationEn;
  final IconData icon;
  final _DuaCategory category;

  const _DuaItem({
    required this.titleAr,
    required this.titleEn,
    required this.arabicText,
    required this.translationEn,
    required this.icon,
    required this.category,
  });
}

const List<_DuaItem> _duas = [
  _DuaItem(
    titleAr: 'دعاء السفر',
    titleEn: 'Dua for Travel',
    arabicText:
    'اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، '
        'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، '
        'وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ، '
        'اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَذَا الْبِرَّ وَالتَّقْوَى، '
        'وَمِنَ الْعَمَلِ مَا تَرْضَى، '
        'اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَذَا وَاطْوِ عَنَّا بُعْدَهُ، '
        'اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ، وَالْخَلِيفَةُ فِي الْأَهْلِ، '
        'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ وَعْثَاءِ السَّفَرِ، وَكَآبَةِ الْمَنْظَرِ، '
        'وَسُوءِ الْمُنْقَلَبِ فِي الْمَالِ وَالْأَهْلِ.',
    translationEn:
    'Allah is the Greatest, Allah is the Greatest, Allah is the Greatest. '
        'Glory to Him Who has made this possible for us, for we could never '
        'have done it by ourselves. And to our Lord we shall surely return. '
        'O Allah, we ask You for righteousness and piety in this journey of '
        'ours, and for deeds that please You. O Allah, ease this journey for '
        'us and make its distance short for us. O Allah, You are our '
        'Companion on the road and the Guardian of our family. O Allah, I '
        'seek refuge in You from the hardships of travel, from a distressing '
        'sight, and from an evil return in wealth and family.',
    icon: Icons.travel_explore_rounded,
    category: _DuaCategory.travel,
  ),
  _DuaItem(
    titleAr: 'دعاء القدوم من السفر',
    titleEn: 'Dua for Returning from Travel',
    arabicText:
    'آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ، '
        'صَدَقَ اللَّهُ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الْأَحْزَابَ وَحْدَهُ.',
    translationEn:
    'We return, repentant, worshipping, and praising our Lord. Allah '
        'fulfilled His promise, granted victory to His servant, and defeated '
        'the confederates alone.',
    icon: Icons.home_rounded,
    category: _DuaCategory.travel,
  ),
  _DuaItem(
    titleAr: 'التلبية',
    titleEn: 'The Talbiyah',
    arabicText:
    'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، '
        'إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ.',
    translationEn:
    'Here I am, O Allah, here I am. Here I am, You have no partner, here '
        'I am. Indeed all praise, grace and sovereignty belong to You. You '
        'have no partner.',
    icon: Icons.mosque_rounded,
    category: _DuaCategory.umrahHajj,
  ),
  _DuaItem(
    titleAr: 'دعاء رؤية الكعبة',
    titleEn: 'Dua on Seeing the Ka\'bah',
    arabicText:
    'اللَّهُمَّ زِدْ هَذَا الْبَيْتَ تَشْرِيفًا وَتَعْظِيمًا وَتَكْرِيمًا وَمَهَابَةً، '
        'وَزِدْ مَنْ شَرَّفَهُ وَكَرَّمَهُ مِمَّنْ حَجَّهُ أَوِ اعْتَمَرَهُ تَشْرِيفًا وَتَكْرِيمًا '
        'وَتَعْظِيمًا وَبِرًّا.',
    translationEn:
    'O Allah, increase this House in honor, greatness, dignity and awe, '
        'and increase those who honor and venerate it — of those who perform '
        'Hajj or Umrah — in honor, dignity, greatness and goodness.',
    icon: Icons.remove_red_eye_rounded,
    category: _DuaCategory.umrahHajj,
  ),
  _DuaItem(
    titleAr: 'دعاء عند نزول المطر',
    titleEn: 'Dua When Rain Falls',
    arabicText: 'اللَّهُمَّ صَيِّبًا نَافِعًا.',
    translationEn: 'O Allah, (make it) a beneficial rain cloud.',
    icon: Icons.water_drop_rounded,
    category: _DuaCategory.rain,
  ),
  _DuaItem(
    titleAr: 'دعاء بعد المطر',
    titleEn: 'Dua After Rain',
    arabicText: 'مُطِرْنَا بِفَضْلِ اللَّهِ وَرَحْمَتِهِ.',
    translationEn: 'We have been given rain by the grace and mercy of Allah.',
    icon: Icons.water_rounded,
    category: _DuaCategory.rain,
  ),
  _DuaItem(
    titleAr: 'دعاء الرزق',
    titleEn: 'Dua for Sustenance',
    arabicText:
    'اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ، وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ.',
    translationEn:
    'O Allah, suffice me with what You have made lawful instead of what '
        'You have made unlawful, and make me independent of all others by '
        'Your grace.',
    icon: Icons.spa_rounded,
    category: _DuaCategory.rizq,
  ),
  _DuaItem(
    titleAr: 'دعاء طلب الذرية الصالحة',
    titleEn: 'Dua for Righteous Offspring',
    arabicText:
    'رَبِّ هَبْ لِي مِن لَّدُنْكَ ذُرِّيَّةً طَيِّبَةً إِنَّكَ سَمِيعُ الدُّعَاءِ.',
    translationEn:
    'My Lord, grant me from Yourself a good offspring. Indeed, You are '
        'the Hearer of supplication.',
    icon: Icons.family_restroom_rounded,
    category: _DuaCategory.child,
  ),
];

// ---------------------------------------------------------------------------
// Dhikr tally counters — moved here from PrayersScreen (this is where they
// belong, alongside the rest of the Adhkar content, instead of being
// duplicated on the Prayer Times screen).
// ---------------------------------------------------------------------------

class _DhikrItem {
  final String text;
  final int target;
  final IconData icon;
  int count = 0;

  _DhikrItem({required this.text, required this.target, required this.icon});
}

// ---------------------------------------------------------------------------
// Palette — the screen now follows the app's light/dark theme (previously
// it was pinned to a fixed light look). Both palettes keep the same
// lavender-tinted brand identity from the reference design; dark mode just
// swaps the base surfaces and lightens the accent slightly for contrast.
// ---------------------------------------------------------------------------

class _AdhkarPalette {
  final Color pageBg;
  final Color cardBg;
  final Color titleColor;
  final Color subtitleColor;
  final Color accent;
  final bool isDark;

  const _AdhkarPalette({
    required this.pageBg,
    required this.cardBg,
    required this.titleColor,
    required this.subtitleColor,
    required this.accent,
    required this.isDark,
  });

  static const light = _AdhkarPalette(
    pageBg: Color(0xFFF3F1FA),
    cardBg: Colors.white,
    titleColor: Color(0xFF181A2E),
    subtitleColor: Color(0xFF8A8CA0),
    accent: Color(0xFF6C63E5),
    isDark: false,
  );

  static const dark = _AdhkarPalette(
    pageBg: Color(0xFF121018),
    cardBg: Color(0xFF1E1B2B),
    titleColor: Color(0xFFF2F1F7),
    subtitleColor: Color(0xFFA6A3B8),
    accent: Color(0xFF8B83FF),
    isDark: true,
  );
}

/// Colors used only inside the banner's photo slides — these stay constant
/// across light/dark app theme since they're overlaid on fixed artwork, not
/// on the page background.
const Color _bannerInkColor = Color(0xFF181A2E);
const Color _bannerImageFallback = Color(0xFF6C63E5);

BoxDecoration _cardDecoration(_AdhkarPalette p, {double radius = 20}) => BoxDecoration(
  color: p.cardBg,
  borderRadius: BorderRadius.circular(radius),
  border: p.isDark ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : null,
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late List<_DhikrItem> _dhikrItems;
  bool _isArInit = false;
  _DuaCategory? _selectedCategory;

  // ── Search ──
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Bookmarks (persisted) ──
  // Ids: 'a:<titleEn>' for travel adhkar, 'd:<titleEn>' for duas.
  final Set<String> _bookmarks = {};

  bool _isBookmarked(String id) => _bookmarks.contains(id);

  Future<void> _loadBookmarks() async {
    // Primary: LocalCacheService single-blob (already inited in main)
    try {
      final cached = LocalCacheService.instance.loadAdhkarBookmarks();
      if (cached.isNotEmpty && mounted) {
        setState(() => _bookmarks.addAll(cached));
        // also sync to dedicated prefs key for web reliability
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('adhkar_bookmarks', _bookmarks.toList());
        return;
      }
    } catch (_) {}
    // Fallback / fresh load: dedicated SharedPreferences key (reliable on web)
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('adhkar_bookmarks');
      if (list != null && list.isNotEmpty && mounted) {
        setState(() {
          _bookmarks
            ..clear()
            ..addAll(list);
        });
        // sync back to LocalCacheService blob for consistency
        await LocalCacheService.instance.saveAdhkarBookmarks(_bookmarks.toList());
      } else {
        // If LocalCache had bookmarks but we already handled non-empty above,
        // this is also the case where LocalCache was empty — try reloading it
        // after prefs check in case it was populated async
        final cached2 = LocalCacheService.instance.loadAdhkarBookmarks();
        if (cached2.isNotEmpty && mounted) {
          setState(() {
            _bookmarks
              ..clear()
              ..addAll(cached2);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark(String id) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_bookmarks.add(id)) _bookmarks.remove(id);
    });
    final list = _bookmarks.toList();
    // Save to both storages so status survives restarts on all platforms (web = localStorage)
    try {
      await LocalCacheService.instance.saveAdhkarBookmarks(list);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('adhkar_bookmarks', list);
    } catch (_) {}
  }

  /// Filters an item by the current search query across both languages and
  /// the Arabic text (case-insensitive).
  bool _matchesSearch({required String ar, required String en, required String body}) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return ar.toLowerCase().contains(q) ||
        en.toLowerCase().contains(q) ||
        body.contains(_searchQuery.trim());
  }

  // ---------------------------------------------------------------------
  // Banner carousel — auto-advances every 5s and loops forever. Uses an
  // unbounded "virtual" page index (mod _bannerSlideCount) so it always
  // glides forward, never snaps backwards, and swiping manually simply
  // re-syncs and restarts the 5s timer.
  // ---------------------------------------------------------------------
  late final PageController _bannerController;
  Timer? _bannerAutoplayTimer;
  int _bannerVirtualPage = 0;
  int _bannerActiveIndex = 0;
  static const int _bannerSlideCount = 2;
  static const double _bannerHeight = 250;

  @override
  void initState() {
    super.initState();
    _buildDhikrItems(AppDataProvider.instance.language == 'ar');
    _bannerController = PageController(initialPage: 0);
    _startBannerAutoplay();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _bannerAutoplayTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startBannerAutoplay() {
    _bannerAutoplayTimer?.cancel();
    _bannerAutoplayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _bannerVirtualPage++;
      _bannerController.animateToPage(
        _bannerVirtualPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _buildDhikrItems(bool isAr) {
    _isArInit = isAr;
    _dhikrItems = [
      _DhikrItem(
        text: isAr ? 'سبحان الله' : 'SubhanAllah',
        target: 33,
        icon: Icons.star_rounded,
      ),
      _DhikrItem(
        text: isAr ? 'الحمد لله' : 'Alhamdulillah',
        target: 33,
        icon: Icons.favorite_rounded,
      ),
      _DhikrItem(
        text: isAr ? 'الله أكبر' : 'Allahu Akbar',
        target: 34,
        icon: Icons.circle_rounded,
      ),
      _DhikrItem(
        text: isAr ? 'لا إله إلا الله وحده لا شريك له' : 'La ilaha illa Allah',
        target: 1,
        icon: Icons.center_focus_strong_rounded,
      ),
    ];
  }

  void _tapDhikr(_DhikrItem item) {
    if (item.count >= item.target) return;
    HapticFeedback.selectionClick();
    setState(() => item.count++);
  }

  void _resetAllDhikr() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final item in _dhikrItems) {
        item.count = 0;
      }
    });
  }

  TextStyle _uiFont(
      bool isAr, {
        required double fontSize,
        FontWeight fontWeight = FontWeight.w400,
        Color? color,
        double? height,
        FontStyle? fontStyle,
      }) {
    final needsTajawal = isAr || AppDataProvider.instance.useArabicNumbers;
    return needsTajawal
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

  String _localizeDigits(String input) {
    if (!AppDataProvider.instance.useArabicNumbers) return input;
    const western = '0123456789';
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = western.indexOf(ch);
      buffer.write(idx == -1 ? ch : eastern[idx]);
    }
    return buffer.toString();
  }

  /// Rounded light-lavender square icon button, matching the back/bookmark
  /// buttons in the reference design (and the same pattern already used
  /// for the calendar action on PrayersScreen's AppBar).
  Widget _chromeButton({
    required IconData icon,
    required VoidCallback onPressed,
    required _AdhkarPalette palette,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: palette.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: palette.accent, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  /// Search field — filters the travel adhkar and duas live across both
  /// languages and the Arabic body text.
  Widget _buildSearchField(_AdhkarPalette palette) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: _uiFont(AppDataProvider.instance.language == 'ar',
          fontSize: 14, color: palette.titleColor),
      decoration: InputDecoration(
        hintText:
            AppDataProvider.instance.language == 'ar' ? 'ابحث في الأذكار والأدعية...' : 'Search adhkar & duas...',
        hintStyle: _uiFont(AppDataProvider.instance.language == 'ar',
            fontSize: 13, color: palette.subtitleColor),
        prefixIcon: Icon(Icons.search_rounded,
            size: 20, color: palette.subtitleColor),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded,
                    size: 18, color: palette.subtitleColor),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: palette.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: palette.titleColor.withValues(
              alpha: palette.isDark ? 0.1 : 0.07,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
    );
  }

  /// Small bookmark toggle used on cards and inside preview dialogs.
  Widget _bookmarkButton({
    required String id,
    required _AdhkarPalette palette,
    double size = 20,
  }) {
    final saved = _isBookmarked(id);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: saved ? 'Remove bookmark' : 'Bookmark',
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: size,
        color: saved ? AppColors.sunsetOrange : palette.subtitleColor,
      ),
      onPressed: () => _toggleBookmark(id),
    );
  }

  /// Bookmarks sheet — lists every saved adhkar/dua; tap to open its
  /// preview, long-press (or the trash icon) to remove.
  void _openBookmarksSheet(bool isAr, _AdhkarPalette palette) {
    final savedAdhkar = _adhkarList
        .where((a) => _bookmarks.contains('a:${a.titleEn}'))
        .toList();
    final savedDuas =
        _duas.where((d) => _bookmarks.contains('d:${d.titleEn}')).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final items = <Widget>[
          for (final a in savedAdhkar)
            ListTile(
              leading: Icon(a.icon, color: a.color),
              title: Text(
                isAr ? a.titleAr : a.titleEn,
                style: _uiFont(isAr,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.titleColor),
              ),
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: palette.subtitleColor),
                onPressed: () {
                  _toggleBookmark('a:${a.titleEn}');
                  Navigator.pop(sheetContext);
                  _openBookmarksSheet(isAr, palette);
                },
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAdhkarPreview(context, isAr, a, palette);
              },
            ),
          for (final d in savedDuas)
            ListTile(
              leading: Icon(
                  _categoryMeta[d.category]?.icon ?? Icons.auto_awesome,
                  color: _categoryMeta[d.category]?.color),
              title: Text(
                isAr ? d.titleAr : d.titleEn,
                style: _uiFont(isAr,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.titleColor),
              ),
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: palette.subtitleColor),
                onPressed: () {
                  _toggleBookmark('d:${d.titleEn}');
                  Navigator.pop(sheetContext);
                  _openBookmarksSheet(isAr, palette);
                },
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDuaPreview(context, isAr, d, palette);
              },
            ),
        ];

        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.titleColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isAr ? 'المحفوظات' : 'Bookmarks',
                      style: _uiFont(isAr,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.titleColor),
                    ),
                    const SizedBox(height: 6),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(
                          children: [
                            Icon(Icons.bookmark_border_rounded,
                                size: 36,
                                color: palette.subtitleColor
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text(
                              isAr
                                  ? 'لا توجد محفوظات بعد — اضغط على أيقونة الحفظ في أي ذكر أو دعاء'
                                  : 'No bookmarks yet — tap the bookmark icon on any adhkar or dua',
                              textAlign: TextAlign.center,
                              style: _uiFont(isAr,
                                  fontSize: 12.5,
                                  color: palette.subtitleColor),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(shrinkWrap: true, children: items),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Tapping an Adhkar card opens the full text in a preview dialog — same
  /// pattern as the Dua preview — instead of the play/copy icon buttons
  /// shown in the original reference design.
  void _showAdhkarPreview(BuildContext context, bool isAr, _AdhkarItem item, _AdhkarPalette palette) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                decoration: _cardDecoration(palette, radius: 24),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, color: item.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isAr ? item.titleAr : item.titleEn,
                              style: _uiFont(isAr, fontSize: 16, fontWeight: FontWeight.w700, color: palette.titleColor),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: palette.titleColor.withValues(alpha: 0.6)),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.titleColor.withValues(alpha: 0.08)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                item.arabicText,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.amiri(
                                  fontSize: 21,
                                  height: 2.0,
                                  fontWeight: FontWeight.w600,
                                  color: palette.titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Divider(color: palette.titleColor.withValues(alpha: 0.08)),
                            const SizedBox(height: 12),
                            Text(
                              item.translationEn,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                color: palette.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: palette.titleColor.withValues(alpha: 0.08)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: item.arabicText));
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isAr ? 'تم النسخ' : 'Copied to clipboard',
                                        style: _uiFont(isAr, fontSize: 13),
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.copy_rounded, size: 18, color: palette.titleColor.withValues(alpha: 0.7)),
                              label: Text(
                                isAr ? 'نسخ' : 'Copy',
                                style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: palette.titleColor.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: item.color),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(
                                isAr ? 'إغلاق' : 'Close',
                                style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Full-text preview dialog for a dua — same pattern as the Adhkar
  /// preview above.
  void _showDuaPreview(BuildContext context, bool isAr, _DuaItem dua, _AdhkarPalette palette) {
    final meta = _categoryMeta[dua.category]!;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                decoration: _cardDecoration(palette, radius: 24),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: meta.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(dua.icon, color: meta.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isAr ? dua.titleAr : dua.titleEn,
                              style: _uiFont(isAr, fontSize: 16, fontWeight: FontWeight.w700, color: palette.titleColor),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: palette.titleColor.withValues(alpha: 0.6)),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.titleColor.withValues(alpha: 0.08)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                dua.arabicText,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.amiri(
                                  fontSize: 21,
                                  height: 2.0,
                                  fontWeight: FontWeight.w600,
                                  color: palette.titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Divider(color: palette.titleColor.withValues(alpha: 0.08)),
                            const SizedBox(height: 12),
                            Text(
                              dua.translationEn,
                              textAlign: TextAlign.start,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                color: palette.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: palette.titleColor.withValues(alpha: 0.08)),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: dua.arabicText));
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isAr ? 'تم النسخ' : 'Copied to clipboard',
                                        style: _uiFont(isAr, fontSize: 13),
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.copy_rounded, size: 18, color: palette.titleColor.withValues(alpha: 0.7)),
                              label: Text(
                                isAr ? 'نسخ' : 'Copy',
                                style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: palette.titleColor.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: meta.color),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(
                                isAr ? 'إغلاق' : 'Close',
                                style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Banner carousel
  // -------------------------------------------------------------------

  /// Shared shell for a single banner slide: a slowly zooming ("Ken Burns")
  /// background image, a readability gradient, and the slide's content.
  /// Deliberately theme-independent — it's overlaid on fixed artwork, not
  /// the page background, so it keeps consistent contrast in light and dark.
  Widget _bannerSlideShell({
    required String imagePath,
    required List<Color> gradientColors,
    required Widget content,
    AlignmentGeometry contentAlignment = Alignment.center,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 1.1),
          duration: const Duration(seconds: 6),
          curve: Curves.easeOut,
          builder: (context, scale, imgChild) => Transform.scale(scale: scale, child: imgChild),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: _bannerImageFallback.withValues(alpha: 0.18),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Align(alignment: contentAlignment, child: content),
        ),
      ],
    );
  }

  /// Slide 1 — assets/Adhkar/DkirBANNER10.png, an intro/overview blurb for
  /// travel adhkar, white text over the artwork.
  Widget _buildBannerSlideTravel(bool isAr) {
    return _bannerSlideShell(
      imagePath: 'assets/Adhkar/DkirBANNER10.png',
      gradientColors: [
        Colors.black.withValues(alpha: 0.05),
        Colors.black.withValues(alpha: 0.42),
      ],
      contentAlignment: const Alignment(0, -0.35),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.card_travel_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isAr
                  ? 'مجموعة من الأذكار والأدعية المأثورة للتنقل للسفر لتطمئن وتيسّر رحلتك'
                  : 'A collection of authentic adhkar and duas for travel — to ease your heart and bless your journey.',
              textAlign: TextAlign.right,
              style: _uiFont(
                isAr,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Slide 2 — assets/Adhkar/DkirBANNER.png, the featured hadith quote.
  Widget _buildBannerSlideHadith(bool isAr) {
    return _bannerSlideShell(
      imagePath: 'assets/Adhkar/DkirBANNER.png',
      gradientColors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.3),
      ],
      contentAlignment: AlignmentDirectional.topStart,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.format_quote_rounded, color: _bannerInkColor.withValues(alpha: 0.55), size: 26),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              _featuredAdhkar.arabicText,
              textAlign: TextAlign.right,
              style: GoogleFonts.amiri(
                fontSize: 19,
                height: 1.7,
                fontWeight: FontWeight.w700,
                color: _bannerInkColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _featuredAdhkar.translationEn,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: _bannerInkColor.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr ? '(رواه أبو داود)' : '(Narrated by Abu Dawud)',
            style: _uiFont(
              isAr,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _bannerInkColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner card: an auto-advancing, infinitely looping carousel between
  /// the travel overview slide and the featured-hadith slide, swapping
  /// every 5 seconds with a smooth slide+zoom transition and a small dot
  /// indicator, matching the reference design's hero card.
  Widget _buildBanner(BuildContext context, bool isAr) {
    final slides = [
      _buildBannerSlideTravel(isAr),
      _buildBannerSlideHadith(isAr),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: _bannerHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
                  // Manual interaction — restart the 5s countdown so autoplay
                  // doesn't fight the user's own swipe.
                  _startBannerAutoplay();
                }
                return false;
              },
              child: PageView.builder(
                controller: _bannerController,
                onPageChanged: (page) {
                  _bannerVirtualPage = page;
                  setState(() => _bannerActiveIndex = page % _bannerSlideCount);
                },
                itemBuilder: (context, index) {
                  return slides[index % _bannerSlideCount];
                },
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_bannerSlideCount, (i) {
                    final active = i == _bannerActiveIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section header with the small vertical accent bar from the reference
  /// design (e.g. "| أذكار السفر").
  Widget _buildSectionHeader(bool isAr, String title, _AdhkarPalette palette, {Color? accent}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: accent ?? palette.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: _uiFont(isAr, fontSize: 17, fontWeight: FontWeight.w700, color: palette.titleColor),
        ),
      ],
    );
  }

  /// Travel Adhkar list card. Icon badge sits at the reading-start edge
  /// (right, in RTL) next to the title, matching the reference layout.
  Widget _buildAdhkarCard(BuildContext context, bool isAr, _AdhkarItem item, _AdhkarPalette palette) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(palette),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isAr ? item.titleAr : item.titleEn,
                    style: _uiFont(isAr, fontSize: 15, fontWeight: FontWeight.w700, color: palette.titleColor),
                  ),
                ),
                _bookmarkButton(
                  id: 'a:${item.titleEn}',
                  palette: palette,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                item.arabicText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.amiri(
                  fontSize: 14,
                  height: 1.5,
                  color: palette.subtitleColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _showAdhkarPreview(context, isAr, item, palette);
                    },
                    icon: Icon(Icons.play_arrow_rounded, size: 18, color: item.color),
                    label: Text(
                      isAr ? 'تشغيل' : 'Play',
                      style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: item.color),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: item.color.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      await Clipboard.setData(ClipboardData(text: item.arabicText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAr ? 'تم النسخ' : 'Copied',
                              style: _uiFont(isAr, fontSize: 13),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.copy_rounded, size: 18, color: item.color),
                    label: Text(
                      isAr ? 'نسخ' : 'Copy',
                      style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: item.color),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: item.color.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDhikrCard(BuildContext context, bool isAr, _DhikrItem item, _AdhkarPalette palette) {
    final isComplete = item.count >= item.target;
    final progress = item.target == 0 ? 0.0 : item.count / item.target;
    final accent = isComplete ? const Color(0xFF2E9E6D) : AppColors.sunsetOrange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _tapDhikr(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(palette),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isComplete ? Icons.check_rounded : item.icon,
                        key: ValueKey(isComplete),
                        color: accent,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: _uiFont(isAr, fontSize: 16, fontWeight: FontWeight.w600, color: palette.titleColor),
                        ),
                        Text(
                          '${_localizeDigits('${item.count}/${item.target}')}'
                              '${item.target == 1 ? (isAr ? " (مرة واحدة)" : " (once)") : (isAr ? " مرة" : " times")}',
                          style: _uiFont(isAr, fontSize: 13, color: palette.subtitleColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: palette.titleColor.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context, bool isAr, _AdhkarPalette palette) {
    Widget chip(String label, Color color, IconData icon, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.transparent : color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: _uiFont(isAr, fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : color),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            isAr ? 'الكل' : 'All',
            palette.titleColor,
            Icons.apps_rounded,
            _selectedCategory == null,
                () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          for (final entry in _categoryMeta.entries) ...[
            chip(
              isAr ? entry.value.labelAr : entry.value.labelEn,
              entry.value.color,
              entry.value.icon,
              _selectedCategory == entry.key,
                  () => setState(() => _selectedCategory = entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDuaCard(BuildContext context, bool isAr, _DuaItem dua, _AdhkarPalette palette) {
    final meta = _categoryMeta[dua.category]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDuaPreview(context, isAr, dua, palette),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(palette),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(dua.icon, color: meta.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? dua.titleAr : dua.titleEn,
                      style: _uiFont(isAr, fontSize: 16, fontWeight: FontWeight.w600, color: palette.titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dua.arabicText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiri(fontSize: 13, color: palette.subtitleColor),
                    ),
                  ],
                ),
              ),
              _bookmarkButton(
                id: 'd:${dua.titleEn}',
                palette: palette,
                size: 19,
              ),
              Icon(
                isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: palette.titleColor.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Other Useful Adhkar" grid item. Square buttons with icon and text centered.
  Widget _buildOtherAdhkarGrid(BuildContext context, bool isAr, _AdhkarPalette palette) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: List.generate(_otherAdhkarLinks.length, (i) {
        final link = _otherAdhkarLinks[i];
        return _StaggeredFadeIn(
          index: i,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAr ? 'هذا القسم غير متاح بعد' : 'This section is not wired up yet',
                      style: _uiFont(isAr, fontSize: 13),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                decoration: _cardDecoration(palette, radius: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (link['color'] as Color).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(link['icon'] as IconData, color: link['color'] as Color, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isAr ? link['ar'] as String : link['en'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: palette.titleColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppDataProvider.instance.language == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? _AdhkarPalette.dark : _AdhkarPalette.light;

    if (isAr != _isArInit) _buildDhikrItems(isAr);

    final filteredDuas = _selectedCategory == null
        ? _duas
        : _duas.where((d) => d.category == _selectedCategory).toList();

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: palette.pageBg,
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            child: _chromeButton(
              icon: isAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              onPressed: () => Navigator.maybePop(context),
              palette: palette,
            ),
          ),
          leadingWidth: 56,
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'الأذكار' : 'Adhkar',
                style: _uiFont(isAr, fontWeight: FontWeight.w700, fontSize: 19, color: palette.titleColor),
              ),
              const SizedBox(height: 2),
              Text(
                isAr ? 'حصن نفسك بذكر الله أينما كنت' : 'Guard yourself with remembrance of Allah',
                style: _uiFont(isAr, fontSize: 11, fontWeight: FontWeight.w500, color: palette.subtitleColor),
              ),
            ],
          ),
          elevation: 0,
          backgroundColor: palette.pageBg,
          surfaceTintColor: Colors.transparent,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: _chromeButton(
                icon: Icons.bookmark_border_rounded,
                palette: palette,
                tooltip: isAr ? 'المحفوظات' : 'Bookmarks',
                onPressed: () => _openBookmarksSheet(isAr, palette),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchField(palette),
              const SizedBox(height: 16),
              _buildBanner(context, isAr),
              const SizedBox(height: 24),

              _buildSectionHeader(isAr, isAr ? 'أذكار السفر' : 'Travel Adhkar', palette),
              const SizedBox(height: 12),
              ...List.generate(_adhkarList.length, (i) {
                final item = _adhkarList[i];
                if (!_matchesSearch(
                  ar: item.titleAr,
                  en: item.titleEn,
                  body: item.arabicText,
                )) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StaggeredFadeIn(
                    index: i,
                    child: _buildAdhkarCard(context, isAr, item, palette),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Dhikr tally counters — moved here from Prayer Times.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(isAr, isAr ? 'التسبيح' : 'Tasbih', palette, accent: AppColors.sunsetOrange),
                  TextButton.icon(
                    onPressed: _resetAllDhikr,
                    icon: Icon(Icons.refresh_rounded, size: 18, color: palette.accent),
                    label: Text(
                      isAr ? 'إعادة تعيين' : 'Reset',
                      style: _uiFont(isAr, fontSize: 13, fontWeight: FontWeight.w600, color: palette.accent),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Text(
                  isAr ? 'اضغط على البطاقة للعد' : 'Tap a card to count',
                  style: _uiFont(isAr, fontSize: 12, color: palette.subtitleColor),
                ),
              ),
              ...List.generate(_dhikrItems.length, (i) {
                final item = _dhikrItems[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StaggeredFadeIn(
                    index: i,
                    child: _buildDhikrCard(context, isAr, item, palette),
                  ),
                );
              }),
              const SizedBox(height: 24),

              _buildSectionHeader(isAr, isAr ? 'الأدعية' : 'Duas', palette),
              const SizedBox(height: 4),
              Text(
                isAr ? 'اضغط لعرض الدعاء كاملاً' : 'Tap a card to read the full dua',
                style: _uiFont(isAr, fontSize: 12, color: palette.subtitleColor),
              ),
              const SizedBox(height: 12),
              _buildCategoryChips(context, isAr, palette),
              const SizedBox(height: 12),
              ...List.generate(filteredDuas.length, (i) {
                final dua = filteredDuas[i];
                if (!_matchesSearch(
                  ar: dua.titleAr,
                  en: dua.titleEn,
                  body: dua.arabicText,
                )) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StaggeredFadeIn(
                    key: ValueKey('dua_${dua.titleEn}'),
                    index: i,
                    child: _buildDuaCard(context, isAr, dua, palette),
                  ),
                );
              }),
              if (filteredDuas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد أدعية في هذا التصنيف' : 'No duas in this category',
                      style: _uiFont(isAr, fontSize: 13, color: palette.subtitleColor),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              _buildSectionHeader(isAr, isAr ? 'أذكار أخرى مفيدة' : 'Other Useful Adhkar', palette),
              const SizedBox(height: 12),
              _buildOtherAdhkarGrid(context, isAr, palette),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight one-shot fade + slide-up entrance animation, staggered by
/// [index]. Used to give the card lists a subtle, professional "cascade in"
/// feel on first build instead of appearing all at once.
class _StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggeredFadeIn({super.key, required this.child, this.index = 0});

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 10)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}