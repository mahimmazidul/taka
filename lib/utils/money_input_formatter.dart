import 'package:flutter/services.dart';

/// Keeps the amount field to something that is actually money: digits, at most
/// one decimal point, at most two decimals, at most nine characters.
///
/// The old pad could not produce `1.2.3`; a text field can, and
/// `keypadTextToMinor('1.2.3')` quietly reads it as 1.20. Silently reinterpreted
/// money is the one kind of bug this app must not have, so the junk never gets
/// in.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.maxWholeDigits = 7, this.maxDecimals = 2});

  final int maxWholeDigits;
  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = newValue.text;
    if (text.isEmpty) return newValue;

    final int dots = '.'.allMatches(text).length;
    if (dots > 1) return oldValue;

    final List<String> parts = text.split('.');
    final String whole = parts.first;
    if (whole.length > maxWholeDigits) return oldValue;
    if (parts.length > 1 && parts[1].length > maxDecimals) return oldValue;
    if (text == '.') return oldValue.replacingWith('0.');

    return newValue;
  }
}

extension on TextEditingValue {
  TextEditingValue replacingWith(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}
