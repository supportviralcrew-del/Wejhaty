/// Central place for app + company metadata shown in Settings → About.
/// Edit these values directly rather than hunting through the UI code.
abstract final class AppInfo {
  // ── App ──────────────────────────────────────────────────────────────
  static const String appNameEn = 'Wejhaty';
  static const String appNameAr = 'وجهتي';

  /// TODO: wire up `package_info_plus` to read this from pubspec.yaml at
  /// runtime instead of hardcoding it, so it never drifts out of sync
  /// with your actual release version.
  static const String appVersion = '1.0.2';

  static const String appLogoAsset = 'assets/icon/RoadTripLogo.png';

  // ── Company ──────────────────────────────────────────────────────────
  static const String companyNameEn = 'ViralScript Labs';
  static const String companyNameAr = 'فايرال سكريبت لاب';
  static const String companyLogoAsset = 'assets/companylogo/ViralCompanyLogo.jpg';
  static const String companyWebsite = 'https://viralscriptlab.netlify.app';
  static const String supportEmail = 'support.viral.crew@gmail.com';

  static const String companyDescriptionEn =
      'Viral Script Lab is an international software development studio. '
      'We build practical, well-crafted apps for the everyday problems '
      'people run into — the kind of tool that should already exist, but '
      'doesn\'t. If there\'s something people need and can\'t easily find, '
      'we try to build it.';

  static const String companyDescriptionAr =
      'فايرال سكريبت لاب شركة عالمية متخصصة في تطوير البرمجيات والتطبيقات. '
      'نبني تطبيقات عملية ومتقنة تحل مشاكل يواجهها الناس يومياً — أدوات كان '
      'يفترض أن تكون موجودة، لكنها غير متوفرة. مهمتنا بسيطة: إن كان هناك '
      'شيء يحتاجه الناس ولا يجدونه بسهولة، نحاول أن نصنعه.';

  // ── Store links ──────────────────────────────────────────────────────
  // TODO: replace with your real store listing IDs once published.
  static const String androidPackageName = 'com.wejhaty.app';
  static const String iosAppId = '0000000000';

  static String get androidStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidPackageName';
  static String get iosStoreUrl => 'https://apps.apple.com/app/id$iosAppId';
}