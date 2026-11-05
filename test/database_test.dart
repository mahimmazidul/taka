import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taka/db/category_repository.dart';
import 'package:taka/db/database.dart';
import 'package:taka/db/settings_repository.dart';
import 'package:taka/db/savings_repository.dart';
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

  test('seeds the two-level category tree with Bangla labels', () async {
    final List<AppCategory> all = await categories.all();

    // Structural checks rather than magic numbers: the point is that every
    // group has items, every item knows its group, and nothing is orphaned.
    final List<AppCategory> groups = all
        .where((AppCategory c) => c.isGroup)
        .toList(growable: false);
    final List<AppCategory> items = all
        .where((AppCategory c) => !c.isGroup && c.parentId != null)
        .toList(growable: false);

    expect(groups.length, greaterThanOrEqualTo(15));
    expect(items.length, greaterThanOrEqualTo(80));
    for (final AppCategory group in groups) {
      expect(
        items.where((AppCategory c) => c.parentId == group.id),
        isNotEmpty,
        reason: '${group.id} should hold at least one item',
      );
    }
    for (final AppCategory item in items) {
      expect(
        groups.map((AppCategory g) => g.id),
        contains(item.parentId),
        reason: '${item.id} points at a missing group',
      );
    }

    final AppCategory rice = all.firstWhere((AppCategory c) => c.id == 'rice');
    expect(rice.nameBn, 'ভাত');
    expect(rice.label, 'ভাত');
    expect(rice.icon, 'rice');
    expect(rice.parentId, 'g_main');

    final AppCategory banana = all.firstWhere(
      (AppCategory c) => c.id == 'banana',
    );
    expect(banana.parentId, 'g_fruits');

    expect(
      all.map((AppCategory c) => c.id),
      containsAll(<String>['drinko', 'mojo', 'shampoo', 'sheet', 'pen', 'doi']),
    );
  });

  test('a v2 database migrates to groups without losing anything', () async {
    final String path = p.join(
      await databaseFactoryFfi.getDatabasesPath(),
      'migration-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    addTearDown(() async {
      await databaseFactoryFfi.deleteDatabase(path);
    });

    // ── build a v2 database by hand: flat categories, no meal column ─────────
    final Database legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              name_bn TEXT NOT NULL DEFAULT '',
              icon TEXT NOT NULL,
              color TEXT NOT NULL,
              kind TEXT NOT NULL,
              budget_minor INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              category_id TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              occurred_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE udhar_entries (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              person TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              occurred_at INTEGER NOT NULL,
              returned INTEGER NOT NULL DEFAULT 0,
              returned_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
          ''');
          await db.insert('categories', <String, Object?>{
            'id': 'rice',
            'name': 'Rice & meal',
            'name_bn': 'ভাত',
            'icon': 'rice',
            'color': '#E9A23B',
            'kind': 'expense',
            'budget_minor': 20000,
            'sort_order': 0,
          });
          await db.insert('categories', <String, Object?>{
            'id': 'other',
            'name': 'Other',
            'name_bn': 'অন্যান্য',
            'icon': 'other',
            'color': '#6B7684',
            'kind': 'expense',
            'sort_order': 99,
          });
        },
      ),
    );
    await legacy.insert('transactions', <String, Object?>{
      'id': 'old-entry',
      'type': 'expense',
      'amount_minor': 4500,
      'category_id': 'rice',
      'note': 'from v2',
      'occurred_at': DateTime(2026, 10, 30, 8).millisecondsSinceEpoch,
      'created_at': DateTime(2026, 10, 30, 8).millisecondsSinceEpoch,
      'updated_at': DateTime(2026, 10, 30, 8).millisecondsSinceEpoch,
    });
    await legacy.close();

    // ── reopen with the current code: onUpgrade + additive seeding run ───────
    final AppDatabase upgraded = AppDatabase.at(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(upgraded.close);

    final List<AppCategory> all = await CategoryRepository(database: upgraded)
        .all();
    final AppCategory rice = all.firstWhere((AppCategory c) => c.id == 'rice');

    expect(rice.parentId, 'g_main', reason: 'old row gains its group');
    expect(rice.nameBn, 'ভাত', reason: 'user-visible label untouched');
    expect(rice.budgetMinor, 20000, reason: 'user budgets survive the upgrade');
    expect(
      await CategoryRepository(database: upgraded).usageCount('rice'),
      1,
      reason: 'the old entry still points at the same category',
    );
    expect(all.length, greaterThan(90), reason: 'new items were added');

    // v6 → v7: the edible branches are flagged, so a new item added inside them
    // inherits "food" instead of being born meal-less.
    expect(
      all.firstWhere((AppCategory c) => c.id == 'g_main').isFood,
      isTrue,
      reason: 'Main course is an edible branch',
    );
    expect(
      all.firstWhere((AppCategory c) => c.id == 'g_hall').isFood,
      isFalse,
      reason: 'hall bills are not food',
    );

    // v7 → v8: the savings pot gets its own empty table. Nothing is migrated
    // into it — money saved before this version was never recorded as savings,
    // and guessing at it would invent a history.
    final SavingsRepository savings = SavingsRepository(database: upgraded);
    expect(await savings.all(), isEmpty);
    expect(await savings.balanceMinor(), 0);

    final TransactionEntry kept = (await TransactionRepository(
      database: upgraded,
    ).query(const TransactionQuery())).single;
    expect(kept.note, 'from v2');
    expect(kept.meal, isNull, reason: 'old rows simply have no meal tag');
  });

  test('a v4 database merges the duplicated egg and noodles rows', () async {
    final String path = p.join(
      await databaseFactoryFfi.getDatabasesPath(),
      'merge-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    addTearDown(() async {
      await databaseFactoryFfi.deleteDatabase(path);
    });

    // A v4 file, exactly as v1.3.0 shipped it: egg twice, noodles twice.
    final Database legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              name_bn TEXT NOT NULL DEFAULT '',
              icon TEXT NOT NULL,
              color TEXT NOT NULL,
              kind TEXT NOT NULL,
              budget_minor INTEGER,
              sort_order INTEGER NOT NULL DEFAULT 0,
              parent_id TEXT,
              is_group INTEGER NOT NULL DEFAULT 0,
              food INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              category_id TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              occurred_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              meal TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE udhar_entries (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              person TEXT NOT NULL,
              amount_minor INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              occurred_at INTEGER NOT NULL,
              returned INTEGER NOT NULL DEFAULT 0,
              returned_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          for (final List<Object?> row in <List<Object?>>[
            <Object?>['g_main', 'Main course', 0],
            <Object?>['g_snacks', 'Snacks', 1],
            <Object?>['egg', 'Egg', 0],
            <Object?>['egg_snack', 'Egg', 0],
            <Object?>['noodles', 'Noodles', 1],
            <Object?>['noodles_main', 'Noodles', 1],
          ]) {
            await db.insert('categories', <String, Object?>{
              'id': row[0],
              'name': row[1],
              'name_bn': row[1] as String,
              'icon': 'egg',
              'color': '#E9A23B',
              'kind': 'expense',
              'sort_order': 0,
              'parent_id': row[0] == 'g_main' || row[0] == 'g_snacks'
                  ? null
                  : (row[2] == 0 ? 'g_main' : 'g_snacks'),
              'is_group': row[0] == 'g_main' || row[0] == 'g_snacks' ? 1 : 0,
              'food': 1,
            });
          }
        },
      ),
    );
    await legacy.insert('transactions', <String, Object?>{
      'id': 'dup-1',
      'type': 'expense',
      'amount_minor': 2000,
      'category_id': 'egg_snack',
      'note': 'two eggs with cha',
      'occurred_at': DateTime(2026, 10, 20, 9).millisecondsSinceEpoch,
      'created_at': DateTime(2026, 10, 20, 9).millisecondsSinceEpoch,
      'updated_at': DateTime(2026, 10, 20, 9).millisecondsSinceEpoch,
    });
    await legacy.close();

    final AppDatabase upgraded = AppDatabase.at(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(upgraded.close);

    final List<AppCategory> all = await CategoryRepository(database: upgraded)
        .all();

    expect(
      all.where((AppCategory c) => c.id == 'egg_snack'),
      isEmpty,
      reason: 'the duplicate row is gone',
    );
    expect(
      all.where((AppCategory c) => c.id == 'noodles_main'),
      isEmpty,
      reason: 'the duplicate row is gone',
    );

    final AppCategory egg = all.firstWhere((AppCategory c) => c.id == 'egg');
    expect(egg.alsoGroups, <String>['g_snacks']);

    final List<TransactionEntry> kept = await TransactionRepository(
      database: upgraded,
    ).query(const TransactionQuery());
    expect(
      kept.single.categoryId,
      'egg',
      reason: 'the entry moved to the original category, not lost',
    );
    expect(kept.single.amountMinor, 2000);
  });

  test('insert, update and delete a transaction', () async {
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 31, 9),
      ),
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
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: day.add(const Duration(hours: 9)),
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 3000,
        at: day.add(const Duration(hours: 14)),
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.income,
        amountMinor: 50000,
        at: day.add(const Duration(hours: 10)),
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 99900,
        at: day.subtract(const Duration(days: 2)),
      ),
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
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 25, 8),
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 12000,
        at: DateTime(2026, 10, 31, 20),
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.income,
        amountMinor: 50000,
        at: DateTime(2026, 10, 31, 21),
      ),
    );

    final List<DailyTotal> series = await transactions.dailySeries(
      DateTime(2026, 10, 25),
      7,
    );

    expect(series.length, 7);
    expect(series.first.expenseMinor, 4500);
    expect(series.last.expenseMinor, 12000);
    expect(series.last.incomeMinor, 50000);
  });

  test('history filters: type, category, note search and date range', () async {
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 31, 8),
        note: 'canteen rice',
      ),
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
      (await transactions.query(const TransactionQuery(type: EntryType.income)))
          .length,
      1,
    );
    expect(
      (await transactions.query(
        const TransactionQuery(categoryId: 'cosmetics'),
      )).length,
      1,
    );
    expect(
      (await transactions.query(const TransactionQuery(search: 'canteen')))
          .length,
      1,
    );
    expect(
      (await transactions.query(
        TransactionQuery(
          from: DateTime(2026, 10, 29),
          toExclusive: DateTime(2026, 11, 1),
        ),
      )).length,
      2,
    );
    // newest first
    final List<TransactionEntry> all = await transactions.query(
      const TransactionQuery(),
    );
    expect(all.first.note, 'canteen rice');
  });

  test('monthly spend per category feeds the budget bars', () async {
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 3),
        categoryId: 'rice',
      ),
    );
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 5000,
        at: DateTime(2026, 10, 4),
        categoryId: 'rice',
      ),
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
    expect(
      all.firstWhere((AppCategory c) => c.id == 'rice').budgetMinor,
      2000000,
    );
  });

  test('deleting a category moves entries to Other', () async {
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 31),
        categoryId: 'rice',
      ),
    );
    expect(await categories.usageCount('rice'), 1);

    await categories.reassignAndDelete(
      fromCategoryId: 'rice',
      toCategoryId: 'other',
    );

    expect(await categories.usageCount('rice'), 0);
    expect((await transactions.recent()).single.categoryId, 'other');
  });

  test('udhar outstanding totals ignore settled records', () async {
    final DateTime now = DateTime(2026, 10, 31, 12);
    UdharEntry record(UdharType type, int amount, bool returned, String id) =>
        UdharEntry(
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

    await settings.write(
      const AppSettings(darkMode: true, monthlyBudgetMinor: 3000000),
    );
    final AppSettings stored = await settings.read();
    expect(stored.darkMode, isTrue);
    expect(stored.monthlyBudgetMinor, 3000000);
  });

  test('backup JSON round-trips through the parser', () async {
    await transactions.insert(
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 31, 8),
        note: 'canteen',
      ),
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
      entry(
        type: EntryType.expense,
        amountMinor: 4500,
        at: DateTime(2026, 10, 31, 8),
        note: 'rice, dal',
      ),
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
