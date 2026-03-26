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

  FoodProduct({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.nutritionPer100g,
    this.barcode,
  });
}

class NutritionService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';
  static const String _turkeyUrl = 'https://tr.openfoodfacts.org';

  // Barkod ile ürün ara
  Future<FoodProduct?> searchByBarcode(String barcode) async {
    try {
      final url = '$_baseUrl/api/v0/product/$barcode.json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NutriLens/1.0 (Flutter; nutrilens@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1) {
          return _parseProduct(data['product'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Barkod araması başarısız: $e');
    }
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
        '';

    if (name.isEmpty) return null;

    double _n(String key) {
      final v = nutriments['${key}_100g'] ?? nutriments[key];
      return v == null ? 0.0 : (v as num).toDouble();
    }

    double? _nNull(String key) {
      final v = nutriments['${key}_100g'] ?? nutriments[key];
      return v == null ? null : (v as num).toDouble();
    }

    return FoodProduct(
      id: product['id'] as String? ?? product['code'] as String? ?? '',
      name: name,
      brand: product['brands'] as String?,
      imageUrl: product['image_front_url'] as String?,
      barcode: product['code'] as String?,
      nutritionPer100g: NutritionData(
        calories: _n('energy-kcal'),
        protein: _n('proteins'),
        carbohydrates: _n('carbohydrates'),
        fat: _n('fat'),
        fiber: _n('fiber'),
        sugar: _n('sugars'),
        saturatedFat: _n('saturated-fat'),
      ),
    );
  }
}
