import 'package:sqflite/sqflite.dart';

import '../models/period_totals.dart';
import '../models/transaction_entry.dart';
import 'database.dart';

/// Optional filter bundle for the history screen.
class TransactionQuery {
  const TransactionQuery({
    this.type,
    this.categoryId,
    this.categoryIds,
    this.search,
    this.from,
    this.toExclusive,
    this.limit,
  });

  final EntryType? type;
  final String? categoryId;

  /// Filter to a whole group: the group is not loggable, but its items are, so
  /// "show me all food" is a single tap.
  final Set<String>? categoryIds;
  final String? search;
  final DateTime? from;
  final DateTime? toExclusive;
  final int? limit;
}

/// All reads/writes for `transactions`. Widgets never touch SQL directly.
class TransactionRepository {
  TransactionRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const String _table = 'transactions';

  Future<void> insert(TransactionEntry entry) async {
    final Database db = await _database.database;
    await db.insert(_table, entry.toMap());
  }

  Future<void> update(TransactionEntry entry) async {
    final Database db = await _database.database;
    await db.update(
      _table,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[entry.id],
    );
  }

  Future<void> delete(String id) async {
    final Database db = await _database.database;
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deleteAll() async {
    final Database db = await _database.database;
    await db.delete(_table);
  }

  Future<List<TransactionEntry>> recent({int limit = 5}) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      orderBy: 'occurred_at DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(TransactionEntry.fromMap).toList(growable: false);
  }

  Future<List<TransactionEntry>> inRange(
    DateTime from,
    DateTime toExclusive, {
    int? limit,
  }) async {
    return query(
      TransactionQuery(from: from, toExclusive: toExclusive, limit: limit),
    );
  }

  /// Filtered, newest-first query used by History.
  Future<List<TransactionEntry>> query(TransactionQuery q) async {
    final Database db = await _database.database;
    final List<String> where = <String>[];
    final List<Object?> args = <Object?>[];

    if (q.type != null) {
      where.add('type = ?');
      args.add(q.type!.dbValue);
    }
    if (q.categoryId != null) {
      where.add('category_id = ?');
      args.add(q.categoryId);
    }
    final Set<String>? ids = q.categoryIds;
    if (ids != null && ids.isNotEmpty) {
      final String marks = List<String>.filled(ids.length, '?').join(', ');
      where.add('category_id IN ($marks)');
      args.addAll(ids);
    }
    if (q.search != null && q.search!.trim().isNotEmpty) {
      where.add('note LIKE ?');
      args.add('%${q.search!.trim()}%');
    }
    if (q.from != null) {
      where.add('occurred_at >= ?');
      args.add(q.from!.millisecondsSinceEpoch);
    }
    if (q.toExclusive != null) {
      where.add('occurred_at < ?');
      args.add(q.toExclusive!.millisecondsSinceEpoch);
    }

    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'occurred_at DESC, created_at DESC',
      limit: q.limit,
    );
    return rows.map(TransactionEntry.fromMap).toList(growable: false);
  }

  Future<PeriodTotals> totals(DateTime from, DateTime toExclusive) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT type, SUM(amount_minor) AS total FROM $_table '
      'WHERE occurred_at >= ? AND occurred_at < ? GROUP BY type',
      <Object?>[
        from.millisecondsSinceEpoch,
        toExclusive.millisecondsSinceEpoch,
      ],
    );

    int expense = 0;
    int income = 0;
    for (final Map<String, Object?> row in rows) {
      final int total = (row['total'] as int?) ?? 0;
      if (row['type'] == 'income') {
        income = total;
      } else {
        expense = total;
      }
    }
    return PeriodTotals(expenseMinor: expense, incomeMinor: income);
  }

  /// Month-to-date expense per category — the input of budget progress.
  Future<Map<String, int>> expenseByCategory(
    DateTime from,
    DateTime toExclusive,
  ) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT category_id, SUM(amount_minor) AS total FROM $_table '
      "WHERE type = 'expense' AND occurred_at >= ? AND occurred_at < ? "
      'GROUP BY category_id',
      <Object?>[
        from.millisecondsSinceEpoch,
        toExclusive.millisecondsSinceEpoch,
      ],
    );

    final Map<String, int> result = <String, int>{};
    for (final Map<String, Object?> row in rows) {
      result[row['category_id']! as String] = (row['total'] as int?) ?? 0;
    }
    return result;
  }

  /// Buckets entries into whole days, oldest day first.
  Future<List<DailyTotal>> dailySeries(DateTime firstDay, int dayCount) async {
    final DateTime from = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final DateTime to = from.add(Duration(days: dayCount));

    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      columns: <String>['type', 'amount_minor', 'occurred_at'],
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: <Object?>[
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
    );

    final List<int> expense = List<int>.filled(dayCount, 0);
    final List<int> income = List<int>.filled(dayCount, 0);

    for (final Map<String, Object?> row in rows) {
      final DateTime moment = DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at']! as int,
      );
      final int index = DateTime(
        moment.year,
        moment.month,
        moment.day,
      ).difference(from).inDays;
      if (index < 0 || index >= dayCount) continue;
      final int amount = (row['amount_minor'] as int?) ?? 0;
      if (row['type'] == 'income') {
        income[index] += amount;
      } else {
        expense[index] += amount;
      }
    }

    return List<DailyTotal>.generate(
      dayCount,
      (int index) => DailyTotal(
        day: from.add(Duration(days: index)),
        expenseMinor: expense[index],
        incomeMinor: income[index],
      ),
      growable: false,
    );
  }

  Future<int> countAll() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $_table',
    );
    return (rows.first['count'] as int?) ?? 0;
  }
}
