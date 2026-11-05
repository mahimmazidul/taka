import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/app.dart';
import 'package:taka/components/settings_row.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/models/savings_entry.dart';
import 'package:taka/store/app_state.dart';
import 'package:taka/store/savings_actions.dart';

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

  // The report from the phone: allowance arrived on 30 October, part of it was
  // spent the same day, and on 1 November the app showed nothing left because it
  // was adding up November alone. Money in a pocket does not reset on the 1st.
  testWidgets('money from 30 October still shows on 1 November', (
    WidgetTester tester,
  ) async {
    final DateTime november = DateTime(2026, 11, 1, 9);
    AppClock.now = () => november;
    addTearDown(() => AppClock.now = () => kTestNow);
    // A phone that was last used in October and is opened on the 1st: the state
    // reloads, exactly as it does on resume or just after midnight. `runAsync`
    // because the reload touches the real database outside the fake clock.
    await tester.runAsync(() => AppState.instance.refresh());

    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    // October left 8,500 in and 990 out, so nothing arrived in November and yet
    // the pocket holds 7,510 — the hero says so, and says where it came from.
    expect(find.textContaining('MONEY ON HAND · NOVEMBER'), findsOneWidget);
    expect(find.textContaining('carried from October'), findsOneWidget);
    // The seeded ledger has ৳1,500 lent out and ৳500 borrowed, so the pocket is
    // 7,510 − 1,500 + 500, and the card says why it is not 7,510.
    expect(find.textContaining('lent out'), findsOneWidget);
    expect(find.textContaining('borrowed'), findsOneWidget);
    // Nothing has been logged this month, so there is no per-day figure to
    // invent and the nudge stays about the week.
    expect(find.textContaining('left for today'), findsNothing);
  });

  testWidgets('home renders the seeded month', (WidgetTester tester) async {
    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('টাকা'), findsOneWidget);
    expect(find.text('৳ 79,000'), findsNothing); // balance lives in a tween
    // v1.3.0: the Home screen must not show a limit. Budgets live in Settings.
    expect(find.textContaining('Budget'), findsNothing);
    expect(find.text('Spent today'), findsOneWidget);
    // …and one quiet line: this week's spend, plus what a day costs from here.
    expect(find.textContaining('this week'), findsOneWidget);
  });

  testWidgets('layouts hold from a small phone to a tablet, both ways up', (
    WidgetTester tester,
  ) async {
    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(360, 800),
      const Size(414, 896),
      const Size(768, 1024),
      // Landscape: the add-entry screen splits into form + pad, the lists get
      // gutters, and nothing overflows.
      const Size(844, 390),
      const Size(640, 360),
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

    // The amount is a real field with the phone's own numeric keyboard.
    await tester.enterText(find.byKey(const Key('amount')), '125');
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('ADD'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();

    // The screen stays open on purpose: ভাত, মাছ, a drink are three entries in
    // a row, and closing after each one was the complaint.
    expect(find.text('New entry'), findsOneWidget);
    expect(find.textContaining('Added '), findsOneWidget);
    expect(
      AppState.instance.today.expenseMinor,
      12500 + 4500 + 12000 + 32000 + 3000 + 6000,
    );

    // The amount is cleared, the category is kept for the next one.
    final TextField amount = tester.widget<TextField>(
      find.byKey(const Key('amount')),
    );
    expect(amount.controller!.text, isEmpty, reason: 'amount resets');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('New entry'), findsNothing);
    expect(find.text('Spent today'), findsOneWidget);
  });

  testWidgets('meal tags are offered for food only', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // The screen opens on a food category, so the meal row is there.
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);

    // Chips carry the Bangla label (কসমেটিকস). Switch group, then pick the
    // face wash — the exact case from the report.
    final Finder grooming = find.text('কসমেটিকস');
    await tester.dragUntilVisible(
      grooming,
      find.byType(ListView).first,
      const Offset(-140, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(grooming);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ফেস ওয়াশ'));
    await tester.pumpAndSettle();

    expect(find.text('Breakfast'), findsNothing);
    expect(find.text('Lunch'), findsNothing);
    expect(find.text('Dinner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a period figure opens its own breakdown', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));

    // "This month" → month view: calendar plus every month so far.
    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(find.text('Where it went'), findsOneWidget);
    expect(find.text('MONTHS'), findsOneWidget);
    expect(find.text('October 2026'), findsWidgets);

    // Week: seven rows, including the days nothing was spent on.
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('nothing logged'), findsWidgets);

    // Year: the whole year at once.
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a calendar day opens the entries of that day', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();

    // The 31st is the last cell of October 2026 and has five entries.
    await tester.tap(find.text('31'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hall dinner'), findsOneWidget);
    expect(find.text('৳ 575'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day with a crowd of entries scrolls instead of overflowing', (
    WidgetTester tester,
  ) async {
    final AppState state = AppState.instance;
    await tester.runAsync(() async {
      for (int i = 0; i < 25; i++) {
        await state.addTransaction(
          type: EntryType.expense,
          amountMinor: 1000 + i,
          categoryId: 'rice',
          note: 'extra $i',
          occurredAt: DateTime(2026, 10, 31, 9),
        );
      }
    });
    await pumpAt(tester, const Size(390, 844));

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('31'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.textContaining('extra'), findsWidgets);
  });

  testWidgets('the licences page opens with this app and its dependencies', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    final Finder vertical = find.byWidgetPredicate(
      (Widget widget) =>
          widget is ListView && widget.scrollDirection == Axis.vertical,
    );
    await tester.drag(vertical.first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The actual terms are on screen, read from the bundle — not an empty page.
    expect(find.textContaining('PolyForm Noncommercial'), findsWidgets);

    // The font's licence is further down the same page.
    await tester.scrollUntilVisible(
      find.textContaining('SIL Open Font License'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('SIL Open Font License'), findsWidgets);
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

  testWidgets('the savings pot is off until asked for, then moves money', (
    WidgetTester tester,
  ) async {
    final AppState state = AppState.instance;
    expect(state.settings.savingsEnabled, isFalse);
    final int pocket = state.moneyOnHand;

    // Settings → Savings pot on.
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    final Finder settingsList = find
        .byWidgetPredicate(
          (Widget widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        )
        .first;
    await tester.dragUntilVisible(
      find.text('Savings pot'),
      settingsList,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    // The switch is the row's trailing widget; the text itself does not toggle.
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Savings pot'),
            matching: find.byType(SettingsRow),
          ),
          matching: find.byType(Switch),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(state.settings.savingsEnabled, isTrue);

    // Home now carries a savings row, and the pot takes money off the pocket.
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    expect(find.text('SAVINGS'), findsOneWidget, reason: 'the Home row');

    await tester.runAsync(
      () => state.addSavings(
        direction: SavingsDirection.aside,
        amountMinor: 100000,
        note: 'Leftover',
      ),
    );
    await tester.pumpAndSettle();
    // ৳ 1,000 in the wallet with ৳ 200 set aside leaves ৳ 800 spendable, and the
    // hero names all three: the spendable figure, SAVINGS beside it, and the
    // wallet total underneath.
    expect(state.moneyOnHand, pocket - 100000);
    expect(state.walletMinor, pocket);
    expect(state.savingsMinor, 100000);
    expect(find.text('SET ASIDE'), findsOneWidget);
    expect(find.textContaining('in your wallet'), findsOneWidget);
    // The month's Out is a fact about purchases and does not move.
    expect(find.textContaining('990'), findsWidgets);
  });

  testWidgets('the savings screen opens, sets money aside and takes it back', (
    WidgetTester tester,
  ) async {
    final AppState state = AppState.instance;
    await tester.runAsync(() => state.setSavingsEnabled(true));
    await pumpAt(tester, const Size(390, 844));

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    final Finder homeList = find
        .byWidgetPredicate(
          (Widget widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        )
        .first;
    await tester.dragUntilVisible(
      find.text('Nothing set aside'),
      homeList,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    // The row itself is the door; "Open" is shared with other sections.
    await tester.tap(find.text('Nothing set aside'));
    await tester.pumpAndSettle();
    expect(find.text('SET ASIDE'), findsOneWidget);

    // Set ৳ 500 aside through the sheet.
    await tester.tap(find.text('Set money aside'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savings_amount')), '500');
    await tester.pumpAndSettle();
    // The write goes to real SQLite, so it needs real time to finish.
    await tester.runAsync(() async {
      await tester.tap(find.text('Set aside'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(state.savingsMinor, 50000);
    expect(find.textContaining('500'), findsWidgets);

    // Take it all back.
    await tester.tap(find.text('Take money back'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savings_amount')), '500');
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Take back'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(state.savingsMinor, 0);
    expect(find.text('Nothing in the pot yet'), findsOneWidget);
  });
}
