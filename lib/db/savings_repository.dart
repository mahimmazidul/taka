import 'package:sqflite/sqflite.dart';

import '../models/savings_entry.dart';
import 'database.dart';

/// The savings pot: movements in and out, and the balance they add up to.
///
/// One table, no joins, no link to `transactions` — the whole point of the pot
/// is that saved money is *not* spent money.
class SavingsRepository {
  SavingsRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const String _table = 'savings';

  /// Newest first, which is the order the history list shows.
  Future<List<SavingsEntry>> all() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      orderBy: 'occurred_at DESC, created_at DESC',
    );
    return rows.map(SavingsEntry.fromMap).toList(growable: false);
  }

  Future<void> insert(SavingsEntry entry) async {
    final Database db = await _database.database;
    await db.insert(_table, entry.toMap());
  }

  Future<void> delete(String id) async {
    final Database db = await _database.database;
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deleteAll() async {
    final Database db = await _database.database;
    await db.delete(_table);
  }

  /// Everything set aside minus everything taken back, in minor units.
  ///
  /// Computed in SQL so the number on screen never depends on a list that a
  /// screen happened to load.
  Future<int> balanceMinor() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT direction, SUM(amount_minor) AS total FROM $_table '
      'GROUP BY direction',
    );
    int balance = 0;
    for (final Map<String, Object?> row in rows) {
      final int total = (row['total'] as int?) ?? 0;
      balance += row['direction'] == 'back' ? -total : total;
    }
    return balance;
  }
}
