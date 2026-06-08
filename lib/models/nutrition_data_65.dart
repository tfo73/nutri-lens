// 65-besin değeri modeli — USDA FNDDS 2019-2020 tabanlı
// Her alan 100g başına değeri temsil eder.

import 'nutrition_data.dart';
import '../services/usda_api_service.dart';

class NutritionData65 {
  // ── MAKROLAR (13) ──────────────────────────────────────────────────────────
  final double energy;         // kcal
  final double protein;        // g
  final double fat;            // g
  final double carb;           // g
  final double fiber;          // g
  final double sugar;          // g
  final double satFat;         // g
  final double monoFat;        // g
  final double polyFat;        // g
  final double transFat;       // g
  final double cholesterol;    // mg
  final double water;          // g
  final double ash;            // g

  // ── MİNERALLER (14) ───────────────────────────────────────────────────────
  final double calcium;        // mg
  final double iron;           // mg
  final double magnesium;      // mg
  final double phosphorus;     // mg
  final double potassium;      // mg
  final double sodium;         // mg
  final double zinc;           // mg
  final double copper;         // mg
  final double manganese;      // mg
  final double selenium;       // mcg
  final double fluoride;       // mcg
  final double chromium;       // mcg
  final double iodine;         // mcg
  final double molybdenum;     // mcg

  // ── VİTAMİNLER (21) ───────────────────────────────────────────────────────
  final double vitA_RAE;       // mcg
  final double vitA_IU;        // IU
  final double retinol;        // mcg
  final double alphaCarot;     // mcg
  final double betaCarot;      // mcg
  final double betaCrypt;      // mcg
  final double lycopene;       // mcg
  final double luteinZea;      // mcg
  final double vitE;           // mg (alpha-tocopherol)
  final double vitD_mcg;       // mcg
  final double vitD_IU;        // IU
  final double vitK;           // mcg (phylloquinone)
  final double vitK_Mena;      // mcg (menaquinone)
  final double vitC;           // mg
  final double thiamine;       // mg
  final double riboflavin;     // mg
  final double niacin;         // mg
  final double pantothenic;    // mg
  final double vitB6;          // mg
  final double folate;         // mcg
  final double vitB12;         // mcg
  final double choline;        // mg
  final double betaine;        // mg
  final double biotin;         // mcg

  // ── YAĞ ASİTLERİ (6) ──────────────────────────────────────────────────────
  final double omega3;         // g (toplam n-3)
  final double omega6;         // g (toplam n-6)
  final double ala;            // g (alpha-linolenic)
  final double epa;            // g (eicosapentaenoic)
  final double dha;            // g (docosahexaenoic)
  final double linoleic;       // g (n-6 linoleic)

  // ── AMİNO ASİTLER (11) ────────────────────────────────────────────────────
  final double tryptophan;     // g
  final double threonine;      // g
  final double isoleucine;     // g
  final double leucine;        // g
  final double lysine;         // g
  final double methionine;     // g
  final double cystine;        // g
  final double phenylalanine;  // g
  final double tyrosine;       // g
  final double valine;         // g
  final double histidine;      // g

  // ── Meta ──────────────────────────────────────────────────────────────────
  final String? dataSource;    // 'FNDDS' | 'Claude' | 'User'
  final int? fdcId;

  const NutritionData65({
    required this.energy,
    required this.protein,
    required this.fat,
    required this.carb,
    this.fiber = 0,
    this.sugar = 0,
    this.satFat = 0,
    this.monoFat = 0,
    this.polyFat = 0,
    this.transFat = 0,
    this.cholesterol = 0,
    this.water = 0,
    this.ash = 0,
    this.calcium = 0,
    this.iron = 0,
    this.magnesium = 0,
    this.phosphorus = 0,
    this.potassium = 0,
    this.sodium = 0,
    this.zinc = 0,
    this.copper = 0,
    this.manganese = 0,
    this.selenium = 0,
    this.fluoride = 0,
    this.chromium = 0,
    this.iodine = 0,
    this.molybdenum = 0,
    this.vitA_RAE = 0,
    this.vitA_IU = 0,
    this.retinol = 0,
    this.alphaCarot = 0,
    this.betaCarot = 0,
    this.betaCrypt = 0,
    this.lycopene = 0,
    this.luteinZea = 0,
    this.vitE = 0,
    this.vitD_mcg = 0,
    this.vitD_IU = 0,
    this.vitK = 0,
    this.vitK_Mena = 0,
    this.vitC = 0,
    this.thiamine = 0,
    this.riboflavin = 0,
    this.niacin = 0,
    this.pantothenic = 0,
    this.vitB6 = 0,
    this.folate = 0,
    this.vitB12 = 0,
    this.choline = 0,
    this.betaine = 0,
    this.biotin = 0,
    this.omega3 = 0,
    this.omega6 = 0,
    this.ala = 0,
    this.epa = 0,
    this.dha = 0,
    this.linoleic = 0,
    this.tryptophan = 0,
    this.threonine = 0,
    this.isoleucine = 0,
    this.leucine = 0,
    this.lysine = 0,
    this.methionine = 0,
    this.cystine = 0,
    this.phenylalanine = 0,
    this.tyrosine = 0,
    this.valine = 0,
    this.histidine = 0,
    this.dataSource,
    this.fdcId,
  });

  // ── Güven skoru (veri kaynağına göre) ─────────────────────────────────────

  int get confidenceScore {
    if (dataSource == 'USDA_API') return 92;
    if (dataSource == 'USDA_CACHE') return 88;
    if (dataSource == 'FNDDS') return 90;
    return 72;
  }

  // ── USDA FoodData Central'dan oluştur ──────────────────────────────────────

  factory NutritionData65.fromUsda({
    required UsdaFoodDetail detail,
    required double grams,
    required String source,
  }) {
    final f = grams / 100.0;
    // Tek ondalık hassasiyetle ölçekle
    double g(int id) =>
        (detail.get(id) * f * 10).round() / 10.0;

    final p = g(1003), c = g(1005), y = g(1004), fi = g(1079);
    final energy = ((p * 4 + c * 4 + y * 9 + fi * 2) / 5).round() * 5.0;

    return NutritionData65(
      energy: energy,
      protein: p,
      fat: y,
      carb: c,
      fiber: fi,
      sugar: g(2000),
      satFat: g(1258),
      monoFat: g(1292),
      polyFat: g(1293),
      transFat: g(1257),
      cholesterol: g(1253),
      water: g(1051),
      calcium: g(1087),
      iron: g(1089),
      magnesium: g(1090),
      phosphorus: g(1091),
      potassium: g(1092),
      sodium: g(1093),
      zinc: g(1095),
      copper: g(1098),
      manganese: g(1101),
      selenium: g(1103),
      iodine: g(1100),
      chromium: g(1096),
      molybdenum: g(1102),
      biotin: g(1176),
      vitA_RAE: g(1106),
      betaCarot: g(1107),
      vitE: g(1109),
      vitD_mcg: g(1114),
      vitK: g(1185),
      vitC: g(1162),
      thiamine: g(1165),
      riboflavin: g(1166),
      niacin: g(1167),
      pantothenic: g(1170),
      vitB6: g(1175),
      folate: g(1177),
      vitB12: g(1178),
      choline: g(1180),
      betaine: g(1198),
      lycopene: g(1122),
      luteinZea: g(1123),
      omega3: g(1404),
      omega6: g(1405),
      ala: g(1269),
      epa: g(1278),
      dha: g(1272),
      tryptophan: g(1210),
      threonine: g(1211),
      isoleucine: g(1212),
      leucine: g(1213),
      lysine: g(1214),
      methionine: g(1215),
      cystine: g(1216),
      phenylalanine: g(1217),
      tyrosine: g(1218),
      valine: g(1219),
      histidine: g(1221),
      dataSource: source,
      fdcId: detail.fdcId,
    );
  }

  // ── Mevcut NutritionData modeline dönüştür ─────────────────────────────────

  NutritionData toNutritionData() {
    return NutritionData(
      calories: energy,
      protein: protein,
      carbohydrates: carb,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      saturatedFat: satFat,
      selenium: selenium > 0 ? selenium : null,
      magnesium: magnesium > 0 ? magnesium : null,
      omega3: omega3 > 0 ? omega3 : null,
      omega6: omega6 > 0 ? omega6 : null,
      iron: iron > 0 ? iron : null,
      zinc: zinc > 0 ? zinc : null,
      vitaminC: vitC > 0 ? vitC : null,
      vitaminD: vitD_mcg > 0 ? vitD_mcg : null,
      vitaminB12: vitB12 > 0 ? vitB12 : null,
      calcium: calcium > 0 ? calcium : null,
      potassium: potassium > 0 ? potassium : null,
      sodium: sodium > 0 ? sodium : null,
    );
  }

  // ── Porsiyon ölçekleme ─────────────────────────────────────────────────────

  NutritionData65 scaleBy(double factor) {
    double s(double v) => v * factor;
    return NutritionData65(
      energy: s(energy),
      protein: s(protein),
      fat: s(fat),
      carb: s(carb),
      fiber: s(fiber),
      sugar: s(sugar),
      satFat: s(satFat),
      monoFat: s(monoFat),
      polyFat: s(polyFat),
      transFat: s(transFat),
      cholesterol: s(cholesterol),
      water: s(water),
      ash: s(ash),
      calcium: s(calcium),
      iron: s(iron),
      magnesium: s(magnesium),
      phosphorus: s(phosphorus),
      potassium: s(potassium),
      sodium: s(sodium),
      zinc: s(zinc),
      copper: s(copper),
      manganese: s(manganese),
      selenium: s(selenium),
      fluoride: s(fluoride),
      chromium: s(chromium),
      iodine: s(iodine),
      molybdenum: s(molybdenum),
      vitA_RAE: s(vitA_RAE),
      vitA_IU: s(vitA_IU),
      retinol: s(retinol),
      alphaCarot: s(alphaCarot),
      betaCarot: s(betaCarot),
      betaCrypt: s(betaCrypt),
      lycopene: s(lycopene),
      luteinZea: s(luteinZea),
      vitE: s(vitE),
      vitD_mcg: s(vitD_mcg),
      vitD_IU: s(vitD_IU),
      vitK: s(vitK),
      vitK_Mena: s(vitK_Mena),
      vitC: s(vitC),
      thiamine: s(thiamine),
      riboflavin: s(riboflavin),
      niacin: s(niacin),
      pantothenic: s(pantothenic),
      vitB6: s(vitB6),
      folate: s(folate),
      vitB12: s(vitB12),
      choline: s(choline),
      betaine: s(betaine),
      biotin: s(biotin),
      omega3: s(omega3),
      omega6: s(omega6),
      ala: s(ala),
      epa: s(epa),
      dha: s(dha),
      linoleic: s(linoleic),
      tryptophan: s(tryptophan),
      threonine: s(threonine),
      isoleucine: s(isoleucine),
      leucine: s(leucine),
      lysine: s(lysine),
      methionine: s(methionine),
      cystine: s(cystine),
      phenylalanine: s(phenylalanine),
      tyrosine: s(tyrosine),
      valine: s(valine),
      histidine: s(histidine),
      dataSource: dataSource,
      fdcId: fdcId,
    );
  }

  Map<String, double> toMap() {
    return {
      'Enerji': energy,
      'Protein': protein,
      'Karbonhidrat': carb,
      'Yağ': fat,
      'Lif': fiber,
      'Şeker': sugar,
      'Doymuş Yağ': satFat,
      'Kalsiyum': calcium,
      'Demir': iron,
      'Magnezyum': magnesium,
      'Fosfor': phosphorus,
      'Potasyum': potassium,
      'Sodyum': sodium,
      'Çinko': zinc,
      'Bakır': copper,
      'Manganez': manganese,
      'Selenyum': selenium,
      'C Vitamini': vitC,
      'B1 Vitamini': thiamine,
      'B2 Vitamini': riboflavin,
      'B3 Vitamini': niacin,
      'B5 Vitamini': pantothenic,
      'B6 Vitamini': vitB6,
      'Folat': folate,
      'B12 Vitamini': vitB12,
    };
  }

  // ── JSON serileştirme ──────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'energy': energy,
        'protein': protein,
        'fat': fat,
        'carb': carb,
        'fiber': fiber,
        'sugar': sugar,
        'sat_fat': satFat,
        'mono_fat': monoFat,
        'poly_fat': polyFat,
        'trans_fat': transFat,
        'cholesterol': cholesterol,
        'water': water,
        'ash': ash,
        'calcium': calcium,
        'iron': iron,
        'magnesium': magnesium,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'sodium': sodium,
        'zinc': zinc,
        'copper': copper,
        'manganese': manganese,
        'selenium': selenium,
        'fluoride': fluoride,
        'chromium': chromium,
        'iodine': iodine,
        'molybdenum': molybdenum,
        'vit_a_rae': vitA_RAE,
        'vit_a_iu': vitA_IU,
        'retinol': retinol,
        'alpha_carot': alphaCarot,
        'beta_carot': betaCarot,
        'beta_crypt': betaCrypt,
        'lycopene': lycopene,
        'lutein_zea': luteinZea,
        'vit_e': vitE,
        'vit_d_mcg': vitD_mcg,
        'vit_d_iu': vitD_IU,
        'vit_k': vitK,
        'vit_k_mena': vitK_Mena,
        'vit_c': vitC,
        'thiamine': thiamine,
        'riboflavin': riboflavin,
        'niacin': niacin,
        'pantothenic': pantothenic,
        'vit_b6': vitB6,
        'folate': folate,
        'vit_b12': vitB12,
        'choline': choline,
        'betaine': betaine,
        'biotin': biotin,
        'omega3': omega3,
        'omega6': omega6,
        'ala': ala,
        'epa': epa,
        'dha': dha,
        'linoleic': linoleic,
        'tryptophan': tryptophan,
        'threonine': threonine,
        'isoleucine': isoleucine,
        'leucine': leucine,
        'lysine': lysine,
        'methionine': methionine,
        'cystine': cystine,
        'phenylalanine': phenylalanine,
        'tyrosine': tyrosine,
        'valine': valine,
        'histidine': histidine,
        if (dataSource != null) 'data_source': dataSource,
        if (fdcId != null) 'fdc_id': fdcId,
      };

  factory NutritionData65.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0.0;
    return NutritionData65(
      energy: d('energy'),
      protein: d('protein'),
      fat: d('fat'),
      carb: d('carb'),
      fiber: d('fiber'),
      sugar: d('sugar'),
      satFat: d('sat_fat'),
      monoFat: d('mono_fat'),
      polyFat: d('poly_fat'),
      transFat: d('trans_fat'),
      cholesterol: d('cholesterol'),
      water: d('water'),
      ash: d('ash'),
      calcium: d('calcium'),
      iron: d('iron'),
      magnesium: d('magnesium'),
      phosphorus: d('phosphorus'),
      potassium: d('potassium'),
      sodium: d('sodium'),
      zinc: d('zinc'),
      copper: d('copper'),
      manganese: d('manganese'),
      selenium: d('selenium'),
      fluoride: d('fluoride'),
      chromium: d('chromium'),
      iodine: d('iodine'),
      molybdenum: d('molybdenum'),
      vitA_RAE: d('vit_a_rae'),
      vitA_IU: d('vit_a_iu'),
      retinol: d('retinol'),
      alphaCarot: d('alpha_carot'),
      betaCarot: d('beta_carot'),
      betaCrypt: d('beta_crypt'),
      lycopene: d('lycopene'),
      luteinZea: d('lutein_zea'),
      vitE: d('vit_e'),
      vitD_mcg: d('vit_d_mcg'),
      vitD_IU: d('vit_d_iu'),
      vitK: d('vit_k'),
      vitK_Mena: d('vit_k_mena'),
      vitC: d('vit_c'),
      thiamine: d('thiamine'),
      riboflavin: d('riboflavin'),
      niacin: d('niacin'),
      pantothenic: d('pantothenic'),
      vitB6: d('vit_b6'),
      folate: d('folate'),
      vitB12: d('vit_b12'),
      choline: d('choline'),
      betaine: d('betaine'),
      biotin: d('biotin'),
      omega3: d('omega3'),
      omega6: d('omega6'),
      ala: d('ala'),
      epa: d('epa'),
      dha: d('dha'),
      linoleic: d('linoleic'),
      tryptophan: d('tryptophan'),
      threonine: d('threonine'),
      isoleucine: d('isoleucine'),
      leucine: d('leucine'),
      lysine: d('lysine'),
      methionine: d('methionine'),
      cystine: d('cystine'),
      phenylalanine: d('phenylalanine'),
      tyrosine: d('tyrosine'),
      valine: d('valine'),
      histidine: d('histidine'),
      dataSource: j['data_source'] as String?,
      fdcId: j['fdc_id'] as int?,
    );
  }
}

extension NutritionDataTo65 on NutritionData {
  NutritionData65 to65() {
    return NutritionData65(
      energy: calories,
      protein: protein,
      fat: fat,
      carb: carbohydrates,
      fiber: fiber,
      sugar: sugar,
      satFat: saturatedFat,
      monoFat: monoFat ?? 0,
      polyFat: polyFat ?? 0,
      transFat: transFat ?? 0,
      cholesterol: cholesterol ?? 0,
      selenium: selenium ?? 0,
      magnesium: magnesium ?? 0,
      iron: iron ?? 0,
      zinc: zinc ?? 0,
      calcium: calcium ?? 0,
      potassium: potassium ?? 0,
      sodium: sodium ?? 0,
      phosphorus: phosphorus ?? 0,
      copper: copper ?? 0,
      manganese: manganese ?? 0,
      vitA_RAE: vitaminA ?? 0,
      vitA_IU: 0,
      retinol: 0,
      vitC: vitaminC ?? 0,
      vitD_mcg: vitaminD ?? 0,
      vitD_IU: 0,
      vitK: vitaminK ?? 0,
      vitK_Mena: 0,
      vitE: vitaminE ?? 0,
      vitB12: vitaminB12 ?? 0,
      thiamine: thiamine ?? 0,
      riboflavin: riboflavin ?? 0,
      niacin: niacin ?? 0,
      pantothenic: pantothenic ?? 0,
      vitB6: vitaminB6 ?? 0,
      folate: folate ?? 0,
      choline: choline ?? 0,
      biotin: biotin ?? 0,
      omega3: omega3 ?? 0,
      omega6: omega6 ?? 0,
      ala: ala ?? 0,
      epa: epa ?? 0,
      dha: dha ?? 0,
      linoleic: 0,
      tryptophan: tryptophan ?? 0,
      threonine: threonine ?? 0,
      isoleucine: isoleucine ?? 0,
      leucine: leucine ?? 0,
      lysine: lysine ?? 0,
      methionine: methionine ?? 0,
      phenylalanine: phenylalanine ?? 0,
      valine: valine ?? 0,
      histidine: histidine ?? 0,
      cystine: 0,
      tyrosine: 0,
      betaCarot: betaCarotene ?? 0,
      lycopene: lycopene ?? 0,
      luteinZea: luteinZeaxanthin ?? 0,
      alphaCarot: alphaCarotene ?? 0,
      ash: 0,
      water: 0,
    );
  }
}
