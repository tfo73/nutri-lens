import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_analysis_result.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import 'config_service.dart';
import 'edamam_nutrition_service.dart';
import 'open_food_facts_service.dart';
import 'usda_api_service.dart';
import 'usda_cache_service.dart';

// ─── Internal models ───────────────────────────────────────────────────────────

class _FoodIdentification {
  final String foodName;
  final String? foodNameEn;
  final String yemekTipi;
  final int confidenceScore;
  final String cookingMethod;
  final double portionGram;

  const _FoodIdentification({
    required this.foodName,
    this.foodNameEn,
    required this.yemekTipi,
    required this.confidenceScore,
    required this.cookingMethod,
    required this.portionGram,
  });
}

// ─── Service ───────────────────────────────────────────────────────────────────

class FoodAnalysisService {
  String get _apiKey => ConfigService.anthropicKey;

  // ── Atwater sabitleri ──────────────────────────────────────────────────────

  static const double _proteinKcal = 4.0;
  static const double _carbKcal = 4.0;
  static const double _fatKcal = 9.0;

  /// Uygulamanın tek kalori hesaplama noktası — Atwater, en yakın 5'e yuvarla.
  static double calculateCalories({
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    final raw =
        (proteinG * _proteinKcal) + (carbsG * _carbKcal) + (fatG * _fatKcal);
    return (raw / 5).round() * 5.0;
  }

  /// Yemek tipine göre sabit varsayılan porsiyon (gram).
  static double _defaultPortion(String yemekTipi) {
    switch (yemekTipi) {
      case 'corba':
        return 250;
      case 'ana_yemek':
        return 300;
      case 'salata':
        return 150;
      case 'tatli':
        return 100;
      case 'icecek':
        return 200;
      case 'kahvalti':
        return 200;
      case 'atistirmalik':
        return 50;
      default:
        return 200;
    }
  }

  // ── Görüntü Ön İşleme ─────────────────────────────────────────────────────

  /// Görüntüyü API için küçültür ve base64'e çevirir (disk I/O yok).
  Future<String> _preprocessToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return base64Encode(bytes);

    // 768px yeterli — yemek tanıma için 1024 gereksiz
    if (image.width > 768 || image.height > 768) {
      if (image.width >= image.height) {
        image = img.copyResize(image, width: 768);
      } else {
        image = img.copyResize(image, height: 768);
      }
    }
    return base64Encode(img.encodeJpg(image, quality: 75));
  }

  // ── Aşama 1: Hızlı kimlik tespiti (Haiku, küçük yanıt) ──────────────────

  Future<Map<String, dynamic>> _analyzeImageFast(
      String base64Image, String? hint) async {
    final prompt = '''
You are a world-class clinical dietitian and advanced computer vision nutrition analyst. Your task is to analyze the food image provided (and utilize any optional user hint) with extreme precision.

User hint/note: "${hint ?? ''}"

STEP 0 — IMAGE QUALITY ASSESSMENT
Before estimating nutrients:
- Determine whether the image quality is sufficient.
- Evaluate: lighting, blur, occlusion, camera angle, visibility of all foods, presence of size reference (plate, fork, hand, cup etc.).
- Decide the image quality: excellent | good | fair | poor.
- Decide portion estimation confidence: high | medium | low.
- Decide food identification confidence: high | medium | low.
- Decide the general confidence score (0-100). If confidence < 60, explain what limits the estimation in "guven_nedeni" (Turkish) and "guven_nedeni_en" (English).

STEP 1 — IDENTIFICATION & QUANTIFICATION:
1. Identify the most probable food item based on the visual evidence. If multiple interpretations are possible, choose the most likely one. Write the Turkish name in "yemek_adi" (e.g. "Sade Omlet") and its English name in "yemek_adi_en" (e.g. "Plain Omelette").
2. You must never refuse because estimation is imperfect. Your goal is to produce the best clinically reasonable estimate from the available visual information. Do not answer "cannot determine" unless the food is completely unrecognizable.
3. Estimate the portion weight in grams ("porsiyon_gram"). If the food is primarily liquid, prioritize volume estimation (mL) instead of weight and set "porsiyon_gram" to its equivalent weight.
4. When estimating portion size, consider whether the presentation resembles: a homemade meal, restaurant serving, fast-food serving, or packaged food. Adjust the estimated portion accordingly.
5. Portion weight estimates should use realistic practical values. Prefer increments of approximately 5–10 g unless there is strong visual evidence for greater precision (e.g. use 150g or 155g, not 153g).
6. Round values consistently: Weight: nearest 5 g, Calories: nearest whole number, Macronutrients: 1 decimal place, Micronutrients: 1 decimal place (or whole numbers where appropriate).
7. If multiple identical food items are present (e.g. 6 meatballs, 12 sushi rolls, 3 nuggets), estimate the portion size and calories of one item first, then multiply by the detected count.
8. If multiple different foods are detected, estimate each component separately and sum all nutrients for the totals.
9. Do not invent ingredients. Only infer hidden ingredients (like butter, cooking oil, cream, cheese, sugar) that are commonly expected from the identified cooking method. Prefer conservative estimates over aggressive assumptions. When visual evidence is insufficient, choose the most statistically typical value rather than an extreme value.
10. Estimate cooking oil separately. If oil is visually present, estimate absorbed oil based on cooking method. If uncertain, assume the average oil absorption for that cooking technique.
11. Unless otherwise indicated, estimate nutrients for the food in its cooked edible form.
12. Identify the cooking method (raw|boiled|grilled|fried|baked|other) and set "pisirme". Identify the food type (soup|main_dish|salad|dessert|drink|breakfast|snack) and set "yemek_tipi".

STEP 2 — MACRONUTRIENT & CALORIE CALCULATION (PER 100G OF THE FOOD):
- Calculate all values PER 100G of the food.
- Calculate protein, carbohydrates, fat, fiber, sugar, saturated fat, etc.
- Use USDA FoodData Central as the primary reference. If the exact food is unavailable, use the closest nutritionally equivalent food.
- Protein, fat, carbohydrate and fiber must be internally consistent.
- Ensure the sum of protein + carbohydrates + fat <= 100g.
- Ensure the sum of amino acids <= protein.

STEP 3 — MICRONUTRIENT & ESSENTIAL NUTRIENT ESTIMATION (PER 100G OF THE FOOD):
- Estimate micronutrients proportionally to the estimated ingredients per 100g.
- Never output zero unless the nutrient is biologically absent from the food.
- Required nutrients match the schema keys precisely.

STEP 4 — USER HINT HANDLING:
- If the user provides a hint (food name, restaurant, ingredients, cooking method, or portion size), use it only if it is consistent with the image.
- Never override obvious visual evidence with the user hint.

STEP 5 — FINAL VALIDATION
Before returning JSON, verify:
✓ Macronutrients match the estimated portion per 100g
✓ Micronutrients are realistic
✓ No biologically impossible values
✓ Sodium is plausible
✓ Sugar is plausible
✓ Saturated fat <= total fat
✓ Fiber <= carbohydrate
✓ All numeric values must be numbers. Do not include units in JSON values. Units belong only to the schema documentation.
✓ Output MUST match the provided JSON Schema exactly. Do not omit required fields. Do not add extra fields. Populate every field. Use 0.0 only when a value is genuinely inapplicable.

GENERAL PRINCIPLE:
Favor nutritional realism over visual precision. The objective is to produce the most clinically plausible nutritional estimate rather than an exact visual measurement.
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${ConfigService.openaiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'max_tokens': 2000,
        'temperature': 0.0,
        'top_p': 1.0,
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'food_analysis_response',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'yemek_adi': { 'type': 'string' },
                'yemek_adi_en': { 'type': 'string' },
                'yemek_tipi': { 'type': 'string' },
                'pisirme': { 'type': 'string' },
                'porsiyon_gram': { 'type': 'number' },
                'guven_skoru': { 'type': 'number' },
                'guven_nedeni': { 'type': 'string' },
                'guven_nedeni_en': { 'type': 'string' },
                'protein': { 'type': 'number' },
                'karbonhidrat': { 'type': 'number' },
                'yag': { 'type': 'number' },
                'lif': { 'type': 'number' },
                'seker': { 'type': 'number' },
                'doymus_yag': { 'type': 'number' },
                'tekli_doymus_yag': { 'type': 'number' },
                'coklu_doymus_yag': { 'type': 'number' },
                'trans_yag': { 'type': 'number' },
                'kolesterol_mg': { 'type': 'number' },
                'su': { 'type': 'number' },
                'kalsiyum_mg': { 'type': 'number' },
                'demir_mg': { 'type': 'number' },
                'magnezyum_mg': { 'type': 'number' },
                'fosfor_mg': { 'type': 'number' },
                'potasyum_mg': { 'type': 'number' },
                'sodyum_mg': { 'type': 'number' },
                'cinko_mg': { 'type': 'number' },
                'bakir_mg': { 'type': 'number' },
                'manganez_mg': { 'type': 'number' },
                'selenyum_mcg': { 'type': 'number' },
                'iyot_mcg': { 'type': 'number' },
                'krom_mcg': { 'type': 'number' },
                'molibden_mcg': { 'type': 'number' },
                'c_vitamini_mg': { 'type': 'number' },
                'd_vitamini_mcg': { 'type': 'number' },
                'e_vitamini_mg': { 'type': 'number' },
                'k1_vitamini_mcg': { 'type': 'number' },
                'a_vitamini_mcg': { 'type': 'number' },
                'beta_karoten_mcg': { 'type': 'number' },
                'likopen_mcg': { 'type': 'number' },
                'lutein_zea_mcg': { 'type': 'number' },
                'b1_tiamin_mg': { 'type': 'number' },
                'b2_riboflavin_mg': { 'type': 'number' },
                'b3_niasin_mg': { 'type': 'number' },
                'b5_pantotenik_mg': { 'type': 'number' },
                'b6_mg': { 'type': 'number' },
                'folat_mcg': { 'type': 'number' },
                'b12_mcg': { 'type': 'number' },
                'kolin_mg': { 'type': 'number' },
                'biotin_mcg': { 'type': 'number' },
                'omega3_g': { 'type': 'number' },
                'omega6_g': { 'type': 'number' },
                'epa_g': { 'type': 'number' },
                'dha_g': { 'type': 'number' },
                'ala_g': { 'type': 'number' },
                'linoleik_g': { 'type': 'number' },
                'losin_g': { 'type': 'number' },
                'lizin_g': { 'type': 'number' },
                'valin_g': { 'type': 'number' },
                'izolosin_g': { 'type': 'number' },
                'treonin_g': { 'type': 'number' },
                'metionin_g': { 'type': 'number' },
                'fenilalanin_g': { 'type': 'number' },
                'triptofan_g': { 'type': 'number' },
                'histidin_g': { 'type': 'number' },
                'sistin_g': { 'type': 'number' },
                'tirozin_g': { 'type': 'number' }
              },
              'required': [
                'yemek_adi', 'yemek_adi_en', 'yemek_tipi', 'pisirme', 'porsiyon_gram', 'guven_skoru', 'guven_nedeni', 'guven_nedeni_en',
                'protein', 'karbonhidrat', 'yag', 'lif', 'seker', 'doymus_yag', 'tekli_doymus_yag', 'coklu_doymus_yag', 'trans_yag', 'kolesterol_mg', 'su',
                'kalsiyum_mg', 'demir_mg', 'magnezyum_mg', 'fosfor_mg', 'potasyum_mg', 'sodyum_mg', 'cinko_mg', 'bakir_mg', 'manganez_mg', 'selenyum_mcg', 'iyot_mcg', 'krom_mcg', 'molibden_mcg',
                'c_vitamini_mg', 'd_vitamini_mcg', 'e_vitamini_mg', 'k1_vitamini_mcg', 'a_vitamini_mcg', 'beta_karoten_mcg', 'likopen_mcg', 'lutein_zea_mcg',
                'b1_tiamin_mg', 'b2_riboflavin_mg', 'b3_niasin_mg', 'b5_pantotenik_mg', 'b6_mg', 'folat_mcg', 'b12_mcg', 'kolin_mg', 'biotin_mcg',
                'omega3_g', 'omega6_g', 'epa_g', 'dha_g', 'ala_g', 'linoleik_g', 'losin_g', 'lizin_g', 'valin_g', 'izolosin_g', 'treonin_g', 'metionin_g', 'fenilalanin_g', 'triptofan_g', 'histidin_g', 'sistin_g', 'tirozin_g'
              ],
              'additionalProperties': false
            }
          }
        },
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['choices'][0]['message']['content'] as String;
      final clean = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } else {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }
  }


  // ── Kullanıcı Geçmişi ──────────────────────────────────────────────────────

  Future<NutritionData?> _checkUserHistory(String foodName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correction_${foodName.toLowerCase().trim()}';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return NutritionData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Kullanıcı düzeltmesini ağırlıklı ortalama ile kaydet.
  Future<void> saveCorrection(
    String foodName,
    NutritionData correctedNutrition,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correction_${foodName.toLowerCase().trim()}';
    final countKey = '${key}_count';

    final existingRaw = prefs.getString(key);
    final count = prefs.getInt(countKey) ?? 0;

    final NutritionData merged;
    if (existingRaw != null && count > 0) {
      final existing = NutritionData.fromJson(
          jsonDecode(existingRaw) as Map<String, dynamic>);
      double wavg(double a, double b) =>
          _round1((a * count + b) / (count + 1));
      merged = NutritionData(
        calories: wavg(existing.calories, correctedNutrition.calories),
        protein: wavg(existing.protein, correctedNutrition.protein),
        carbohydrates:
            wavg(existing.carbohydrates, correctedNutrition.carbohydrates),
        fat: wavg(existing.fat, correctedNutrition.fat),
        fiber: wavg(existing.fiber, correctedNutrition.fiber),
        sugar: wavg(existing.sugar, correctedNutrition.sugar),
        saturatedFat:
            wavg(existing.saturatedFat, correctedNutrition.saturatedFat),
        sodium: correctedNutrition.sodium,
        vitaminC: correctedNutrition.vitaminC,
        vitaminD: correctedNutrition.vitaminD,
        vitaminB12: correctedNutrition.vitaminB12,
        iron: correctedNutrition.iron,
        calcium: correctedNutrition.calcium,
        magnesium: correctedNutrition.magnesium,
        potassium: correctedNutrition.potassium,
        omega3: correctedNutrition.omega3,
      );
    } else {
      merged = correctedNutrition;
    }

    await prefs.setString(key, jsonEncode(merged.toJson()));
    await prefs.setInt(countKey, count + 1);
  }

  // ── Dış servisler ─────────────────────────────────────────────────────────

  final _usda = UsdaApiService();
  final _cache = UsdaCacheService.instance;
  final _off = OpenFoodFactsService();

  // Türkçe → İngilizce sorgu çevirisi
  static const Map<String, String> _trToEn = {
    'tavuk': 'chicken', 'köfte': 'beef meatball',
    'pilav': 'rice pilaf', 'mercimek': 'lentil',
    'bulgur': 'bulgur wheat', 'nohut': 'chickpea',
    'ızgara': 'grilled', 'haşlama': 'boiled',
    'kızartma': 'fried', 'çorba': 'soup',
    'salata': 'salad', 'börek': 'pastry',
    'yoğurt': 'yogurt', 'peynir': 'cheese',
    'ekmek': 'bread', 'domates': 'tomato',
    'patlıcan': 'eggplant', 'somon': 'salmon',
    'ton balığı': 'tuna', 'karides': 'shrimp',
    'yumurta': 'egg', 'süt': 'milk',
    'kıyma': 'ground beef', 'kuzu': 'lamb',
    'dana': 'beef', 'hindi': 'turkey',
    'balık': 'fish', 'fasulye': 'beans',
    'patates': 'potato', 'pirinç': 'rice',
    'makarna': 'pasta', 'soğan': 'onion',
    'havuç': 'carrot', 'ıspanak': 'spinach',
    'elma': 'apple', 'muz': 'banana',
    'portakal': 'orange', 'badem': 'almond',
    'ceviz': 'walnut', 'zeytinyağı': 'olive oil',
  };

  String _toEnglish(String tr) {
    final lower = tr.toLowerCase();
    for (final entry in _trToEn.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return tr;
  }

  /// Pişirme yöntemini USDA sorgusuna ekler (ızgara tavuk, kızartılmış patates…)
  String _toEnglishWithCooking(String tr, String cooking) {
    final base = _toEnglish(tr);
    final prefix = switch (cooking) {
      'izgara' => 'grilled',
      'kizartma' => 'fried',
      'hashlama' => 'boiled',
      'firin' => 'baked',
      _ => null,
    };
    return prefix != null ? '$prefix $base' : base;
  }

  Future<FoodAnalysisResult> analyzeText(String description) async {
    final json = await _callClaude(
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': '''
You are an expert nutrition coach and food analyst with deep knowledge of "Nutrition5k" and "USDA" data standards. Virtually segment the dish described by the user and analyze it with high precision: "$description"
1. Determine the exact name of the food. Set "yemek_adi" to the language of the user's description (if user describes it in English, "yemek_adi" MUST be in English. If user describes it in Turkish, "yemek_adi" MUST be in Turkish). Set "yemek_adi_en" to English.
2. Calculate the portion weight in grams for the entire dish.
3. Segment the dish into its main component ingredients.
4. For each main component, select an EXACT USDA standard entry (e.g., USDA 170456 Cooked Salmon) and calculate the cumulative macro/micronutrients by weight.

--- IN-CONTEXT CALIBRATION RULES ---
Rule 1: As meat cooks, it shrinks in volume, increasing its macros/micros per 100g.
Rule 2: As grains cook, they absorb water, decreasing their macros/micros per 100g.
Rule 3: You MUST NOT return 0 or null for micronutrients if the ingredients are known to contain them. You MUST estimate realistic, USDA-aligned values (per 100g) for all standard vitamins, minerals, amino acids, and fatty acids known to exist in the ingredients.
  - For eggs (yumurta): Eggs are extremely nutrient-dense. You MUST estimate realistic non-zero values per 100g. Typical values per 100g of whole raw egg are: water (76g), cholesterol_mg (370mg), sodium_mg (140mg), kalsiyum_mg (50mg), demir_mg (1.75mg), magnezyum_mg (12mg), fosfor_mg (198mg), potasyum_mg (138mg), cinko_mg (1.29mg), bakir_mg (0.07mg), manganez_mg (0.02mg), selenyum_mcg (30mcg), a_vitamini_mcg (140mcg), e_vitamini_mg (1mg), d_vitamini_mcg (2mcg), b1_tiamin_mg (0.04mg), b2_riboflavin_mg (0.45mg), b3_niasin_mg (0.07mg), b5_pantotenik_mg (1.4mg), b6_mg (0.17mg), folat_mcg (44mcg), b12_mcg (0.89mcg), kolin_mg (290mg), biotin_mcg (20mcg), omega3_g (0.1g), omega6_g (1.1g), and all standard amino acids (losin_g, lizin_g, valin_g, izolosin_g, treonin_g, metionin_g, fenilalanin_g, triptofan_g, histidin_g, sistin_g, tirozin_g). DO NOT set these to 0.
  - For meats: Estimate realistic non-zero values for iron, zinc, selenium, phosphorus, potassium, B-vitamins (B1, B2, B3, B5, B6, B12), and amino acids.
  - For dairy: Estimate calcium, phosphorus, B2 (riboflavin), B12, vitamin A, and zinc.
  - For grains: Estimate magnesium, iron, selenium, zinc, manganese, and B-vitamins.
  - For vegetables: Estimate vitamin C, folate, potassium, calcium, vitamin K, beta-carotene, and fiber.

Rule 5: If the description is extremely brief or ambiguous (e.g., just "egg", "yumurta", "chicken", or "et" without specific quantities, portions, or cooking styles):
  - Do NOT default to any cooked or processed preparation (e.g., do NOT assume "boiled egg"/"haşlanmış yumurta" or "grilled chicken" unless the user explicitly said "haşlanmış", "kızartılmış", "ızgara", etc. in their description). Instead, default to the raw/standard whole version of that ingredient (e.g., set the name to "Yumurta" or "Bütün Yumurta" as a raw whole egg of 50g; chicken as raw chicken breast of 100g). Set "pisirme" to "raw".
  - Calculate portion size based on a standard single portion (e.g., 1 whole raw egg ≈ 50g, raw chicken breast ≈ 100g, meat portion ≈ 150g).
  - Set "guven_skoru" below 70 (e.g., 60 or 65) to indicate it's an estimate.
  - Write a helpful, specific recommendation in Turkish in "guven_nedeni" advising the user to specify cooking method, portion, or ingredients for higher accuracy (e.g., "Yumurtanın pişirilme şeklini (haşlanmış, sahanda vb.) ve miktarını yazarak daha kesin sonuçlar alabilirsiniz.").
  - Write the same recommendation in English in "guven_nedeni_en" contextually and naturally (e.g., "For more accurate results, try specifying the cooking method (boiled, fried, etc.) and portion size.").
------------------------------------------------

Return ONLY JSON, nothing else. All values must be per 100g:
{"yemek_adi":"string","yemek_adi_en":"string","yemek_tipi":"soup|main_dish|salad|dessert|drink|breakfast|snack","pisirme":"raw|boiled|grilled|fried|baked|other","porsiyon_gram":number,"guven_skoru":number,"guven_nedeni":"string","guven_nedeni_en":"string","protein":number,"karbonhidrat":number,"yag":number,"lif":number,"seker":number,"doymus_yag":number,"tekli_doymus_yag":number,"coklu_doymus_yag":number,"trans_yag":number,"kolesterol_mg":number,"su":number,"kalsiyum_mg":number,"demir_mg":number,"magnezyum_mg":number,"fosfor_mg":number,"potasyum_mg":number,"sodyum_mg":number,"cinko_mg":number,"bakir_mg":number,"manganez_mg":number,"selenyum_mcg":number,"iyot_mcg":number,"krom_mcg":number,"molibden_mcg":number,"c_vitamini_mg":number,"d_vitamini_mcg":number,"e_vitamini_mg":number,"k1_vitamini_mcg":number,"a_vitamini_mcg":number,"beta_karoten_mcg":number,"likopen_mcg":number,"lutein_zea_mcg":number,"b1_tiamin_mg":number,"b2_riboflavin_mg":number,"b3_niasin_mg":number,"b5_pantotenik_mg":number,"b6_mg":number,"folat_mcg":number,"b12_mcg":number,"kolin_mg":number,"biotin_mcg":number,"omega3_g":number,"omega6_g":number,"epa_g":number,"dha_g":number,"ala_g":number,"linoleik_g":number,"losin_g":number,"lizin_g":number,"valin_g":number,"izolosin_g":number,"treonin_g":number,"metionin_g":number,"fenilalanin_g":number,"triptofan_g":number,"histidin_g":number,"sistin_g":number,"tirozin_g":number}

Rules: If unknown, write 0. protein+karbonhidrat+yag ≤ 100. Sum of amino acids ≤ protein.
''',
            }
          ],
        }
      ],
      maxTokens: 2000,
    );

    double g(String k) => (json[k] as num?)?.toDouble() ?? 0.0;

    final foodName = (json['yemek_adi'] as String?) ?? 'Bilinmeyen';
    final foodNameEn = json['yemek_adi_en'] as String?;
    final portionGrams = (json['porsiyon_gram'] as num?)?.toDouble() ?? 200.0;

    final n65 = NutritionData65(
      energy: calculateCalories(
        proteinG: g('protein'),
        carbsG: g('karbonhidrat'),
        fatG: g('yag'),
      ),
      protein: g('protein'),
      fat: g('yag'),
      carb: g('karbonhidrat'),
      fiber: g('lif'),
      sugar: g('seker'),
      satFat: g('doymus_yag'),
      monoFat: g('tekli_doymus_yag'),
      polyFat: g('coklu_doymus_yag'),
      transFat: g('trans_yag'),
      cholesterol: g('kolesterol_mg'),
      water: g('su'),
      calcium: g('kalsiyum_mg'),
      iron: g('demir_mg'),
      magnesium: g('magnezyum_mg'),
      phosphorus: g('fosfor_mg'),
      potassium: g('potasyum_mg'),
      sodium: g('sodyum_mg'),
      zinc: g('cinko_mg'),
      copper: g('bakir_mg'),
      manganese: g('manganez_mg'),
      selenium: g('selenyum_mcg'),
      iodine: g('iyot_mcg'),
      chromium: g('krom_mcg'),
      molybdenum: g('molibden_mcg'),
      vitC: g('c_vitamini_mg'),
      vitD_mcg: g('d_vitamini_mcg'),
      vitE: g('e_vitamini_mg'),
      vitK: g('k1_vitamini_mcg'),
      vitA_RAE: g('a_vitamini_mcg'),
      betaCarot: g('beta_karoten_mcg'),
      lycopene: g('likopen_mcg'),
      luteinZea: g('lutein_zea_mcg'),
      thiamine: g('b1_tiamin_mg'),
      riboflavin: g('b2_riboflavin_mg'),
      niacin: g('b3_niasin_mg'),
      pantothenic: g('b5_pantotenik_mg'),
      vitB6: g('b6_mg'),
      folate: g('folat_mcg'),
      vitB12: g('b12_mcg'),
      choline: g('kolin_mg'),
      biotin: g('biotin_mcg'),
      omega3: g('omega3_g'),
      omega6: g('omega6_g'),
      ala: g('ala_g'),
      epa: g('epa_g'),
      dha: g('dha_g'),
      linoleic: g('linoleik_g'),
      leucine: g('losin_g'),
      lysine: g('lizin_g'),
      valine: g('valin_g'),
      isoleucine: g('izolosin_g'),
      threonine: g('treonin_g'),
      methionine: g('metionin_g'),
      phenylalanine: g('fenilalanin_g'),
      tryptophan: g('triptofan_g'),
      histidine: g('histidin_g'),
      cystine: g('sistin_g'),
      tyrosine: g('tirozin_g'),
      dataSource: 'Claude (Text)',
    );

    final nd100 = n65.toNutritionData();

    final portionCalories = calculateCalories(
      proteinG: _round1(nd100.protein * portionGrams / 100),
      carbsG: _round1(nd100.carbohydrates * portionGrams / 100),
      fatG: _round1(nd100.fat * portionGrams / 100),
    );

    return FoodAnalysisResult(
      foodName: foodName,
      foodNameEn: foodNameEn,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: n65,
      sources: const ['Claude (Text)'],
      confidenceScore: (json['guven_skoru'] as num?)?.toInt() ?? 85,
      confidenceReason: (json['guven_nedeni'] as String?) ?? '',
      confidenceReasonEn: (json['guven_nedeni_en'] as String?) ?? '',
      alternativeMin: portionCalories * 0.9,
      alternativeMax: portionCalories * 1.1,
    );
  }

  // ── ANA ANALİZ FONKSİYONU ──────────────────────────────────────────────────

  Future<FoodAnalysisResult> analyze({
    required File image,
    String? hint,
    double? gramsHint,
    String? barcode,
  }) async {
    // Aşama 0: Barkod varsa direkt OFF araması
    if (barcode != null) {
      final offProduct = await _off.getByBarcode(barcode);
      if (offProduct != null && offProduct.calories > 0) {
        return _buildFromOff(offProduct, gramsHint ?? 100);
      }
    }

    // Aşama 1: Görüntüyü hazırla
    final base64Image = await _preprocessToBase64(image);

    // Aşama 2: Tek bir API çağrısı ile kimlik ve 65 besin değerini al (Haiku)
    final json = await _analyzeImageFast(base64Image, hint);

    final foodName = (json['yemek_adi'] as String?) ?? 'Bilinmeyen';
    final foodNameEn = json['yemek_adi_en'] as String?;
    final yemekTipi = (json['yemek_tipi'] as String?) ?? 'ana_yemek';
    final aiPortion = (json['porsiyon_gram'] as num?)?.toDouble() ?? 0;
    final confidence = (json['guven_skoru'] as num?)?.toInt() ?? 85;
    final confReason = (json['guven_nedeni'] as String?) ?? '';
    final confReasonEn = (json['guven_nedeni_en'] as String?) ?? '';

    final portionGrams = gramsHint ?? (aiPortion > 0 ? aiPortion : _defaultPortion(yemekTipi));

    // Aşama 3: Geçmişi paralel kontrol et
    final history = await _checkUserHistory(foodName);

    double g(String k) => (json[k] as num?)?.toDouble() ?? 0.0;

    final baseN65 = NutritionData65(
      energy: calculateCalories(
        proteinG: g('protein'),
        carbsG: g('karbonhidrat'),
        fatG: g('yag'),
      ),
      protein: g('protein'),
      fat: g('yag'),
      carb: g('karbonhidrat'),
      fiber: g('lif'),
      sugar: g('seker'),
      satFat: g('doymus_yag'),
      monoFat: g('tekli_doymus_yag'),
      polyFat: g('coklu_doymus_yag'),
      transFat: g('trans_yag'),
      cholesterol: g('kolesterol_mg'),
      water: g('su'),
      calcium: g('kalsiyum_mg'),
      iron: g('demir_mg'),
      magnesium: g('magnezyum_mg'),
      phosphorus: g('fosfor_mg'),
      potassium: g('potasyum_mg'),
      sodium: g('sodyum_mg'),
      zinc: g('cinko_mg'),
      copper: g('bakir_mg'),
      manganese: g('manganez_mg'),
      selenium: g('selenyum_mcg'),
      iodine: g('iyot_mcg'),
      chromium: g('krom_mcg'),
      vitC: g('c_vitamini_mg'),
      vitD_mcg: g('d_vitamini_mcg'),
      vitE: g('e_vitamini_mg'),
      vitK: g('k1_vitamini_mcg'),
      vitA_RAE: g('a_vitamini_mcg'),
      betaCarot: g('beta_karoten_mcg'),
      lycopene: g('likopen_mcg'),
      luteinZea: g('lutein_zea_mcg'),
      thiamine: g('b1_tiamin_mg'),
      riboflavin: g('b2_riboflavin_mg'),
      niacin: g('b3_niasin_mg'),
      pantothenic: g('b5_pantotenik_mg'),
      vitB6: g('b6_mg'),
      folate: g('folat_mcg'),
      vitB12: g('b12_mcg'),
      choline: g('kolin_mg'),
      biotin: g('biotin_mcg'),
      omega3: g('omega3_g'),
      omega6: g('omega6_g'),
      ala: g('ala_g'),
      epa: g('epa_g'),
      dha: g('dha_g'),
      linoleic: g('linoleik_g'),
      leucine: g('losin_g'),
      lysine: g('lizin_g'),
      valine: g('valin_g'),
      isoleucine: g('izolosin_g'),
      threonine: g('treonin_g'),
      methionine: g('metionin_g'),
      phenylalanine: g('fenilalanin_g'),
      tryptophan: g('triptofan_g'),
      histidine: g('histidin_g'),
      cystine: g('sistin_g'),
      tyrosine: g('tirozin_g'),
      dataSource: 'Claude',
    );

    final NutritionData65 finalN65;
    final bool fromHistory;
    if (history != null) {
      finalN65 = NutritionData65(
        energy: calculateCalories(
          proteinG: history.protein,
          carbsG: history.carbohydrates,
          fatG: history.fat,
        ),
        protein: history.protein,
        fat: history.fat,
        carb: history.carbohydrates,
        fiber: history.fiber,
        sugar: history.sugar,
        satFat: history.saturatedFat,
        monoFat: baseN65.monoFat,
        polyFat: baseN65.polyFat,
        transFat: baseN65.transFat,
        cholesterol: baseN65.cholesterol,
        water: baseN65.water,
        calcium: history.calcium ?? baseN65.calcium,
        iron: history.iron ?? baseN65.iron,
        magnesium: history.magnesium ?? baseN65.magnesium,
        phosphorus: baseN65.phosphorus,
        potassium: history.potassium ?? baseN65.potassium,
        sodium: history.sodium ?? baseN65.sodium,
        zinc: history.zinc ?? baseN65.zinc,
        copper: baseN65.copper,
        manganese: baseN65.manganese,
        selenium: history.selenium ?? baseN65.selenium,
        iodine: baseN65.iodine,
        chromium: baseN65.chromium,
        vitC: history.vitaminC ?? baseN65.vitC,
        vitD_mcg: history.vitaminD ?? baseN65.vitD_mcg,
        vitE: baseN65.vitE,
        vitK: baseN65.vitK,
        vitA_RAE: baseN65.vitA_RAE,
        thiamine: baseN65.thiamine,
        riboflavin: baseN65.riboflavin,
        niacin: baseN65.niacin,
        pantothenic: baseN65.pantothenic,
        vitB6: baseN65.vitB6,
        folate: baseN65.folate,
        vitB12: history.vitaminB12 ?? baseN65.vitB12,
        choline: baseN65.choline,
        biotin: baseN65.biotin,
        omega3: history.omega3 ?? baseN65.omega3,
        omega6: history.omega6 ?? baseN65.omega6,
        ala: baseN65.ala,
        epa: baseN65.epa,
        dha: baseN65.dha,
        linoleic: baseN65.linoleic,
        leucine: baseN65.leucine,
        lysine: baseN65.lysine,
        valine: baseN65.valine,
        isoleucine: baseN65.isoleucine,
        threonine: baseN65.threonine,
        methionine: baseN65.methionine,
        phenylalanine: baseN65.phenylalanine,
        tryptophan: baseN65.tryptophan,
        histidine: baseN65.histidine,
        cystine: baseN65.cystine,
        tyrosine: baseN65.tyrosine,
        dataSource: 'Geçmiş+Claude',
      );
      fromHistory = true;
    } else {
      finalN65 = baseN65;
      fromHistory = false;
    }

    final nd100 = finalN65.toNutritionData();
    final portionCalories = calculateCalories(
      proteinG: _round1(nd100.protein * portionGrams / 100),
      carbsG: _round1(nd100.carbohydrates * portionGrams / 100),
      fatG: _round1(nd100.fat * portionGrams / 100),
    );

    return FoodAnalysisResult(
      foodName: foodName,
      foodNameEn: foodNameEn,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: finalN65,
      sources: fromHistory ? const ['Geçmiş', 'Claude'] : const ['Claude'],
      confidenceScore: fromHistory ? 92 : confidence,
      confidenceReason: fromHistory ? 'Kullanıcının geçmiş verilerinden eşleşti.' : confReason,
      confidenceReasonEn: fromHistory ? 'Matched from user history.' : confReasonEn,
      alternativeMin: portionCalories * 0.9,
      alternativeMax: portionCalories * 1.1,
    );
  }


  // ── Ağırlıklı Kaynak Birleştirme ──────────────────────────────────────────

  FoodAnalysisResult _mergeResults({
    required _FoodIdentification id,
    required NutritionData65 claudeN65,
    UsdaFoodDetail? usdaDetail,
    OFFProduct? offProduct,
    required double portionGrams,
    String usdaSource = 'USDA_API',
  }) {
    final sources = <String>['Claude'];
    NutritionData65? usdaN65;

    if (usdaDetail != null) {
      usdaN65 = NutritionData65.fromUsda(detail: usdaDetail, grams: 100, source: usdaSource);
      // Pişirme yöntemi USDA ham değerini gerçekçi hale getirir
      usdaN65 = _applyCooking(usdaN65, id.cookingMethod);
      sources.add(usdaSource);
    }
    if (offProduct != null) sources.add('OpenFoodFacts');

    // Kaynaklar: USDA=0.90, OFF=0.75, Claude=0.55
    // Sıfır değerleri ortalamaya dahil etme (veri yok anlamına gelir)
    double w(double c, {double? u, double? o}) {
      double sw = 0, sv = 0;
      if (c > 0)                       { sw += 0.55; sv += 0.55 * c; }
      if (u != null && u > 0)          { sw += 0.90; sv += 0.90 * u; }
      if (o != null && o > 0)          { sw += 0.75; sv += 0.75 * o; }
      return sw > 0 ? sv / sw : 0;
    }

    final merged = NutritionData65(
      energy:       w(claudeN65.energy,       u: usdaN65?.energy,       o: offProduct?.calories),
      protein:      w(claudeN65.protein,      u: usdaN65?.protein,      o: offProduct?.protein),
      fat:          w(claudeN65.fat,          u: usdaN65?.fat,          o: offProduct?.fat),
      carb:         w(claudeN65.carb,         u: usdaN65?.carb,         o: offProduct?.carbs),
      fiber:        w(claudeN65.fiber,        u: usdaN65?.fiber,        o: offProduct?.fiber),
      sugar:        w(claudeN65.sugar,        u: usdaN65?.sugar,        o: offProduct?.sugar),
      satFat:       w(claudeN65.satFat,       u: usdaN65?.satFat,       o: offProduct?.saturatedFat),
      monoFat:      w(claudeN65.monoFat,      u: usdaN65?.monoFat),
      polyFat:      w(claudeN65.polyFat,      u: usdaN65?.polyFat),
      transFat:     w(claudeN65.transFat,     u: usdaN65?.transFat),
      cholesterol:  w(claudeN65.cholesterol,  u: usdaN65?.cholesterol),
      water:        w(claudeN65.water,        u: usdaN65?.water),
      calcium:      w(claudeN65.calcium,      u: usdaN65?.calcium),
      iron:         w(claudeN65.iron,         u: usdaN65?.iron),
      magnesium:    w(claudeN65.magnesium,    u: usdaN65?.magnesium),
      phosphorus:   w(claudeN65.phosphorus,   u: usdaN65?.phosphorus),
      potassium:    w(claudeN65.potassium,    u: usdaN65?.potassium),
      sodium:       w(claudeN65.sodium,       u: usdaN65?.sodium,       o: offProduct?.sodium),
      zinc:         w(claudeN65.zinc,         u: usdaN65?.zinc),
      copper:       w(claudeN65.copper,       u: usdaN65?.copper),
      manganese:    w(claudeN65.manganese,    u: usdaN65?.manganese),
      selenium:     w(claudeN65.selenium,     u: usdaN65?.selenium),
      fluoride:     w(claudeN65.fluoride,     u: usdaN65?.fluoride),
      chromium:     w(claudeN65.chromium,     u: usdaN65?.chromium),
      iodine:       w(claudeN65.iodine,       u: usdaN65?.iodine),
      molybdenum:   w(claudeN65.molybdenum,   u: usdaN65?.molybdenum),
      vitA_RAE:     w(claudeN65.vitA_RAE,     u: usdaN65?.vitA_RAE),
      betaCarot:    w(claudeN65.betaCarot,    u: usdaN65?.betaCarot),
      lycopene:     w(claudeN65.lycopene,     u: usdaN65?.lycopene),
      luteinZea:    w(claudeN65.luteinZea,    u: usdaN65?.luteinZea),
      vitE:         w(claudeN65.vitE,         u: usdaN65?.vitE),
      vitD_mcg:     w(claudeN65.vitD_mcg,     u: usdaN65?.vitD_mcg),
      vitK:         w(claudeN65.vitK,         u: usdaN65?.vitK),
      vitC:         w(claudeN65.vitC,         u: usdaN65?.vitC),
      thiamine:     w(claudeN65.thiamine,     u: usdaN65?.thiamine),
      riboflavin:   w(claudeN65.riboflavin,   u: usdaN65?.riboflavin),
      niacin:       w(claudeN65.niacin,       u: usdaN65?.niacin),
      pantothenic:  w(claudeN65.pantothenic,  u: usdaN65?.pantothenic),
      vitB6:        w(claudeN65.vitB6,        u: usdaN65?.vitB6),
      folate:       w(claudeN65.folate,       u: usdaN65?.folate),
      vitB12:       w(claudeN65.vitB12,       u: usdaN65?.vitB12),
      choline:      w(claudeN65.choline,      u: usdaN65?.choline),
      betaine:      w(claudeN65.betaine,      u: usdaN65?.betaine),
      biotin:       w(claudeN65.biotin,       u: usdaN65?.biotin),
      omega3:       w(claudeN65.omega3,       u: usdaN65?.omega3),
      omega6:       w(claudeN65.omega6,       u: usdaN65?.omega6),
      ala:          w(claudeN65.ala,          u: usdaN65?.ala),
      epa:          w(claudeN65.epa,          u: usdaN65?.epa),
      dha:          w(claudeN65.dha,          u: usdaN65?.dha),
      linoleic:     w(claudeN65.linoleic,     u: usdaN65?.linoleic),
      tryptophan:   w(claudeN65.tryptophan,   u: usdaN65?.tryptophan),
      threonine:    w(claudeN65.threonine,    u: usdaN65?.threonine),
      isoleucine:   w(claudeN65.isoleucine,   u: usdaN65?.isoleucine),
      leucine:      w(claudeN65.leucine,      u: usdaN65?.leucine),
      lysine:       w(claudeN65.lysine,       u: usdaN65?.lysine),
      methionine:   w(claudeN65.methionine,   u: usdaN65?.methionine),
      cystine:      w(claudeN65.cystine,      u: usdaN65?.cystine),
      phenylalanine:w(claudeN65.phenylalanine,u: usdaN65?.phenylalanine),
      tyrosine:     w(claudeN65.tyrosine,     u: usdaN65?.tyrosine),
      valine:       w(claudeN65.valine,       u: usdaN65?.valine),
      histidine:    w(claudeN65.histidine,    u: usdaN65?.histidine),
      dataSource: sources.join('+'),
    );

    final nd100 = merged.toNutritionData();
    final kcal = merged.energy * portionGrams / 100;
    final confBoost = (usdaDetail != null ? 15 : 0) + (offProduct != null ? 8 : 0);
    final confidence = (id.confidenceScore + confBoost).clamp(0, 99);

    return FoodAnalysisResult(
      foodName: id.foodName,
      foodNameEn: id.foodNameEn,
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: merged,
      offProduct: offProduct,
      sources: sources,
      confidenceScore: confidence,
      alternativeMin: kcal * 0.9,
      alternativeMax: kcal * 1.1,
    );
  }

  FoodAnalysisResult _buildFromOff(OFFProduct product, double portionGrams) {
    final nd = NutritionData(
      calories: product.calories,
      protein: product.protein,
      carbohydrates: product.carbs,
      fat: product.fat,
      fiber: product.fiber,
      sugar: product.sugar,
      saturatedFat: product.saturatedFat,
      sodium: product.sodium,
      dataSource: 'OpenFoodFacts',
      confidenceScore: 88,
    );
    final kcal = product.calories * portionGrams / 100;
    return FoodAnalysisResult(
      foodName: product.name,
      foodNameEn: product.nameEn,
      portionGrams: portionGrams,
      nutritionPer100g: nd,
      offProduct: product,
      sources: const ['OpenFoodFacts'],
      confidenceScore: 88,
      alternativeMin: kcal * 0.9,
      alternativeMax: kcal * 1.1,
    );
  }

  // ── Pişirme Yöntemi Düzeltmesi ────────────────────────────────────────────

  /// USDA ham değerlerine pişirme yöntemi etkisini uygular.
  /// Referans: USDA SR28 retention factors + standart mutfak kimyası.
  NutritionData65 _applyCooking(NutritionData65 n, String cooking) {
    if (cooking == 'diger' || cooking == 'cig') return n;

    double fatMult = 1.0;
    double protMult = 1.0;
    double carbMult = 1.0;
    double waterMult = 1.0;

    switch (cooking) {
      case 'kizartma':
        fatMult = 1.20;   // yağ emilimi +%20
        waterMult = 0.85; // nem kaybı
      case 'izgara':
        fatMult = 0.90;   // yağ damlıyor
        protMult = 1.10;  // nem kaybıyla protein konsantrasyonu
        waterMult = 0.80;
      case 'hashlama':
        fatMult = 0.95;
        waterMult = 1.05; // su emilimi
      case 'firin':
        fatMult = 0.95;
        waterMult = 0.88;
    }

    final newFat = n.fat * fatMult;
    final newProt = n.protein * protMult;
    final newCarb = n.carb * carbMult;
    final newEnergy = newProt * 4.0 + newCarb * 4.0 + newFat * 9.0 + n.fiber * 2.0;

    return NutritionData65(
      energy: (newEnergy / 5).round() * 5.0,
      protein: newProt,
      fat: newFat,
      carb: newCarb,
      fiber: n.fiber,
      sugar: n.sugar,
      satFat: n.satFat * fatMult,
      monoFat: n.monoFat * fatMult,
      polyFat: n.polyFat * fatMult,
      transFat: n.transFat,
      cholesterol: n.cholesterol,
      water: n.water * waterMult,
      calcium: n.calcium,
      iron: n.iron,
      magnesium: n.magnesium,
      phosphorus: n.phosphorus,
      potassium: n.potassium,
      sodium: n.sodium,
      zinc: n.zinc,
      copper: n.copper,
      manganese: n.manganese,
      selenium: n.selenium,
      iodine: n.iodine,
      chromium: n.chromium,
      vitC: cooking == 'hashlama' ? n.vitC * 0.70 : n.vitC * 0.85,
      vitD_mcg: n.vitD_mcg,
      vitE: n.vitE * 0.90,
      vitK: n.vitK,
      vitA_RAE: n.vitA_RAE,
      thiamine: cooking == 'hashlama' ? n.thiamine * 0.75 : n.thiamine * 0.85,
      riboflavin: n.riboflavin * 0.90,
      niacin: n.niacin * 0.90,
      pantothenic: n.pantothenic,
      vitB6: n.vitB6 * 0.85,
      folate: cooking == 'hashlama' ? n.folate * 0.65 : n.folate * 0.80,
      vitB12: n.vitB12,
      choline: n.choline,
      biotin: n.biotin,
      omega3: n.omega3 * fatMult,
      omega6: n.omega6 * fatMult,
      ala: n.ala,
      epa: n.epa,
      dha: n.dha,
      linoleic: n.linoleic,
      leucine: n.leucine * protMult,
      lysine: n.lysine * protMult,
      valine: n.valine * protMult,
      isoleucine: n.isoleucine * protMult,
      threonine: n.threonine * protMult,
      methionine: n.methionine * protMult,
      phenylalanine: n.phenylalanine * protMult,
      tryptophan: n.tryptophan * protMult,
      histidine: n.histidine * protMult,
      cystine: n.cystine * protMult,
      tyrosine: n.tyrosine * protMult,
      dataSource: n.dataSource,
    );
  }

  // ── Claude API Yardımcısı ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> _callClaude({
    required List<Map<String, dynamic>> messages,
    int maxTokens = 2000,
    String model = 'claude-haiku-4-5-20251001',
  }) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'temperature': 0,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }

    final raw = jsonDecode(response.body)['content'][0]['text'] as String;
    return jsonDecode(_cleanJson(raw)) as Map<String, dynamic>;
  }

  String _cleanJson(String raw) =>
      raw.replaceAll(RegExp(r'```json|```'), '').trim();

  double _round1(double v) => (v * 10).round() / 10;

  // ── BARKOD ANALİZİ ─────────────────────────────────────────────────────────

  Future<FoodAnalysisResult?> analyzeBarcode(String barcode) async {
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;
    final n = (data['product']['nutriments'] ?? {}) as Map<String, dynamic>;

    final protein = (n['proteins_100g'] as num?)?.toDouble() ?? 0;
    final carbs = (n['carbohydrates_100g'] as num?)?.toDouble() ?? 0;
    final fat = (n['fat_100g'] as num?)?.toDouble() ?? 0;
    final calories =
        calculateCalories(proteinG: protein, carbsG: carbs, fatG: fat);

    return FoodAnalysisResult(
      foodName: (data['product']['product_name'] as String?) ?? 'Bilinmeyen',
      foodNameEn: (data['product']['product_name_en'] as String?) ?? (data['product']['product_name'] as String?),
      portionGrams: 100,
      nutritionPer100g: NutritionData(
        calories: calories,
        protein: protein,
        carbohydrates: carbs,
        fat: fat,
        fiber: (n['fiber_100g'] as num?)?.toDouble() ?? 0,
        sodium: (n['sodium_100g'] as num?)?.toDouble(),
      ),
      sources: const ['OpenFoodFacts'],
      confidenceScore: 88,
      alternativeMin: calories * 0.9,
      alternativeMax: calories * 1.1,
    );
  }

  // ── Eski uyumluluk metotları ───────────────────────────────────────────────

  Future<void> saveUserCorrection(
    String foodName,
    NutritionData correctedNutrition,
  ) =>
      saveCorrection(foodName, correctedNutrition);

  Future<NutritionData?> getUserCorrection(String foodName) =>
      _checkUserHistory(foodName);
}
