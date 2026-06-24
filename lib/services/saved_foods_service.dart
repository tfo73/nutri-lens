import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nutrition_data.dart';

class SavedFood {
  final String id;
  final String name;
  final String? brand;
  final double portionGrams;
  final NutritionData nutritionPer100g;
  final List<String> sources;
  final DateTime savedAt;
  final String? imagePath;
  final String? imageUrl;

  const SavedFood({
    required this.id,
    required this.name,
    this.brand,
    required this.portionGrams,
    required this.nutritionPer100g,
    required this.sources,
    required this.savedAt,
    this.imagePath,
    this.imageUrl,
  });

  NutritionData get nutritionScaled => nutritionPer100g.scaleBy(portionGrams / 100.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (brand != null) 'brand': brand,
        'portionGrams': portionGrams,
        'nutritionPer100g': nutritionPer100g.toJson(),
        'sources': sources,
        'savedAt': savedAt.toIso8601String(),
        if (imagePath != null) 'imagePath': imagePath,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory SavedFood.fromJson(Map<String, dynamic> j) => SavedFood(
        id: j['id'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String?,
        portionGrams: (j['portionGrams'] as num).toDouble(),
        nutritionPer100g: NutritionData.fromJson(j['nutritionPer100g'] as Map<String, dynamic>),
        sources: (j['sources'] as List<dynamic>).cast<String>(),
        savedAt: DateTime.parse(j['savedAt'] as String),
        imagePath: j['imagePath'] as String?,
        imageUrl: j['imageUrl'] as String?,
      );
}

class SavedFoodsService {
  static const _key = 'saved_foods_v1';

  static Future<List<SavedFood>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedFood.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(SavedFood food) async {
    final list = await load();
    list.removeWhere((f) => f.id == food.id);
    list.insert(0, food);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((f) => f.toJson()).toList()));
  }

  static Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((f) => f.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((f) => f.toJson()).toList()));
  }

  static Future<bool> isSaved(String name) async {
    final list = await load();
    return list.any((f) => f.name == name);
  }
}
