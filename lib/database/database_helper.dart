import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/item_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'po_viewer.db';
  static const String _tableName = 'purchase_order_histories';
  static const String _ftsTableName = 'purchase_order_histories_fts';
  static const int _databaseVersion = 2;

  // Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database table
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        po_date TEXT NOT NULL,
        po_number TEXT NOT NULL,
        vendor_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        category TEXT,
        product_qty INTEGER NOT NULL,
        product_qty_unit TEXT NOT NULL,
        product_unit_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(po_number, vendor_name, product_name)
      )
    ''');

    await _createFtsInfrastructure(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _dropFtsInfrastructure(db);
      await _createFtsInfrastructure(db);
    }
  }

  Future<void> _dropFtsInfrastructure(Database db) async {
    await db.execute('DROP TRIGGER IF EXISTS ${_tableName}_ai');
    await db.execute('DROP TRIGGER IF EXISTS ${_tableName}_ad');
    await db.execute('DROP TRIGGER IF EXISTS ${_tableName}_au');
    await db.execute('DROP TABLE IF EXISTS $_ftsTableName');
  }

  Future<void> _createFtsInfrastructure(Database db) async {
    await _createFtsVirtualTable(db);
    await _createFtsSyncTriggers(db);
    await _rebuildFtsIndex(db);
  }

  Future<void> _createFtsVirtualTable(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $_ftsTableName USING fts4(
        product_name,
        vendor_name,
        category,
        content='$_tableName'
      )
    ''');
  }

  Future<void> _createFtsSyncTriggers(Database db) async {
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS ${_tableName}_ai AFTER INSERT ON $_tableName BEGIN
        INSERT INTO $_ftsTableName(rowid, product_name, vendor_name, category)
        VALUES (new.id, new.product_name, new.vendor_name, COALESCE(new.category, ''));
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS ${_tableName}_ad AFTER DELETE ON $_tableName BEGIN
        INSERT INTO $_ftsTableName($_ftsTableName, rowid, product_name, vendor_name, category)
        VALUES ('delete', old.id, old.product_name, old.vendor_name, COALESCE(old.category, ''));
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS ${_tableName}_au AFTER UPDATE ON $_tableName BEGIN
        INSERT INTO $_ftsTableName($_ftsTableName, rowid, product_name, vendor_name, category)
        VALUES ('delete', old.id, old.product_name, old.vendor_name, COALESCE(old.category, ''));
        INSERT INTO $_ftsTableName(rowid, product_name, vendor_name, category)
        VALUES (new.id, new.product_name, new.vendor_name, COALESCE(new.category, ''));
      END;
    ''');
  }

  Future<void> _rebuildFtsIndex(Database db) async {
    await db.execute("INSERT INTO $_ftsTableName($_ftsTableName) VALUES('rebuild')");
  }

  String _buildFtsMatchQuery(String query) {
    final tokens = query
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .map((token) => '"${token.replaceAll('"', '""')}"*')
        .toList();

    return tokens.join(' ');
  }

  /// Insert an item into the database
  Future<int> insertItem(PurchaseOrderItem item) async {
    final db = await database;
    return await db.insert(
      _tableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Bulk insert multiple items into the database
  /// Uses a transaction for better performance and atomicity
  /// Returns the number of items actually inserted (excluding conflicts)
  Future<int> insertItems(List<PurchaseOrderItem> items) async {
    final db = await database;
    int insertedCount = 0;

    await db.transaction((txn) async {
      for (var item in items) {
        final id = await txn.insert(
          _tableName,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id != -1) {
          insertedCount++;
        }
      }
    });

    return insertedCount;
  }

  /// Get all items from the database
  Future<List<PurchaseOrderItem>> getAllItems() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return PurchaseOrderItem.fromMap(maps[i]);
    });
  }

  /// Delete an item by id
  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all items
  Future<int> deleteAllItems() async {
    final db = await database;
    return await db.delete(_tableName);
  }


  /// Search items with optional query, vendor, and category filters.
  Future<List<PurchaseOrderItem>> searchItemsWithFilters({
    String? query,
    String? vendor,
    String? category,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    final trimmedQuery = (query ?? '').trim();
    if (trimmedQuery.isNotEmpty) {
      whereClauses.add('$_ftsTableName MATCH ?');
      whereArgs.add(_buildFtsMatchQuery(trimmedQuery));
    }

    if (vendor != null && vendor.isNotEmpty) {
      whereClauses.add('p.vendor_name = ?');
      whereArgs.add(vendor);
    }

    if (category != null && category.isNotEmpty) {
      whereClauses.add('p.category = ?');
      whereArgs.add(category);
    }

    final maps = trimmedQuery.isNotEmpty
        ? await db.rawQuery(
            '''
            SELECT p.*
            FROM $_tableName p
            INNER JOIN $_ftsTableName ON $_ftsTableName.rowid = p.id
            WHERE ${whereClauses.join(' AND ')}
            ORDER BY p.po_date DESC
            ''',
            whereArgs,
          )
        : await db.query(
            '$_tableName p',
            where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
            whereArgs: whereArgs.isEmpty ? null : whereArgs,
            orderBy: 'p.po_date DESC',
          );

    return List.generate(maps.length, (i) {
      return PurchaseOrderItem.fromMap(maps[i]);
    });
  }

  /// Get distinct vendor names.
  Future<List<String>> getDistinctVendors() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT vendor_name
      FROM $_tableName
      WHERE vendor_name IS NOT NULL AND TRIM(vendor_name) != ''
      ORDER BY vendor_name ASC
    ''');
    return maps.map((m) => (m['vendor_name'] as String?) ?? '').where((v) => v.isNotEmpty).toList();
  }

  /// Get distinct categories; when vendor is provided categories are constrained to that vendor.
  Future<List<String>> getDistinctCategories({String? vendor}) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT DISTINCT category
      FROM $_tableName
      WHERE category IS NOT NULL AND TRIM(category) != ''
      ${vendor != null && vendor.isNotEmpty ? 'AND vendor_name = ?' : ''}
      ORDER BY category ASC
      ''',
      vendor != null && vendor.isNotEmpty ? [vendor] : null,
    );

    return maps.map((m) => (m['category'] as String?) ?? '').where((c) => c.isNotEmpty).toList();
  }

  /// Count all items in the database
  Future<int> countItems() async {
    final db = await database;
    final countQuery = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final count = Sqflite.firstIntValue(countQuery);
    return count ?? 0;
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

