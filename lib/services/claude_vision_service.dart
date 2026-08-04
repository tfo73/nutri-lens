import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'config_service.dart';

class ClaudeVisionService {
  String get _apiKey => ConfigService.anthropicKey;

  static Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<Map<String, dynamic>> analyzeFoodFromBytes(
    Uint8List bytes, {
    String? hint,
  }) async {
    if (!await hasConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }
    return _callApi(base64Encode(bytes), hint: hint);
  }

  Future<Map<String, dynamic>> analyzeFood(
    File imageFile, {
    String? hint,
  }) async {
    if (!await hasConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }
    final bytes = await imageFile.readAsBytes();
    return _callApi(base64Encode(bytes), hint: hint);
  }

  /// Kullanıcının metin/sesle tarif ettiği yiyeceği analiz eder.
  Future<Map<String, dynamic>> analyzeFoodFromText(String description) async {
    if (!await hasConnection()) {
      throw Exception('İnternet bağlantısı yok');
    }
    final prompt = '''
Sen bir uzman diyetisyen ve besin analisti olarak kullanıcının tarif ettiği yiyeceği analiz et.

Kullanıcı tarifi: "$description"

ADIM 1 — YEMEK TANIMI:
- Tarife göre yemeğin tam adını belirle (Türkçe - yemek_adi, İngilizce - yemek_adi_en)
- Pişirme yöntemini tahmin et (eğer belirtilmemişse en yaygın yöntemi kullan)
- Malzemeleri tespit et

ADIM 2 — PORSIYON HESAPLAMA:
- Kullanıcı gramaj/miktar belirtmişse kullan
- Belirtilmemişse standart bir porsiyon varsay (örn. 1 köfte ≈ 60g, 1 kase pilav ≈ 200g)
- Toplam gram cinsinden porsiyon_gram değerini hesapla

ADIM 3 — MAKRO HESAPLAMA:
- Kalori, protein, karbonhidrat, yağ, lif değerlerini hesapla
- Pişirme yöntemi etkisini uygula

ADIM 4 — MİKRO BESİN TAHMİNİ (DETAYLI):
- Her malzemenin bilinen mikro besin içeriğini kullanarak tahmini değerleri hesapla.
- ASLA 0.0 veya sıfır vermeyin: Eğer malzemede iz miktarda bile varsa biyolojik olarak tamamen yok olmadığı sürece mutlaka gerçekçi, USDA standartlarıyla uyumlu bir değer girin. Mikro besin değerlerinin eksiksiz girilmesi zorunludur.
- Birimler: vitaminler μg veya mg (ilgili standartta), mineraller mg, omega'lar g

ADIM 5 — GÜVENİLİRLİK:
- Kullanıcı ne kadar detay verdiyse güven skoru o kadar yüksek
- Belirsiz tarif = düşük güven, detaylı tarif = yüksek güven

SADECE JSON döndür, başka hiçbir şey yazma:
{
  "yemek_adi": "",
  "yemek_adi_en": "",
  "pişirme_yöntemi": "",
  "malzemeler": [],
  "porsiyon_gram": 0,
  "hacim_ml": 0,
  "referans_nesne": "",
  "porsiyon_aciklamasi": "",
  "kalori": 0,
  "protein": 0,
  "karbonhidrat": 0,
  "yag": 0,
  "lif": 0,
  "sodyum": 0,
  "seker": 0,
  "doymus_yag": 0,
  "vitaminA": 0,
  "vitaminC": 0,
  "vitaminD": 0,
  "vitaminE": 0,
  "vitaminK": 0,
  "vitaminB6": 0,
  "vitaminB12": 0,
  "folate": 0,
  "kalsiyum": 0,
  "demir": 0,
  "magnezyum": 0,
  "potasyum": 0,
  "cinko": 0,
  "selenyum": 0,
  "omega3": 0,
  "omega6": 0,
  "guven_skoru": 0,
  "guven_nedeni": "",
  "alternatif_tahmin": {
    "min_kalori": 0,
    "max_kalori": 0
  }
}''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 2000,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['content'][0]['text'] as String;
      final clean = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } else {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _callApi(
    String base64Image, {
    String? hint,
  }) async {
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
- Decide the general confidence score (0-100). If confidence < 60, explain what limits the estimation in "limitations" and "analysis_notes".

STEP 1 — IDENTIFICATION & QUANTIFICATION:
1. Identify the most probable food item based on the visual evidence. If multiple interpretations are possible, choose the most likely one. Write the Turkish name in "yemek_adi" (e.g. "Sade Omlet") and its English name in "yemek_adi_en" (e.g. "Plain Omelette").
2. You must never refuse because estimation is imperfect. Your goal is to produce the best clinically reasonable estimate from the available visual information. Do not answer "cannot determine" unless the food is completely unrecognizable.
3. Estimate the portion weight in grams ("porsiyon_gram") and liquid volume in milliliters ("hacim_ml"). If the food is primarily liquid, prioritize volume estimation (mL) instead of weight.
4. When estimating portion size, consider whether the presentation resembles: a homemade meal, restaurant serving, fast-food serving, or packaged food. Adjust the estimated portion accordingly.
5. Portion weight estimates should use realistic practical values. Prefer increments of approximately 5–10 g unless there is strong visual evidence for greater precision (e.g. use 150g or 155g, not 153g).
6. Round values consistently: Weight: nearest 5 g, Volume: nearest 5 mL, Calories: nearest whole number, Macronutrients: 1 decimal place, Micronutrients: 1 decimal place (or whole numbers where appropriate).
7. If multiple identical food items are present (e.g. 6 meatballs, 12 sushi rolls, 3 nuggets), estimate the portion size and calories of one item first, then multiply by the detected count.
8. If multiple different foods are detected, estimate each component separately in "components" (e.g. eggs, cooking oil, butter, cheese, vegetables) and sum all nutrients for the totals.
9. Do not invent ingredients. Only infer hidden ingredients (like butter, cooking oil, cream, cheese, sugar) that are commonly expected from the identified cooking method. Prefer conservative estimates over aggressive assumptions. When visual evidence is insufficient, choose the most statistically typical value rather than an extreme value.
10. Estimate cooking oil separately. If oil is visually present, estimate absorbed oil based on cooking method. If uncertain, assume the average oil absorption for that cooking technique.
11. Unless otherwise indicated, estimate nutrients for the food in its cooked edible form.
12. Identify the cooking method (ızgara|haşlama|kızartma|çiğ|fırın|diğer) and list all detected ingredients in "malzemeler".

STEP 2 — MACRONUTRIENT & CALORIE CALCULATION:
- Calculate total calories ("kalori"), protein ("protein" in g), carbohydrates ("karbonhidrat" in g), fat ("yag" in g), fiber ("lif" in g), sodium ("sodyum" in mg), sugar ("seker" in g), and saturated fat ("doymus_yag" in g).
- Use USDA FoodData Central as the primary reference. If the exact food is unavailable, use the closest nutritionally equivalent food.
- Protein, fat, carbohydrate and fiber must be internally consistent.
- Calories should satisfy: Calories ≈ (Protein * 4) + (Carbohydrate * 4) + (Fat * 9) + (Fiber * 2). The difference must be less than ±5%.

STEP 3 — MICRONUTRIENT & ESSENTIAL NUTRIENT ESTIMATION:
- Estimate micronutrients proportionally to the estimated ingredients and portion size.
- Never output zero unless the nutrient is biologically absent from the food.
- Required nutrients: Vitamin A (μg), Vitamin C (mg), Vitamin D (μg), Vitamin E (mg), Vitamin K (μg), Vitamin B6 (mg), Vitamin B12 (μg), Folate (μg).
- Minerals: Calcium (mg), Iron (mg), Magnesium (mg), Potassium (mg), Zinc (mg), Selenium (μg).
- Essential Fats: Omega 3 (g), Omega 6 (g).

STEP 4 — USER HINT HANDLING:
- If the user provides a hint (food name, restaurant, ingredients, cooking method, or portion size), use it only if it is consistent with the image.
- Never override obvious visual evidence with the user hint.

STEP 5 — FINAL VALIDATION
Before returning JSON, verify:
✓ Calories are consistent with macros
✓ Macronutrients match the estimated portion
✓ Micronutrients are realistic
✓ No biologically impossible values
✓ Sodium is plausible
✓ Sugar is plausible
✓ Saturated fat ≤ total fat
✓ Fiber ≤ carbohydrate
✓ Sum of all component weights in "components" should approximately equal "porsiyon_gram" (±10%).
✓ Sum of component calories and macronutrients should approximately equal the reported totals.
✓ All numeric values must be numbers. Do not include units in JSON values. Units belong only to the schema documentation.
✓ Output MUST match the provided JSON Schema exactly. Do not omit required fields. Do not add extra fields. Populate every field. Use null or 0.0 only when a value is genuinely inapplicable.

GENERAL PRINCIPLE:
Favor nutritional realism over visual precision. The objective is to produce the most clinically plausible nutritional estimate rather than an exact visual measurement.

JSON Schema:
{
  "yemek_adi": "Turkish Name",
  "yemek_adi_en": "English Name",
  "pişirme_yöntemi": "ızgara|haşlama|kızartma|çiğ|fırın|diğer",
  "malzemeler": ["ingredient1", "ingredient2"],
  "porsiyon_gram": 0.0,
  "hacim_ml": 0.0,
  "referans_nesne": "tabak|çatal|bardak|yok",
  "porsiyon_aciklamasi": "description (e.g. 1 plate, 1 bowl)",
  "kalori": 0.0,
  "protein": 0.0,
  "karbonhidrat": 0.0,
  "yag": 0.0,
  "lif": 0.0,
  "sodyum": 0.0,
  "seker": 0.0,
  "doymus_yag": 0.0,
  "vitaminA": 0.0,
  "vitaminC": 0.0,
  "vitaminD": 0.0,
  "vitaminE": 0.0,
  "vitaminK": 0.0,
  "vitaminB6": 0.0,
  "vitaminB12": 0.0,
  "folate": 0.0,
  "kalsiyum": 0.0,
  "demir": 0.0,
  "magnezyum": 0.0,
  "potasyum": 0.0,
  "cinko": 0.0,
  "selenyum": 0.0,
  "omega3": 0.0,
  "omega6": 0.0,
  "guven_skoru": 85,
  "guven_nedeni": "confidence explanation in Turkish",
  "limitations": ["occluded", "etc"],
  "analysis_notes": "additional notes in Turkish",
  "components": [
    {
      "name_tr": "Yumurta",
      "name_en": "Egg",
      "estimated_weight_g": 100.0,
      "estimated_calories": 140.0
    }
  ],
  "alternatif_tahmin": {
    "min_kalori": 0.0,
    "max_kalori": 0.0
  }
}
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
                'pişirme_yöntemi': { 'type': 'string' },
                'malzemeler': {
                  'type': 'array',
                  'items': { 'type': 'string' }
                },
                'porsiyon_gram': { 'type': 'number' },
                'hacim_ml': { 'type': 'number' },
                'referans_nesne': { 'type': 'string' },
                'porsiyon_aciklamasi': { 'type': 'string' },
                'kalori': { 'type': 'number' },
                'protein': { 'type': 'number' },
                'karbonhidrat': { 'type': 'number' },
                'yag': { 'type': 'number' },
                'lif': { 'type': 'number' },
                'sodyum': { 'type': 'number' },
                'seker': { 'type': 'number' },
                'doymus_yag': { 'type': 'number' },
                'vitaminA': { 'type': 'number' },
                'vitaminC': { 'type': 'number' },
                'vitaminD': { 'type': 'number' },
                'vitaminE': { 'type': 'number' },
                'vitaminK': { 'type': 'number' },
                'vitaminB6': { 'type': 'number' },
                'vitaminB12': { 'type': 'number' },
                'folate': { 'type': 'number' },
                'kalsiyum': { 'type': 'number' },
                'demir': { 'type': 'number' },
                'magnezyum': { 'type': 'number' },
                'potasyum': { 'type': 'number' },
                'cinko': { 'type': 'number' },
                'selenyum': { 'type': 'number' },
                'omega3': { 'type': 'number' },
                'omega6': { 'type': 'number' },
                'guven_skoru': { 'type': 'number' },
                'guven_nedeni': { 'type': 'string' },
                'limitations': {
                  'type': 'array',
                  'items': { 'type': 'string' }
                },
                'analysis_notes': { 'type': 'string' },
                'components': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name_tr': { 'type': 'string' },
                      'name_en': { 'type': 'string' },
                      'estimated_weight_g': { 'type': 'number' },
                      'estimated_calories': { 'type': 'number' }
                    },
                    'required': ['name_tr', 'name_en', 'estimated_weight_g', 'estimated_calories'],
                    'additionalProperties': false
                  }
                },
                'alternatif_tahmin': {
                  'type': 'object',
                  'properties': {
                    'min_kalori': { 'type': 'number' },
                    'max_kalori': { 'type': 'number' }
                  },
                  'required': ['min_kalori', 'max_kalori'],
                  'additionalProperties': false
                }
              },
              'required': [
                'yemek_adi', 'yemek_adi_en', 'pişirme_yöntemi', 'malzemeler',
                'porsiyon_gram', 'hacim_ml', 'referans_nesne', 'porsiyon_aciklamasi',
                'kalori', 'protein', 'karbonhidrat', 'yag', 'lif', 'sodyum', 'seker',
                'doymus_yag', 'vitaminA', 'vitaminC', 'vitaminD', 'vitaminE', 'vitaminK',
                'vitaminB6', 'vitaminB12', 'folate', 'kalsiyum', 'demir', 'magnezyum',
                'potasyum', 'cinko', 'selenyum', 'omega3', 'omega6', 'guven_skoru',
                'guven_nedeni', 'limitations', 'analysis_notes', 'components', 'alternatif_tahmin'
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
}
