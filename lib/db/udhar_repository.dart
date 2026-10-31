import 'package:sqflite/sqflite.dart';

import '../models/udhar_entry.dart';
import 'database.dart';

/// Lend/borrow records. Kept separate from `transactions`: udhar is not
/// spending until it stays unreturned.
class UdharRepository {
  UdharRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const String _table = 'udhar_entries';

  Future<List<UdharEntry>> all({bool includeReturned = true}) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: includeReturned ? null : 'returned = 0',
      orderBy: 'returned ASC, occurred_at DESC',
    );
    return rows.map(UdharEntry.fromMap).toList(growable: false);
  }

  Future<void> insert(UdharEntry entry) async {
    final Database db = await _database.database;
    await db.insert(_table, entry.toMap());
  }

  Future<void> update(UdharEntry entry) async {
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

  Future<void> setReturned(String id, {required bool returned}) async {
    final Database db = await _database.database;
    await db.update(
      _table,
      <String, Object?>{
        'returned': returned ? 1 : 0,
        'returned_at': returned ? DateTime.now().millisecondsSinceEpoch : null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Outstanding totals only — settled records are excluded.
  Future<UdharTotals> outstandingTotals() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT type, SUM(amount_minor) AS total FROM $_table '
      'WHERE returned = 0 GROUP BY type',
    );

    int lent = 0;
    int borrowed = 0;
    for (final Map<String, Object?> row in rows) {
      final int total = (row['total'] as int?) ?? 0;
      if (row['type'] == 'borrowed') {
        borrowed = total;
      } else {
        lent = total;
      }
    }
    return UdharTotals(lentMinor: lent, borrowedMinor: borrowed);
  }
}
