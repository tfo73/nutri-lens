class NutritionData {
  // Makro besinler (100g başına)
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;

  const NutritionData({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.saturatedFat = 0,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => v == null ? 0.0 : (v as num).toDouble();

    return NutritionData(
      calories: toDouble(json['calories']),
      protein: toDouble(json['protein']),
      carbohydrates: toDouble(json['carbohydrates']),
      fat: toDouble(json['fat']),
      fiber: toDouble(json['fiber']),
      sugar: toDouble(json['sugar']),
      saturatedFat: toDouble(json['saturatedFat']),
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
    );
  }

  NutritionData operator +(NutritionData other) {
    return NutritionData(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbohydrates: carbohydrates + other.carbohydrates,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
      sugar: sugar + other.sugar,
      saturatedFat: saturatedFat + other.saturatedFat,
    );
  }

  static const NutritionData empty = NutritionData(
    calories: 0,
    protein: 0,
    carbohydrates: 0,
    fat: 0,
  );
}
