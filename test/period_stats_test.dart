import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/store/app_state.dart';
import 'package:taka/utils/date_helpers.dart';
import 'package:taka/utils/period_stats.dart';

import 'support/seed.dart';

/// The period screens answer "how much did I spend on that day / week / month".
/// These are the numbers behind them, checked against the seeded ledger.
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
  });

  tearDown(() async {
    await database.close();
  });

  group('daily totals', () {
    test('a week has seven rows, empty days included', () {
      final DateTime start = startOfWeek(kTestNow);
      final List<DayTotal> days = dailyTotals(
        state.allEntries,
        from: start,
        toExclusive: start.add(const Duration(days: 7)),
      );

      expect(days.length, 7);
      expect(days.first.day, start);
      // The week runs Sunday 25 → Saturday 31 (kWeekStartsOnWeekday is Sunday).
      final Map<int, int> byDay = <int, int>{
        for (final DayTotal d in days) d.day.day: d.expenseMinor,
      };
      expect(byDay[25], 8500, reason: 'medicine on the 25th');
      expect(byDay[26], 0);
      expect(byDay[27], 18000);
      expect(byDay[28], 0);
      expect(byDay[29], 6000);
      expect(byDay[30], 9000);
      expect(byDay[31], 57500);
    });

    test('the week adds up to what Home calls "this week"', () {
      final DateTime start = startOfWeek(kTestNow);
      final int sum = dailyTotals(
        state.allEntries,
        from: start,
        toExclusive: start.add(const Duration(days: 7)),
      ).fold<int>(0, (int a, DayTotal d) => a + d.expenseMinor);

      expect(sum, state.week.expenseMinor);
      expect(sum, 99000);
    });

    test('income is kept apart from spending', () {
      final List<DayTotal> days = dailyTotals(
        state.allEntries,
        from: startOfMonth(kTestNow),
        toExclusive: startOfNextMonth(kTestNow),
      );
      final int spent = days.fold<int>(
        0,
        (int a, DayTotal d) => a + d.expenseMinor,
      );
      final int earned = days.fold<int>(
        0,
        (int a, DayTotal d) => a + d.incomeMinor,
      );
      expect(spent, 99000);
      expect(earned, 850000);
      expect(days.length, 31, reason: 'every day of October');
    });

    test('a day with nothing logged reports zero, not a missing row', () {
      final List<DayTotal> days = dailyTotals(
        state.allEntries,
        from: DateTime(2026, 10, 28),
        toExclusive: DateTime(2026, 10, 29),
      );
      expect(days.single.expenseMinor, 0);
      expect(days.single.isEmpty, isTrue);
    });
  });

  group('months and years', () {
    test('one month, with the days that actually have entries', () {
      final List<MonthTotal> months = monthlyTotals(
        state.allEntries,
        from: DateTime(2026, 10),
        to: DateTime(2026, 10),
      );
      expect(months.length, 1);
      expect(months.single.expenseMinor, 99000);
      expect(months.single.incomeMinor, 850000);
      expect(
        months.single.days,
        7,
        reason: 'spend on the 25/27/29/30/31 plus income on the 2nd and 18th',
      );
      expect(months.single.netMinor, 850000 - 99000);
    });

    test('months before the ledger start show zero, in order', () {
      final List<MonthTotal> months = monthlyTotals(
        state.allEntries,
        from: DateTime(2026, 8),
        to: DateTime(2026, 10),
      );
      expect(months.map((MonthTotal m) => m.month.month), <int>[8, 9, 10]);
      expect(months.first.expenseMinor, 0);
      expect(months.last.expenseMinor, 99000);
    });

    test('the month list starts where the history starts', () {
      expect(firstMonthOf(state.allEntries, kTestNow), DateTime(2026, 10));
      expect(
        firstMonthOf(const <TransactionEntry>[], kTestNow),
        DateTime(2026, 10),
      );
    });

    test('years are listed newest first', () {
      expect(yearsCovered(state.allEntries, kTestNow), <int>[2026]);
    });
  });

  group('a single day', () {
    test('lists that day newest first, and only that day', () {
      final List<TransactionEntry> entries = entriesOnDay(
        state.allEntries,
        DateTime(2026, 10, 31),
      );
      expect(entries.length, 5);
      expect(
        entries.map((TransactionEntry e) => e.occurredAt.hour).toList(),
        <int>[18, 18, 16, 13, 8],
        reason: 'newest first: 18:20, 18:00, 16:05, 13:40, 08:10',
      );
      expect(
        entries.fold<int>(
          0,
          (int sum, TransactionEntry e) => sum + e.amountMinor,
        ),
        57500,
      );
    });

    test('a day with no entries is empty, not an error', () {
      expect(entriesOnDay(state.allEntries, DateTime(2026, 10, 28)), isEmpty);
    });
  });
}
