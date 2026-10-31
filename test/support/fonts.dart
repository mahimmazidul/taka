import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real app font into the test renderer, otherwise every glyph in a
/// golden screenshot would be a box.
Future<void> loadTestFonts() async {
  final FontLoader loader = FontLoader('HindSiliguri');
  for (final String asset in <String>[
    'assets/fonts/HindSiliguri-Regular.ttf',
    'assets/fonts/HindSiliguri-Medium.ttf',
    'assets/fonts/HindSiliguri-SemiBold.ttf',
    'assets/fonts/HindSiliguri-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();

  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
