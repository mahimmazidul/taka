import 'package:taka/core/clock.dart';
import 'package:taka/db/category_repository.dart';
import 'package:taka/db/database.dart';
import 'package:taka/db/settings_repository.dart';
import 'package:taka/db/transaction_repository.dart';
import 'package:taka/db/udhar_repository.dart';
import 'package:taka/models/meal_slot.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/models/udhar_entry.dart';
import 'package:taka/store/app_state.dart';

/// Fixed "now" so tests never depend on the real clock.
final DateTime kTestNow = DateTime(2026, 10, 31, 18, 30);

/// An AppState backed by an in-memory database with one believable month of
/// hall-student spending.
Future<AppState> buildSeededState({required AppDatabase database}) async {
  final TransactionRepository transactions = TransactionRepository(
    database: database,
  );
  final CategoryRepository categories = CategoryRepository(database: database);
  final UdharRepository udhar = UdharRepository(database: database);
  final SettingsRepository settings = SettingsRepository(database: database);

  Future<void> add(
    EntryType type,
    String categoryId,
    int amountMinor,
    DateTime at,
    String note, {
    MealSlot? meal,
  }) {
    return transactions.insert(
      TransactionEntry(
        id: '${at.millisecondsSinceEpoch}-$categoryId',
        type: type,
        amountMinor: amountMinor,
        categoryId: categoryId,
        note: note,
        occurredAt: at,
        createdAt: at,
        updatedAt: at,
        meal: meal,
      ),
    );
  }

  // Income this month
  await add(
    EntryType.income,
    'home_money',
    600000,
    DateTime(2026, 10, 2, 11),
    'Bari theke',
  );
  await add(
    EntryType.income,
    'tuition',
    250000,
    DateTime(2026, 10, 18, 17),
    'Two students',
  );

  // Hall life: rice, fish, cosmetics, laundry, transport…
  await add(
    EntryType.expense,
    'rice',
    4500,
    DateTime(2026, 10, 31, 8, 10),
    'Hall canteen',
    meal: MealSlot.breakfast,
  );
  await add(
    EntryType.expense,
    'fish',
    12000,
    DateTime(2026, 10, 31, 13, 40),
    'Rupali 250g',
    meal: MealSlot.lunch,
  );
  await add(
    EntryType.expense,
    'shampoo',
    32000,
    DateTime(2026, 10, 31, 16, 5),
    'Body wash + shampoo',
  );
  await add(
    EntryType.expense,
    'rickshaw',
    3000,
    DateTime(2026, 10, 31, 18, 0),
    'Rickshaw to campus',
  );
  await add(
    EntryType.expense,
    'khichuri',
    6000,
    DateTime(2026, 10, 31, 18, 20),
    'Hall dinner',
    meal: MealSlot.dinner,
  );
  await add(
    EntryType.expense,
    'rice',
    5000,
    DateTime(2026, 10, 30, 8, 20),
    'Lunch',
  );
  await add(
    EntryType.expense,
    'snacks',
    4000,
    DateTime(2026, 10, 30, 17, 0),
    'Cha + singara',
  );
  await add(
    EntryType.expense,
    'laundry',
    6000,
    DateTime(2026, 10, 29, 10, 30),
    'Weekly wash',
  );
  await add(
    EntryType.expense,
    'books',
    18000,
    DateTime(2026, 10, 27, 15, 0),
    'Photocopy + khata',
  );
  await add(
    EntryType.expense,
    'medicine',
    8500,
    DateTime(2026, 10, 25, 20, 15),
    'Napa + ORS',
  );

  // Budgets: one group cap, one healthy item, one blown item
  await categories.setMonthlyBudget('g_main', 50000);
  await categories.setMonthlyBudget('shampoo', 20000);
  await categories.setMonthlyBudget('fish', 30000);

  // Udhar both ways
  await udhar.insert(
    UdharEntry(
      id: 'u1',
      type: UdharType.lent,
      person: 'Rahim',
      amountMinor: 150000,
      note: 'Bike repair',
      occurredAt: DateTime(2026, 10, 22),
      returned: false,
      createdAt: kTestNow,
      updatedAt: kTestNow,
    ),
  );
  await udhar.insert(
    UdharEntry(
      id: 'u2',
      type: UdharType.borrowed,
      person: 'Karim',
      amountMinor: 50000,
      note: 'Mess bill',
      occurredAt: DateTime(2026, 10, 26),
      returned: false,
      createdAt: kTestNow,
      updatedAt: kTestNow,
    ),
  );

  final AppState state = AppState(
    transactions: transactions,
    categories: categories,
    udhar: udhar,
    settings: settings,
    clock: () => AppClock.now(),
  );
  await state.load();
  return state;
}
