import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nutrition_data_65.dart';

/// Edamam Nutrition Analysis API — Developer Plan
/// Env: EDAMAM_NUTRITION_APP_ID, EDAMAM_NUTRITION_APP_KEY
/// Returns null on any failure (rate limit, network, missing key) — caller falls back silently.
class EdamamNutritionService {
  static const _appId = String.fromEnvironment(
    'EDAMAM_NUTRITION_APP_ID',
    defaultValue: '',
  );
  static const _appKey = String.fromEnvironment(
    'EDAMAM_NUTRITION_APP_KEY',
    defaultValue: '',
  );

  static EdamamNutritionService? _instance;
  static EdamamNutritionService get instance =>
      _instance ??= EdamamNutritionService._();
  EdamamNutritionService._();

  /// Analyses [foodName] and returns nutrition per 100 g, or null on failure.
  Future<NutritionData65?> analyze(String foodName) async {
    if (_appId.isEmpty || _appKey.isEmpty) return null;
    try {
      final ingr = Uri.encodeComponent('100g $foodName');
      final uri = Uri.parse(
        'https://api.edamam.com/api/nutrition-data'
        '?app_id=$_appId&app_key=$_appKey&ingr=$ingr',
      );
      final res =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final nutrients =
          data['totalNutrients'] as Map<String, dynamic>?;
      if (nutrients == null || nutrients.isEmpty) return null;

      double q(String key) {
        final n = nutrients[key] as Map<String, dynamic>?;
        return (n?['quantity'] as num?)?.toDouble() ?? 0.0;
      }

      final protein = q('PROCNT');
      final carb = q('CHOCDF');
      final fat = q('FAT');
      final fiber = q('FIBTG');
      final energy = protein * 4.0 + carb * 4.0 + fat * 9.0 + fiber * 2.0;

      return NutritionData65(
        energy: (energy / 5).round() * 5.0,
        protein: protein,
        fat: fat,
        carb: carb,
        fiber: fiber,
        sugar: q('SUGAR'),
        satFat: q('FASAT'),
        monoFat: q('FAMS'),
        polyFat: q('FAPU'),
        cholesterol: q('CHOLE'),
        sodium: q('NA'),
        calcium: q('CA'),
        iron: q('FE'),
        magnesium: q('MG'),
        phosphorus: q('P'),
        potassium: q('K'),
        zinc: q('ZN'),
        copper: q('CU'),
        manganese: q('MN'),
        selenium: q('SE'),
        vitC: q('VITC'),
        vitD_mcg: q('VITD'),
        vitE: q('TOCPHA'),
        vitK: q('VITK1'),
        vitA_RAE: q('VITA_RAE'),
        thiamine: q('THIA'),
        riboflavin: q('RIBF'),
        niacin: q('NIA'),
        pantothenic: q('PANTAC'),
        vitB6: q('VITB6A'),
        folate: q('FOLDFE'),
        vitB12: q('VITB12'),
        choline: q('CHOLN'),
        dataSource: 'Edamam',
      );
    } catch (_) {
      return null;
    }
  }

  /// Merges Claude estimate with Edamam data.
  /// Macros: 50/50 average. Micros: prefer Edamam if non-zero.
  static NutritionData65 merge(
      NutritionData65 claude, NutritionData65 edamam) {
    double avg(double a, double b) => (a + b) / 2;
    double prefer(double a, double b) =>
        b > 0 ? (a > 0 ? (a + b) / 2 : b) : a;

    final protein = avg(claude.protein, edamam.protein);
    final carb = avg(claude.carb, edamam.carb);
    final fat = avg(claude.fat, edamam.fat);
    final fiber = prefer(claude.fiber, edamam.fiber);
    final energy =
        protein * 4.0 + carb * 4.0 + fat * 9.0 + fiber * 2.0;

    return NutritionData65(
      energy: (energy / 5).round() * 5.0,
      protein: protein,
      fat: fat,
      carb: carb,
      fiber: fiber,
      sugar: prefer(claude.sugar, edamam.sugar),
      satFat: prefer(claude.satFat, edamam.satFat),
      monoFat: prefer(claude.monoFat, edamam.monoFat),
      polyFat: prefer(claude.polyFat, edamam.polyFat),
      transFat: claude.transFat,
      cholesterol: prefer(claude.cholesterol, edamam.cholesterol),
      water: claude.water,
      ash: claude.ash,
      calcium: prefer(claude.calcium, edamam.calcium),
      iron: prefer(claude.iron, edamam.iron),
      magnesium: prefer(claude.magnesium, edamam.magnesium),
      phosphorus: prefer(claude.phosphorus, edamam.phosphorus),
      potassium: prefer(claude.potassium, edamam.potassium),
      sodium: prefer(claude.sodium, edamam.sodium),
      zinc: prefer(claude.zinc, edamam.zinc),
      copper: prefer(claude.copper, edamam.copper),
      manganese: prefer(claude.manganese, edamam.manganese),
      selenium: prefer(claude.selenium, edamam.selenium),
      fluoride: claude.fluoride,
      chromium: claude.chromium,
      iodine: claude.iodine,
      molybdenum: claude.molybdenum,
      vitA_RAE: prefer(claude.vitA_RAE, edamam.vitA_RAE),
      vitA_IU: claude.vitA_IU,
      retinol: claude.retinol,
      alphaCarot: claude.alphaCarot,
      betaCarot: claude.betaCarot,
      betaCrypt: claude.betaCrypt,
      lycopene: claude.lycopene,
      luteinZea: claude.luteinZea,
      vitE: prefer(claude.vitE, edamam.vitE),
      vitD_mcg: prefer(claude.vitD_mcg, edamam.vitD_mcg),
      vitD_IU: claude.vitD_IU,
      vitK: prefer(claude.vitK, edamam.vitK),
      vitK_Mena: claude.vitK_Mena,
      vitC: prefer(claude.vitC, edamam.vitC),
      thiamine: prefer(claude.thiamine, edamam.thiamine),
      riboflavin: prefer(claude.riboflavin, edamam.riboflavin),
      niacin: prefer(claude.niacin, edamam.niacin),
      pantothenic: prefer(claude.pantothenic, edamam.pantothenic),
      vitB6: prefer(claude.vitB6, edamam.vitB6),
      folate: prefer(claude.folate, edamam.folate),
      vitB12: prefer(claude.vitB12, edamam.vitB12),
      choline: prefer(claude.choline, edamam.choline),
      betaine: claude.betaine,
      biotin: claude.biotin,
      omega3: prefer(claude.omega3, edamam.omega3),
      omega6: prefer(claude.omega6, edamam.omega6),
      ala: claude.ala,
      epa: claude.epa,
      dha: claude.dha,
      linoleic: claude.linoleic,
      tryptophan: claude.tryptophan,
      threonine: claude.threonine,
      isoleucine: claude.isoleucine,
      leucine: claude.leucine,
      lysine: claude.lysine,
      methionine: claude.methionine,
      cystine: claude.cystine,
      phenylalanine: claude.phenylalanine,
      tyrosine: claude.tyrosine,
      valine: claude.valine,
      histidine: claude.histidine,
      dataSource: 'Claude+Edamam',
    );
  }
}
