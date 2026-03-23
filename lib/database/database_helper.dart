import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'po_viewer.db';
  static const String _tableName = 'purchase_order_histories';
  static const int _databaseVersion = 1;

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
    );
  }

  /// Create database table
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        po_date TEXT,
        po_number TEXT NOT NULL,
        vendor_name TEXT NOT NULL,
        project_name TEXT NOT NULL,
        product_name TEXT NOT NULL,
        product_qty INTEGER NOT NULL,
        product_qty_unit TEXT NOT NULL,
        product_unit_price REAL NOT NULL,
        product_discount_pct REAL NOT NULL,
        product_final_price REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Insert an item into the database
  Future<int> insertItem(PurchaseOrderItem item) async {
    final db = await database;
    return await db.insert(
      _tableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  /// Search items by product name or vendor name
  Future<List<PurchaseOrderItem>> searchItems(String query) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'product_name LIKE ? OR vendor_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return PurchaseOrderItem.fromMap(maps[i]);
    });
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

