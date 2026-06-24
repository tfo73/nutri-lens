import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_data.dart';

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

  // Barkod ile ürün ara (Hem Türkiye hem de Dünya veritabanlarını ve V2/V0 API'lerini tarar)
  Future<FoodProduct?> searchByBarcode(String barcode) async {
    try {
      // 1. world v0 API dene
      var product = await _searchBarcodeOnDomain('https://world.openfoodfacts.org', barcode);
      if (product != null) return product;

      // 2. tr v0 API dene (Türkiye özel barkodlar)
      product = await _searchBarcodeOnDomain('https://tr.openfoodfacts.org', barcode);
      if (product != null) return product;

      // 3. world v2 API dene
      product = await _searchBarcodeV2(barcode);
      if (product != null) return product;

      return null;
    } catch (e) {
      throw Exception('Barkod araması başarısız: $e');
    }
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
