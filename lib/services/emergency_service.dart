import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tripproject/data/country_codes.dart';
import 'package:tripproject/data/emergency_numbers.dart';

/// How the numbers shown to the user were sourced. Determines whether the
/// UI should show a "these are our best guess" disclosure.
enum EmergencyDataSource {
  /// From [curatedCoreNumbersByIso] — hand-verified against official
  /// government sources. Highest confidence; used even when the live API
  /// is reachable, since it's more accurate for these countries.
  verifiedCurated,

  /// From the live Emergency Number API.
  liveApi,

  /// From [genericFallbackNumbers] — a 112/911 guess used only when
  /// neither of the above is available.
  genericGuess,
}

class EmergencyLookupResult {
  const EmergencyLookupResult({
    required this.numbers,
    required this.source,
    required this.resolvedCountryIso,
  });

  final List<EmergencyNumber> numbers;
  final EmergencyDataSource source;
  final String? resolvedCountryIso;

  /// Only the generic 112/911 guess should carry a "we're not sure"
  /// disclosure — curated and live data are both considered reliable.
  bool get isBestEffortGuess => source == EmergencyDataSource.genericGuess;
}

/// Fetches official emergency numbers for a country dynamically instead
/// of relying purely on hardcoded values.
///
/// Priority order, highest confidence first:
///  1. [curatedCoreNumbersByIso] — hand-verified core numbers for
///     countries where the generic 112/911 heuristic is actually WRONG
///     (Saudi Arabia, Jordan, UAE, Egypt, Qatar, Bahrain, Oman). These are
///     used even when the live API is reachable, and don't require a
///     network call at all, so they're immune to the live API being slow
///     or unreachable.
///  2. The live Emergency Number API (https://emergencynumberapi.com),
///     for any other country.
///  3. [genericFallbackNumbers] — a 112/911 guess, only when both of the
///     above have nothing.
///
/// [curatedExtraNumbersByIso] (Civil Defense, Tourist Police, etc. — not
/// carried by the public API) is layered on top of whichever core source
/// was used.
class EmergencyService {
  EmergencyService._();
  static final EmergencyService instance = EmergencyService._();

  final Map<String, EmergencyLookupResult> _cache = {};

  static const _defaultCountryName = 'Saudi Arabia';
  static const _requestTimeout = Duration(seconds: 6);

  Future<EmergencyLookupResult> fetchFor(String? countryName) async {
    final effectiveName = (countryName == null || countryName.trim().isEmpty)
        ? _defaultCountryName
        : countryName;
    final iso = isoCodeForCountryName(effectiveName) ?? 'SA';

    if (_cache.containsKey(iso)) return _cache[iso]!;

    final extras = curatedExtraNumbersByIso[iso] ?? [];

    // 1. Verified curated data wins outright for the countries we've
    // hand-checked — skip the network entirely so it's instant and can
    // never be knocked out by a third-party outage.
    final core = curatedCoreNumbersByIso[iso];
    if (core != null) {
      final result = EmergencyLookupResult(
        numbers: [...core, ...extras],
        source: EmergencyDataSource.verifiedCurated,
        resolvedCountryIso: iso,
      );
      _cache[iso] = result;
      return result;
    }

    // 2. Try the live API for everywhere else.
    try {
      final uri = Uri.parse('https://emergencynumberapi.com/api/country/$iso');
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;

        if (data != null && body['error'] == null) {
          final parsed = _parseApiData(data);
          if (parsed.isNotEmpty) {
            final result = EmergencyLookupResult(
              numbers: [...parsed, ...extras],
              source: EmergencyDataSource.liveApi,
              resolvedCountryIso: iso,
            );
            _cache[iso] = result;
            return result;
          }
        }
      } else {
        debugPrint('EmergencyService: HTTP ${response.statusCode} for $iso');
      }
    } catch (e) {
      // Common causes if this always triggers: no internet permission
      // configured for the platform, a firewall/proxy blocking the
      // domain, or the third-party API being temporarily down. None of
      // that matters for countries covered by curatedCoreNumbersByIso
      // above, which never reach this branch.
      debugPrint('EmergencyService: live lookup failed for $iso: $e');
    }

    // 3. Last resort: generic guess + any curated extras we still have.
    return EmergencyLookupResult(
      numbers: [...genericFallbackNumbers(iso), ...extras],
      source: EmergencyDataSource.genericGuess,
      resolvedCountryIso: iso,
    );
    // Deliberately not cached — a later attempt (e.g. once connectivity
    // returns) should still try the live API again.
  }

  List<EmergencyNumber> _parseApiData(Map<String, dynamic> data) {
    final result = <EmergencyNumber>[];

    List<String> numbersFrom(dynamic service) {
      if (service is! Map<String, dynamic>) return [];
      final all = <String>[];
      for (final key in ['All', 'GSM', 'Fixed']) {
        final list = service[key];
        if (list is List) {
          for (final n in list) {
            final s = n.toString();
            if (s.isNotEmpty && !all.contains(s)) all.add(s);
          }
        }
      }
      return all;
    }

    final police = numbersFrom(data['Police']);
    if (police.isNotEmpty) {
      result.add(EmergencyNumber(labelEn: 'Police', labelAr: 'الشرطة', numbers: police, icon: 'shield'));
    }

    final ambulance = numbersFrom(data['Ambulance']);
    if (ambulance.isNotEmpty) {
      result.add(EmergencyNumber(labelEn: 'Ambulance', labelAr: 'الإسعاف', numbers: ambulance, icon: 'medical'));
    }

    final fire = numbersFrom(data['Fire']);
    if (fire.isNotEmpty) {
      result.add(EmergencyNumber(labelEn: 'Fire Department', labelAr: 'الدفاع المدني', numbers: fire, icon: 'fire'));
    }

    final dispatch = numbersFrom(data['Dispatch']);
    if (dispatch.isNotEmpty && result.isEmpty) {
      result.add(EmergencyNumber(
        labelEn: 'Emergency Dispatch',
        labelAr: 'الطوارئ الموحدة',
        numbers: dispatch,
        icon: 'shield',
      ));
    }

    return result;
  }
}