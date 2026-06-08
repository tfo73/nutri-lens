import 'dart:convert';
import 'package:http/http.dart' as http;

import 'config_service.dart';

class UsdaApiService {
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';
  String get _apiKey => ConfigService.usdaKey;

  /// USDA FoodData Central nutrient IDs we care about.
  static const List<int> targetNutrients = [
    1008, 1003, 1004, 1005, 1079, 2000, 1258, 1292, 1293,
    1257, 1253, 1051, 1087, 1089, 1090, 1091, 1092, 1093,
    1095, 1098, 1101, 1103, 1100, 1106, 1109, 1114, 1185,
    1162, 1165, 1166, 1167, 1170, 1175, 1177, 1190, 1178,
    1180, 1404, 1405, 1278, 1272, 1107, 1122, 1123,
    1210, 1211, 1212, 1213, 1214, 1215, 1216, 1217,
    1218, 1219, 1221, 1096, 1102, 1176, 1186, 1198,
    1269, // ALA (alpha-linolenic acid)
  ];

  Future<List<UsdaFoodItem>> searchFood(String query) async {
    if (_apiKey.isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$_baseUrl/foods/search'
        '?api_key=$_apiKey'
        '&query=${Uri.encodeComponent(query)}'
        '&dataType=Foundation,SR%20Legacy,Survey%20(FNDDS)'
        '&pageSize=5',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final foods = json['foods'] as List? ?? [];
      return foods.map((f) => UsdaFoodItem.fromJson(f as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<UsdaFoodDetail?> getFoodDetail(int fdcId) async {
    if (_apiKey.isEmpty) return null;
    try {
      final uri = Uri.parse(
        '$_baseUrl/food/$fdcId'
        '?api_key=$_apiKey'
        '&nutrients=${targetNutrients.join(',')}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return UsdaFoodDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<UsdaFoodDetail?> lookupFood(String query) async {
    final results = await searchFood(query);
    if (results.isEmpty) return null;
    return getFoodDetail(results.first.fdcId);
  }
}

class UsdaFoodItem {
  final int fdcId;
  final String description;
  const UsdaFoodItem({required this.fdcId, required this.description});

  factory UsdaFoodItem.fromJson(Map<String, dynamic> j) => UsdaFoodItem(
        fdcId: j['fdcId'] as int,
        description: j['description'] as String? ?? '',
      );
}

class UsdaFoodDetail {
  final int fdcId;
  final String description;
  final Map<int, double> nutrients;

  const UsdaFoodDetail({
    required this.fdcId,
    required this.description,
    required this.nutrients,
  });

  factory UsdaFoodDetail.fromJson(Map<String, dynamic> j) {
    final Map<int, double> nutrients = {};
    final list = j['foodNutrients'] as List? ?? [];
    for (final n in list) {
      final id = (n['nutrient']?['id'] as num?)?.toInt()
          ?? (n['nutrientId'] as num?)?.toInt();
      final val = (n['amount'] as num?)?.toDouble()
          ?? (n['value'] as num?)?.toDouble();
      if (id != null && val != null) nutrients[id] = val;
    }
    return UsdaFoodDetail(
      fdcId: j['fdcId'] as int,
      description: j['description'] as String? ?? '',
      nutrients: nutrients,
    );
  }

  double get(int id) => nutrients[id] ?? 0.0;
}
