import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/store/app_state.dart';
import 'package:taka/store/data_actions.dart';

import 'support/seed.dart';

/// Two promises this file guards:
///
/// 1. A month does not wipe the slate. Money that was never spent is still
///    spendable on the 1st, and the nudge maths has to know it.
/// 2. Search finds an entry wherever it is — in any month, by note, or by the
///    English or Bangla name of its category.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    AppClock.now = () => kTestNow;
  });

  late AppDatabase database;
  late AppState state;

  setUp(() async {
    database = AppDatabase.inMemory(factory: databaseFactoryFfi);
    state = await buildSeededState(database: database);
    AppState.instance = state;
  });

  tearDown(() async {
    await database.close();
  });

  group('carry-over', () {
    test('nothing before the month means nothing carried', () {
      // The seed starts in October and "now" is October.
      expect(state.carryIntoMonth(kTestNow), 0);
    });

    test('last month’s leftover money is still available this month', () async {
      // September: 5,000 in, 3,000 out → 2,000 left over.
      await state.transactions.insert(
        TransactionEntry(
          id: 'sep-in',
          type: EntryType.income,
          amountMinor: 500000,
          categoryId: 'home_money',
          note: 'September',
          occurredAt: DateTime(2026, 9, 2, 11),
          createdAt: DateTime(2026, 9, 2, 11),
          updatedAt: DateTime(2026, 9, 2, 11),
        ),
      );
      await state.transactions.insert(
        TransactionEntry(
          id: 'sep-out',
          type: EntryType.expense,
          amountMinor: 300000,
          categoryId: 'rice',
          note: 'September food',
          occurredAt: DateTime(2026, 9, 20, 13),
          createdAt: DateTime(2026, 9, 20, 13),
          updatedAt: DateTime(2026, 9, 20, 13),
        ),
      );
      await state.refresh();

      expect(state.carryIntoMonth(kTestNow), 200000);
      // Available = carried + this month's income − this month's spend, which is
      // exactly the net of everything up to now.
      final int allTimeNet = state.allEntries.fold<int>(
        0,
        (int sum, TransactionEntry e) =>
            sum + (e.isExpense ? -e.amountMinor : e.amountMinor),
      );
      expect(state.availableThisMonth, allTimeNet);
    });

    test('overspending last month carries a negative, never a bonus', () async {
      await state.transactions.insert(
        TransactionEntry(
          id: 'sep-out',
          type: EntryType.expense,
          amountMinor: 100000,
          categoryId: 'rice',
          note: 'September food',
          occurredAt: DateTime(2026, 9, 28, 13),
          createdAt: DateTime(2026, 9, 28, 13),
          updatedAt: DateTime(2026, 9, 28, 13),
        ),
      );
      await state.refresh();
      expect(state.carryIntoMonth(kTestNow), -100000);
    });
  });

  // A separate, empty ledger: the story below is about one allowance arriving at
  // the end of a month, and it should read as itself rather than as a delta
  // against the seeded month.
  group('the real case', () {
    // An empty pocket: the seeded month is wiped, so the numbers below are the
    // story itself rather than a delta against someone else's spending.
    late AppState pocket;

    setUp(() async {
      await state.clearAllData();
      pocket = AppState.instance;
    });

    test('money that arrived on 30 October is still there on 1 November', () async {
      // Allowance lands late in the month, some of it is spent the same day,
      // and the rest has to survive the calendar.
      await pocket.transactions.insert(
        TransactionEntry(
          id: 'oct-allowance',
          type: EntryType.income,
          amountMinor: 500000,
          categoryId: 'home_money',
          note: 'Bari theke, 30 October',
          occurredAt: DateTime(2026, 10, 30, 11),
          createdAt: DateTime(2026, 10, 30, 11),
          updatedAt: DateTime(2026, 10, 30, 11),
        ),
      );
      await pocket.transactions.insert(
        TransactionEntry(
          id: 'oct-spend',
          type: EntryType.expense,
          amountMinor: 120000,
          categoryId: 'rice',
          note: 'Canteen, 30 October',
          occurredAt: DateTime(2026, 10, 30, 13),
          createdAt: DateTime(2026, 10, 30, 13),
          updatedAt: DateTime(2026, 10, 30, 13),
        ),
      );
      await pocket.refresh();

      // On 1 November nothing has come in yet this month, but the pocket is not
      // empty: 5,000 in, 1,200 out on the 30th, so 3,800 is carried.
      final DateTime nov1 = DateTime(2026, 11, 1, 9);
      expect(pocket.carryIntoMonth(nov1), 380000);

      // The old mistake: the month's own net is zero, so a "balance" built from
      // it would read ৳0 on the 1st. The number on Home is built from the
      // carry-over instead.
      final int novemberNet = -(await pocket.transactions.totals(
        DateTime(2026, 11),
        DateTime(2026, 12),
      )).netMinor;
      expect(novemberNet, 0, reason: 'nothing logged in November yet');

      // And once November starts spending, it comes out of the carried money.
      await pocket.transactions.insert(
        TransactionEntry(
          id: 'nov-spend',
          type: EntryType.expense,
          amountMinor: 50000,
          categoryId: 'rice',
          note: 'Canteen, 1 November',
          occurredAt: DateTime(2026, 11, 1, 10),
          createdAt: DateTime(2026, 11, 1, 10),
          updatedAt: DateTime(2026, 11, 1, 10),
        ),
      );
      await state.refresh();
      final int available =
          state.carryIntoMonth(nov1) +
          (await state.transactions.totals(
            DateTime(2026, 11),
            DateTime(2026, 12),
          )).incomeMinor -
          (await state.transactions.totals(
            DateTime(2026, 11),
            DateTime(2026, 12),
          )).expenseMinor;
      expect(available, 330000, reason: '3,800 carried minus 500 spent');
    });

    test('two months of leftovers both carry, and a month with no money kept', () async {
      // September leaves 1,000; October brings 2,000 and spends 500.
      await pocket.transactions.insert(
        TransactionEntry(
          id: 'sep-in',
          type: EntryType.income,
          amountMinor: 100000,
          categoryId: 'home_money',
          note: 'September',
          occurredAt: DateTime(2026, 9, 3, 11),
          createdAt: DateTime(2026, 9, 3, 11),
          updatedAt: DateTime(2026, 9, 3, 11),
        ),
      );
      await pocket.transactions.insert(
        TransactionEntry(
          id: 'oct-in',
          type: EntryType.income,
          amountMinor: 200000,
          categoryId: 'home_money',
          note: 'October',
          occurredAt: DateTime(2026, 10, 30, 11),
          createdAt: DateTime(2026, 10, 30, 11),
          updatedAt: DateTime(2026, 10, 30, 11),
        ),
      );
      await pocket.transactions.insert(
        TransactionEntry(
          id: 'oct-out',
          type: EntryType.expense,
          amountMinor: 50000,
          categoryId: 'rice',
          note: 'October',
          occurredAt: DateTime(2026, 10, 31, 13),
          createdAt: DateTime(2026, 10, 31, 13),
          updatedAt: DateTime(2026, 10, 31, 13),
        ),
      );
      await pocket.refresh();

      // November inherits everything not spent before it: 1,000 + 2,000 − 500.
      expect(pocket.carryIntoMonth(DateTime(2026, 11, 1)), 250000);
      // December inherits nothing extra if November neither earns nor spends.
      expect(pocket.carryIntoMonth(DateTime(2026, 12, 1)), 250000);
    });
  });

  group('the clock', () {
    test('a new day reloads, the same day does not touch the database', () async {
      // The stored numbers belong to 31 October.
      expect(state.today.expenseMinor, 57500);

      // Same day: a resume must not re-read the ledger, and totals stay as they
      // were even if the file changed behind our back.
      await state.transactions.insert(
        TransactionEntry(
          id: 'sneaky',
          type: EntryType.expense,
          amountMinor: 100,
          categoryId: 'rice',
          note: 'not loaded yet',
          occurredAt: kTestNow,
          createdAt: kTestNow,
          updatedAt: kTestNow,
        ),
      );
      await state.refreshIfDayChanged();
      expect(state.today.expenseMinor, 57500);

      // Next day: the app is opened on 1 November and the totals move with it.
      AppClock.now = () => DateTime(2026, 11, 1, 9);
      addTearDown(() => AppClock.now = () => kTestNow);
      await state.refreshIfDayChanged();
      expect(
        state.today.expenseMinor,
        0,
        reason: 'nothing spent on 1 November',
      );
      expect(state.month.expenseMinor, 0);
    });
  });

  group('search', () {
    test('an empty query returns everything, newest first', () {
      expect(state.filterEntries().length, state.allEntries.length);
    });

    test('finds an entry by its note, in any month', () async {
      await state.transactions.insert(
        TransactionEntry(
          id: 'old',
          type: EntryType.expense,
          amountMinor: 5000,
          categoryId: 'rice',
          note: 'Cha and singara with Rifat',
          occurredAt: DateTime(2026, 3, 4, 17),
          createdAt: DateTime(2026, 3, 4, 17),
          updatedAt: DateTime(2026, 3, 4, 17),
        ),
      );
      await state.refresh();

      final List<TransactionEntry> found = state.filterEntries(search: 'rifat');
      expect(found.length, 1);
      expect(found.single.id, 'old');
    });

    test('matches the English name of the category', () {
      // Every seeded food entry, found by typing the English category name.
      final List<TransactionEntry> rice = state.filterEntries(search: 'rice');
      expect(rice, isNotEmpty);
      expect(
        rice.every((TransactionEntry e) => e.categoryId == 'rice'),
        isTrue,
      );
    });

    test('matches the Bangla name of the category', () {
      final List<TransactionEntry> byBangla = state.filterEntries(
        search: 'ভাত',
      );
      expect(byBangla, isNotEmpty);
      expect(
        byBangla.every((TransactionEntry e) => e.categoryId == 'rice'),
        isTrue,
      );
    });

    test('case does not matter and nothing is matched by accident', () {
      expect(state.filterEntries(search: 'RIFAT'), isEmpty);
      expect(state.filterEntries(search: 'zzzz'), isEmpty);
    });
  });
}
