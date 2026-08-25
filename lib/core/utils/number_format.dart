/// Formats numbers according to the user's preference for Arabic or English digits.
///
/// When [useArabicNumbers] is true, standard Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩)
/// are used. Otherwise Western digits (0123456789) are used.
class NumberFormatUtil {
  static const _englishDigits = '0123456789';
  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

  /// Converts any numeric string to the desired digit system.
  static String format(String input, {required bool useArabicNumbers}) {
    if (!useArabicNumbers) return input;

    return input.split('').map((char) {
      final index = _englishDigits.indexOf(char);
      if (index >= 0) {
        return _arabicDigits[index];
      }
      return char;
    }).join();
  }

  /// Convenience: formats an [int] to the desired digit system.
  static String formatInt(int value, {required bool useArabicNumbers}) {
    return format(value.toString(), useArabicNumbers: useArabicNumbers);
  }

  /// Convenience: formats a [double] with the given number of decimal places.
  static String formatDouble(
    double value, {
    required bool useArabicNumbers,
    int decimals = 1,
  }) {
    return format(
      value.toStringAsFixed(decimals),
      useArabicNumbers: useArabicNumbers,
    );
  }

  /// Formats [value] with no decimal places, useful for whole numbers like
  /// prayer times hours/minutes, distances, speeds, etc.
  static String formatWhole(double value, {required bool useArabicNumbers}) {
    return formatInt(value.round(), useArabicNumbers: useArabicNumbers);
  }
}