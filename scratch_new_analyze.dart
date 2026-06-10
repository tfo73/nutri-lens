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
    final yemekTipi = (json['yemek_tipi'] as String?) ?? 'ana_yemek';
    final aiPortion = (json['porsiyon_gram'] as num?)?.toDouble() ?? 0;
    final confidence = (json['guven_skoru'] as num?)?.toInt() ?? 85;

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
      betaCarotene: g('beta_karoten_mcg'),
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
      portionGrams: portionGrams,
      nutritionPer100g: nd100,
      nutrition65per100g: finalN65,
      sources: fromHistory ? const ['Geçmiş', 'Claude'] : const ['Claude'],
      confidenceScore: fromHistory ? 92 : confidence,
      alternativeMin: portionCalories * 0.9,
      alternativeMax: portionCalories * 1.1,
    );
  }
