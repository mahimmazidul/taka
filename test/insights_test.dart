import 'package:flutter_test/flutter_test.dart';
import 'package:taka/constants/default_categories.dart';
import 'package:taka/models/app_category.dart';
import 'package:taka/models/meal_slot.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/services/update_checker.dart';
import 'package:taka/utils/insights.dart';

TransactionEntry _e({
  required String id,
  required String categoryId,
  required DateTime at,
  int minor = 1000,
  MealSlot? meal,
  bool income = false,
}) {
  return TransactionEntry(
    id: id,
    type: income ? EntryType.income : EntryType.expense,
    amountMinor: minor,
    categoryId: categoryId,
    occurredAt: at,
    note: '',
    meal: meal,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  final List<AppCategory> categories = kDefaultCategories;

  group('missedMeals', () {
    test('counts a day as missed only when nothing was logged', () {
      // Fri 2 Oct, 20:00 — breakfast and lunch have passed, dinner has not.
      final DateTime now = DateTime(2026, 10, 2, 20);
      final List<TransactionEntry> entries = <TransactionEntry>[
        _e(
          id: 'a',
          categoryId: 'rice',
          at: DateTime(2026, 10, 1, 8),
          meal: MealSlot.breakfast,
        ),
        _e(
          id: 'b',
          categoryId: 'rice',
          at: DateTime(2026, 10, 2, 8),
          meal: MealSlot.breakfast,
        ),
      ];
      final List<MealGap> gaps = missedMeals(
        entries,
        categories,
        from: DateTime(2026, 10),
        toExclusive: DateTime(2026, 11),
        now: now,
      );
      final MealGap breakfast = gaps.firstWhere(
        (MealGap g) => g.slot == MealSlot.breakfast,
      );
      final MealGap lunch = gaps.firstWhere(
        (MealGap g) => g.slot == MealSlot.lunch,
      );
      final MealGap dinner = gaps.firstWhere(
        (MealGap g) => g.slot == MealSlot.dinner,
      );

      expect(breakfast.days, 2);
      expect(breakfast.missedDays, 0);
      expect(lunch.missedDays, 2, reason: 'no lunch logged either day');
      // Dinner at 20:00 today is not over yet, so today does not count.
      expect(dinner.days, 1);
      expect(dinner.missedDays, 1);
    });

    test('a non-food entry never counts as a meal', () {
      final DateTime now = DateTime(2026, 10, 2, 23);
      final List<TransactionEntry> entries = <TransactionEntry>[
        // Face wash at breakfast time, tagged breakfast by hand.
        _e(
          id: 'a',
          categoryId: 'toiletries',
          at: DateTime(2026, 10, 1, 8),
          meal: MealSlot.breakfast,
        ),
      ];
      final List<MealGap> gaps = missedMeals(
        entries,
        categories,
        from: DateTime(2026, 10),
        toExclusive: DateTime(2026, 11),
        now: now,
      );
      final MealGap breakfast = gaps.firstWhere(
        (MealGap g) => g.slot == MealSlot.breakfast,
      );
      expect(breakfast.loggedDays, 0);
      expect(breakfast.missedDays, breakfast.days);
    });

    test('income is ignored', () {
      final DateTime now = DateTime(2026, 10, 2, 23);
      final List<TransactionEntry> entries = <TransactionEntry>[
        _e(
          id: 'a',
          categoryId: 'rice',
          at: DateTime(2026, 10, 1, 13),
          meal: MealSlot.lunch,
          income: true,
        ),
      ];
      final List<MealGap> gaps = missedMeals(
        entries,
        categories,
        from: DateTime(2026, 10),
        toExclusive: DateTime(2026, 11),
        now: now,
      );
      expect(
        gaps.firstWhere((MealGap g) => g.slot == MealSlot.lunch).loggedDays,
        0,
      );
    });
  });

  group('topSpending', () {
    test('adds up per category, biggest first, expenses only', () {
      final List<TransactionEntry> entries = <TransactionEntry>[
        _e(id: 'a', categoryId: 'rice', at: DateTime(2026, 10, 1), minor: 3000),
        _e(id: 'b', categoryId: 'rice', at: DateTime(2026, 10, 2), minor: 2000),
        _e(id: 'c', categoryId: 'tea', at: DateTime(2026, 10, 3), minor: 6000),
        _e(
          id: 'd',
          categoryId: 'allowance',
          at: DateTime(2026, 10, 4),
          minor: 90000,
          income: true,
        ),
        _e(id: 'e', categoryId: 'tea', at: DateTime(2026, 11, 1), minor: 999),
      ];
      final List<CategorySpend> rows = topSpending(
        entries,
        categories,
        from: DateTime(2026, 10),
        toExclusive: DateTime(2026, 11),
      );

      expect(rows.length, 2);
      expect(rows.first.category.id, 'tea');
      expect(rows.first.amountMinor, 6000);
      expect(rows.first.entries, 1);
      expect(rows.last.category.id, 'rice');
      expect(rows.last.amountMinor, 5000);
      expect(rows.last.entries, 2);
    });
  });

  group('monthRhythm', () {
    test('counts quiet days and finds the biggest one', () {
      final List<TransactionEntry> entries = <TransactionEntry>[
        _e(
          id: 'a',
          categoryId: 'rice',
          at: DateTime(2026, 10, 1, 13),
          minor: 4000,
        ),
        _e(
          id: 'b',
          categoryId: 'rice',
          at: DateTime(2026, 10, 3, 13),
          minor: 9000,
        ),
      ];
      final MonthRhythm rhythm = monthRhythm(
        entries,
        from: DateTime(2026, 10),
        toExclusive: DateTime(2026, 11),
        now: DateTime(2026, 10, 4, 20),
      );
      expect(rhythm.days, 4);
      expect(rhythm.noSpendDays, 2);
      expect(rhythm.totalMinor, 13000);
      expect(rhythm.averagePerDay, 3250);
      expect(rhythm.biggestDay!.day.day, 3);
    });
  });

  group('isNewerVersion', () {
    test('compares numbers, not strings', () {
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
      expect(isNewerVersion('1.4.1', '1.4.0'), isTrue);
      expect(isNewerVersion('1.4.0', '1.4.0'), isFalse);
      expect(isNewerVersion('1.3.9', '1.4.0'), isFalse);
      expect(isNewerVersion('2.0', '1.99.99'), isTrue);
      expect(isNewerVersion('v1.5.0', '1.4.0'), isTrue);
    });
  });
}
