import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/app.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/store/app_state.dart';
import 'package:taka/store/settings_actions.dart';

import 'support/fonts.dart';
import 'support/seed.dart';

/// Screenshots committed to `docs/screenshots/` and the README.
/// Refresh with: flutter test test/golden_test.dart --update-goldens
void main() {
  setUpAll(() async {
    // Pin "now" so date chips, week starts and Today/Yesterday labels are stable.
    AppClock.now = () => kTestNow;
    sqfliteFfiInit();
    await loadTestFonts();
    // The note field blinks its caret while focused; freeze it so screenshots are
    // byte-identical between runs instead of drifting by a few pixels.
    EditableText.debugDeterministicCursor = true;
  });

  testWidgets('01 home — light', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await _shot(tester, 'home_light');
  });

  testWidgets('02 home — dark', (WidgetTester tester) async {
    await _render(tester, darkMode: true);
    await _shot(tester, 'home_dark');
  });

  testWidgets('03 home — small phone', (WidgetTester tester) async {
    await _render(tester, darkMode: false, size: const Size(320, 568));
    await _shot(tester, 'home_small');
  });

  testWidgets('04 add entry', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    for (final String digit in <String>['2', '5', '0']) {
      await tester.tap(find.text(digit));
      await tester.pumpAndSettle();
    }
    await _shot(tester, 'add_entry');
  });

  testWidgets('05 history', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.receipt_long_rounded));
    await tester.pumpAndSettle();
    await _shot(tester, 'history');
  });

  testWidgets('06 udhar', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.handshake_rounded));
    await tester.pumpAndSettle();
    await _shot(tester, 'udhar');
  });

  testWidgets('07 settings', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await _shot(tester, 'settings');
  });
}

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  debugDisableShadows = true;
}

Future<void> _render(
  WidgetTester tester, {
  required bool darkMode,
  Size size = const Size(390, 844),
}) async {
  // Shadows must be enabled *before* the frame is painted, otherwise the test
  // binding draws them as flat silhouettes.
  debugDisableShadows = false;
  final AppDatabase database = AppDatabase.inMemory(
    factory: databaseFactoryFfi,
  );
  addTearDown(database.close);

  final AppState? seeded = await tester.runAsync(
    () => buildSeededState(database: database),
  );
  if (seeded == null) throw StateError('seeding failed');
  if (darkMode) {
    await tester.runAsync(() => seeded.setDarkMode(true));
  }
  AppState.instance = seeded;

  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const TakaApp());
  await tester.pumpAndSettle();
}
