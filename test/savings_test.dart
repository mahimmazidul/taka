import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/constants/default_categories.dart';
import 'package:taka/core/clock.dart';
import 'package:taka/db/database.dart';
import 'package:taka/models/app_category.dart';
import 'package:taka/models/meal_slot.dart';
import 'package:taka/models/savings_entry.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/store/app_state.dart';
import 'package:taka/store/savings_actions.dart';

import 'support/seed.dart';

/// Saving is not spending.
///
/// The pot takes money out of the pocket without ever appearing in In/Out,
/// budgets or Patterns — the same rule udhar follows, in the other direction.
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
    // The pot is off until the user asks for it, so the tests ask.
    await state.setSavingsEnabled(true);
  });

  tearDown(() async {
    await database.close();
  });

  group('the pot', () {
    test('starts empty and moves money out of the pocket', () async {
      expect(state.savingsMinor, 0);
      final int before = state.moneyOnHand;

      await state.addSavings(
        direction: SavingsDirection.aside,
        amountMinor: 200000,
        note: 'October leftover',
      );

      expect(state.savingsMinor, 200000);
      expect(state.moneyOnHand, before - 200000);
      // The month's own arithmetic is untouched: this was not a purchase.
      expect(state.month.expenseMinor, 99000);
      expect(state.availableThisMonth, 751000);
    });

    test('taking money back puts it in the pocket again', () async {
      await state.addSavings(
        direction: SavingsDirection.aside,
        amountMinor: 300000,
      );
      await state.addSavings(
        direction: SavingsDirection.back,
        amountMinor: 50000,
        note: 'Books',
      );

      expect(state.savingsMinor, 250000);
      expect(state.savingsEntries.length, 2);
      // Newest first, so the take-back is on top.
      expect(state.savingsEntries.first.direction, SavingsDirection.back);
    });

    test(
      'a pot bigger than the pocket is allowed but shows as it is',
      () async {
        // Spend everything, then set money aside that is not there: the app records
        // what the user says rather than blocking it, and money on hand goes
        // negative instead of pretending.
        await state.addSavings(
          direction: SavingsDirection.aside,
          amountMinor: 900000,
        );
        expect(state.savingsMinor, 900000);
        expect(state.moneyOnHand, lessThan(0));
      },
    );

    test('removing a movement reverses it exactly', () async {
      await state.addSavings(
        direction: SavingsDirection.aside,
        amountMinor: 100000,
      );
      final String id = state.savingsEntries.single.id;
      await state.deleteSavings(id);

      expect(state.savingsMinor, 0);
      expect(state.moneyOnHand, 651000, reason: 'back to the seed pocket');
    });

    test(
      'turning the pot off hides it and returns the money to the pocket',
      () async {
        await state.addSavings(
          direction: SavingsDirection.aside,
          amountMinor: 100000,
        );
        expect(state.moneyOnHand, 551000);

        await state.setSavingsEnabled(false);
        expect(state.savingsMinor, 0, reason: 'not shown, not subtracted');
        expect(state.moneyOnHand, 651000);

        // The rows are still in the database; turning it back on restores them.
        await state.setSavingsEnabled(true);
        expect(state.savingsMinor, 100000);
      },
    );

    test('savings and udhar both correct the pocket, independently', () async {
      await state.addSavings(
        direction: SavingsDirection.aside,
        amountMinor: 100000,
      );
      // Seed: 8,500 in − 990 out − 1,500 lent + 500 borrowed − 1,000 saved.
      expect(state.moneyOnHand, 551000);
      expect(state.udharAdjustmentMinor, -100000);
      expect(state.savingsMinor, 100000);
    });
  });

  group('the goal', () {
    test('is optional, and can be cleared', () async {
      expect(state.settings.savingsGoalMinor, isNull);

      await state.setSavingsGoal(amountMinor: 500000, label: 'Laptop');
      expect(state.settings.savingsGoalMinor, 500000);
      expect(state.settings.savingsGoalLabel, 'Laptop');

      await state.setSavingsGoal();
      expect(state.settings.savingsGoalMinor, isNull);
      expect(state.settings.savingsGoalLabel, isNull);
    });

    test('survives a reload', () async {
      await state.setSavingsGoal(amountMinor: 250000, label: 'Trip');
      await state.refresh();
      expect(state.settings.savingsGoalMinor, 250000);
      expect(state.settings.savingsGoalLabel, 'Trip');
    });
  });

  group('groceries', () {
    test('মুদি sits on the top row and is not a meal', () {
      final AppCategory groceries = kDefaultCategories.firstWhere(
        (AppCategory category) => category.id == 'groceries',
      );
      expect(groceries.nameBn, 'মুদি');
      expect(groceries.parentId, isNull, reason: 'one tap from the top row');
      expect(groceries.isFood, isFalse);
      expect(groceries.isGroup, isFalse);
      expect(state.acceptsMeal('groceries'), isFalse);
    });

    test('a sauce bought for the room still shows up in the month', () async {
      final Map<MealSlot, int> mealsBefore = Map<MealSlot, int>.of(
        state.mealSpendToday,
      );
      await state.addTransaction(
        type: EntryType.expense,
        amountMinor: 12000,
        categoryId: 'groceries',
        note: 'Tomato sauce',
        occurredAt: kTestNow,
      );
      expect(state.monthSpend['groceries'], 12000);
      expect(state.month.expenseMinor, 99000 + 12000);
      // …but nowhere in today's meals.
      expect(state.mealSpendToday, mealsBefore);
    });
  });
}
