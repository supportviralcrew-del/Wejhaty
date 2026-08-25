/// A single emergency contact entry (one service, one or more numbers).
class EmergencyNumber {
  const EmergencyNumber({
    required this.labelEn,
    required this.labelAr,
    required this.numbers,
    this.icon = 'call',
  });

  final String labelEn;
  final String labelAr;

  /// A service can have more than one valid number (e.g. GSM vs fixed
  /// line, or multiple regional numbers) — each is shown as its own
  /// tappable chip so nothing gets silently dropped or squeezed.
  final List<String> numbers;

  /// Logical icon key, mapped to a Material icon in the UI layer.
  final String icon;
}

/// Verified core services (Police / Ambulance / Fire) for countries where
/// the generic 112-vs-911 guess is actually WRONG — e.g. Saudi Arabia
/// (999 / 997 / 998) and Jordan (911 unified), not 112. Sourced from
/// official government pages (psd.gov.jo, gov.om, u.ae) and cross-checked
/// against multiple independent guides, current as of mid-2026. This is
/// used as the *primary* source for these countries — ahead of the live
/// API — precisely because getting an emergency number wrong is worse
/// than a live lookup occasionally being unreachable.
final Map<String, List<EmergencyNumber>> curatedCoreNumbersByIso = {
  'SA': [
    EmergencyNumber(labelEn: 'Police', labelAr: 'الشرطة', numbers: ['999', '911'], icon: 'shield'),
    EmergencyNumber(labelEn: 'Ambulance', labelAr: 'الإسعاف', numbers: ['997'], icon: 'medical'),
    EmergencyNumber(labelEn: 'Fire / Civil Defense', labelAr: 'الدفاع المدني', numbers: ['998'], icon: 'fire'),
  ],
  'JO': [
    EmergencyNumber(labelEn: 'Police / Ambulance / Fire (Unified)', labelAr: 'الطوارئ الموحدة', numbers: ['911'], icon: 'shield'),
  ],
  'AE': [
    EmergencyNumber(labelEn: 'Police', labelAr: 'الشرطة', numbers: ['999'], icon: 'shield'),
    EmergencyNumber(labelEn: 'Ambulance', labelAr: 'الإسعاف', numbers: ['998'], icon: 'medical'),
    EmergencyNumber(labelEn: 'Fire Department', labelAr: 'الدفاع المدني', numbers: ['997'], icon: 'fire'),
  ],
  'EG': [
    EmergencyNumber(labelEn: 'Police', labelAr: 'الشرطة', numbers: ['122'], icon: 'shield'),
    EmergencyNumber(labelEn: 'Ambulance', labelAr: 'الإسعاف', numbers: ['123'], icon: 'medical'),
    EmergencyNumber(labelEn: 'Fire Department', labelAr: 'الدفاع المدني', numbers: ['180'], icon: 'fire'),
  ],
  'QA': [
    EmergencyNumber(labelEn: 'Police / Ambulance / Fire (Unified)', labelAr: 'الطوارئ الموحدة', numbers: ['999'], icon: 'shield'),
  ],
  'BH': [
    EmergencyNumber(labelEn: 'Police / Ambulance / Fire (Unified)', labelAr: 'الطوارئ الموحدة', numbers: ['999'], icon: 'shield'),
  ],
  'OM': [
    EmergencyNumber(labelEn: 'Police / Ambulance / Fire (Unified)', labelAr: 'الطوارئ الموحدة', numbers: ['9999'], icon: 'shield'),
  ],
};

/// Curated services that the generic emergency-number API does not cover
/// (civil defense, tourist police), keyed by ISO alpha-2 country code.
/// Kept intentionally small and high-confidence rather than exhaustive.
final Map<String, List<EmergencyNumber>> curatedExtraNumbersByIso = {
  'SA': [
    EmergencyNumber(labelEn: 'Traffic Police', labelAr: 'شرطة المرور', numbers: ['993'], icon: 'traffic'),
  ],
  'AE': [
    EmergencyNumber(labelEn: 'Tourist Police', labelAr: 'شرطة السياحة', numbers: ['800-4438'], icon: 'travel'),
  ],
  'JO': [
    EmergencyNumber(labelEn: 'Tourist Police', labelAr: 'شرطة السياحة', numbers: ['+962795505755'], icon: 'travel'),
  ],
  'EG': [
    EmergencyNumber(labelEn: 'Tourist & Antiquities Police', labelAr: 'شرطة السياحة والآثار', numbers: ['126'], icon: 'travel'),
  ],
  'TR': [
    EmergencyNumber(labelEn: 'Tourist Police', labelAr: 'شرطة السياحة', numbers: ['155'], icon: 'travel'),
    EmergencyNumber(labelEn: 'Jandarma (Rural Security)', labelAr: 'الدرك', numbers: ['156'], icon: 'shield'),
  ],
  'US': [
    EmergencyNumber(labelEn: 'Poison Control', labelAr: 'مكافحة السموم', numbers: ['18002221222'], icon: 'medical'),
  ],
  'GB': [
    EmergencyNumber(labelEn: 'Non-Emergency Police', labelAr: 'الشرطة (غير طارئ)', numbers: ['101'], icon: 'shield'),
  ],
};

/// Last-resort fallback used only for a country that has no curated core
/// data AND whose live lookup failed. Most of the Americas default to
/// 911, most of Europe/Middle East/Asia to 112 — a reasonable guess for
/// the many countries that really do use one of those two, but NOT a
/// substitute for real data where it matters (see
/// [curatedCoreNumbersByIso] for the countries where this guess would be
/// wrong, e.g. Saudi Arabia, Jordan, UAE, Egypt).
List<EmergencyNumber> genericFallbackNumbers(String? countryIso) {
  final use911 = const {'US', 'CA', 'MX'}.contains(countryIso);
  final primary = use911 ? '911' : '112';

  return [
    EmergencyNumber(labelEn: 'Police', labelAr: 'الشرطة', numbers: [primary], icon: 'shield'),
    EmergencyNumber(labelEn: 'Ambulance', labelAr: 'الإسعاف', numbers: [primary], icon: 'medical'),
    EmergencyNumber(labelEn: 'Fire Department', labelAr: 'الدفاع المدني', numbers: [primary], icon: 'fire'),
  ];
}