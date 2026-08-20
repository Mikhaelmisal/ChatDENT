import 'package:flutter/services.dart';

/// Formats typed digits as `DD/MM/YYYY`, inserting `/` after day and month.
///
/// - DD: 01–31
/// - MM: 01–12
/// - YYYY: 1900–current year
class DdMmYyyyInputFormatter extends TextInputFormatter {
  static const minYear = 1900;

  static int get maxYear => DateTime.now().year;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final isDeleting = newValue.text.length < oldValue.text.length;
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    if (!isDeleting) {
      final accepted = acceptDigits(digits);
      if (accepted == null) return oldValue;
      digits = accepted;
    }

    final formatted = _format(digits, addTrailingSlash: !isDeleting);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Returns a (possibly auto-padded) digit string, or null if invalid.
  static String? acceptDigits(String digits) {
    if (digits.isEmpty) return '';

    if (digits.length == 1) {
      final dayDigit = int.parse(digits);
      if (dayDigit >= 4 && dayDigit <= 9) return '0$dayDigit';
      if (dayDigit >= 0 && dayDigit <= 3) return digits;
      return null;
    }

    final day = int.parse(digits.substring(0, 2));
    if (day < 1 || day > 31) return null;
    if (digits.length == 2) return digits;

    if (digits.length == 3) {
      final monthDigit = int.parse(digits[2]);
      if (monthDigit >= 2 && monthDigit <= 9) {
        return '${digits.substring(0, 2)}0$monthDigit';
      }
      if (monthDigit == 0 || monthDigit == 1) return digits;
      return null;
    }

    final month = int.parse(digits.substring(2, 4));
    if (month < 1 || month > 12) return null;
    if (digits.length == 4) return digits;

    if (!_yearPrefixCanBeValid(digits.substring(4))) return null;
    return digits;
  }

  static bool _yearPrefixCanBeValid(String prefix) {
    if (prefix.isEmpty) return true;
    final start = int.parse(prefix.padRight(4, '0'));
    final end = int.parse(prefix.padRight(4, '9'));
    return start <= maxYear && end >= minYear;
  }

  static String _format(String digits, {required bool addTrailingSlash}) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    if (addTrailingSlash && (digits.length == 2 || digits.length == 4)) {
      buffer.write('/');
    }
    return buffer.toString();
  }
}

final ddMmYyyyInputFormatter = DdMmYyyyInputFormatter();
