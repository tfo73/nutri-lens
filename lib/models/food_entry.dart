import 'nutrition_data.dart';

class FoodEntry {
  final String id;
  final String name;
  final String? brand;
  final double portionSize;
  final String portionUnit;
  final NutritionData nutritionData;
  final DateTime timestamp;
  final String mealType; // kahvaltı, öğle, akşam, ara öğün
  final String? imageUrl;
  final String? imagePath;
  final String? notes;

  FoodEntry({
    required this.id,
    required this.name,
    this.brand,
    required this.portionSize,
    this.portionUnit = 'g',
    required this.nutritionData,
    required this.timestamp,
    required this.mealType,
    this.imageUrl,
    this.imagePath,
    this.notes,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      portionSize: (json['portionSize'] as num).toDouble(),
      portionUnit: json['portionUnit'] as String? ?? 'g',
      nutritionData: NutritionData.fromJson(json['nutritionData'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      mealType: json['mealType'] as String,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'portionSize': portionSize,
      'portionUnit': portionUnit,
      'nutritionData': nutritionData.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'mealType': mealType,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'notes': notes,
    };
  }

  FoodEntry copyWith({
    String? id,
    String? name,
    String? brand,
    double? portionSize,
    String? portionUnit,
    NutritionData? nutritionData,
    DateTime? timestamp,
    String? mealType,
    String? imageUrl,
    String? imagePath,
    String? notes,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      portionSize: portionSize ?? this.portionSize,
      portionUnit: portionUnit ?? this.portionUnit,
      nutritionData: nutritionData ?? this.nutritionData,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
    );
  }
}
