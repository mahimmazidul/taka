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

  /// A database at an explicit path. Tests use it to open a *file*, close it and
  /// reopen it, which is the only way to exercise `onUpgrade` and the additive
  /// seeding that protects a user's data across versions.
  factory AppDatabase.at({
    required DatabaseFactory factory,
    required String path,
  }) => AppDatabase._internal(factory, path);

  static const String _fileName = 'taka.db';
  static const int _version = 3;

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
        onOpen: _seedMissingCategories,
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
        sort_order INTEGER NOT NULL DEFAULT 0,
        parent_id TEXT,
        is_group INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('CREATE INDEX idx_cat_parent ON categories(parent_id)');

    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('expense', 'income')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
        note TEXT NOT NULL DEFAULT '',
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        meal TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_tx_occurred ON transactions(occurred_at DESC)',
    );
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
      batch.execute(
        "ALTER TABLE categories ADD COLUMN name_bn TEXT NOT NULL DEFAULT ''",
      );

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
        '🍚': 'rice',
        '🚌': 'bus',
        '🧾': 'wifi',
        '🛍️': 'shirt',
        '💊': 'medicine',
        '🎬': 'movie',
        '📦': 'other',
        '💼': 'salary',
        '🏪': 'salary',
        '💻': 'laptop',
        '🎁': 'gift',
        '➕': 'income_other',
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

    if (oldVersion < 3) {
      await _upgradeToGroups(db);
    }
  }

  /// v2 → v3: two-level categories plus meal tags.
  ///
  /// Nothing is dropped and no transaction is rewritten. Existing rows simply
  /// gain a parent (rice → Main course, cosmetics → Grooming…), the new items
  /// are inserted, and every old entry keeps pointing at the same id — which is
  /// the whole reason those ids were never renamed.
  Future<void> _upgradeToGroups(Database db) async {
    // Idempotent on purpose: an interrupted upgrade (or a database restored from
    // a backup mid-way) must not leave the app unable to open its own file.
    await _addColumnIfMissing(db, 'categories', 'parent_id', 'TEXT');
    await _addColumnIfMissing(
      db,
      'categories',
      'is_group',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'transactions', 'meal', 'TEXT');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cat_parent ON categories(parent_id)',
    );

    // Groups first, then reparent what already exists, then add what is new.
    final Batch groups = db.batch();
    for (final AppCategory category in kDefaultCategories) {
      if (category.isGroup) {
        groups.insert(
          'categories',
          category.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await groups.commit(noResult: true);

    final Batch links = db.batch();
    for (final AppCategory category in kDefaultCategories) {
      final String? parentId = category.parentId;
      if (parentId == null) continue;
      links.update(
        'categories',
        <String, Object?>{'parent_id': parentId},
        where: 'id = ? AND parent_id IS NULL AND is_group = 0',
        whereArgs: <Object?>[category.id],
      );
    }
    await links.commit(noResult: true);

    await _seedMissingCategories(db);
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final List<Map<String, Object?>> info = await db.rawQuery(
      'PRAGMA table_info($table)',
    );
    if (info.any((Map<String, Object?> c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Inserts any seeded category the database does not have yet.
  ///
  /// Runs on **every** open, not just on a version bump, so a future release can
  /// ship new categories (or whole new groups) without touching the schema and
  /// without ever overwriting a name, colour, icon or limit the user changed.
  Future<void> _seedMissingCategories(Database db) async {
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      columns: <String>['id'],
    );
    final Set<String> present = rows
        .map((Map<String, Object?> row) => row['id']! as String)
        .toSet();

    final Batch batch = db.batch();
    int added = 0;
    for (final AppCategory category in kDefaultCategories) {
      if (present.contains(category.id)) continue;
      // A child whose parent was deleted on an older build would be orphaned;
      // fall back to the top level so it stays usable.
      batch.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      added++;
    }
    if (added > 0) await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
