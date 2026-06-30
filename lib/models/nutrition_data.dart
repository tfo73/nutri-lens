class NutritionData {
  // Makro besinler (100g başına)
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;

  // Yağlar
  final double? monoFat;       // g - Tekli doymamış
  final double? polyFat;       // g - Çoklu doymamış
  final double? transFat;      // g - Trans yağ
  final double? cholesterol;   // mg - Kolesterol

  // Mineraller
  final double? selenium;      // μg
  final double? magnesium;     // mg
  final double? iron;          // mg
  final double? zinc;          // mg
  final double? calcium;       // mg
  final double? potassium;     // mg
  final double? sodium;        // mg
  final double? phosphorus;    // mg
  final double? copper;        // mg
  final double? manganese;     // mg

  // Vitaminler
  final double? vitaminA;      // μg RAE
  final double? vitaminC;      // mg
  final double? vitaminD;      // μg
  final double? vitaminE;      // mg
  final double? vitaminK;      // μg
  final double? vitaminB12;    // μg
  final double? thiamine;      // mg - B1
  final double? riboflavin;    // mg - B2
  final double? niacin;        // mg - B3
  final double? pantothenic;   // mg - B5
  final double? vitaminB6;     // mg
  final double? folate;        // μg
  final double? choline;       // mg
  final double? biotin;        // μg

  // Yağ asitleri
  final double? omega3;        // g
  final double? omega6;        // g
  final double? ala;           // g - Alpha-linolenik
  final double? epa;           // g
  final double? dha;           // g

  // Amino asitler
  final double? tryptophan;    // g
  final double? threonine;     // g
  final double? isoleucine;    // g
  final double? leucine;       // g
  final double? lysine;        // g
  final double? methionine;    // g
  final double? phenylalanine; // g
  final double? valine;        // g
  final double? histidine;     // g
  
  // Karotenoidler
  final double? betaCarotene;  // μg
  final double? lycopene;      // μg
  final double? luteinZeaxanthin; // μg
  final double? alphaCarotene; // μg

  // Metadata
  final String? dataSource;
  final int? confidenceScore;

  const NutritionData({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.saturatedFat = 0,
    this.monoFat,
    this.polyFat,
    this.transFat,
    this.cholesterol,
    this.selenium,
    this.magnesium,
    this.iron,
    this.zinc,
    this.calcium,
    this.potassium,
    this.sodium,
    this.phosphorus,
    this.copper,
    this.manganese,
    this.vitaminA,
    this.vitaminC,
    this.vitaminD,
    this.vitaminE,
    this.vitaminK,
    this.vitaminB12,
    this.thiamine,
    this.riboflavin,
    this.niacin,
    this.pantothenic,
    this.vitaminB6,
    this.folate,
    this.choline,
    this.biotin,
    this.omega3,
    this.omega6,
    this.ala,
    this.epa,
    this.dha,
    this.tryptophan,
    this.threonine,
    this.isoleucine,
    this.leucine,
    this.lysine,
    this.methionine,
    this.phenylalanine,
    this.valine,
    this.histidine,
    this.betaCarotene,
    this.lycopene,
    this.luteinZeaxanthin,
    this.alphaCarotene,
    this.dataSource,
    this.confidenceScore,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
    double? nd(dynamic v) => v == null ? null : (v as num).toDouble();

    return NutritionData(
      calories: toDouble(json['calories']),
      protein: toDouble(json['protein']),
      carbohydrates: toDouble(json['carbohydrates']),
      fat: toDouble(json['fat']),
      fiber: toDouble(json['fiber'] ?? json['lif']),
      sugar: toDouble(json['sugar'] ?? json['seker']),
      saturatedFat: toDouble(json['saturatedFat'] ?? json['doymus_yag']),
      monoFat: nd(json['monoFat']),
      polyFat: nd(json['polyFat']),
      transFat: nd(json['transFat']),
      cholesterol: nd(json['cholesterol']),
      selenium: nd(json['selenium'] ?? json['selenyum']),
      magnesium: nd(json['magnesium'] ?? json['magnezyum']),
      iron: nd(json['iron'] ?? json['demir']),
      zinc: nd(json['zinc'] ?? json['cinko']),
      calcium: nd(json['calcium'] ?? json['kalsiyum']),
      potassium: nd(json['potassium'] ?? json['potasyum']),
      sodium: nd(json['sodium'] ?? json['sodyum']),
      phosphorus: nd(json['phosphorus']),
      copper: nd(json['copper']),
      manganese: nd(json['manganese']),
      vitaminA: nd(json['vitaminA'] ?? json['vitamin_a']),
      vitaminC: nd(json['vitaminC'] ?? json['vitamin_c']),
      vitaminD: nd(json['vitaminD'] ?? json['vitamin_d'] ?? json['d_vitamini']),
      vitaminE: nd(json['vitaminE'] ?? json['vitamin_e']),
      vitaminK: nd(json['vitaminK'] ?? json['vitamin_k']),
      vitaminB12: nd(json['vitaminB12'] ?? json['vitamin_b12'] ?? json['b12']),
      thiamine: nd(json['thiamine']),
      riboflavin: nd(json['riboflavin']),
      niacin: nd(json['niacin']),
      pantothenic: nd(json['pantothenic']),
      vitaminB6: nd(json['vitaminB6'] ?? json['vitamin_b6']),
      folate: nd(json['folate'] ?? json['folat']),
      choline: nd(json['choline']),
      biotin: nd(json['biotin']),
      omega3: nd(json['omega3']),
      omega6: nd(json['omega6']),
      ala: nd(json['ala']),
      epa: nd(json['epa']),
      dha: nd(json['dha']),
      tryptophan: nd(json['tryptophan']),
      threonine: nd(json['threonine']),
      isoleucine: nd(json['isoleucine']),
      leucine: nd(json['leucine']),
      lysine: nd(json['lysine']),
      methionine: nd(json['methionine']),
      phenylalanine: nd(json['phenylalanine']),
      valine: nd(json['valine']),
      histidine: nd(json['histidine']),
      betaCarotene: nd(json['betaCarotene'] ?? json['beta_karoten']),
      lycopene: nd(json['lycopene'] ?? json['likopen']),
      luteinZeaxanthin: nd(json['luteinZeaxanthin'] ?? json['lutein_zea']),
      alphaCarotene: nd(json['alphaCarotene'] ?? json['alfa_karoten']),
      dataSource: json['dataSource'] as String?,
      confidenceScore: (json['confidenceScore'] as num?)?.toInt(),
    );
  }

  Map<String, double> toMap() {
    return {
      'Kalori': calories,
      'Protein': protein,
      'Karbonhidrat': carbohydrates,
      'Yağ': fat,
      'Lif': fiber,
      'Şeker': sugar,
      'Doymuş Yağ': saturatedFat,
      if (cholesterol != null) 'Kolesterol': cholesterol!,
      if (sodium != null) 'Sodyum': sodium!,
      if (calcium != null) 'Kalsiyum': calcium!,
      if (iron != null) 'Demir': iron!,
      if (magnesium != null) 'Magnezyum': magnesium!,
      if (zinc != null) 'Çinko': zinc!,
      if (potassium != null) 'Potasyum': potassium!,
      if (vitaminA != null) 'A Vitamini': vitaminA!,
      if (vitaminC != null) 'C Vitamini': vitaminC!,
      if (vitaminD != null) 'D Vitamini': vitaminD!,
      if (vitaminE != null) 'E Vitamini': vitaminE!,
      if (vitaminK != null) 'K Vitamini': vitaminK!,
      if (vitaminB12 != null) 'B12 Vitamini': vitaminB12!,
      if (vitaminB6 != null) 'B6 Vitamini': vitaminB6!,
      if (omega3 != null) 'Omega-3': omega3!,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'saturatedFat': saturatedFat,
      if (monoFat != null) 'monoFat': monoFat,
      if (polyFat != null) 'polyFat': polyFat,
      if (transFat != null) 'transFat': transFat,
      if (cholesterol != null) 'cholesterol': cholesterol,
      if (selenium != null) 'selenium': selenium,
      if (magnesium != null) 'magnesium': magnesium,
      if (iron != null) 'iron': iron,
      if (zinc != null) 'zinc': zinc,
      if (calcium != null) 'calcium': calcium,
      if (potassium != null) 'potassium': potassium,
      if (sodium != null) 'sodium': sodium,
      if (phosphorus != null) 'phosphorus': phosphorus,
      if (copper != null) 'copper': copper,
      if (manganese != null) 'manganese': manganese,
      if (vitaminA != null) 'vitaminA': vitaminA,
      if (vitaminC != null) 'vitaminC': vitaminC,
      if (vitaminD != null) 'vitaminD': vitaminD,
      if (vitaminE != null) 'vitaminE': vitaminE,
      if (vitaminK != null) 'vitaminK': vitaminK,
      if (vitaminB12 != null) 'vitaminB12': vitaminB12,
      if (thiamine != null) 'thiamine': thiamine,
      if (riboflavin != null) 'riboflavin': riboflavin,
      if (niacin != null) 'niacin': niacin,
      if (pantothenic != null) 'pantothenic': pantothenic,
      if (vitaminB6 != null) 'vitaminB6': vitaminB6,
      if (folate != null) 'folate': folate,
      if (choline != null) 'choline': choline,
      if (biotin != null) 'biotin': biotin,
      if (omega3 != null) 'omega3': omega3,
      if (omega6 != null) 'omega6': omega6,
      if (ala != null) 'ala': ala,
      if (epa != null) 'epa': epa,
      if (dha != null) 'dha': dha,
      if (tryptophan != null) 'tryptophan': tryptophan,
      if (threonine != null) 'threonine': threonine,
      if (isoleucine != null) 'isoleucine': isoleucine,
      if (leucine != null) 'leucine': leucine,
      if (lysine != null) 'lysine': lysine,
      if (methionine != null) 'methionine': methionine,
      if (phenylalanine != null) 'phenylalanine': phenylalanine,
      if (valine != null) 'valine': valine,
      if (histidine != null) 'histidine': histidine,
      if (betaCarotene != null) 'betaCarotene': betaCarotene,
      if (lycopene != null) 'lycopene': lycopene,
      if (luteinZeaxanthin != null) 'luteinZeaxanthin': luteinZeaxanthin,
      if (alphaCarotene != null) 'alphaCarotene': alphaCarotene,
      if (dataSource != null) 'dataSource': dataSource,
      if (confidenceScore != null) 'confidenceScore': confidenceScore,
    };
  }

  NutritionData scaleBy(double factor) {
    double? s(double? v) => v != null ? v * factor : null;
    return NutritionData(
      calories: calories * factor,
      protein: protein * factor,
      carbohydrates: carbohydrates * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      sugar: sugar * factor,
      saturatedFat: saturatedFat * factor,
      monoFat: s(monoFat), polyFat: s(polyFat), transFat: s(transFat), cholesterol: s(cholesterol),
      selenium: s(selenium), magnesium: s(magnesium), iron: s(iron), zinc: s(zinc),
      calcium: s(calcium), potassium: s(potassium), sodium: s(sodium),
      phosphorus: s(phosphorus), copper: s(copper), manganese: s(manganese),
      vitaminA: s(vitaminA), vitaminC: s(vitaminC), vitaminD: s(vitaminD),
      vitaminE: s(vitaminE), vitaminK: s(vitaminK), vitaminB12: s(vitaminB12),
      thiamine: s(thiamine), riboflavin: s(riboflavin), niacin: s(niacin),
      pantothenic: s(pantothenic), vitaminB6: s(vitaminB6), folate: s(folate),
      choline: s(choline), biotin: s(biotin),
      omega3: s(omega3), omega6: s(omega6), ala: s(ala), epa: s(epa), dha: s(dha),
      tryptophan: s(tryptophan), threonine: s(threonine), isoleucine: s(isoleucine),
      leucine: s(leucine), lysine: s(lysine), methionine: s(methionine),
      phenylalanine: s(phenylalanine), valine: s(valine), histidine: s(histidine),
      betaCarotene: s(betaCarotene), lycopene: s(lycopene),
      luteinZeaxanthin: s(luteinZeaxanthin), alphaCarotene: s(alphaCarotene),
      dataSource: dataSource,
      confidenceScore: confidenceScore,
    );
  }

  NutritionData operator +(NutritionData o) {
    double? a(double? x, double? y) => (x == null && y == null) ? null : (x ?? 0) + (y ?? 0);
    return NutritionData(
      calories: calories + o.calories,
      protein: protein + o.protein,
      carbohydrates: carbohydrates + o.carbohydrates,
      fat: fat + o.fat,
      fiber: fiber + o.fiber,
      sugar: sugar + o.sugar,
      saturatedFat: saturatedFat + o.saturatedFat,
      monoFat: a(monoFat, o.monoFat), polyFat: a(polyFat, o.polyFat),
      transFat: a(transFat, o.transFat), cholesterol: a(cholesterol, o.cholesterol),
      selenium: a(selenium, o.selenium), magnesium: a(magnesium, o.magnesium),
      iron: a(iron, o.iron), zinc: a(zinc, o.zinc),
      calcium: a(calcium, o.calcium), potassium: a(potassium, o.potassium),
      sodium: a(sodium, o.sodium), phosphorus: a(phosphorus, o.phosphorus),
      copper: a(copper, o.copper), manganese: a(manganese, o.manganese),
      vitaminA: a(vitaminA, o.vitaminA), vitaminC: a(vitaminC, o.vitaminC),
      vitaminD: a(vitaminD, o.vitaminD), vitaminE: a(vitaminE, o.vitaminE),
      vitaminK: a(vitaminK, o.vitaminK), vitaminB12: a(vitaminB12, o.vitaminB12),
      thiamine: a(thiamine, o.thiamine), riboflavin: a(riboflavin, o.riboflavin),
      niacin: a(niacin, o.niacin), pantothenic: a(pantothenic, o.pantothenic),
      vitaminB6: a(vitaminB6, o.vitaminB6), folate: a(folate, o.folate),
      choline: a(choline, o.choline), biotin: a(biotin, o.biotin),
      omega3: a(omega3, o.omega3), omega6: a(omega6, o.omega6),
      ala: a(ala, o.ala), epa: a(epa, o.epa), dha: a(dha, o.dha),
      tryptophan: a(tryptophan, o.tryptophan), threonine: a(threonine, o.threonine),
      isoleucine: a(isoleucine, o.isoleucine), leucine: a(leucine, o.leucine),
      lysine: a(lysine, o.lysine), methionine: a(methionine, o.methionine),
      phenylalanine: a(phenylalanine, o.phenylalanine), valine: a(valine, o.valine),
      histidine: a(histidine, o.histidine),
      betaCarotene: a(betaCarotene, o.betaCarotene),
      lycopene: a(lycopene, o.lycopene),
      luteinZeaxanthin: a(luteinZeaxanthin, o.luteinZeaxanthin),
      alphaCarotene: a(alphaCarotene, o.alphaCarotene),
    );
  }

  Map<String, dynamic> toStructuredJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'saturatedFat': saturatedFat,
      if (monoFat != null) 'monoFat': monoFat,
      if (polyFat != null) 'polyFat': polyFat,
      if (transFat != null) 'transFat': transFat,
      'micros': {
        if (cholesterol != null) 'cholesterol': cholesterol,
        if (selenium != null) 'selenium': selenium,
        if (magnesium != null) 'magnesium': magnesium,
        if (iron != null) 'iron': iron,
        if (zinc != null) 'zinc': zinc,
        if (calcium != null) 'calcium': calcium,
        if (potassium != null) 'potassium': potassium,
        if (sodium != null) 'sodium': sodium,
        if (phosphorus != null) 'phosphorus': phosphorus,
        if (copper != null) 'copper': copper,
        if (manganese != null) 'manganese': manganese,
        if (vitaminA != null) 'vitaminA': vitaminA,
        if (vitaminC != null) 'vitaminC': vitaminC,
        if (vitaminD != null) 'vitaminD': vitaminD,
        if (vitaminE != null) 'vitaminE': vitaminE,
        if (vitaminK != null) 'vitaminK': vitaminK,
        if (vitaminB12 != null) 'vitaminB12': vitaminB12,
        if (thiamine != null) 'thiamine': thiamine,
        if (riboflavin != null) 'riboflavin': riboflavin,
        if (niacin != null) 'niacin': niacin,
        if (pantothenic != null) 'pantothenic': pantothenic,
        if (vitaminB6 != null) 'vitaminB6': vitaminB6,
        if (folate != null) 'folate': folate,
        if (choline != null) 'choline': choline,
        if (biotin != null) 'biotin': biotin,
        if (omega3 != null) 'omega3': omega3,
        if (omega6 != null) 'omega6': omega6,
        if (ala != null) 'ala': ala,
        if (epa != null) 'epa': epa,
        if (dha != null) 'dha': dha,
        if (tryptophan != null) 'tryptophan': tryptophan,
        if (threonine != null) 'threonine': threonine,
        if (isoleucine != null) 'isoleucine': isoleucine,
        if (leucine != null) 'leucine': leucine,
        if (lysine != null) 'lysine': lysine,
        if (methionine != null) 'methionine': methionine,
        if (phenylalanine != null) 'phenylalanine': phenylalanine,
        if (valine != null) 'valine': valine,
        if (histidine != null) 'histidine': histidine,
        if (betaCarotene != null) 'betaCarotene': betaCarotene,
        if (lycopene != null) 'lycopene': lycopene,
        if (luteinZeaxanthin != null) 'luteinZeaxanthin': luteinZeaxanthin,
        if (alphaCarotene != null) 'alphaCarotene': alphaCarotene,
      }
    };
  }

  NutritionData copyWith({
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
    double? fiber,
    double? sugar,
    double? saturatedFat,
    double? monoFat,
    double? polyFat,
    double? transFat,
    double? cholesterol,
    double? selenium,
    double? magnesium,
    double? iron,
    double? zinc,
    double? calcium,
    double? potassium,
    double? sodium,
    double? phosphorus,
    double? copper,
    double? manganese,
    double? vitaminA,
    double? vitaminC,
    double? vitaminD,
    double? vitaminE,
    double? vitaminK,
    double? vitaminB12,
    double? thiamine,
    double? riboflavin,
    double? niacin,
    double? pantothenic,
    double? vitaminB6,
    double? folate,
    double? choline,
    double? biotin,
    double? omega3,
    double? omega6,
    double? ala,
    double? epa,
    double? dha,
    double? tryptophan,
    double? threonine,
    double? isoleucine,
    double? leucine,
    double? lysine,
    double? methionine,
    double? phenylalanine,
    double? valine,
    double? histidine,
    double? betaCarotene,
    double? lycopene,
    double? luteinZeaxanthin,
    double? alphaCarotene,
    String? dataSource,
    int? confidenceScore,
  }) {
    return NutritionData(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      saturatedFat: saturatedFat ?? this.saturatedFat,
      monoFat: monoFat ?? this.monoFat,
      polyFat: polyFat ?? this.polyFat,
      transFat: transFat ?? this.transFat,
      cholesterol: cholesterol ?? this.cholesterol,
      selenium: selenium ?? this.selenium,
      magnesium: magnesium ?? this.magnesium,
      iron: iron ?? this.iron,
      zinc: zinc ?? this.zinc,
      calcium: calcium ?? this.calcium,
      potassium: potassium ?? this.potassium,
      sodium: sodium ?? this.sodium,
      phosphorus: phosphorus ?? this.phosphorus,
      copper: copper ?? this.copper,
      manganese: manganese ?? this.manganese,
      vitaminA: vitaminA ?? this.vitaminA,
      vitaminC: vitaminC ?? this.vitaminC,
      vitaminD: vitaminD ?? this.vitaminD,
      vitaminE: vitaminE ?? this.vitaminE,
      vitaminK: vitaminK ?? this.vitaminK,
      vitaminB12: vitaminB12 ?? this.vitaminB12,
      thiamine: thiamine ?? this.thiamine,
      riboflavin: riboflavin ?? this.riboflavin,
      niacin: niacin ?? this.niacin,
      pantothenic: pantothenic ?? this.pantothenic,
      vitaminB6: vitaminB6 ?? this.vitaminB6,
      folate: folate ?? this.folate,
      choline: choline ?? this.choline,
      biotin: biotin ?? this.biotin,
      omega3: omega3 ?? this.omega3,
      omega6: omega6 ?? this.omega6,
      ala: ala ?? this.ala,
      epa: epa ?? this.epa,
      dha: dha ?? this.dha,
      tryptophan: tryptophan ?? this.tryptophan,
      threonine: threonine ?? this.threonine,
      isoleucine: isoleucine ?? this.isoleucine,
      leucine: leucine ?? this.leucine,
      lysine: lysine ?? this.lysine,
      methionine: methionine ?? this.methionine,
      phenylalanine: phenylalanine ?? this.phenylalanine,
      valine: valine ?? this.valine,
      histidine: histidine ?? this.histidine,
      betaCarotene: betaCarotene ?? this.betaCarotene,
      lycopene: lycopene ?? this.lycopene,
      luteinZeaxanthin: luteinZeaxanthin ?? this.luteinZeaxanthin,
      alphaCarotene: alphaCarotene ?? this.alphaCarotene,
      dataSource: dataSource ?? this.dataSource,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }

  static const NutritionData empty = NutritionData(
    calories: 0,
    protein: 0,
    carbohydrates: 0,
    fat: 0,
  );
}
