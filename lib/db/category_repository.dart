import 'package:sqflite/sqflite.dart';

import '../models/app_category.dart';
import 'database.dart';

/// Reads and edits the `categories` table (expense categories + income sources).
class CategoryRepository {
  CategoryRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const String _table = 'categories';

  Future<List<AppCategory>> all() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      orderBy: 'kind ASC, sort_order ASC, name ASC',
    );
    return rows.map(AppCategory.fromMap).toList(growable: false);
  }

  Future<void> upsert(AppCategory category) async {
    final Database db = await _database.database;
    await db.insert(
      _table,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setMonthlyBudget(String categoryId, int? budgetMinor) async {
    final Database db = await _database.database;
    await db.update(
      _table,
      <String, Object?>{'budget_minor': budgetMinor},
      where: 'id = ?',
      whereArgs: <Object?>[categoryId],
    );
  }

  /// How many transactions reference this category, so the UI can offer
  /// "move them to Other" instead of silently orphaning the ledger.
  Future<int> usageCount(String categoryId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM transactions WHERE category_id = ?',
      <Object?>[categoryId],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<void> delete(String categoryId) async {
    final Database db = await _database.database;
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[categoryId]);
  }

  /// Moves entries to a fallback category, then deletes the original.
  Future<void> reassignAndDelete({
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.update(
        'transactions',
        <String, Object?>{'category_id': toCategoryId},
        where: 'category_id = ?',
        whereArgs: <Object?>[fromCategoryId],
      );
      await txn.delete(
        _table,
        where: 'id = ?',
        whereArgs: <Object?>[fromCategoryId],
      );
    });
  }

  Future<int> nextSortOrder(CategoryKind kind) async {
    final List<AppCategory> rows = await all();
    final Iterable<AppCategory> same = rows.where(
      (AppCategory c) => c.kind == kind,
    );
    if (same.isEmpty) return 0;
    return same
            .map((AppCategory c) => c.sortOrder)
            .reduce((int a, int b) => a > b ? a : b) +
        1;
  }
}
