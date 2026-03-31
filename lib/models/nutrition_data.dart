class NutritionData {
  // Makro besinler (100g başına)
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;

  // Mikro besinler (nullable — her yiyeceğin verisi olmayabilir)
  final double? selenium;    // μg
  final double? magnesium;   // mg
  final double? omega3;      // g
  final double? omega6;      // g
  final double? iron;        // mg
  final double? zinc;        // mg
  final double? vitaminD;    // μg
  final double? vitaminB12;  // μg
  final double? calcium;     // mg
  final double? potassium;   // mg
  final double? sodium;      // mg

  const NutritionData({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.saturatedFat = 0,
    this.selenium,
    this.magnesium,
    this.omega3,
    this.omega6,
    this.iron,
    this.zinc,
    this.vitaminD,
    this.vitaminB12,
    this.calcium,
    this.potassium,
    this.sodium,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
    double? toNullableDouble(dynamic v) =>
        v == null ? null : (v as num).toDouble();

    return NutritionData(
      calories: toDouble(json['calories']),
      protein: toDouble(json['protein']),
      carbohydrates: toDouble(json['carbohydrates']),
      fat: toDouble(json['fat']),
      // Hem Türkçe (API) hem İngilizce (storage) key desteği
      fiber: toDouble(json['fiber'] ?? json['lif']),
      sugar: toDouble(json['sugar'] ?? json['seker']),
      saturatedFat: toDouble(json['saturatedFat'] ?? json['doymus_yag']),
      selenium: toNullableDouble(json['selenium'] ?? json['selenyum']),
      magnesium: toNullableDouble(json['magnesium'] ?? json['magnezyum']),
      omega3: toNullableDouble(json['omega3']),
      omega6: toNullableDouble(json['omega6']),
      iron: toNullableDouble(json['iron'] ?? json['demir']),
      zinc: toNullableDouble(json['zinc'] ?? json['cinko']),
      vitaminD: toNullableDouble(json['vitaminD'] ?? json['d_vitamini']),
      vitaminB12: toNullableDouble(json['vitaminB12'] ?? json['b12']),
      calcium: toNullableDouble(json['calcium'] ?? json['kalsiyum']),
      potassium: toNullableDouble(json['potassium'] ?? json['potasyum']),
      sodium: toNullableDouble(json['sodium'] ?? json['sodyum']),
    );
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
      if (selenium != null) 'selenium': selenium,
      if (magnesium != null) 'magnesium': magnesium,
      if (omega3 != null) 'omega3': omega3,
      if (omega6 != null) 'omega6': omega6,
      if (iron != null) 'iron': iron,
      if (zinc != null) 'zinc': zinc,
      if (vitaminD != null) 'vitaminD': vitaminD,
      if (vitaminB12 != null) 'vitaminB12': vitaminB12,
      if (calcium != null) 'calcium': calcium,
      if (potassium != null) 'potassium': potassium,
      if (sodium != null) 'sodium': sodium,
    };
  }

  // Porsiyon miktarına göre ölçeklendir
  NutritionData scaleBy(double factor) {
    return NutritionData(
      calories: calories * factor,
      protein: protein * factor,
      carbohydrates: carbohydrates * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      sugar: sugar * factor,
      saturatedFat: saturatedFat * factor,
      selenium: selenium != null ? selenium! * factor : null,
      magnesium: magnesium != null ? magnesium! * factor : null,
      omega3: omega3 != null ? omega3! * factor : null,
      omega6: omega6 != null ? omega6! * factor : null,
      iron: iron != null ? iron! * factor : null,
      zinc: zinc != null ? zinc! * factor : null,
      vitaminD: vitaminD != null ? vitaminD! * factor : null,
      vitaminB12: vitaminB12 != null ? vitaminB12! * factor : null,
      calcium: calcium != null ? calcium! * factor : null,
      potassium: potassium != null ? potassium! * factor : null,
      sodium: sodium != null ? sodium! * factor : null,
    );
  }

  NutritionData operator +(NutritionData other) {
    double? addNullable(double? a, double? b) {
      if (a == null && b == null) return null;
      return (a ?? 0) + (b ?? 0);
    }

    return NutritionData(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbohydrates: carbohydrates + other.carbohydrates,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
      sugar: sugar + other.sugar,
      saturatedFat: saturatedFat + other.saturatedFat,
      selenium: addNullable(selenium, other.selenium),
      magnesium: addNullable(magnesium, other.magnesium),
      omega3: addNullable(omega3, other.omega3),
      omega6: addNullable(omega6, other.omega6),
      iron: addNullable(iron, other.iron),
      zinc: addNullable(zinc, other.zinc),
      vitaminD: addNullable(vitaminD, other.vitaminD),
      vitaminB12: addNullable(vitaminB12, other.vitaminB12),
      calcium: addNullable(calcium, other.calcium),
      potassium: addNullable(potassium, other.potassium),
      sodium: addNullable(sodium, other.sodium),
    );
  }

  static const NutritionData empty = NutritionData(
    calories: 0,
    protein: 0,
    carbohydrates: 0,
    fat: 0,
  );
}
