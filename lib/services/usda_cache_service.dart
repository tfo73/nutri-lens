import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'usda_api_service.dart';

class UsdaCacheService {
  static UsdaCacheService? _instance;
  static Database? _db;
  UsdaCacheService._();
  static UsdaCacheService get instance =>
      _instance ??= UsdaCacheService._();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'usda_cache.db');
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE food_cache (
          fdc_id    INTEGER PRIMARY KEY,
          query     TEXT,
          name      TEXT,
          nutrients TEXT,
          cached_at TEXT
        )
      ''');
      await db.execute('CREATE INDEX idx_query ON food_cache(query)');
    });
  }

  Future<void> save(String query, UsdaFoodDetail detail) async {
    final db = await database;
    await db.insert(
      'food_cache',
      {
        'fdc_id': detail.fdcId,
        'query': _normalize(query),
        'name': detail.description,
        'nutrients': jsonEncode(
            detail.nutrients.map((k, v) => MapEntry(k.toString(), v))),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UsdaFoodDetail?> get(String query) async {
    final db = await database;
    final rows = await db.query('food_cache',
        where: 'query = ?', whereArgs: [_normalize(query)], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToDetail(rows.first);
  }

  Future<UsdaFoodDetail?> getById(int fdcId) async {
    final db = await database;
    final rows = await db.query('food_cache',
        where: 'fdc_id = ?', whereArgs: [fdcId], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToDetail(rows.first);
  }

  UsdaFoodDetail _rowToDetail(Map<String, dynamic> row) {
    final raw = jsonDecode(row['nutrients'] as String) as Map;
    final nutrients = raw.map(
        (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()));
    return UsdaFoodDetail(
      fdcId: row['fdc_id'] as int,
      description: row['name'] as String,
      nutrients: nutrients,
    );
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .trim();
}
