import 'package:sqflite/sqflite.dart';

import '../models/nutrition_data.dart';

/// SQLite veritabanı — kullanıcı düzeltmeleri tablosunu yönetir
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _db;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/nutrilens.db';

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
      },
    );
  }

  Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_food_corrections (
        id TEXT PRIMARY KEY,
        food_name TEXT UNIQUE,
        calories REAL,
        protein REAL,
        carbohydrates REAL,
        fat REAL,
        fiber REAL,
        sodium REAL,
        original_source TEXT,
        correction_count INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_entries (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        meal_type TEXT,
        food_name TEXT NOT NULL,
        portion_grams REAL NOT NULL,
        data_source TEXT,
        fdc_id INTEGER,
        logged_at TEXT NOT NULL,

        -- Makrolar
        energy REAL DEFAULT 0,
        protein REAL DEFAULT 0,
        fat REAL DEFAULT 0,
        carb REAL DEFAULT 0,
        fiber REAL DEFAULT 0,
        sugar REAL DEFAULT 0,
        sat_fat REAL DEFAULT 0,
        mono_fat REAL DEFAULT 0,
        poly_fat REAL DEFAULT 0,
        trans_fat REAL DEFAULT 0,
        cholesterol REAL DEFAULT 0,
        water REAL DEFAULT 0,
        ash REAL DEFAULT 0,

        -- Mineraller
        calcium REAL DEFAULT 0,
        iron REAL DEFAULT 0,
        magnesium REAL DEFAULT 0,
        phosphorus REAL DEFAULT 0,
        potassium REAL DEFAULT 0,
        sodium REAL DEFAULT 0,
        zinc REAL DEFAULT 0,
        copper REAL DEFAULT 0,
        manganese REAL DEFAULT 0,
        selenium REAL DEFAULT 0,
        fluoride REAL DEFAULT 0,
        chromium REAL DEFAULT 0,
        iodine REAL DEFAULT 0,
        molybdenum REAL DEFAULT 0,

        -- Vitaminler
        vit_a_rae REAL DEFAULT 0,
        vit_a_iu REAL DEFAULT 0,
        retinol REAL DEFAULT 0,
        alpha_carot REAL DEFAULT 0,
        beta_carot REAL DEFAULT 0,
        beta_crypt REAL DEFAULT 0,
        lycopene REAL DEFAULT 0,
        lutein_zea REAL DEFAULT 0,
        vit_e REAL DEFAULT 0,
        vit_d_mcg REAL DEFAULT 0,
        vit_d_iu REAL DEFAULT 0,
        vit_k REAL DEFAULT 0,
        vit_k_mena REAL DEFAULT 0,
        vit_c REAL DEFAULT 0,
        thiamine REAL DEFAULT 0,
        riboflavin REAL DEFAULT 0,
        niacin REAL DEFAULT 0,
        pantothenic REAL DEFAULT 0,
        vit_b6 REAL DEFAULT 0,
        folate REAL DEFAULT 0,
        vit_b12 REAL DEFAULT 0,
        choline REAL DEFAULT 0,
        betaine REAL DEFAULT 0,
        biotin REAL DEFAULT 0,

        -- Yağ asitleri
        omega3 REAL DEFAULT 0,
        omega6 REAL DEFAULT 0,
        ala REAL DEFAULT 0,
        epa REAL DEFAULT 0,
        dha REAL DEFAULT 0,
        linoleic REAL DEFAULT 0,

        -- Amino asitler
        tryptophan REAL DEFAULT 0,
        threonine REAL DEFAULT 0,
        isoleucine REAL DEFAULT 0,
        leucine REAL DEFAULT 0,
        lysine REAL DEFAULT 0,
        methionine REAL DEFAULT 0,
        cystine REAL DEFAULT 0,
        phenylalanine REAL DEFAULT 0,
        tyrosine REAL DEFAULT 0,
        valine REAL DEFAULT 0,
        histidine REAL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_food_entries_profile ON food_entries(profile_id, logged_at)');
  }

  // ── Kullanıcı Düzeltmesi Kaydet ────────────────────────────────────────────

  Future<void> saveUserFoodCorrection({
    required String foodName,
    required NutritionData corrected,
    required NutritionData original,
    String? originalSource,
  }) async {
    final db = await database;
    final key = foodName.toLowerCase().trim();

    final existing = await db.query(
      'user_food_corrections',
      where: 'food_name = ?',
      whereArgs: [key],
    );

    final now = DateTime.now().toIso8601String();

    if (existing.isEmpty) {
      await db.insert(
        'user_food_corrections',
        {
          'id': '${DateTime.now().microsecondsSinceEpoch}',
          'food_name': key,
          'calories': corrected.calories,
          'protein': corrected.protein,
          'carbohydrates': corrected.carbohydrates,
          'fat': corrected.fat,
          'fiber': corrected.fiber,
          'sodium': corrected.sodium ?? 0,
          'original_source': originalSource ?? 'Claude',
          'correction_count': 1,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _updateUserCorrection(key, corrected);
    }
  }

  Future<void> _updateUserCorrection(
      String foodNameKey, NutritionData newCorrection) async {
    final db = await database;
    final existing = await db.query(
      'user_food_corrections',
      where: 'food_name = ?',
      whereArgs: [foodNameKey],
    );
    if (existing.isEmpty) return;

    final old = existing.first;
    final count = (old['correction_count'] as int) + 1;
    // Ağırlıklı ortalama: yeni düzeltme giderek daha az ağırlık alır
    final weight = 1.0 / count;

    await db.update(
      'user_food_corrections',
      {
        'calories': (old['calories'] as double) * (1 - weight) +
            newCorrection.calories * weight,
        'protein': (old['protein'] as double) * (1 - weight) +
            newCorrection.protein * weight,
        'carbohydrates': (old['carbohydrates'] as double) * (1 - weight) +
            newCorrection.carbohydrates * weight,
        'fat': (old['fat'] as double) * (1 - weight) +
            newCorrection.fat * weight,
        'fiber': (old['fiber'] as double) * (1 - weight) +
            newCorrection.fiber * weight,
        'sodium': (old['sodium'] as double) * (1 - weight) +
            (newCorrection.sodium ?? 0) * weight,
        'correction_count': count,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'food_name = ?',
      whereArgs: [foodNameKey],
    );
  }

  // ── Kullanıcı Düzeltmesini Oku ─────────────────────────────────────────────

  Future<NutritionData?> getUserCorrection(String foodName) async {
    final db = await database;
    final key = foodName.toLowerCase().trim();
    final rows = await db.query(
      'user_food_corrections',
      where: 'food_name = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return NutritionData(
      calories: (r['calories'] as num).toDouble(),
      protein: (r['protein'] as num).toDouble(),
      carbohydrates: (r['carbohydrates'] as num).toDouble(),
      fat: (r['fat'] as num).toDouble(),
      fiber: (r['fiber'] as num).toDouble(),
      sodium: (r['sodium'] as num).toDouble(),
    );
  }

  Future<bool> hasUserCorrection(String foodName) async {
    final result = await getUserCorrection(foodName);
    return result != null;
  }

  // ── Tüm Verileri Sil ──────────────────────────────────────────────────────

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('food_entries');
    await db.execute('DROP TABLE IF EXISTS user_food_corrections');
    await db.execute('''
      CREATE TABLE user_food_corrections (
        id TEXT PRIMARY KEY,
        food_name TEXT UNIQUE,
        calories REAL,
        protein REAL,
        carbohydrates REAL,
        fat REAL,
        fiber REAL,
        sodium REAL,
        original_source TEXT,
        correction_count INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }
}
