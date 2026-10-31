import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/default_categories.dart';
import '../models/app_category.dart';

/// Owns the single SQLite file, its schema and its migrations.
class AppDatabase {
  AppDatabase._internal(this._factory, this._path);

  /// Real app database: a file in the platform's private database directory.
  static final AppDatabase instance = AppDatabase._internal(null, null);

  /// Throwaway database for tests — same schema and seeds, nothing on disk.
  factory AppDatabase.inMemory({required DatabaseFactory factory}) =>
      AppDatabase._internal(factory, ':memory:');

  static const String _fileName = 'taka.db';
  static const int _version = 2;

  final DatabaseFactory? _factory;
  final String? _path;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final DatabaseFactory factory = _factory ?? databaseFactory;
    final String path =
        _path ?? p.join(await factory.getDatabasesPath(), _fileName);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    final Batch batch = db.batch();

    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        name_bn TEXT NOT NULL DEFAULT '',
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('expense', 'income')),
        budget_minor INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('expense', 'income')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
        note TEXT NOT NULL DEFAULT '',
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_tx_occurred ON transactions(occurred_at DESC)');
    batch.execute('CREATE INDEX idx_tx_category ON transactions(category_id)');

    batch.execute('''
      CREATE TABLE udhar_entries (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('lent', 'borrowed')),
        person TEXT NOT NULL,
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        note TEXT NOT NULL DEFAULT '',
        occurred_at INTEGER NOT NULL,
        returned INTEGER NOT NULL DEFAULT 0,
        returned_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_udhar_returned ON udhar_entries(returned)');

    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    for (final AppCategory category in kDefaultCategories) {
      batch.insert('categories', category.toMap());
    }

    await batch.commit(noResult: true);
  }

  /// v1 → v2: Bangla labels plus the granular hall-life category set.
  /// Non-destructive: existing rows are relabelled, new ones are inserted.
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final Batch batch = db.batch();
      batch.execute("ALTER TABLE categories ADD COLUMN name_bn TEXT NOT NULL DEFAULT ''");

      const Map<String, String> banglaByOldId = <String, String>{
        'food': 'খাবার',
        'transport': 'যাতায়াত',
        'bills': 'বিল',
        'shopping': 'কেনাকাটা',
        'health': 'ওষুধ',
        'entertainment': 'বিনোদন',
        'other': 'অন্যান্য',
        'salary': 'বেতন',
        'business': 'ব্যবসা',
        'freelance': 'ফ্রিল্যান্স',
        'gift': 'উপহার',
        'other_income': 'অন্যান্য',
      };
      const Map<String, String> iconByOldEmoji = <String, String>{
        '🍚': 'rice', '🚌': 'bus', '🧾': 'wifi', '🛍️': 'shirt', '💊': 'medicine',
        '🎬': 'movie', '📦': 'other', '💼': 'salary', '🏪': 'salary',
        '💻': 'laptop', '🎁': 'gift', '➕': 'income_other',
      };

      banglaByOldId.forEach((String id, String bn) {
        batch.update(
          'categories',
          <String, Object?>{'name_bn': bn},
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      });
      iconByOldEmoji.forEach((String emoji, String key) {
        batch.update(
          'categories',
          <String, Object?>{'icon': key},
          where: 'icon = ?',
          whereArgs: <Object?>[emoji],
        );
      });

      for (final AppCategory category in kDefaultCategories) {
        batch.insert(
          'categories',
          category.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
