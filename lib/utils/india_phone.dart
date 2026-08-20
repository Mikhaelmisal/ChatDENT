/// India patient phone numbers: country code `91` + 10-digit local number.
class IndiaPhone {
  static const countryCode = '91';
  static const localLength = 10;

  /// Stored form: `91` followed by 10 digits, no spaces or `+`.
  static String persist(String localDigits) => '$countryCode$localDigits';

  static String e164(String localDigits) => '+$countryCode$localDigits';

  static bool isCompleteLocal(String digits) =>
      digits.length == localLength && RegExp(r'^\d{10}$').hasMatch(digits);

  /// Local 10-digit part from stored/E.164/input text, or leftover digits.
  static String localDigitsFrom(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith(countryCode) && digits.length >= 12) {
      return digits.substring(2, 12);
    }
    if (digits.length > localLength) {
      return digits.substring(digits.length - localLength);
    }
    return digits;
  }
}
