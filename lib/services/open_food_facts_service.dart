import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_data.dart';

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';
  static const String _userAgent =
      'NutriLens/2.0 (Flutter; contact@nutrilens.app)';

  Future<OFFProduct?> getByBarcode(String barcode) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/v2/product/$barcode'
        '?fields=product_name,product_name_en,nutriments,nutriscore_grade,'
        'nova_group,ecoscore_grade,allergens_tags,'
        'ingredients_text,labels_tags,quantity,'
        'serving_size,image_url,categories_tags',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;
      return OFFProduct.fromJson(json['product'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<OFFProduct>> searchByName(String query) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1&action=process&json=1&page_size=5'
        '&fields=product_name,product_name_en,nutriments,nutriscore_grade,'
        'nova_group,allergens_tags,quantity,image_url',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final products = json['products'] as List? ?? [];
      return products
          .map((p) => OFFProduct.fromJson(p as Map<String, dynamic>))
          .where((p) => p.calories > 0)
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// [grams] = 100 için per-100g değerler döner; diğer değerler için ölçeklendirilir.
  NutritionData? toNutritionData(OFFProduct product, double grams) {
    if (product.calories == 0) return null;
    final f = grams / 100.0;
    return NutritionData(
      calories: (product.calories * f * 2).round() / 2,
      protein: _r(product.protein * f),
      carbohydrates: _r(product.carbs * f),
      fat: _r(product.fat * f),
      fiber: _r(product.fiber * f),
      sodium: _r(product.sodium * f),
      sugar: _r(product.sugar * f),
      saturatedFat: _r(product.saturatedFat * f),
      dataSource: 'OpenFoodFacts',
      confidenceScore: 78,
    );
  }

  double _r(double v) => (v * 10).round() / 10;
}

// ─── Model ────────────────────────────────────────────────────────────────────

class OFFProduct {
  final String name;
  final String? nameEn;
  final String? barcode;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;
  final double sugar;
  final double saturatedFat;

  final String? nutriscoreGrade; // a-e
  final int? novaGroup;          // 1-4
  final String? ecoscoreGrade;   // a-e
  final List<String> allergens;
  final List<String> labels;     // vegan, organic, vb.
  final String? imageUrl;
  final String? servingSize;

  const OFFProduct({
    required this.name,
    this.nameEn,
    this.barcode,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.sugar,
    required this.saturatedFat,
    this.nutriscoreGrade,
    this.novaGroup,
    this.ecoscoreGrade,
    this.allergens = const [],
    this.labels = const [],
    this.imageUrl,
    this.servingSize,
  });

  factory OFFProduct.fromJson(Map<String, dynamic> j) {
    final n = j['nutriments'] as Map<String, dynamic>? ?? {};
    double g(String key) =>
        (n['${key}_100g'] as num?)?.toDouble() ?? 0.0;

    return OFFProduct(
      name: (j['product_name'] as String?) ?? '',
      nameEn: (j['product_name_en'] as String?) ?? (j['product_name'] as String?),
      calories: g('energy-kcal'),
      protein: g('proteins'),
      carbs: g('carbohydrates'),
      fat: g('fat'),
      fiber: g('fiber'),
      sodium: (g('sodium')) * 1000, // kg → mg
      sugar: g('sugars'),
      saturatedFat: g('saturated-fat'),
      nutriscoreGrade: j['nutriscore_grade'] as String?,
      novaGroup: (j['nova_group'] as num?)?.toInt(),
      ecoscoreGrade: j['ecoscore_grade'] as String?,
      allergens: (j['allergens_tags'] as List? ?? [])
          .map((e) => (e as String)
              .replaceAll('en:', '')
              .replaceAll('-', ' '))
          .toList(),
      labels: (j['labels_tags'] as List? ?? [])
          .map((e) => (e as String).replaceAll('en:', ''))
          .toList(),
      imageUrl: j['image_url'] as String?,
      servingSize: j['serving_size'] as String?,
    );
  }
}
