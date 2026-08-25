/// Resolves a free-text country name (as returned by reverse-geocoding /
/// weather APIs, in English or Arabic) to an ISO 3166-1 alpha-2 code, which
/// is what the emergency-number lookup service expects.
///
/// This intentionally covers the countries most relevant to a Middle-East
/// centred road-trip app plus all major world regions, and normalises
/// input (case, whitespace, diacritics, "Al/El" article variants) so small
/// differences between data providers don't cause lookup misses.
library country_codes;

final Map<String, String> _countryNameToIso2 = {
  // ── Middle East / Gulf ──────────────────────────────────────────────
  'saudi arabia': 'SA', 'kingdom of saudi arabia': 'SA', 'ksa': 'SA', 'المملكة العربية السعودية': 'SA', 'السعودية': 'SA',
  'united arab emirates': 'AE', 'uae': 'AE', 'الإمارات العربية المتحدة': 'AE', 'الإمارات': 'AE',
  'jordan': 'JO', 'الأردن': 'JO',
  'kuwait': 'KW', 'الكويت': 'KW',
  'qatar': 'QA', 'قطر': 'QA',
  'bahrain': 'BH', 'البحرين': 'BH',
  'oman': 'OM', 'عمان': 'OM',
  'egypt': 'EG', 'مصر': 'EG',
  'iraq': 'IQ', 'العراق': 'IQ',
  'syria': 'SY', 'سوريا': 'SY',
  'lebanon': 'LB', 'لبنان': 'LB',
  'yemen': 'YE', 'اليمن': 'YE',
  'palestine': 'PS', 'فلسطين': 'PS',
  'israel': 'IL',
  'turkey': 'TR', 'türkiye': 'TR', 'تركيا': 'TR',
  'iran': 'IR',
  // ── North Africa ────────────────────────────────────────────────────
  'morocco': 'MA', 'المغرب': 'MA',
  'algeria': 'DZ', 'الجزائر': 'DZ',
  'tunisia': 'TN', 'تونس': 'TN',
  'libya': 'LY', 'ليبيا': 'LY',
  'sudan': 'SD', 'السودان': 'SD',
  // ── Europe ──────────────────────────────────────────────────────────
  'united kingdom': 'GB', 'uk': 'GB', 'great britain': 'GB', 'england': 'GB',
  'ireland': 'IE',
  'france': 'FR',
  'germany': 'DE',
  'spain': 'ES',
  'portugal': 'PT',
  'italy': 'IT',
  'netherlands': 'NL',
  'belgium': 'BE',
  'switzerland': 'CH',
  'austria': 'AT',
  'greece': 'GR',
  'sweden': 'SE',
  'norway': 'NO',
  'denmark': 'DK',
  'finland': 'FI',
  'poland': 'PL',
  'czech republic': 'CZ', 'czechia': 'CZ',
  'romania': 'RO',
  'hungary': 'HU',
  'russia': 'RU',
  'ukraine': 'UA',
  'cyprus': 'CY',
  // ── Americas ────────────────────────────────────────────────────────
  'united states': 'US', 'united states of america': 'US', 'usa': 'US', 'us': 'US',
  'canada': 'CA',
  'mexico': 'MX',
  'brazil': 'BR',
  'argentina': 'AR',
  'chile': 'CL',
  'colombia': 'CO',
  // ── Asia / Pacific ──────────────────────────────────────────────────
  'china': 'CN',
  'japan': 'JP',
  'south korea': 'KR', 'republic of korea': 'KR',
  'india': 'IN',
  'pakistan': 'PK',
  'bangladesh': 'BD',
  'indonesia': 'ID',
  'malaysia': 'MY',
  'singapore': 'SG',
  'thailand': 'TH',
  'philippines': 'PH',
  'vietnam': 'VN',
  'australia': 'AU',
  'new zealand': 'NZ',
  // ── Africa (Sub-Saharan) ────────────────────────────────────────────
  'south africa': 'ZA',
  'nigeria': 'NG',
  'kenya': 'KE',
  'ethiopia': 'ET',
};

String _normalize(String input) {
  var s = input.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'[\u064B-\u0652]'), ''); // strip Arabic diacritics
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

/// Looks up the ISO alpha-2 country code for a given [countryName].
/// Returns null if no match is found.
String? isoCodeForCountryName(String? countryName) {
  if (countryName == null || countryName.trim().isEmpty) return null;
  final key = _normalize(countryName);
  if (_countryNameToIso2.containsKey(key)) return _countryNameToIso2[key];

  // If the input already looks like a 2-letter ISO code, accept it directly.
  final upper = countryName.trim().toUpperCase();
  if (RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return upper;

  // Fall back to a loose "contains" match (handles things like
  // "Kingdom of Saudi Arabia, Makkah Province").
  for (final entry in _countryNameToIso2.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return null;
}