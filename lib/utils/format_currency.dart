/// Money is stored as an integer count of **paisa** (1 BDT = 100 paisa).
/// These helpers are the only place where minor units become text.
library;

const String kDefaultCurrencySymbol = '৳';

/// 125050 → "৳ 1,250" (or "৳ 1,250.50" with [showDecimals]).
String formatMoney(
  int minorUnits, {
  String symbol = kDefaultCurrencySymbol,
  bool showDecimals = false,
  bool withSymbol = true,
  bool signed = false,
}) {
  final bool negative = minorUnits < 0;
  final int magnitude = minorUnits.abs();
  final int whole = magnitude ~/ 100;
  final int cents = magnitude % 100;

  final String wholeText = _groupThousands(whole.toString());
  final String decimals = showDecimals
      ? '.${cents.toString().padLeft(2, '0')}'
      : '';

  final String sign;
  if (negative) {
    sign = '−';
  } else if (signed) {
    sign = '+';
  } else {
    sign = '';
  }

  return '$sign${withSymbol ? '$symbol ' : ''}$wholeText$decimals';
}

/// "৳ 12.5k" style, for tight spots.
String formatCompactMoney(
  int minorUnits, {
  String symbol = kDefaultCurrencySymbol,
}) {
  final bool negative = minorUnits < 0;
  final double major = minorUnits.abs() / 100;
  final String sign = negative ? '−' : '';

  if (major >= 1000000) return '$sign$symbol ${_trim(major / 1000000)}m';
  if (major >= 1000) return '$sign$symbol ${_trim(major / 1000)}k';
  return formatMoney(minorUnits, symbol: symbol);
}

String _trim(double value) =>
    value.toStringAsFixed(value >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '');

String _groupThousands(String digits) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Parses "1,250.50", "1250" or ".5" into minor units. Null when not positive.
int? parseAmountToMinor(String input) {
  final String cleaned = input.trim().replaceAll(',', '').replaceAll(' ', '');
  if (cleaned.isEmpty) return null;

  final double? value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;

  final int minor = (value * 100).round();
  return minor > 0 ? minor : null;
}

/// 125050 → "1250.50", for prefilling an edit field.
String minorToInputText(int minorUnits) {
  final int whole = minorUnits ~/ 100;
  final int cents = minorUnits % 100;
  if (cents == 0) return whole.toString();
  return '$whole.${cents.toString().padLeft(2, '0')}';
}

/// Keypad text → minor units without going through a double parse of the
/// whole string: "1234.5" is read as 1234.50 exactly.
int keypadTextToMinor(String text) {
  if (text.isEmpty) return 0;
  final List<String> parts = text.split('.');
  final String whole = parts.first.isEmpty ? '0' : parts.first;
  String fraction = parts.length > 1 ? parts[1] : '';
  if (fraction.length > 2) fraction = fraction.substring(0, 2);
  fraction = fraction.padRight(2, '0');
  final int wholeValue = int.tryParse(whole) ?? 0;
  final int fractionValue = int.tryParse(fraction) ?? 0;
  return wholeValue * 100 + fractionValue;
}

/// 125050 → "1250.50" for the keypad display.
String minorToKeypadText(int minorUnits) {
  final int whole = minorUnits ~/ 100;
  final int cents = minorUnits % 100;
  if (cents == 0) return '$whole';
  return '$whole.${cents.toString().padLeft(2, '0')}';
}
