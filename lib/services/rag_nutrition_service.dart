// RAG (Retrieval-Augmented Generation) besin servisi
// Önce yerel FNDDS veritabanında fuzzy search yapar,
// eşleşme bulunursa Claude API'ye gitmeden döner.

import 'dart:math';

import '../data/fndds_database.dart';
import '../models/food_analysis_result.dart';
import '../models/nutrition_data_65.dart';

// ── Arama sonucu ──────────────────────────────────────────────────────────────

class RagMatch {
  final FnddsFood food;
  final double score; // 0.0 – 1.0
  const RagMatch(this.food, this.score);
}

// ── Singleton servis ──────────────────────────────────────────────────────────

class RagNutritionService {
  RagNutritionService._internal();
  static final RagNutritionService instance = RagNutritionService._internal();

  // Minimum eşleşme skoru — altında Claude'a gidilir
  static const double _minScore = 0.55;

  // ── Fuzzy Search ─────────────────────────────────────────────────────────────

  /// Sorguya en iyi uyan [topK] FNDDS kaydını döndürür.
  List<RagMatch> search(String query, {int topK = 5}) {
    final q = _normalize(query);
    final tokens = q.split(' ').where((t) => t.length >= 2).toSet();

    final scored = <RagMatch>[];

    for (final food in fnddsDatabase) {
      final nameNorm = _normalize(food.name);
      double best = 0.0;

      // 1. Tam isim içeriyor mu?
      if (nameNorm.contains(q)) {
        best = max(best, 0.95);
      }

      // 2. Alias tam eşleşmesi
      for (final alias in food.aliases) {
        final aliasNorm = _normalize(alias);
        if (aliasNorm == q) {
          best = max(best, 1.0);
          break;
        }
        if (aliasNorm.contains(q) || q.contains(aliasNorm)) {
          best = max(best, 0.85);
        }
      }

      // 3. Token (kelime) örtüşmesi
      if (tokens.isNotEmpty) {
        final nameTokens = nameNorm.split(' ').toSet();
        final aliasTokens = food.aliases
            .expand((a) => _normalize(a).split(' '))
            .where((t) => t.length >= 2)
            .toSet();
        final allTokens = {...nameTokens, ...aliasTokens};

        final overlap =
            tokens.where((t) => allTokens.any((at) => at.contains(t) || t.contains(at))).length;
        final tokenScore = overlap / max(tokens.length, 1);
        best = max(best, tokenScore * 0.8);
      }

      // 4. Trigram benzerliği (fallback)
      if (best < 0.5) {
        final trigram = _trigramSim(q, _normalize(food.name));
        best = max(best, trigram * 0.75);
        for (final alias in food.aliases) {
          final t = _trigramSim(q, _normalize(alias));
          best = max(best, t * 0.75);
        }
      }

      if (best > 0) scored.add(RagMatch(food, best));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  /// En iyi eşleşmeyi döndürür. Skor < [_minScore] ise null.
  RagMatch? findBest(String query) {
    final results = search(query, topK: 1);
    if (results.isEmpty || results.first.score < _minScore) return null;
    return results.first;
  }

  // ── Hesaplama ────────────────────────────────────────────────────────────────

  /// FNDDS yemeği için verilen gram miktarına göre 65-besin değeri hesaplar.
  NutritionData65 calculate(FnddsFood food, double grams,
      {String? cookingMethod}) {
    final f = grams / 100.0;
    final lossF = _cookingLoss(cookingMethod);
    // Pişirme kaybı sadece su bazlı besinlere (protein, karbonhidrat) uygulanır.
    // Mineraller ve vitaminler farklı etkilenebilir; burada sadece enerji/makro.
    final mf = f * lossF;

    double n(String id) => food.nutrient(id);

    return NutritionData65(
      energy: _r(n(nEnergy) * mf),
      protein: _r(n(nProtein) * mf),
      fat: _r(n(nFat) * f), // yağ pişirmede azalmaz
      carb: _r(n(nCarb) * mf),
      fiber: _r(n(nFiber) * f),
      sugar: _r(n(nSugar) * mf),
      satFat: _r(n(nSatFat) * f),
      monoFat: _r(n(nMonoFat) * f),
      polyFat: _r(n(nPolyFat) * f),
      transFat: _r(n(nTransFat) * f),
      cholesterol: _r(n(nCholesterol) * f),
      water: _r(n(nWater) * f),
      ash: _r(n(nAsh) * f),
      calcium: _r(n(nCalcium) * f),
      iron: _r(n(nIron) * f),
      magnesium: _r(n(nMagnesium) * f),
      phosphorus: _r(n(nPhosphorus) * f),
      potassium: _r(n(nPotassium) * f),
      sodium: _r(n(nSodium) * f),
      zinc: _r(n(nZinc) * f),
      copper: _r(n(nCopper) * f),
      manganese: _r(n(nManganese) * f),
      selenium: _r(n(nSelenium) * f),
      vitC: _r(n(nVitC) * f),
      thiamine: _r(n(nThiamine) * f),
      riboflavin: _r(n(nRiboflavin) * f),
      niacin: _r(n(nNiacin) * f),
      pantothenic: _r(n(nPantothenic) * f),
      vitB6: _r(n(nVitB6) * f),
      folate: _r(n(nFolate) * f),
      vitB12: _r(n(nVitB12) * f),
      vitE: _r(n(nVitE) * f),
      vitD_mcg: _r(n(nVitD_mcg) * f),
      vitK: _r(n(nVitK) * f),
      omega3: _r(n(nOmega3) * f),
      omega6: _r(n(nOmega6) * f),
      ala: _r(n(nALA) * f),
      epa: _r(n(nEPA) * f),
      dha: _r(n(nDHA) * f),
      linoleic: _r(n(nLinoleic) * f),
      tryptophan: _r(n(nTryptophan) * f),
      threonine: _r(n(nThreonine) * f),
      isoleucine: _r(n(nIsoleucine) * f),
      leucine: _r(n(nLeucine) * f),
      lysine: _r(n(nLysine) * f),
      methionine: _r(n(nMethionine) * f),
      cystine: _r(n(nCystine) * f),
      phenylalanine: _r(n(nPhenylalanine) * f),
      tyrosine: _r(n(nTyrosine) * f),
      valine: _r(n(nValine) * f),
      histidine: _r(n(nHistidine) * f),
      dataSource: 'FNDDS',
      fdcId: food.fdcId,
    );
  }

  /// FNDDS eşleşmesinden [FoodAnalysisResult] üret.
  FoodAnalysisResult buildResult({
    required FnddsFood food,
    required double matchScore,
    required double portionGrams,
    String? cookingMethod,
    String? originalQuery,
  }) {
    // 100g başına 65-besin verisi (ölçeklenmemiş — FoodEntry portionSize ile ölçekler)
    final nd65per100g = calculate(food, 100, cookingMethod: cookingMethod);
    final nd100 = nd65per100g.toNutritionData();

    // Porsiyon için sadece kalori aralığı hesabına lazım
    final portionNd = calculate(food, portionGrams, cookingMethod: cookingMethod).toNutritionData();

    final confScore = (matchScore * 100).round().clamp(60, 98);

    return FoodAnalysisResult(
      foodName: originalQuery ?? food.name,
      cookingMethod: cookingMethod,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: nd65per100g,
      sources: const ['FNDDS'],
      confidenceScore: confScore,
      confidenceReason:
          'FNDDS veritabanı — ${food.name} (${(matchScore * 100).toStringAsFixed(0)}% eşleşme)',
      alternativeMin: portionNd.calories * 0.92,
      alternativeMax: portionNd.calories * 1.08,
    );
  }

  // ── Pişirme Kaybı ─────────────────────────────────────────────────────────

  double _cookingLoss(String? method) {
    if (method == null) return 1.0;
    final m = method.toLowerCase();
    if (m.contains('kızart') || m.contains('fry')) return 0.80;
    if (m.contains('fırın') || m.contains('bake') || m.contains('oven')) return 0.85;
    if (m.contains('haşla') || m.contains('boil')) return 0.90;
    if (m.contains('buharda') || m.contains('steam')) return 0.92;
    if (m.contains('ızgara') || m.contains('grill')) return 0.88;
    return 1.0;
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────────

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .trim();

  double _trigramSim(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final setA = _trigrams(a);
    final setB = _trigrams(b);
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    return intersection / max(setA.length, setB.length);
  }

  Set<String> _trigrams(String s) {
    if (s.length < 3) return {s};
    return {for (int i = 0; i <= s.length - 3; i++) s.substring(i, i + 3)};
  }

  double _r(double v) => (v * 10).round() / 10;
}
