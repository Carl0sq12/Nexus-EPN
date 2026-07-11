/// Shared phone helpers for matching emergency contacts to app users.
abstract final class PhoneNormalizer {
  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  /// Canonical Ecuador-style mobile key (last 9 digits).
  static String canonicalKey(String value) {
    final digits = digitsOnly(value);
    if (digits.length >= 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  /// Variants used when looking up a profile by phone.
  static List<String> lookupVariants(String value) {
    final digits = digitsOnly(value);
    final key = canonicalKey(value);
    final variants = <String>{
      value.trim(),
      digits,
      key,
      if (key.length == 9) '0$key',
      if (key.length == 9) '593$key',
      if (key.length == 9) '+593$key',
    };
    return variants.where((v) => v.isNotEmpty).toList();
  }

  /// Preferred storage format for profile phone numbers.
  static String forStorage(String value) {
    final key = canonicalKey(value);
    if (key.length == 9) return '0$key';
    return digitsOnly(value);
  }
}
