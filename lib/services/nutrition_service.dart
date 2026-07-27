import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_data.dart';
import 'config_service.dart';

class FoodProduct {
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final NutritionData nutritionPer100g;
  final String? barcode;
  final double? portionSizeGrams;

  FoodProduct({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.nutritionPer100g,
    this.barcode,
    this.portionSizeGrams,
  });
}

class NutritionService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';
  static const String _turkeyUrl = 'https://tr.openfoodfacts.org';

  // Barkod ile ürün ara (Hem Türkiye hem de Dünya veritabanlarını, V2/V0 API'lerini tarar, ayrıca USDA ve Edamam'a yedeklenir)
  Future<FoodProduct?> searchByBarcode(String barcode) async {
    try {
      final List<String> candidates = [barcode];
      final trimmed = barcode.trim();
      if (trimmed != barcode && trimmed.isNotEmpty) {
        candidates.add(trimmed);
      }
      if (trimmed.startsWith('0')) {
        var stripped = trimmed;
        while (stripped.startsWith('0') && stripped.length > 8) {
          stripped = stripped.substring(1);
          if (!candidates.contains(stripped)) {
            candidates.add(stripped);
          }
        }
      }
      if (trimmed.length == 12) {
        final ean = '0$trimmed';
        if (!candidates.contains(ean)) {
          candidates.add(ean);
        }
      }

      // 1. Aşama: OpenFoodFacts (Tüm aday formatlar için)
      for (final code in candidates) {
        // world v0 API dene
        var product = await _searchBarcodeOnDomain('https://world.openfoodfacts.org', code);
        if (product != null) return product;

        // tr v0 API dene (Türkiye özel barkodlar)
        product = await _searchBarcodeOnDomain('https://tr.openfoodfacts.org', code);
        if (product != null) return product;

        // world v2 API dene
        product = await _searchBarcodeV2(code);
        if (product != null) return product;
      }

      // 2. Aşama: USDA FoodData Central yedek araması
      for (final code in candidates) {
        final product = await _searchUSDAByBarcode(code);
        if (product != null) return product;
      }

      // 3. Aşama: Edamam Food Database yedek araması
      for (final code in candidates) {
        final product = await _searchEdamamByBarcode(code);
        if (product != null) return product;
      }

      return null;
    } catch (e) {
      throw Exception('Barkod araması başarısız: $e');
    }
  }

  Future<FoodProduct?> _searchUSDAByBarcode(String barcode) async {
    final apiKey = ConfigService.usdaKey;
    if (apiKey.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search'
        '?api_key=$apiKey'
        '&query=${Uri.encodeComponent(barcode)}'
        '&pageSize=1',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final foods = data['foods'] as List? ?? [];
      if (foods.isEmpty) return null;

      final item = foods.first as Map<String, dynamic>;
      final nutrientsList = item['foodNutrients'] as List? ?? [];

      double getVal(int targetId) {
        for (final n in nutrientsList) {
          final id = (n['nutrientId'] as num?)?.toInt() ?? (n['nutrient']?['id'] as num?)?.toInt();
          if (id == targetId) {
            return (n['value'] as num?)?.toDouble() ?? (n['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
        return 0.0;
      }

      double? getValNullable(int targetId) {
        for (final n in nutrientsList) {
          final id = (n['nutrientId'] as num?)?.toInt() ?? (n['nutrient']?['id'] as num?)?.toInt();
          if (id == targetId) {
            return (n['value'] as num?)?.toDouble() ?? (n['amount'] as num?)?.toDouble();
          }
        }
        return null;
      }

      final servingSize = (item['servingSize'] as num?)?.toDouble();

      return FoodProduct(
        id: (item['fdcId'] as num?)?.toString() ?? '',
        name: (item['description'] as String?) ?? '',
        brand: (item['brandOwner'] as String?) ?? (item['brandName'] as String?),
        imageUrl: null,
        barcode: barcode,
        portionSizeGrams: servingSize,
        nutritionPer100g: NutritionData(
          calories: getVal(1008),
          protein: getVal(1003),
          carbohydrates: getVal(1005),
          fat: getVal(1004),
          fiber: getVal(1079),
          sugar: getVal(2000),
          saturatedFat: getVal(1258),
          monoFat: getValNullable(1292),
          polyFat: getValNullable(1293),
          transFat: getValNullable(1257),
          cholesterol: getValNullable(1253),
          sodium: getValNullable(1093),
          calcium: getValNullable(1087),
          iron: getValNullable(1089),
          potassium: getValNullable(1092),
          magnesium: getValNullable(1090),
          phosphorus: getValNullable(1091),
          zinc: getValNullable(1095),
          copper: getValNullable(1098),
          manganese: getValNullable(1101),
          selenium: getValNullable(1103),
          vitaminA: getValNullable(1106),
          vitaminC: getValNullable(1162),
          vitaminD: getValNullable(1114),
          vitaminE: getValNullable(1158) ?? getValNullable(1109),
          vitaminK: getValNullable(1185),
          thiamine: getValNullable(1165),
          riboflavin: getValNullable(1166),
          niacin: getValNullable(1167),
          pantothenic: getValNullable(1170),
          vitaminB6: getValNullable(1175),
          folate: getValNullable(1177),
          vitaminB12: getValNullable(1178),
          dataSource: 'USDA',
          confidenceScore: 85,
        ),
      );
    } catch (_) {}
    return null;
  }

  Future<FoodProduct?> _searchEdamamByBarcode(String barcode) async {
    final edamamKey = ConfigService.edamamNutritionKey;
    if (!edamamKey.contains(':')) return null;
    try {
      final parts = edamamKey.split(':');
      final appId = parts[0].trim();
      final appKey = parts[1].trim();
      if (appId.isEmpty || appKey.isEmpty) return null;

      final uri = Uri.parse(
        'https://api.edamam.com/api/food-database/v2/parser'
        '?app_id=$appId'
        '&app_key=$appKey'
        '&upc=${Uri.encodeComponent(barcode)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final hints = data['hints'] as List? ?? [];
      if (hints.isEmpty) return null;

      final hint = hints.first as Map<String, dynamic>;
      final food = hint['food'] as Map<String, dynamic>?;
      if (food == null) return null;

      final nutrients = food['nutrients'] as Map<String, dynamic>? ?? {};

      double getVal(String key) {
        return (nutrients[key] as num?)?.toDouble() ?? 0.0;
      }

      double? getValNullable(String key) {
        final v = nutrients[key];
        return v == null ? null : (v as num).toDouble();
      }

      return FoodProduct(
        id: (food['foodId'] as String?) ?? '',
        name: (food['label'] as String?) ?? '',
        brand: (food['brand'] as String?),
        imageUrl: (food['image'] as String?),
        barcode: barcode,
        portionSizeGrams: null,
        nutritionPer100g: NutritionData(
          calories: getVal('ENERC_KCAL'),
          protein: getVal('PROCNT'),
          carbohydrates: getVal('CHOCDF'),
          fat: getVal('FAT'),
          fiber: getVal('FIBTG'),
          sugar: getVal('SUGAR'),
          saturatedFat: getVal('FASAT'),
          monoFat: getValNullable('FAMS'),
          polyFat: getValNullable('FAPU'),
          transFat: getValNullable('FATRN'),
          cholesterol: getValNullable('CHOLE'),
          sodium: getValNullable('NA'),
          calcium: getValNullable('CA'),
          iron: getValNullable('FE'),
          potassium: getValNullable('K'),
          magnesium: getValNullable('MG'),
          phosphorus: getValNullable('P'),
          zinc: getValNullable('ZN'),
          copper: getValNullable('CU'),
          manganese: getValNullable('MN'),
          selenium: getValNullable('SE'),
          vitaminA: getValNullable('VITA_RAE'),
          vitaminC: getValNullable('VITC'),
          vitaminD: getValNullable('VITD'),
          vitaminE: getValNullable('TOCPHA'),
          vitaminK: getValNullable('VITK1'),
          thiamine: getValNullable('THIA'),
          riboflavin: getValNullable('RIBF'),
          niacin: getValNullable('NIA'),
          pantothenic: getValNullable('PANTAC'),
          vitaminB6: getValNullable('VITB6A'),
          folate: getValNullable('FOLDFE') ?? getValNullable('FOL'),
          vitaminB12: getValNullable('VITB12'),
          dataSource: 'Edamam',
          confidenceScore: 80,
        ),
      );
    } catch (_) {}
    return null;
  }

  Future<FoodProduct?> _searchBarcodeOnDomain(String domain, String barcode) async {
    try {
      final url = '$domain/api/v0/product/$barcode.json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NutriLens/1.0 (Flutter; nutrilens@example.com)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] != null) {
          return _parseProduct(data['product'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<FoodProduct?> _searchBarcodeV2(String barcode) async {
    try {
      final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NutriLens/1.0 (Flutter; nutrilens@example.com)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] != null) {
          return _parseProduct(data['product'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  // İsimle ürün ara
  Future<List<FoodProduct>> searchByName(String query, {int pageSize = 20}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/cgi/search.pl'
          '?search_terms=$encodedQuery'
          '&search_simple=1'
          '&action=process'
          '&json=1'
          '&page_size=$pageSize'
          '&lc=tr';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NutriLens/1.0 (Flutter; nutrilens@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products = (data['products'] as List<dynamic>? ?? [])
            .map((p) => _parseProduct(p as Map<String, dynamic>))
            .whereType<FoodProduct>()
            .toList();
        return products;
      }
      return [];
    } catch (e) {
      throw Exception('Ürün araması başarısız: $e');
    }
  }

  // Türk ürünlerini ara
  Future<List<FoodProduct>> searchTurkishProducts(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_turkeyUrl/cgi/search.pl'
          '?search_terms=$encodedQuery'
          '&search_simple=1'
          '&action=process'
          '&json=1'
          '&page_size=20';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NutriLens/1.0 (Flutter; nutrilens@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products = (data['products'] as List<dynamic>? ?? [])
            .map((p) => _parseProduct(p as Map<String, dynamic>))
            .whereType<FoodProduct>()
            .toList();
        return products;
      }
      return [];
    } catch (e) {
      throw Exception('Türk ürünü araması başarısız: $e');
    }
  }

  FoodProduct? _parseProduct(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    if (nutriments == null) return null;

    final name = product['product_name_tr'] as String? ??
        product['product_name'] as String? ??
        product['product_name_en'] as String? ??
        product['product_name_fr'] as String? ??
        product['product_name_de'] as String? ??
        product['generic_name'] as String? ??
        '';

    if (name.isEmpty) return null;

    double _n(String key) {
      final v = nutriments['${key}_100g'] ?? nutriments[key];
      return v == null ? 0.0 : (v as num).toDouble();
    }

    double? _nn(String key) {
      final v = nutriments['${key}_100g'] ?? nutriments[key];
      return v == null ? null : (v as num).toDouble();
    }

    double? _gToMg(String key) {
      final v = _nn(key);
      return v != null ? v * 1000.0 : null;
    }

    double? _gToMcg(String key) {
      final v = _nn(key);
      return v != null ? v * 1000000.0 : null;
    }

    // Format brand to Title Case (first letter capital)
    String? rawBrand = product['brands'] as String?;
    String? formattedBrand;
    if (rawBrand != null && rawBrand.trim().isNotEmpty) {
      formattedBrand = rawBrand.split(',').first.trim().split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    double? portionSize;
    final sq = product['serving_quantity'];
    if (sq != null) {
      portionSize = (sq as num).toDouble();
    } else {
      final pq = product['product_quantity'];
      if (pq != null) {
        portionSize = (pq as num).toDouble();
      }
    }

    return FoodProduct(
      id: product['id'] as String? ?? product['code'] as String? ?? '',
      name: name,
      brand: formattedBrand,
      imageUrl: product['image_front_url'] as String?,
      barcode: product['code'] as String?,
      portionSizeGrams: portionSize,
      nutritionPer100g: NutritionData(
        calories: _n('energy-kcal'),
        protein: _n('proteins'),
        carbohydrates: _n('carbohydrates'),
        fat: _n('fat'),
        fiber: _n('fiber'),
        sugar: _n('sugars'),
        saturatedFat: _n('saturated-fat'),
        monoFat: _nn('monounsaturated-fat'),
        polyFat: _nn('polyunsaturated-fat'),
        transFat: _nn('trans-fat'),
        cholesterol: _gToMg('cholesterol'),
        sodium: _gToMg('sodium'),
        calcium: _gToMg('calcium'),
        iron: _gToMg('iron'),
        potassium: _gToMg('potassium'),
        magnesium: _gToMg('magnesium'),
        phosphorus: _gToMg('phosphorus'),
        zinc: _gToMg('zinc'),
        copper: _gToMg('copper'),
        manganese: _gToMg('manganese'),
        selenium: _gToMcg('selenium'),
        vitaminA: _gToMcg('vitamin-a'),
        vitaminC: _gToMg('vitamin-c'),
        vitaminD: _gToMcg('vitamin-d'),
        vitaminE: _gToMg('vitamin-e'),
        vitaminK: _gToMcg('vitamin-k'),
        thiamine: _gToMg('vitamin-b1'),
        riboflavin: _gToMg('vitamin-b2'),
        niacin: _gToMg('vitamin-b3'),
        pantothenic: _gToMg('vitamin-b5'),
        vitaminB6: _gToMg('vitamin-b6'),
        folate: _gToMcg('vitamin-b9'),
        vitaminB12: _gToMcg('vitamin-b12'),
      ),
    );
  }
}
