import 'nutrition_data.dart';
import 'nutrition_data_65.dart';

class FoodEntry {
  final String id;
  final String name;
  final String? brand;
  final double portionSize;
  final String portionUnit;
  final NutritionData nutritionData;

  /// 65-besin değeri (100g başına, ölçeklenmemiş). FNDDS eşleşmesi varsa dolu.
  final NutritionData65? nutrition65per100g;

  final DateTime timestamp;
  final String mealType; // kahvaltı, öğle, akşam, ara öğün
  final String? imageUrl;
  final String? imagePath;
  final String? notes;

  /// OpenFoodFacts NOVA grubu (1–4). Barkod taraması veya OFF eşleşmesinde dolu.
  final int? novaGroup;

  FoodEntry({
    required this.id,
    required this.name,
    this.brand,
    required this.portionSize,
    this.portionUnit = 'g',
    required this.nutritionData,
    this.nutrition65per100g,
    required this.timestamp,
    required this.mealType,
    this.imageUrl,
    this.imagePath,
    this.notes,
    this.novaGroup,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    final n65raw = json['nutrition65'] as Map<String, dynamic>?;
    return FoodEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      portionSize: (json['portionSize'] as num).toDouble(),
      portionUnit: json['portionUnit'] as String? ?? 'g',
      nutritionData: NutritionData.fromJson(json['nutritionData'] as Map<String, dynamic>),
      nutrition65per100g: n65raw != null ? NutritionData65.fromJson(n65raw) : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      mealType: json['mealType'] as String,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      notes: json['notes'] as String?,
      novaGroup: (json['novaGroup'] as num?)?.toInt(),
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
      if (nutrition65per100g != null) 'nutrition65': nutrition65per100g!.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'mealType': mealType,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'notes': notes,
      if (novaGroup != null) 'novaGroup': novaGroup,
    };
  }

  FoodEntry copyWith({
    String? id,
    String? name,
    String? brand,
    double? portionSize,
    String? portionUnit,
    NutritionData? nutritionData,
    NutritionData65? nutrition65per100g,
    DateTime? timestamp,
    String? mealType,
    String? imageUrl,
    String? imagePath,
    String? notes,
    int? novaGroup,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      portionSize: portionSize ?? this.portionSize,
      portionUnit: portionUnit ?? this.portionUnit,
      nutritionData: nutritionData ?? this.nutritionData,
      nutrition65per100g: nutrition65per100g ?? this.nutrition65per100g,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      novaGroup: novaGroup ?? this.novaGroup,
    );
  }
}
