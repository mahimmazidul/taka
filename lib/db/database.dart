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
  static const int _version = 9;

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
        is_group INTEGER NOT NULL DEFAULT 0,
        food INTEGER NOT NULL DEFAULT 0,
        also_groups TEXT
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
      CREATE TABLE savings (
        id TEXT PRIMARY KEY,
        direction TEXT NOT NULL CHECK(direction IN ('aside', 'back')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        note TEXT NOT NULL DEFAULT '',
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_savings_occurred ON savings(occurred_at)');

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
    // Every column addition happens first, before anything that writes a seed
    // row: the seed map carries every column the current version knows about, so
    // adding a column at the end of this method makes a v2 file try to insert a
    // column that does not exist yet. Learned twice — once for `food`, once for
    // `also_groups`.
    if (oldVersion < 4) {
      await _addColumnIfMissing(
        db,
        'categories',
        'food',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'categories', 'also_groups', 'TEXT');
    }

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

    if (oldVersion < 4) {
      await _upgradeToFood(db);
    }

    if (oldVersion < 5) {
      await _upgradeToAlsoGroups(db);
    }

    if (oldVersion < 6) {
      await _upgradeToEatoutGroup(db);
    }

    if (oldVersion < 7) {
      await _upgradeFoodGroups(db);
    }

    if (oldVersion < 9) {
      await _upgradeGroceriesGroup(db);
    }

    if (oldVersion < 8) {
      // The savings pot. A separate table on purpose: saved money is not spent
      // money, so it must never enter the transactions ledger.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS savings (
          id TEXT PRIMARY KEY,
          direction TEXT NOT NULL CHECK(direction IN ('aside', 'back')),
          amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
          note TEXT NOT NULL DEFAULT '',
          occurred_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_savings_occurred ON savings(occurred_at)',
      );
    }
  }

  /// v8 → v9: মুদি grows a sub-list.
  ///
  /// v1.10.0 shipped Groceries as a single item, and a single item can only ever
  /// say "৳ 120 groceries". It is a group now — sauce, oil, salt, noodles — so an
  /// existing database flips the row from leaf to container. Its own history is
  /// untouched: entries logged against `groceries` before this still belong to
  /// that row, and a group rollup picks them up with the items.
  Future<void> _upgradeGroceriesGroup(Database db) async {
    await db.update(
      'categories',
      <String, Object?>{'is_group': '1', 'food': '0'},
      where: 'id = ?',
      whereArgs: <Object?>['groceries'],
    );
  }

  /// v6 → v7: the edible groups are marked edible.
  ///
  /// `food` used to be set per item only, so a category added under Main course by
  /// hand was born non-food: no meal chips on the Add screen, and no line in
  /// today's meals. The groups are flagged now and new items inherit the flag;
  /// this marks the seeded ones so an existing database behaves the same way as a
  /// fresh install.
  Future<void> _upgradeFoodGroups(Database db) async {
    const List<String> foodGroups = <String>[
      'g_main',
      'g_drinks',
      'g_snacks',
      'g_sweets',
      'g_fruits',
      'g_eatout',
    ];
    for (final String id in foodGroups) {
      await db.update(
        'categories',
        <String, Object?>{'food': 1},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    }

    // And repair the items already added by hand inside those groups: they were
    // stored with food = 0, which is why a home-made "ভর্তা" showed no meal chips
    // and never appeared in today's meals.
    await db.rawUpdate(
      "UPDATE categories SET food = 1 "
      "WHERE is_group = 0 AND parent_id IN "
      "('g_main', 'g_drinks', 'g_snacks', 'g_sweets', 'g_fruits', 'g_eatout')",
    );
  }

  /// v5 → v6: "Dining out" becomes a group with fast food inside it.
  ///
  /// The old top-level row keeps its id and label and simply gains a parent, so
  /// every entry logged before this version still reads the way it did. The new
  /// group and its items are inserted by the usual additive seeding on open.
  Future<void> _upgradeToEatoutGroup(Database db) async {
    await db.update(
      'categories',
      <String, Object?>{'parent_id': 'g_eatout'},
      where: 'id = ? AND parent_id IS NULL',
      whereArgs: <Object?>['eatout'],
    );
  }

  /// v4 → v5: an item can be listed under more than one group.
  ///
  /// v1.3.0 shipped egg and noodles twice — once in snacks, once in the main
  /// course — as two categories. That split the spend in half and made "how much
  /// did I spend on egg?" answer with two numbers. The duplicates are merged
  /// back into the original item here, entries included, and the one row is
  /// listed in both groups from now on.
  Future<void> _upgradeToAlsoGroups(Database db) async {
    const Map<String, String> duplicateToOriginal = <String, String>{
      'egg_snack': 'egg',
      'noodles_main': 'noodles',
    };
    for (final MapEntry<String, String> pair in duplicateToOriginal.entries) {
      final List<Map<String, Object?>> rows = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: <Object?>[pair.key],
      );
      if (rows.isEmpty) continue;
      await db.update(
        'transactions',
        <String, Object?>{'category_id': pair.value},
        where: 'category_id = ?',
        whereArgs: <Object?>[pair.key],
      );
      await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: <Object?>[pair.key],
      );
    }

    final Batch batch = db.batch();
    for (final AppCategory category in kDefaultCategories) {
      if (category.alsoGroups.isEmpty) continue;
      batch.update(
        'categories',
        <String, Object?>{'also_groups': category.alsoGroups.join(',')},
        where: 'id = ?',
        whereArgs: <Object?>[category.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// v3 → v4: mark the edible categories.
  ///
  /// Meal tags are only offered for food, so the flag has to live on the row
  /// rather than be guessed from a group name. Seeded food is flagged from the
  /// seed list; anything the user created stays non-food (no meal tag) until
  /// they say otherwise.
  Future<void> _upgradeToFood(Database db) async {
    final Batch batch = db.batch();
    for (final AppCategory category in kDefaultCategories) {
      if (!category.isFood) continue;
      batch.update(
        'categories',
        <String, Object?>{'food': 1},
        where: 'id = ?',
        whereArgs: <Object?>[category.id],
      );
    }
    await batch.commit(noResult: true);
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
