import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Model ────────────────────────────────────────────────────────────────────

class EdamamRecipe {
  final String label;
  final String? image;
  final int calories;          // per serving (kcal)
  final int totalTime;         // minutes
  final List<String> ingredientLines;
  final List<String> dietLabels;
  final List<String> healthLabels;
  final List<String> mealType;
  final double protein;        // g per serving
  final double carbs;          // g per serving
  final double fat;            // g per serving
  final double fiber;          // g per serving
  final String? cuisineType;
  final String url;            // original recipe source

  const EdamamRecipe({
    required this.label,
    this.image,
    required this.calories,
    this.totalTime = 30,
    required this.ingredientLines,
    this.dietLabels = const [],
    this.healthLabels = const [],
    this.mealType = const [],
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.cuisineType,
    this.url = '',
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Edamam Recipe Search API v2 — Developer Plan
///
/// Used for two purposes:
///  1. search()             — user-triggered recipe search
///  2. getRecommendations() — Meal-Planner-style personalised suggestions
///
/// Env: EDAMAM_RECIPE_APP_ID, EDAMAM_RECIPE_APP_KEY
/// All methods return empty list on any failure — callers fall back silently.
class EdamamRecipeService {
  static const _appId = String.fromEnvironment(
    'EDAMAM_RECIPE_APP_ID',
    defaultValue: '',
  );
  static const _appKey = String.fromEnvironment(
    'EDAMAM_RECIPE_APP_KEY',
    defaultValue: '',
  );
  static const _base = 'https://api.edamam.com/api/recipes/v2';

  static EdamamRecipeService? _instance;
  static EdamamRecipeService get instance =>
      _instance ??= EdamamRecipeService._();
  EdamamRecipeService._();

  // Turkish → English keyword translation (recipe queries)
  static const _trToEn = <String, String>{
    'tavuk': 'chicken', 'köfte': 'meatball', 'pilav': 'rice pilaf',
    'mercimek': 'lentil', 'bulgur': 'bulgur wheat', 'nohut': 'chickpea',
    'çorba': 'soup', 'salata': 'salad', 'börek': 'börek pastry',
    'yoğurt': 'yogurt', 'peynir': 'cheese', 'ekmek': 'bread',
    'domates': 'tomato', 'patlıcan': 'eggplant', 'somon': 'salmon',
    'ton balığı': 'tuna', 'karides': 'shrimp', 'yumurta': 'egg',
    'süt': 'milk', 'kıyma': 'ground beef', 'kuzu': 'lamb',
    'dana': 'beef', 'hindi': 'turkey', 'balık': 'fish',
    'fasulye': 'beans', 'patates': 'potato', 'pirinç': 'rice',
    'makarna': 'pasta', 'soğan': 'onion', 'havuç': 'carrot',
    'ıspanak': 'spinach', 'elma': 'apple', 'muz': 'banana',
    'portakal': 'orange', 'badem': 'almond', 'ceviz': 'walnut',
    'zeytinyağı': 'olive oil', 'izgara': 'grilled', 'haşlama': 'boiled',
    'fırın': 'baked', 'kızartma': 'fried', 'sebze': 'vegetable',
    'meyve': 'fruit', 'kahvaltı': 'breakfast', 'öğle': 'lunch',
    'akşam': 'dinner', 'tatlı': 'dessert', 'sağlıklı': 'healthy',
    'protein': 'high protein', 'diyet': 'diet', 'vegan': 'vegan',
    'kinoa': 'quinoa', 'avokado': 'avocado', 'smoothie': 'smoothie',
    'granola': 'granola', 'yulaf': 'oatmeal', 'tost': 'toast',
  };

  static String _toEnglish(String query) {
    final lower = query.toLowerCase();
    for (final entry in _trToEn.entries) {
      if (lower.contains(entry.key)) {
        return query.toLowerCase().replaceAll(entry.key, entry.value);
      }
    }
    return query;
  }

  // ── Recipe Search ──────────────────────────────────────────────────────────

  /// Search Edamam for recipes matching [query].
  /// Tries the original query first; if empty, retries with English translation.
  Future<List<EdamamRecipe>> search(
    String query, {
    String? dietLabel,    // e.g. 'balanced', 'high-protein'
    String? healthLabel,  // e.g. 'vegan', 'gluten-free'
    int? maxCalories,
    int to = 8,
  }) async {
    if (_appId.isEmpty || _appKey.isEmpty) return [];

    var results = await _doSearch(
      query,
      dietLabel: dietLabel,
      healthLabel: healthLabel,
      maxCalories: maxCalories,
      to: to,
    );

    if (results.isEmpty) {
      final en = _toEnglish(query);
      if (en != query) {
        results = await _doSearch(
          en,
          dietLabel: dietLabel,
          healthLabel: healthLabel,
          maxCalories: maxCalories,
          to: to,
        );
      }
    }
    return results;
  }

  // ── Meal-Planner-Style Personalised Recommendations ───────────────────────

  /// Returns [to] recipes suitable for [mealType] fitting [maxCalories].
  /// Used by the suggestions screen to populate personalised sections.
  /// [mealType]: 'breakfast' | 'lunch/dinner' | 'snack' | 'teatime'
  Future<List<EdamamRecipe>> getRecommendations({
    String mealType = 'lunch/dinner',
    String? dietLabel,
    String? healthLabel,
    int maxCalories = 700,
    int to = 6,
  }) async {
    if (_appId.isEmpty || _appKey.isEmpty) return [];
    return _doSearch(
      'healthy',
      mealType: mealType,
      dietLabel: dietLabel,
      healthLabel: healthLabel,
      maxCalories: maxCalories,
      to: to,
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<List<EdamamRecipe>> _doSearch(
    String query, {
    String? mealType,
    String? dietLabel,
    String? healthLabel,
    int? maxCalories,
    required int to,
  }) async {
    try {
      final params = <String, String>{
        'type': 'public',
        'q': query,
        'app_id': _appId,
        'app_key': _appKey,
        'to': to.toString(),
      };
      if (mealType != null) params['mealType'] = mealType;
      if (dietLabel != null) params['diet'] = dietLabel;
      if (healthLabel != null) params['health'] = healthLabel;
      if (maxCalories != null) params['calories'] = '0-$maxCalories';

      final uri = Uri.parse(_base).replace(queryParameters: params);
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final hits = data['hits'] as List<dynamic>? ?? [];

      return hits.map((h) => _parseHit(h)).whereType<EdamamRecipe>().toList();
    } catch (_) {
      return [];
    }
  }

  EdamamRecipe? _parseHit(dynamic hit) {
    try {
      final r = (hit as Map<String, dynamic>)['recipe'] as Map<String, dynamic>;
      final label = (r['label'] as String?) ?? '';
      if (label.isEmpty) return null;

      final yield_ = (r['yield'] as num?)?.toDouble() ?? 1.0;
      final totalCals = (r['calories'] as num?)?.toDouble() ?? 0.0;
      final perServing = (totalCals / yield_).round();

      final nutrients =
          r['totalNutrients'] as Map<String, dynamic>? ?? {};
      double n(String key) {
        final nv = nutrients[key] as Map<String, dynamic>?;
        return ((nv?['quantity'] as num?)?.toDouble() ?? 0.0) / yield_;
      }

      final cuisines = r['cuisineType'] as List<dynamic>?;

      return EdamamRecipe(
        label: label,
        image: r['image'] as String?,
        calories: perServing,
        totalTime: (r['totalTime'] as num?)?.toInt() ?? 0,
        ingredientLines:
            (r['ingredientLines'] as List<dynamic>?)?.cast<String>() ?? [],
        dietLabels:
            (r['dietLabels'] as List<dynamic>?)?.cast<String>() ?? [],
        healthLabels:
            (r['healthLabels'] as List<dynamic>?)?.cast<String>() ?? [],
        mealType:
            (r['mealType'] as List<dynamic>?)?.cast<String>() ?? [],
        protein: n('PROCNT'),
        carbs: n('CHOCDF'),
        fat: n('FAT'),
        fiber: n('FIBTG'),
        cuisineType: cuisines?.isNotEmpty == true
            ? (cuisines!.first as String?)
            : null,
        url: (r['url'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
