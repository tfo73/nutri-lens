import 'exercise_entry.dart';
import 'food_entry.dart';
import 'nutrition_data.dart';
import 'nutrition_data_65.dart';

// Su girdi modeli
class WaterEntry {
  final DateTime time;
  final double amount; // ml

  WaterEntry({required this.time, required this.amount});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'amount': amount,
  };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
    time: DateTime.parse(json['time'] as String),
    amount: (json['amount'] as num).toDouble(),
  );
}

class DailyLog {
  final String id;
  final DateTime date;
  final List<FoodEntry> entries;
  final double waterIntakeMl;
  final int? stepsCount;
  final double? weightKg;
  final String? notes;
  final List<ExerciseEntry> exercises;
  final List<WaterEntry> waterEntries;

  DailyLog({
    required this.id,
    required this.date,
    this.entries = const [],
    this.waterIntakeMl = 0,
    this.stepsCount,
    this.weightKg,
    this.notes,
    this.exercises = const [],
    this.waterEntries = const [],
  });

  // Günlük toplam besin değerleri
  NutritionData get totalNutrition {
    if (entries.isEmpty) return NutritionData.empty;
    return entries.fold(NutritionData.empty, (sum, entry) {
      final scaled = entry.nutritionData.scaleBy(entry.portionSize / 100);
      return sum + scaled;
    });
  }

  /// 65-besin günlük toplamı — sadece FNDDS kaynaklı girişler katkıda bulunur.
  NutritionData65? get totalNutrition65 {
    final with65 = entries.where((e) => e.nutrition65per100g != null).toList();
    if (with65.isEmpty) return null;

    NutritionData65 acc = with65.first.nutrition65per100g!
        .scaleBy(with65.first.portionSize / 100);

    for (int i = 1; i < with65.length; i++) {
      final e = with65[i];
      final scaled = e.nutrition65per100g!.scaleBy(e.portionSize / 100);
      acc = _add65(acc, scaled);
    }
    return acc;
  }

  static NutritionData65 _add65(NutritionData65 a, NutritionData65 b) {
    return NutritionData65(
      energy: a.energy + b.energy,
      protein: a.protein + b.protein,
      fat: a.fat + b.fat,
      carb: a.carb + b.carb,
      fiber: a.fiber + b.fiber,
      sugar: a.sugar + b.sugar,
      satFat: a.satFat + b.satFat,
      monoFat: a.monoFat + b.monoFat,
      polyFat: a.polyFat + b.polyFat,
      transFat: a.transFat + b.transFat,
      cholesterol: a.cholesterol + b.cholesterol,
      water: a.water + b.water,
      ash: a.ash + b.ash,
      calcium: a.calcium + b.calcium,
      iron: a.iron + b.iron,
      magnesium: a.magnesium + b.magnesium,
      phosphorus: a.phosphorus + b.phosphorus,
      potassium: a.potassium + b.potassium,
      sodium: a.sodium + b.sodium,
      zinc: a.zinc + b.zinc,
      copper: a.copper + b.copper,
      manganese: a.manganese + b.manganese,
      selenium: a.selenium + b.selenium,
      fluoride: a.fluoride + b.fluoride,
      chromium: a.chromium + b.chromium,
      iodine: a.iodine + b.iodine,
      molybdenum: a.molybdenum + b.molybdenum,
      vitA_RAE: a.vitA_RAE + b.vitA_RAE,
      vitA_IU: a.vitA_IU + b.vitA_IU,
      retinol: a.retinol + b.retinol,
      alphaCarot: a.alphaCarot + b.alphaCarot,
      betaCarot: a.betaCarot + b.betaCarot,
      betaCrypt: a.betaCrypt + b.betaCrypt,
      lycopene: a.lycopene + b.lycopene,
      luteinZea: a.luteinZea + b.luteinZea,
      vitE: a.vitE + b.vitE,
      vitD_mcg: a.vitD_mcg + b.vitD_mcg,
      vitD_IU: a.vitD_IU + b.vitD_IU,
      vitK: a.vitK + b.vitK,
      vitK_Mena: a.vitK_Mena + b.vitK_Mena,
      vitC: a.vitC + b.vitC,
      thiamine: a.thiamine + b.thiamine,
      riboflavin: a.riboflavin + b.riboflavin,
      niacin: a.niacin + b.niacin,
      pantothenic: a.pantothenic + b.pantothenic,
      vitB6: a.vitB6 + b.vitB6,
      folate: a.folate + b.folate,
      vitB12: a.vitB12 + b.vitB12,
      choline: a.choline + b.choline,
      betaine: a.betaine + b.betaine,
      biotin: a.biotin + b.biotin,
      omega3: a.omega3 + b.omega3,
      omega6: a.omega6 + b.omega6,
      ala: a.ala + b.ala,
      epa: a.epa + b.epa,
      dha: a.dha + b.dha,
      linoleic: a.linoleic + b.linoleic,
      tryptophan: a.tryptophan + b.tryptophan,
      threonine: a.threonine + b.threonine,
      isoleucine: a.isoleucine + b.isoleucine,
      leucine: a.leucine + b.leucine,
      lysine: a.lysine + b.lysine,
      methionine: a.methionine + b.methionine,
      cystine: a.cystine + b.cystine,
      phenylalanine: a.phenylalanine + b.phenylalanine,
      tyrosine: a.tyrosine + b.tyrosine,
      valine: a.valine + b.valine,
      histidine: a.histidine + b.histidine,
    );
  }

  // Öğüne göre grupla
  Map<String, List<FoodEntry>> get entriesByMeal {
    final Map<String, List<FoodEntry>> grouped = {
      'kahvaltı': [],
      'öğle': [],
      'akşam': [],
      'ara öğün': [],
    };
    for (final entry in entries) {
      final meal = entry.mealType.toLowerCase();
      if (grouped.containsKey(meal)) {
        grouped[meal]!.add(entry);
      } else {
        grouped['ara öğün']!.add(entry);
      }
    }
    return grouped;
  }

  // Kalori hedefine göre kalan
  double remainingCalories(double dailyGoal) {
    return dailyGoal - totalNutrition.calories;
  }

  // Toplam egzersizden yakılan kalori
  double get totalBurnedFromExercises =>
      exercises.fold(0.0, (sum, e) => sum + e.burnedCalories);

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      waterIntakeMl: (json['waterIntakeMl'] as num?)?.toDouble() ?? 0,
      stepsCount: json['stepsCount'] as int?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      waterEntries: (json['waterEntries'] as List<dynamic>? ?? [])
          .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'waterIntakeMl': waterIntakeMl,
      'stepsCount': stepsCount,
      'weightKg': weightKg,
      'notes': notes,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'waterEntries': waterEntries.map((e) => e.toJson()).toList(),
    };
  }

  DailyLog copyWith({
    String? id,
    DateTime? date,
    List<FoodEntry>? entries,
    double? waterIntakeMl,
    int? stepsCount,
    double? weightKg,
    String? notes,
    List<ExerciseEntry>? exercises,
    List<WaterEntry>? waterEntries,
  }) {
    return DailyLog(
      id: id ?? this.id,
      date: date ?? this.date,
      entries: entries ?? this.entries,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      stepsCount: stepsCount ?? this.stepsCount,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
      exercises: exercises ?? this.exercises,
      waterEntries: waterEntries ?? this.waterEntries,
    );
  }
}
