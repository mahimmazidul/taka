import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/store/app_state.dart';

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
