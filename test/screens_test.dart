import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/app.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/store/app_state.dart';

import 'support/seed.dart';

/// Pumps the whole app at several phone sizes. Any RenderFlex overflow or
/// layout assertion fails the test instead of showing up as yellow stripes.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    // Pin "now" so Today/Yesterday labels and the week strip never drift.
    AppClock.now = () => kTestNow;
  });

  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.inMemory(factory: databaseFactoryFfi);
    AppState.instance = await buildSeededState(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const TakaApp());
    await tester.pumpAndSettle();
  }

  testWidgets('home renders the seeded month', (WidgetTester tester) async {
    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('টাকা'), findsOneWidget);
    expect(find.text('৳ 79,000'), findsNothing); // balance lives in a tween
    expect(find.textContaining('Budget'.toUpperCase()), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('layouts hold on small, large and tablet widths', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(360, 800),
      const Size(414, 896),
      const Size(768, 1024),
    ]) {
      await pumpAt(tester, size);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });

  testWidgets('survives a large accessibility text scale', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(360, 800), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom bar switches between the four tabs', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.tap(find.byIcon(Icons.receipt_long_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('entries · net'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.handshake_rounded));
    await tester.pumpAndSettle();
    expect(find.text('I lent'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Dark mode'), findsOneWidget);
  });

  testWidgets('adding an entry through the keypad updates the ledger', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('New entry'), findsOneWidget);

    for (final String digit in <String>['1', '2', '5']) {
      await tester.tap(find.text(digit));
      await tester.pumpAndSettle();
    }

    await tester.runAsync(() async {
      await tester.tap(find.text('Save entry'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();

    expect(find.text('New entry'), findsNothing);
    expect(
      AppState.instance.today.expenseMinor,
      12500 + 4500 + 12000 + 32000 + 3000 + 6000,
    );
  });

  testWidgets('dark mode toggle persists and repaints', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.dark_mode_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(AppState.instance.settings.darkMode, isTrue);
    expect(tester.takeException(), isNull);
  });
}
