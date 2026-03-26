import 'exercise_entry.dart';
import 'food_entry.dart';
import 'nutrition_data.dart';

class DailyLog {
  final String id;
  final DateTime date;
  final List<FoodEntry> entries;
  final double waterIntakeMl;
  final int? stepsCount;
  final double? weightKg;
  final String? notes;
  final List<ExerciseEntry> exercises;

  DailyLog({
    required this.id,
    required this.date,
    this.entries = const [],
    this.waterIntakeMl = 0,
    this.stepsCount,
    this.weightKg,
    this.notes,
    this.exercises = const [],
  });

  // Günlük toplam besin değerleri
  NutritionData get totalNutrition {
    if (entries.isEmpty) return NutritionData.empty;
    return entries.fold(NutritionData.empty, (sum, entry) {
      final scaled = entry.nutritionData.scaleBy(entry.portionSize / 100);
      return sum + scaled;
    });
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
    );
  }
}
