import 'nutrition_data.dart';
import 'nutrition_data_65.dart';
import '../services/open_food_facts_service.dart';

/// Çok kaynaklı analiz sonucu — NutritionData'ya metadata ekler
class FoodAnalysisResult {
  final String foodName;
  final String? cookingMethod;
  final double portionGrams;
  final double? volumeMl;
  final String? referenceObject;
  final String? portionDescription;

  /// 100g başına beslenme değerleri (ölçeklendirilmemiş)
  final NutritionData nutritionPer100g;

  /// 65-besin değeri (FNDDS kaynağı olduğunda dolu, yoksa null)
  final NutritionData65? nutrition65per100g;

  /// OpenFoodFacts ürün verisi (barkod/isim eşleşmesi varsa dolu)
  final OFFProduct? offProduct;

  /// Porsiyon miktarına göre ölçeklendirilmiş değerler
  NutritionData get nutritionScaled =>
      nutritionPer100g.scaleBy(portionGrams / 100.0);

  /// Kaynaklar: 'USDA', 'OpenFoodFacts', 'Turkish_DB', 'User', 'Claude'
  final List<String> sources;

  /// Tek string kaynak (sources.join(', ') kısayolu)
  String get source => sources.join(', ');

  /// 0–100 güven skoru
  final int confidenceScore;
  final String? confidenceReason;

  /// Kalori belirsizlik aralığı (ölçeklendirilmiş)
  final double alternativeMin;
  final double alternativeMax;

  const FoodAnalysisResult({
    required this.foodName,
    this.cookingMethod,
    required this.portionGrams,
    this.volumeMl,
    this.referenceObject,
    this.portionDescription,
    required this.nutritionPer100g,
    this.nutrition65per100g,
    this.offProduct,
    required this.sources,
    required this.confidenceScore,
    this.confidenceReason,
    required this.alternativeMin,
    required this.alternativeMax,
  });

  factory FoodAnalysisResult.empty() => const FoodAnalysisResult(
        foodName: 'Bilinmeyen',
        portionGrams: 100,
        nutritionPer100g: NutritionData.empty,
        sources: [],
        confidenceScore: 0,
        alternativeMin: 0,
        alternativeMax: 0,
      );

  /// Claude Vision JSON çıktısından oluştur
  factory FoodAnalysisResult.fromClaudeJson(Map<String, dynamic> json) {
    double g(String k, [double def = 0]) =>
        (json[k] as num?)?.toDouble() ?? def;
    double? gn(String k) => json[k] == null ? null : (json[k] as num).toDouble();

    final portionGrams = g('porsiyon_gram', 100);
    final factor = portionGrams > 0 ? portionGrams / 100.0 : 1.0;
    final kalori = g('kalori') / factor;
    final minK = g('min_kalori', kalori * 0.85) / factor;
    final maxK = g('max_kalori', kalori * 1.15) / factor;

    // min_kalori / max_kalori alternatif yapıda gelebilir
    final alt = json['alternatif_tahmin'] as Map<String, dynamic>?;
    final altMin = alt != null
        ? (alt['min_kalori'] as num?)?.toDouble() ?? (kalori * 0.85)
        : minK;
    final altMax = alt != null
        ? (alt['max_kalori'] as num?)?.toDouble() ?? (kalori * 1.15)
        : maxK;

    return FoodAnalysisResult(
      foodName: json['yemek_adi']?.toString() ?? 'Bilinmeyen',
      cookingMethod: json['pişirme_yöntemi']?.toString(),
      portionGrams: portionGrams,
      volumeMl: gn('hacim_ml'),
      referenceObject: json['referans_nesne']?.toString(),
      portionDescription: json['porsiyon_aciklamasi']?.toString(),
      nutritionPer100g: NutritionData(
        calories: kalori,
        protein: g('protein') / factor,
        carbohydrates: g('karbonhidrat') / factor,
        fat: g('yag') / factor,
        fiber: g('lif') / factor,
        sugar: g('seker') / factor,
        saturatedFat: g('doymus_yag') / factor,
        sodium: gn('sodyum') != null ? gn('sodyum')! / factor : null,
        magnesium: gn('magnezyum') != null ? gn('magnezyum')! / factor : null,
        vitaminA: (gn('vitaminA') ?? gn('vitamin_a')) != null ? (gn('vitaminA') ?? gn('vitamin_a'))! / factor : null,
        vitaminC: (gn('vitaminC') ?? gn('vitamin_c')) != null ? (gn('vitaminC') ?? gn('vitamin_c'))! / factor : null,
        vitaminD: (gn('vitaminD') ?? gn('vitamin_d')) != null ? (gn('vitaminD') ?? gn('vitamin_d'))! / factor : null,
        vitaminE: (gn('vitaminE') ?? gn('vitamin_e')) != null ? (gn('vitaminE') ?? gn('vitamin_e'))! / factor : null,
        vitaminK: (gn('vitaminK') ?? gn('vitamin_k')) != null ? (gn('vitaminK') ?? gn('vitamin_k'))! / factor : null,
        vitaminB6: (gn('vitaminB6') ?? gn('vitamin_b6')) != null ? (gn('vitaminB6') ?? gn('vitamin_b6'))! / factor : null,
        vitaminB12: (gn('vitaminB12') ?? gn('vitamin_b12')) != null ? (gn('vitaminB12') ?? gn('vitamin_b12'))! / factor : null,
        folate: (gn('folate') ?? gn('folat')) != null ? (gn('folate') ?? gn('folat'))! / factor : null,
        iron: gn('demir') != null ? gn('demir')! / factor : null,
        calcium: gn('kalsiyum') != null ? gn('kalsiyum')! / factor : null,
        potassium: gn('potasyum') != null ? gn('potasyum')! / factor : null,
        zinc: gn('cinko') != null ? gn('cinko')! / factor : null,
        selenium: gn('selenyum') != null ? gn('selenyum')! / factor : null,
        omega3: gn('omega3') != null ? gn('omega3')! / factor : null,
        omega6: gn('omega6') != null ? gn('omega6')! / factor : null,
      ),
      sources: const ['Claude'],
      confidenceScore: (json['guven_skoru'] as num?)?.toInt() ?? 50,
      confidenceReason: json['guven_nedeni']?.toString(),
      alternativeMin: altMin,
      alternativeMax: altMax,
    );
  }

  FoodAnalysisResult copyWith({
    String? foodName,
    String? cookingMethod,
    double? portionGrams,
    NutritionData? nutritionPer100g,
    List<String>? sources,
    int? confidenceScore,
    String? confidenceReason,
    double? alternativeMin,
    double? alternativeMax,
  }) {
    return FoodAnalysisResult(
      foodName: foodName ?? this.foodName,
      cookingMethod: cookingMethod ?? this.cookingMethod,
      portionGrams: portionGrams ?? this.portionGrams,
      volumeMl: volumeMl,
      referenceObject: referenceObject,
      portionDescription: portionDescription,
      nutritionPer100g: nutritionPer100g ?? this.nutritionPer100g,
      sources: sources ?? this.sources,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceReason: confidenceReason ?? this.confidenceReason,
      alternativeMin: alternativeMin ?? this.alternativeMin,
      alternativeMax: alternativeMax ?? this.alternativeMax,
    );
  }
}
