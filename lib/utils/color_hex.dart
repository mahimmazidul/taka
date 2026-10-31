import 'dart:ui';

/// Parses "#RRGGBB" (or "RRGGBB", or "#AARRGGBB") into a [Color].
/// Falls back to slate grey instead of throwing, so a hand-edited backup file
/// can never crash the dashboard.
Color colorFromHex(String hex) {
  String cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length == 8) {
    // #AARRGGBB already carries alpha; keep the last 6 channel digits.
    cleaned = cleaned.substring(2);
  }
  if (cleaned.length != 6) return const Color(0xFF64748B);

  final int? value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFF64748B);
  return Color(0xFF000000 | value);
}

/// Inverse of [colorFromHex], used by the category editor.
String colorToHex(Color color) {
  int channel(double value) => (value * 255).round().clamp(0, 255);

  final String r = channel(color.r).toRadixString(16).padLeft(2, '0');
  final String g = channel(color.g).toRadixString(16).padLeft(2, '0');
  final String b = channel(color.b).toRadixString(16).padLeft(2, '0');
  return '#${(r + g + b).toUpperCase()}';
}
