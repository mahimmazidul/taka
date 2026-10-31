import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/db/category_repository.dart';
import 'package:taka/db/database.dart';
import 'package:taka/db/settings_repository.dart';
import 'package:taka/db/transaction_repository.dart';
import 'package:taka/db/udhar_repository.dart';
import 'package:taka/models/app_category.dart';
import 'package:taka/models/app_settings.dart';
import 'package:taka/models/period_totals.dart';
import 'package:taka/models/transaction_entry.dart';
import 'package:taka/models/udhar_entry.dart';
import 'package:taka/utils/export_data.dart';

/// Exercises the real schema and the real SQL against an in-memory database.
void main() {
  late AppDatabase database;
  late TransactionRepository transactions;
  late CategoryRepository categories;
  late UdharRepository udhar;
  late SettingsRepository settings;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = AppDatabase.inMemory(factory: databaseFactoryFfi);
    transactions = TransactionRepository(database: database);
    categories = CategoryRepository(database: database);
    udhar = UdharRepository(database: database);
    settings = SettingsRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  TransactionEntry entry({
    required EntryType type,
    required int amountMinor,
    required DateTime at,
    String categoryId = 'rice',
    String note = 'test',
  }) {
    final DateTime now = DateTime(2026, 10, 31, 12);
    return TransactionEntry(
      id: 'id-${at.millisecondsSinceEpoch}-$amountMinor-${type.name}',
      type: type,
      amountMinor: amountMinor,
      categoryId: categoryId,
      note: note,
      occurredAt: at,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('seeds hall-life categories with Bangla labels', () async {
    final List<AppCategory> all = await categories.all();
    expect(all.length, 22);
    expect(all.where((AppCategory c) => c.kind == CategoryKind.expense).length, 16);
    expect(all.where((AppCategory c) => c.kind == CategoryKind.income).length, 6);

    final AppCategory rice = all.firstWhere((AppCategory c) => c.id == 'rice');
    expect(rice.nameBn, 'ভাত');
    expect(rice.label, 'ভাত');
    expect(rice.icon, 'rice');

    expect(all.map((AppCategory c) => c.id), containsAll(<String>[
      'fish', 'cosmetics', 'laundry', 'snacks', 'medicine', 'other',
    ]));
  });

  test('insert, update and delete a transaction', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 31, 9)),
    );
    expect((await transactions.recent()).length, 1);

    final TransactionEntry saved = (await transactions.recent()).single;
    await transactions.update(saved.copyWith(amountMinor: 5500));
    expect((await transactions.recent()).single.amountMinor, 5500);

    await transactions.delete(saved.id);
    expect(await transactions.recent(), isEmpty);
  });

  test('totals group by type inside the window', () async {
    final DateTime day = DateTime(2026, 10, 31);
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: day.add(const Duration(hours: 9))),
    );
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 3000, at: day.add(const Duration(hours: 14))),
    );
    await transactions.insert(
      entry(type: EntryType.income, amountMinor: 50000, at: day.add(const Duration(hours: 10))),
    );
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 99900, at: day.subtract(const Duration(days: 2))),
    );

    final PeriodTotals totals = await transactions.totals(
      DateTime(2026, 10, 31),
      DateTime(2026, 11, 1),
    );

    expect(totals.expenseMinor, 7500);
    expect(totals.incomeMinor, 50000);
    expect(totals.netMinor, 42500);
  });

  test('dailySeries buckets entries per day, oldest first', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 25, 8)),
    );
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 12000, at: DateTime(2026, 10, 31, 20)),
    );
    await transactions.insert(
      entry(type: EntryType.income, amountMinor: 50000, at: DateTime(2026, 10, 31, 21)),
    );

    final List<DailyTotal> series = await transactions.dailySeries(DateTime(2026, 10, 25), 7);

    expect(series.length, 7);
    expect(series.first.expenseMinor, 4500);
    expect(series.last.expenseMinor, 12000);
    expect(series.last.incomeMinor, 50000);
  });

  test('history filters: type, category, note search and date range', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 31, 8), note: 'canteen rice'),
    );
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 32000,
        at: DateTime(2026, 10, 30, 16),
        categoryId: 'cosmetics',
        note: 'face wash',
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.income,
        amountMinor: 250000,
        at: DateTime(2026, 10, 18, 17),
        categoryId: 'tuition',
        note: 'two students',
      ),
    );

    expect((await transactions.query(const TransactionQuery())).length, 3);
    expect(
      (await transactions.query(const TransactionQuery(type: EntryType.income))).length,
      1,
    );
    expect(
      (await transactions.query(const TransactionQuery(categoryId: 'cosmetics'))).length,
      1,
    );
    expect(
      (await transactions.query(const TransactionQuery(search: 'canteen'))).length,
      1,
    );
    expect(
      (await transactions.query(
        TransactionQuery(from: DateTime(2026, 10, 29), toExclusive: DateTime(2026, 11, 1)),
      ))
          .length,
      2,
    );
    // newest first
    final List<TransactionEntry> all = await transactions.query(const TransactionQuery());
    expect(all.first.note, 'canteen rice');
  });

  test('monthly spend per category feeds the budget bars', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 3), categoryId: 'rice'),
    );
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 5000, at: DateTime(2026, 10, 4), categoryId: 'rice'),
    );
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 32000,
        at: DateTime(2026, 10, 5),
        categoryId: 'cosmetics',
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.income,
        amountMinor: 250000,
        at: DateTime(2026, 10, 5),
        categoryId: 'tuition',
      ),
    );

    final Map<String, int> spent = await transactions.expenseByCategory(
      DateTime(2026, 10, 1),
      DateTime(2026, 11, 1),
    );

    expect(spent['rice'], 9500);
    expect(spent['cosmetics'], 32000);
    expect(spent.containsKey('tuition'), isFalse);
  });

  test('category budgets persist', () async {
    await categories.setMonthlyBudget('rice', 2000000);
    final List<AppCategory> all = await categories.all();
    expect(all.firstWhere((AppCategory c) => c.id == 'rice').budgetMinor, 2000000);
  });

  test('deleting a category moves entries to Other', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 31), categoryId: 'rice'),
    );
    expect(await categories.usageCount('rice'), 1);

    await categories.reassignAndDelete(fromCategoryId: 'rice', toCategoryId: 'other');

    expect(await categories.usageCount('rice'), 0);
    expect((await transactions.recent()).single.categoryId, 'other');
  });

  test('udhar outstanding totals ignore settled records', () async {
    final DateTime now = DateTime(2026, 10, 31, 12);
    UdharEntry record(UdharType type, int amount, bool returned, String id) => UdharEntry(
          id: id,
          type: type,
          person: 'Rahim',
          amountMinor: amount,
          note: '',
          occurredAt: now,
          returned: returned,
          returnedAt: returned ? now : null,
          createdAt: now,
          updatedAt: now,
        );

    await udhar.insert(record(UdharType.lent, 150000, false, 'a'));
    await udhar.insert(record(UdharType.lent, 20000, true, 'b'));
    await udhar.insert(record(UdharType.borrowed, 50000, false, 'c'));

    final UdharTotals totals = await udhar.outstandingTotals();
    expect(totals.lentMinor, 150000);
    expect(totals.borrowedMinor, 50000);
    expect(totals.netMinor, 100000);

    await udhar.setReturned('a', returned: true);
    expect((await udhar.outstandingTotals()).lentMinor, 0);
  });

  test('settings default when empty and persist when written', () async {
    expect((await settings.read()).currencySymbol, '৳');

    await settings.write(const AppSettings(darkMode: true, monthlyBudgetMinor: 3000000));
    final AppSettings stored = await settings.read();
    expect(stored.darkMode, isTrue);
    expect(stored.monthlyBudgetMinor, 3000000);
  });

  test('backup JSON round-trips through the parser', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 31, 8), note: 'canteen'),
    );
    final List<AppCategory> cats = await categories.all();
    final String json = buildBackupJson(
      settings: const AppSettings(darkMode: true),
      categories: cats,
      transactions: await transactions.query(const TransactionQuery()),
      udhar: await udhar.all(),
    );

    final ImportBundle bundle = parseBackupJson(json);
    expect(bundle.transactions.single.note, 'canteen');
    expect(bundle.transactions.single.amountMinor, 4500);
    expect(bundle.categories.length, cats.length);
    expect(bundle.settings.darkMode, isTrue);
  });

  test('CSV export has a header and one row per entry', () async {
    await transactions.insert(
      entry(type: EntryType.expense, amountMinor: 4500, at: DateTime(2026, 10, 31, 8), note: 'rice, dal'),
    );
    final String csv = buildLedgerCsv(
      transactions: await transactions.query(const TransactionQuery()),
      categories: await categories.all(),
    );
    final List<String> lines = csv.trim().split('\n');
    expect(lines.first, 'date,type,amount_bdt,category,category_bn,note');
    expect(lines.length, 2);
    expect(lines.last, contains('45.00'));
    expect(lines.last, contains('rice, dal'));
  });
}
