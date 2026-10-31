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

/// Screenshots committed to `docs/screenshots/` and the README — one per screen.
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

  testWidgets('08 budgets', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly budgets'));
    await tester.pumpAndSettle();
    await _shot(tester, 'budgets');
  });

  testWidgets('10 about', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    // The About row lives at the bottom of Settings. The scrollable is named
    // explicitly because the tab PageView is one too.
    await tester.scrollUntilVisible(
      find.textContaining('Made by'),
      220,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Made by'));
    await tester.pumpAndSettle();
    await _shot(tester, 'about');
  });

  testWidgets('11 add entry — landscape', (WidgetTester tester) async {
    // Form on the left, pad on the right: the whole point of the landscape pass.
    await _render(tester, darkMode: false, size: const Size(844, 390));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    for (final String digit in <String>['8', '0']) {
      await tester.tap(find.text(digit));
      await tester.pumpAndSettle();
    }
    await _shot(tester, 'add_entry_landscape');
  });

  testWidgets('12 home — landscape', (WidgetTester tester) async {
    await _render(tester, darkMode: false, size: const Size(844, 390));
    await _shot(tester, 'home_landscape');
  });

  testWidgets('13 add entry — after saving', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    for (final String digit in <String>['4', '5']) {
      await tester.tap(find.text(digit));
      await tester.pumpAndSettle();
    }
    await tester.runAsync(() async {
      await tester.tap(find.text('ADD'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await _shot(tester, 'add_entry_saved');
  });

  testWidgets('09 categories', (WidgetTester tester) async {
    await _render(tester, darkMode: false);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage categories'));
    await tester.pumpAndSettle();
    await _shot(tester, 'categories');
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
