import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import 'database.dart';

/// Key/value settings store. Absent keys fall back to [AppSettings] defaults.
class SettingsRepository {
  SettingsRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const String _table = 'settings';

  Future<AppSettings> read() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(_table);

    final Map<String, String> values = <String, String>{};
    for (final Map<String, Object?> row in rows) {
      values[row['key']! as String] = row['value']! as String;
    }
    return AppSettings.fromMap(values);
  }

  /// Upserts every key of [settings] in one transaction.
  Future<void> write(AppSettings settings) async {
    final Database db = await _database.database;
    final Map<String, String> values = settings.toMap();
    await db.transaction((Transaction txn) async {
      for (final MapEntry<String, String> entry in values.entries) {
        await txn.insert(_table, <String, Object?>{
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
