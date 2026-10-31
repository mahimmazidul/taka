import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/constants/default_categories.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/db/transaction_repository.dart';
import 'package:taka/models/app_category.dart';
import 'package:taka/models/meal_slot.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/store/app_state.dart';

import 'support/seed.dart';

/// The bug this file exists for: a face wash was offered breakfast, lunch and
/// dinner, and its money then showed up under "meals for today". Meal tags are
/// only meaningful for food, so the rule is asserted here rather than assumed.
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

  AppCategory seeded(String id) =>
      kDefaultCategories.firstWhere((AppCategory c) => c.id == id);

  group('the seed tree', () {
    test('food groups carry food items only', () {
      const List<String> foodGroups = <String>[
        'g_main',
        'g_drinks',
        'g_snacks',
        'g_sweets',
      ];
      for (final AppCategory item in kDefaultCategories) {
        if (!foodGroups.contains(item.parentId)) continue;
        expect(
          item.isFood,
          isTrue,
          reason: '${item.id} sits in a food group but is not flagged',
        );
      }
    });

    test('grooming, study and transport are never food', () {
      const List<String> notFood = <String>[
        'cosmetics',
        'shampoo',
        'soap',
        'khata',
        'books',
        'laundry',
        'rickshaw',
        'medicine',
      ];
      for (final String id in notFood) {
        expect(seeded(id).isFood, isFalse, reason: '$id must not take a meal');
      }
    });

    test('eating out is food, groups never are', () {
      expect(seeded('eatout').isFood, isTrue);
      for (final AppCategory category in kDefaultCategories) {
        if (!category.isGroup) continue;
        expect(category.isFood, isFalse, reason: '${category.id} is a group');
      }
    });

    test('egg and noodles are listed twice but stored once', () {
      final AppCategory egg = seeded('egg');
      final AppCategory noodles = seeded('noodles');

      // One row each: one id, one total, one thing to budget.
      expect(egg.parentId, 'g_main');
      expect(egg.alsoGroups, <String>['g_snacks']);
      expect(noodles.parentId, 'g_snacks');
      expect(noodles.alsoGroups, <String>['g_main']);

      expect(egg.listedIn('g_main'), isTrue);
      expect(egg.listedIn('g_snacks'), isTrue);
      expect(noodles.listedIn('g_snacks'), isTrue);
      expect(noodles.listedIn('g_main'), isTrue);

      // The v1.3.0 duplicates are gone for good.
      expect(
        kDefaultCategories.where((AppCategory c) => c.id == 'egg_snack'),
        isEmpty,
      );
      expect(
        kDefaultCategories.where((AppCategory c) => c.id == 'noodles_main'),
        isEmpty,
      );
    });

    test('the picker lists a shared item under each of its groups', () {
      final List<String> snacks = state
          .childrenOf('g_snacks')
          .map((AppCategory c) => c.id)
          .toList();
      final List<String> main = state
          .childrenOf('g_main')
          .map((AppCategory c) => c.id)
          .toList();

      expect(snacks, contains('egg'));
      expect(main, contains('egg'));
      expect(snacks, contains('noodles'));
      expect(main, contains('noodles'));
      expect(snacks.toSet().length, snacks.length, reason: 'no duplicate rows');
      expect(main.toSet().length, main.length, reason: 'no duplicate rows');
    });

    test('spending on egg is one number, not two', () async {
      await state.addTransaction(
        type: EntryType.expense,
        amountMinor: 2000,
        categoryId: 'egg',
        note: 'two eggs',
        occurredAt: kTestNow,
      );
      expect(state.monthSpend['egg'], 2000);
      // It rolls into both groups it is listed under, and still once into the
      // month's total.
      expect(state.spendOf('g_main'), greaterThanOrEqualTo(2000));
      expect(state.spendOf('g_snacks'), greaterThanOrEqualTo(2000));
      // Listed in two groups, counted once in the month: 99,000 seeded + 2,000.
      expect(
        state.monthSpend.values.fold<int>(0, (int a, int b) => a + b),
        101000,
      );
      expect(state.month.expenseMinor, 101000);
    });

    test('every item points at a real group, and ids are unique', () {
      final Set<String> groups = kDefaultCategories
          .where((AppCategory c) => c.isGroup)
          .map((AppCategory c) => c.id)
          .toSet();
      final Set<String> ids = <String>{};
      for (final AppCategory c in kDefaultCategories) {
        expect(ids.add(c.id), isTrue, reason: 'duplicate id ${c.id}');
        if (c.parentId != null) {
          expect(groups.contains(c.parentId), isTrue, reason: c.id);
        }
      }
    });
  });

  group('acceptsMeal', () {
    test('true for food items, false for everything else', () {
      expect(state.acceptsMeal('rice'), isTrue);
      expect(state.acceptsMeal('egg'), isTrue);
      expect(state.acceptsMeal('noodles'), isTrue);
      expect(state.acceptsMeal('cosmetics'), isFalse);
      expect(state.acceptsMeal('khata'), isFalse);
      expect(state.acceptsMeal('g_main'), isFalse, reason: 'a group');
      expect(state.acceptsMeal(null), isFalse);
      expect(state.acceptsMeal('does-not-exist'), isFalse);
    });
  });

  group('meal money', () {
    test('a cosmetic entry never lands in a meal slot', () async {
      // Old rows (or an old build) could store a meal on anything. The flag,
      // not the stored tag, decides where the money is counted.
      await TransactionRepository(database: database).insert(
        TransactionEntry(
          id: 'bad-shampoo',
          type: EntryType.expense,
          amountMinor: 25000,
          categoryId: 'shampoo',
          note: 'Face wash with a bogus meal tag',
          occurredAt: DateTime(2026, 10, 31, 9),
          createdAt: DateTime(2026, 10, 31, 9),
          updatedAt: DateTime(2026, 10, 31, 9),
          meal: MealSlot.breakfast,
        ),
      );
      await state.refresh();

      final Map<MealSlot, int> meals = state.mealSpendToday;
      expect(meals[MealSlot.breakfast], 4500, reason: 'rice only');
      expect(meals[MealSlot.lunch], 12000);
      expect(meals[MealSlot.dinner], 6000);

      final int mealSum = meals.values.fold<int>(0, (int a, int b) => a + b);
      expect(mealSum, 4500 + 12000 + 6000);
      // …but the money is still spent today, just not attributed to a meal.
      expect(
        state.today.expenseMinor,
        4500 + 12000 + 32000 + 3000 + 6000 + 25000,
      );
      expect(mealSum, lessThan(state.today.expenseMinor));
    });

    test('meal totals add up to the food entries of the day', () async {
      final List<TransactionEntry> foodToday = state.allEntries
          .where(
            (TransactionEntry e) =>
                state.acceptsMeal(e.categoryId) &&
                e.isExpense &&
                e.occurredAt.day == 31,
          )
          .toList();
      final int expected = foodToday.fold<int>(
        0,
        (int sum, TransactionEntry e) => sum + e.amountMinor,
      );
      final int actual = state.mealSpendToday.values.fold<int>(
        0,
        (int a, int b) => a + b,
      );
      expect(actual, expected);
    });
  });

  group('daily counter', () {
    test('today counts only today, and resets at midnight', () async {
      // Seeded on the 31st: 4,500 + 12,000 + 32,000 + 3,000 + 6,000.
      expect(state.today.expenseMinor, 57500);
      expect(state.today.incomeMinor, 0);

      // Same ledger, read one minute after midnight: today must be empty while
      // nothing was deleted.
      final AppState afterMidnight = AppState(
        transactions: state.transactions,
        categories: state.categoryRepo,
        udhar: state.udharRepo,
        settings: state.settingsRepo,
        clock: () => DateTime(2026, 11, 1, 0, 5),
      );
      await afterMidnight.load();

      expect(
        afterMidnight.today.expenseMinor,
        0,
        reason: 'a new day starts at 0',
      );
      expect(
        afterMidnight.month.expenseMinor,
        0,
        reason: 'November is new too',
      );
      expect(afterMidnight.allTime.expenseMinor, 99000, reason: 'nothing lost');
    });

    test('week and month bracket the seeded month', () {
      // Mon 26 Oct – Sun 1 Nov 2026 contains the 31st.
      expect(state.week.expenseMinor, greaterThan(0));
      expect(
        state.month.expenseMinor,
        57500 + 5000 + 4000 + 6000 + 18000 + 8500,
        reason: 'the 31st, 30th, 29th, 27th and 25th',
      );
      expect(state.month.incomeMinor, 600000 + 250000);
    });
  });
}
