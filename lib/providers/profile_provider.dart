import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../services/purchase_service.dart';

enum Gender { male, female, other }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { lose, maintain, gain }

// Gelişmiş hedef sabitleri
class AdvancedGoals {
  static const muscleGain = 'muscleGain';
  static const bodyRecomposition = 'bodyRecomposition';
  static const visceralFat = 'visceralFat';
  static const athletic = 'athletic';
  static const hormonalBalance = 'hormonalBalance';
  static const gutHealth = 'gutHealth';
  static const antiInflammatory = 'antiInflammatory';
  static const longevity = 'longevity';

  static String label(String goal) {
    switch (goal) {
      case muscleGain: return 'Kas Kütlesi Artır';
      case bodyRecomposition: return 'Yağ Yak – Kas Koru';
      case visceralFat: return 'Visceral Yağ Azalt';
      case athletic: return 'Atletik Performans';
      case hormonalBalance: return 'Hormonal Denge';
      case gutHealth: return 'Gut Sağlığı';
      case antiInflammatory: return 'Anti-İnflamatuar';
      case longevity: return 'Uzun Ömür';
      default: return goal;
    }
  }

  static String emoji(String goal) {
    switch (goal) {
      case muscleGain: return '💪';
      case bodyRecomposition: return '🔥';
      case visceralFat: return '🎯';
      case athletic: return '🏃';
      case hormonalBalance: return '⚖️';
      case gutHealth: return '🌿';
      case antiInflammatory: return '🍵';
      case longevity: return '✨';
      default: return '🎯';
    }
  }

  static const all = [
    muscleGain, bodyRecomposition, visceralFat, athletic,
    hormonalBalance, gutHealth, antiInflammatory, longevity,
  ];
}

// Sağlık durumu kategorileri
class HealthConditionCategories {
  static const digestive = 'Sindirim';
  static const metabolic = 'Metabolik';
  static const cardiovascular = 'Kardiyovasküler';
  static const kidneyLiver = 'Böbrek & Karaciğer';
  static const autoimmune = 'Otoimmün';
  static const allergy = 'Alerji & İntolerans';
  static const boneJoint = 'Kemik & Eklem';
  static const psychological = 'Psikolojik';
  static const other = 'Diğer';

  static const Map<String, List<String>> all = {
    digestive: ['SIBO', 'IBS', 'Crohn', 'Çölyak', 'Laktoz İntoleransı', 'Reflü'],
    metabolic: ['Tip 1 Diyabet', 'Tip 2 Diyabet', 'İnsülin Direnci', 'Hipotiroidi', 'Hipertiroidi', 'PCOS'],
    cardiovascular: ['Hipertansiyon', 'Yüksek Kolesterol', 'Kalp Hastalığı'],
    kidneyLiver: ['Böbrek Hastalığı', 'Karaciğer Hastalığı'],
    autoimmune: ['Hashimoto', 'Lupus', 'Romatoid Artrit'],
    allergy: ['Fıstık Alerjisi', 'Gluten İntoleransı', 'Süt Alerjisi', 'Yumurta Alerjisi', 'Deniz Ürünleri Alerjisi'],
    boneJoint: ['Osteoporoz', 'Gut Hastalığı'],
    psychological: ['Yeme Bozukluğu Geçmişi'],
    other: ['Gebelik', 'Emzirme', 'Menopoz'],
  };
}

// Beslenme tercihleri
class DietaryPreferences {
  static const vegan = 'Vegan';
  static const vegetarian = 'Vejetaryen';
  static const halal = 'Helal';
  static const glutenFree = 'Gluten-Free';
  static const lactoseFree = 'Laktozsuz';
  static const kosher = 'Koşer';
  static const lowCarb = 'Düşük Karbonhidrat';
  static const mediterranean = 'Akdeniz Diyeti';
  static const paleo = 'Paleo';
  static const keto = 'Ketojenik';
  static const carnivore = 'Karnivor';

  static const all = [
    vegan, vegetarian, halal, glutenFree, lactoseFree,
    kosher, lowCarb, mediterranean, paleo, keto, carnivore,
  ];
}

class UserProfile {
  final String id;
  final String name;
  final int age;
  final double height;
  final double weight;
  final Gender gender;
  final ActivityLevel activityLevel;
  final Goal goal;
  final String? imagePath;
  final List<String> healthConditions;
  final String? advancedGoal;
  final List<String> dietaryPreferences;
  final DateTime createdAt;
  final double weeklyWeightDelta;
  final double startingWeight;
  final bool isFavorite;
  final DateTime? favoritedAt;
  final bool isPremium;
  final String? premiumPlan; // 'monthly' | 'yearly' | 'lifetime' | null
  final bool hadPremiumBefore;
  final DateTime? premiumExpirationDate;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.height,
    required this.weight,
    required this.gender,
    required this.activityLevel,
    required this.goal,
    this.imagePath,
    this.healthConditions = const [],
    this.advancedGoal,
    this.dietaryPreferences = const [],
    required this.createdAt,
    required this.weeklyWeightDelta,
    required this.startingWeight,
    this.isFavorite = false,
    this.favoritedAt,
    this.isPremium = false,
    this.premiumPlan,
    this.hadPremiumBefore = false,
    this.premiumExpirationDate,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    int? age,
    double? height,
    double? weight,
    Gender? gender,
    ActivityLevel? activityLevel,
    Goal? goal,
    String? imagePath,
    bool clearImagePath = false,
    List<String>? healthConditions,
    String? advancedGoal,
    bool clearAdvancedGoal = false,
    List<String>? dietaryPreferences,
    DateTime? createdAt,
    double? weeklyWeightDelta,
    double? startingWeight,
    bool? isFavorite,
    DateTime? favoritedAt,
    bool? isPremium,
    String? premiumPlan,
    bool clearPremiumPlan = false,
    bool? hadPremiumBefore,
    DateTime? premiumExpirationDate,
    bool clearPremiumExpirationDate = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      healthConditions: healthConditions ?? this.healthConditions,
      advancedGoal: clearAdvancedGoal ? null : (advancedGoal ?? this.advancedGoal),
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      createdAt: createdAt ?? this.createdAt,
      weeklyWeightDelta: weeklyWeightDelta ?? this.weeklyWeightDelta,
      startingWeight: startingWeight ?? this.startingWeight,
      isFavorite: isFavorite ?? this.isFavorite,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      isPremium: isPremium ?? this.isPremium,
      premiumPlan: clearPremiumPlan ? null : (premiumPlan ?? this.premiumPlan),
      hadPremiumBefore: hadPremiumBefore ?? this.hadPremiumBefore,
      premiumExpirationDate: clearPremiumExpirationDate ? null : (premiumExpirationDate ?? this.premiumExpirationDate),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'height': height,
        'weight': weight,
        'gender': gender.index,
        'activityLevel': activityLevel.index,
        'goal': goal.index,
        if (imagePath != null) 'imagePath': imagePath,
        'healthConditions': healthConditions,
        if (advancedGoal != null) 'advancedGoal': advancedGoal,
        'dietaryPreferences': dietaryPreferences,
        'createdAt': createdAt.toIso8601String(),
        'weeklyWeightDelta': weeklyWeightDelta,
        'startingWeight': startingWeight,
        'isFavorite': isFavorite,
        if (favoritedAt != null) 'favoritedAt': favoritedAt!.toIso8601String(),
        'isPremium': isPremium,
        if (premiumPlan != null) 'premiumPlan': premiumPlan,
        'hadPremiumBefore': hadPremiumBefore,
        if (premiumExpirationDate != null) 'premiumExpirationDate': premiumExpirationDate!.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        age: json['age'] as int,
        height: (json['height'] as num).toDouble(),
        weight: (json['weight'] as num).toDouble(),
        gender: Gender.values[json['gender'] as int],
        activityLevel: ActivityLevel.values[json['activityLevel'] as int],
        goal: Goal.values[json['goal'] as int],
        imagePath: json['imagePath'] as String?,
        healthConditions: (json['healthConditions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        advancedGoal: json['advancedGoal'] as String?,
        dietaryPreferences: (json['dietaryPreferences'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
        weeklyWeightDelta: (json['weeklyWeightDelta'] as num?)?.toDouble() ?? 0.0,
        startingWeight: (json['startingWeight'] as num?)?.toDouble() ?? (json['weight'] as num?)?.toDouble() ?? 70.0,
        isFavorite: json['isFavorite'] as bool? ?? false,
        favoritedAt: json['favoritedAt'] != null ? DateTime.parse(json['favoritedAt']) : null,
        isPremium: json['isPremium'] as bool? ?? false,
        premiumPlan: json['premiumPlan'] as String?,
        hadPremiumBefore: json['hadPremiumBefore'] as bool? ?? json['isPremium'] as bool? ?? false,
        premiumExpirationDate: json['premiumExpirationDate'] != null ? DateTime.parse(json['premiumExpirationDate']) : null,
      );

  // ─── Kalori / makro hesaplama ───────────────────────────────────────────────

  static double calculateBmr({
    required double weight,
    required double height,
    required int age,
    required Gender gender,
  }) {
    if (weight <= 0 || height <= 0 || age <= 0) return 2000;
    if (gender == Gender.male) {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      return 10 * weight + 6.25 * height - 5 * age - 161;
    }
  }

  double get bmr => calculateBmr(
        weight: weight,
        height: height,
        age: age,
        gender: gender,
      );

  double get tdee {
    const multipliers = {
      ActivityLevel.sedentary: 1.2,
      ActivityLevel.light: 1.375,
      ActivityLevel.moderate: 1.55,
      ActivityLevel.active: 1.725,
      ActivityLevel.veryActive: 1.9,
    };
    return bmr * (multipliers[activityLevel] ?? 1.2);
  }

  double get calorieGoal {
    switch (goal) {
      case Goal.lose:
        return (tdee - 500).clamp(1200, double.infinity);
      case Goal.maintain:
        return tdee;
      case Goal.gain:
        return tdee + 500;
    }
  }

  double get proteinGoal {
    if (weight <= 0) return 150;
    final isCarnivore = dietaryPreferences.contains('Karnivor') || dietaryPreferences.contains('Carnivore');
    if (isCarnivore) {
      const factors = {
        ActivityLevel.sedentary: 1.8,
        ActivityLevel.light: 2.0,
        ActivityLevel.moderate: 2.2,
        ActivityLevel.active: 2.4,
        ActivityLevel.veryActive: 2.6,
      };
      return weight * (factors[activityLevel] ?? 2.2);
    }
    const factors = {
      ActivityLevel.sedentary: 0.8,
      ActivityLevel.light: 1.2,
      ActivityLevel.moderate: 1.6,
      ActivityLevel.active: 2.0,
      ActivityLevel.veryActive: 2.2,
    };
    return weight * (factors[activityLevel] ?? 1.6);
  }

  double get fatGoal {
    final isCarnivore = dietaryPreferences.contains('Karnivor') || dietaryPreferences.contains('Carnivore');
    if (isCarnivore) {
      final fatCal = (calorieGoal - (proteinGoal * 4)).clamp(0.0, double.infinity);
      return fatCal / 9;
    }
    return calorieGoal * 0.25 / 9;
  }

  double get carbGoal {
    final isCarnivore = dietaryPreferences.contains('Karnivor') || dietaryPreferences.contains('Carnivore');
    if (isCarnivore) {
      return 0.0;
    }
    final proteinCalories = proteinGoal * 4;
    final fatCalories = fatGoal * 9;
    return ((calorieGoal - proteinCalories - fatCalories) / 4)
        .clamp(0.0, double.infinity);
  }

  double get bmi {
    if (height <= 0 || weight <= 0) return 0;
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  // ─── Mikro besin hedefleri (yaş/cinsiyet/hastalık) ─────────────────────────

  double get seleniumGoal => 55.0; // μg

  double get magnesiumGoal => gender == Gender.male ? 400.0 : 310.0; // mg

  double get omega3Goal => gender == Gender.male ? 1.6 : 1.1; // g

  double get omega6Goal => gender == Gender.male ? 17.0 : 12.0; // g

  double get ironGoal {
    if (healthConditions.contains('Gebelik')) return 27.0;
    if (healthConditions.contains('Emzirme')) return 10.0;
    return gender == Gender.male ? 8.0 : 18.0;
  } // mg

  double get zincGoal => gender == Gender.male ? 11.0 : 8.0; // mg

  double get vitaminDGoal =>
      healthConditions.contains('Osteoporoz') ? 20.0 : 15.0; // μg

  double get vitaminB12Goal =>
      healthConditions.contains('Gebelik') ? 2.8 : 2.4; // μg

  double get calciumGoal {
    if (healthConditions.contains('Osteoporoz')) return 1200.0;
    if (healthConditions.contains('Gebelik')) return 1300.0;
    return 1000.0;
  } // mg

  double get potassiumGoal {
    if (healthConditions.contains('Böbrek Hastalığı')) return 2000.0;
    return gender == Gender.male ? 3400.0 : 2600.0;
  } // mg

  double get sodiumLimit {
    if (healthConditions.contains('Hipertansiyon') ||
        healthConditions.contains('Böbrek Hastalığı')) {
      return 1500.0;
    }
    return 2300.0;
  } // mg (üst limit)

  double get fiberGoal {
    final isCarnivore = dietaryPreferences.contains('Karnivor') || dietaryPreferences.contains('Carnivore');
    if (isCarnivore) return 0.0;
    if (healthConditions.contains('SIBO')) return 0.0;
    return gender == Gender.male ? 38.0 : 25.0;
  } // g

  // ─── Etiketler ─────────────────────────────────────────────────────────────

  String get goalLabel {
    if (advancedGoal != null && advancedGoal!.isNotEmpty) {
      return AdvancedGoals.label(advancedGoal!);
    }
    switch (goal) {
      case Goal.lose: return 'Kilo Ver';
      case Goal.maintain: return 'Kilo Koru';
      case Goal.gain: return 'Kilo Al';
    }
  }

  String get activityLabel {
    switch (activityLevel) {
      case ActivityLevel.sedentary: return 'Hareketsiz';
      case ActivityLevel.light: return 'Az Hareketli';
      case ActivityLevel.moderate: return 'Orta Aktif';
      case ActivityLevel.active: return 'Çok Aktif';
      case ActivityLevel.veryActive: return 'Sporcu';
    }
  }

  bool get isComplete =>
      name.isNotEmpty && age > 0 && height > 0 && weight > 0;
}

class ProfileProvider extends ChangeNotifier {
  List<UserProfile> _profiles = [];
  UserProfile? _activeProfile;

  // Custom overrides (0 = use auto-calculated value)
  int _customCalorieGoal = 0;
  int _customProteinGoal = 0;
  int _customCarbGoal = 0;
  int _customFatGoal = 0;
  int _customWaterGoalMl = 0;
  int _customStepGoal = 0;
  bool _useMetricUnits = true;
  bool _healthSyncEnabled = false;
  bool _showMicroPercentage = false;
  int _weekStartDay = 1; // 1 = Monday, 7 = Sunday
  Map<String, double> _customMicroGoals = {};
  List<UserProfile> _friends = [];

  Future<void> _syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Sync settings
      batch.set(
        db.collection('users').doc(user.uid),
        {
          'settings': {
            'customCalorieGoal': _customCalorieGoal,
            'customProteinGoal': _customProteinGoal,
            'customCarbGoal': _customCarbGoal,
            'customFatGoal': _customFatGoal,
            'customWaterGoalMl': _customWaterGoalMl,
            'customStepGoal': _customStepGoal,
            'useMetricUnits': _useMetricUnits,
            'healthSyncEnabled': _healthSyncEnabled,
            'showMicroPercentage': _showMicroPercentage,
            'weekStartDay': _weekStartDay,
            'customMicroGoals': _customMicroGoals,
          },
          if (_activeProfile != null) 'profile': _activeProfile!.toJson(),
          'lastSync': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Sync active profile
      if (_activeProfile != null) {
        batch.set(
          db.collection('users').doc(user.uid).collection('profiles').doc(_activeProfile!.id),
          _activeProfile!.toJson(),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Cloud sync error: $e');
    }
  }

  ProfileProvider() {
    loadProfiles();
  }

  List<UserProfile> get profiles => _profiles;
  List<UserProfile> get friends {
    final list = List<UserProfile>.from(_friends);
    list.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      
      // If both are favorites, sort by favoritedAt (newest first)
      if (a.isFavorite && b.isFavorite) {
        final dateA = a.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      }
      
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }
  UserProfile? get activeProfile => _activeProfile;
  String get activeProfileId => _activeProfile?.id ?? '';

  String get name => activeProfile?.name ?? '';
  int get age => activeProfile?.age ?? 0;
  double get height => activeProfile?.height ?? 0;
  double get weight => activeProfile?.weight ?? 0;
  Gender get gender => activeProfile?.gender ?? Gender.male;
  ActivityLevel get activityLevel =>
      activeProfile?.activityLevel ?? ActivityLevel.sedentary;
  Goal get goal => activeProfile?.goal ?? Goal.maintain;

  bool get isProfileComplete => activeProfile?.isComplete ?? false;
  bool get useMetricUnits => _useMetricUnits;
  bool get healthSyncEnabled => _healthSyncEnabled;
  bool get showMicroPercentage => _showMicroPercentage;
  int get weekStartDay => _weekStartDay;
  bool get isPremium => _activeProfile?.isPremium ?? false;

  double get bmr => activeProfile?.bmr ?? 2000;
  double get tdee => activeProfile?.tdee ?? 2000;
  double get calorieGoal => _customCalorieGoal > 0
      ? _customCalorieGoal.toDouble()
      : (activeProfile?.calorieGoal ?? 2000);
  double get proteinGoal => _customProteinGoal > 0
      ? _customProteinGoal.toDouble()
      : (activeProfile?.proteinGoal ?? 150);
  double get fatGoal => _customFatGoal > 0
      ? _customFatGoal.toDouble()
      : (activeProfile?.fatGoal ?? 55);
  double get carbGoal => _customCarbGoal > 0
      ? _customCarbGoal.toDouble()
      : (activeProfile?.carbGoal ?? 250);
  double get fiberGoal => activeProfile?.fiberGoal ?? 25;
  int get waterGoalMl {
    if (_customWaterGoalMl > 0) return _customWaterGoalMl;
    if (_activeProfile != null && _activeProfile!.weight > 0) {
      return (_activeProfile!.weight * 35).round();
    }
    return 2000;
  }
  int get stepGoal => _customStepGoal > 0 ? _customStepGoal : 10000;

  // Custom overrides for settings display
  int get customCalorieGoalOverride => _customCalorieGoal;
  int get customProteinGoalOverride => _customProteinGoal;
  int get customCarbGoalOverride => _customCarbGoal;
  int get customFatGoalOverride => _customFatGoal;

  Future<void> setCustomCalorieGoal(int val) async {
    _customCalorieGoal = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_calorie_goal', val);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setCustomProteinGoal(int val) async {
    _customProteinGoal = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_protein_goal', val);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setCustomCarbGoal(int val) async {
    _customCarbGoal = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_carb_goal', val);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setCustomFatGoal(int val) async {
    _customFatGoal = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_fat_goal', val);
    notifyListeners();
    _syncToFirestore();
  }

  double getMicroGoal(String key, double fallback) {
    return _customMicroGoals[key] ?? fallback;
  }

  Future<void> setCustomMicroGoal(String key, double val) async {
    _customMicroGoals[key] = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_micro_goals', jsonEncode(_customMicroGoals));
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> autoGenerateNutritionGoals() async {
    _customCalorieGoal = 0;
    _customProteinGoal = 0;
    _customCarbGoal = 0;
    _customFatGoal = 0;
    _customMicroGoals.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_calorie_goal');
    await prefs.remove('custom_protein_goal');
    await prefs.remove('custom_carb_goal');
    await prefs.remove('custom_fat_goal');
    await prefs.remove('custom_micro_goals');
    
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setCustomWaterGoal(int ml) async {
    _customWaterGoalMl = ml;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_water_goal_ml', ml);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setCustomStepGoal(int steps) async {
    _customStepGoal = steps;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_step_goal', steps);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setUseMetricUnits(bool metric) async {
    _useMetricUnits = metric;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_metric_units', metric);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setHealthSyncEnabled(bool enabled) async {
    _healthSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_sync_enabled', enabled);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setShowMicroPercentage(bool val) async {
    _showMicroPercentage = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_micro_percentage', val);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setWeekStartDay(int day) async {
    _weekStartDay = day;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('week_start_day', day);
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> _saveWaterGoal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', waterGoalMl);
  }

  Future<void> updatePremiumStatus(bool val, {String? planName}) async {
    if (_activeProfile == null) return;
    
    DateTime? expDate;
    if (val) {
      if (planName == 'monthly') {
        final hasTrial = !_activeProfile!.hadPremiumBefore;
        expDate = DateTime.now().add(Duration(days: hasTrial ? 3 : 30));
      } else if (planName == 'yearly') {
        expDate = DateTime.now().add(const Duration(days: 365));
      } else if (planName == 'lifetime') {
        expDate = DateTime(2099, 12, 31);
      }
    }

    _activeProfile = _activeProfile!.copyWith(
      isPremium: val,
      premiumPlan: planName,
      clearPremiumPlan: planName == null && !val,
      premiumExpirationDate: expDate,
      clearPremiumExpirationDate: expDate == null && !val,
      hadPremiumBefore: val ? true : _activeProfile!.hadPremiumBefore,
    );

    final idx = _profiles.indexWhere((p) => p.id == _activeProfile!.id);
    if (idx != -1) {
      _profiles[idx] = _activeProfile!;
    }

    notifyListeners();
    await _saveAll();
    await _syncToFirestore();
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'all_profiles',
      _profiles.map((e) => jsonEncode(e.toJson())).toList(),
    );
    if (_activeProfile != null) {
      await prefs.setString('active_profile_id', _activeProfile!.id);
    }
  }

  void clearAll() {
    _profiles = [];
    _activeProfile = null;
    _customCalorieGoal = 0;
    _customProteinGoal = 0;
    _customCarbGoal = 0;
    _customFatGoal = 0;
    _customWaterGoalMl = 0;
    _customStepGoal = 0;
    _customMicroGoals = {};
    _friends = [];
    notifyListeners();
  }

  Future<void> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final oldData = prefs.getStringList('profiles');
    if (oldData != null && oldData.isNotEmpty) {
      await prefs.setStringList('all_profiles', oldData);
      await prefs.remove('profiles');
    }
    final data = prefs.getStringList('all_profiles') ?? [];
    _profiles = data
        .map((e) => UserProfile.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    final activeId = prefs.getString('active_profile_id');
    if (_profiles.isNotEmpty) {
      _activeProfile = _profiles.firstWhere(
        (p) => p.id == activeId,
        orElse: () => _profiles.first,
      );
      await _saveWaterGoal();
    }
    // Load custom overrides
    _customCalorieGoal = prefs.getInt('custom_calorie_goal') ?? 0;
    _customProteinGoal = prefs.getInt('custom_protein_goal') ?? 0;
    _customCarbGoal = prefs.getInt('custom_carb_goal') ?? 0;
    _customFatGoal = prefs.getInt('custom_fat_goal') ?? 0;
    _customWaterGoalMl = prefs.getInt('custom_water_goal_ml') ?? 0;
    _customStepGoal = prefs.getInt('custom_step_goal') ?? 0;
    _useMetricUnits = prefs.getBool('use_metric_units') ?? true;
    _healthSyncEnabled = prefs.getBool('health_sync_enabled') ?? false;
    _showMicroPercentage = prefs.getBool('show_micro_percentage') ?? false;
    _weekStartDay = prefs.getInt('week_start_day') ?? 1;
    
    final microStr = prefs.getString('custom_micro_goals');
    if (microStr != null) {
      try {
        final decoded = jsonDecode(microStr) as Map<String, dynamic>;
        _customMicroGoals = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (e) {
        _customMicroGoals = {};
      }
    } else {
      _customMicroGoals = {};
    }
    
    // Load friends
    final friendsData = prefs.getStringList('all_friends') ?? [];
    if (friendsData.isEmpty) {
      _friends = [];
    } else {
      _friends = friendsData
          .map((e) => UserProfile.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    }
    
    notifyListeners();

    // After local load, attempt cloud fetch if authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final settings = data['settings'] as Map<String, dynamic>?;
          if (settings != null) {
            _customCalorieGoal = settings['customCalorieGoal'] ?? _customCalorieGoal;
            _customProteinGoal = settings['customProteinGoal'] ?? _customProteinGoal;
            _customCarbGoal = settings['customCarbGoal'] ?? _customCarbGoal;
            _customFatGoal = settings['customFatGoal'] ?? _customFatGoal;
            _customWaterGoalMl = settings['customWaterGoalMl'] ?? _customWaterGoalMl;
            _customStepGoal = settings['customStepGoal'] ?? _customStepGoal;
            _useMetricUnits = settings['useMetricUnits'] ?? _useMetricUnits;
            _healthSyncEnabled = settings['healthSyncEnabled'] ?? _healthSyncEnabled;
            _showMicroPercentage = settings['showMicroPercentage'] ?? _showMicroPercentage;
            _weekStartDay = settings['weekStartDay'] ?? _weekStartDay;
            if (settings['customMicroGoals'] != null) {
              _customMicroGoals = (settings['customMicroGoals'] as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, (v as num).toDouble()));
            }
          }
          
          // Also fetch profiles from subcollection if local is empty
          if (_profiles.isEmpty) {
            final profileQuery = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profiles')
                .get();
            if (profileQuery.docs.isNotEmpty) {
              _profiles = profileQuery.docs
                  .map((d) => UserProfile.fromJson(d.data()))
                  .toList();
              _activeProfile = _profiles.first;
              await _saveAll();
            }
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Cloud load error: $e');
      }
    }

    // Check if subscription or promo code has expired
    _checkPremiumExpiration();
  }
  Future<void> _checkPremiumExpiration() async {
    // Only check if they are currently marked as premium
    if (_activeProfile == null || !_activeProfile!.isPremium) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Check promo code expiration from Firestore root user document
    if (!user.isAnonymous) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final premiumData = data['premium'] as Map<String, dynamic>?;
          if (premiumData != null) {
            final isPremiumDoc = premiumData['isPremium'] as bool? ?? false;
            final expirationStr = premiumData['expirationDate'] as String?;
            if (expirationStr != null) {
              final expiration = DateTime.parse(expirationStr);
              if (expiration.isBefore(DateTime.now())) {
                debugPrint('[ProfileProvider] Promo code premium expired! Expiration: $expiration');
                await updatePremiumStatus(false);
                return; // Exited early since premium is now false
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ProfileProvider] Error checking promo code expiration: $e');
      }
    }

    // 2. Check subscription status against Google Play Store
    if (_activeProfile != null && 
        _activeProfile!.isPremium && 
        (_activeProfile!.premiumPlan == 'monthly' || _activeProfile!.premiumPlan == 'yearly')) {
      try {
        final activePurchases = await PurchaseService.instance.queryActivePurchasesSilently();
        
        // Find if our subscription product is in the active purchases list
        PurchaseDetails? subPurchase;
        for (final p in activePurchases) {
          if (p.productID == kProductMonthly || p.productID == kProductYearly) {
            subPurchase = p;
            break;
          }
        }

        if (subPurchase == null) {
          // Store doesn't return the purchase at all!
          // We check local premiumExpirationDate. If it is null or passed, we deactivate.
          final expDate = _activeProfile!.premiumExpirationDate;
          if (expDate == null || expDate.isBefore(DateTime.now())) {
            debugPrint('[ProfileProvider] Store returned no purchases and expiration date has passed. Deactivating.');
            await updatePremiumStatus(false);
          } else {
            debugPrint('[ProfileProvider] Store returned no purchases but paid cycle is still valid until: $expDate. Keeping active.');
          }
        } else {
          // Store returned the purchase!
          // Let's check Google Play specific details (isAutoRenewing and purchaseTime)
          bool autoRenewing = true;
          int purchaseTime = DateTime.now().millisecondsSinceEpoch;

          if (defaultTargetPlatform == TargetPlatform.android && subPurchase is GooglePlayPurchaseDetails) {
            autoRenewing = subPurchase.billingClientPurchase.isAutoRenewing;
            purchaseTime = subPurchase.billingClientPurchase.purchaseTime;
          }

          if (autoRenewing) {
            // Subscription is still active and auto-renewing.
            // We extend the local expiration date dynamically!
            final isMonthly = subPurchase.productID == kProductMonthly;
            final duration = isMonthly 
                ? const Duration(days: 30) 
                : const Duration(days: 365);
            final newExpDate = DateTime.fromMillisecondsSinceEpoch(purchaseTime).add(duration);
            
            if (_activeProfile!.premiumExpirationDate == null || 
                _activeProfile!.premiumExpirationDate!.isBefore(newExpDate)) {
              debugPrint('[ProfileProvider] Active subscription found. Syncing/Extending expiration to: $newExpDate');
              _activeProfile = _activeProfile!.copyWith(
                isPremium: true,
                premiumPlan: isMonthly ? 'monthly' : 'yearly',
                premiumExpirationDate: newExpDate,
              );
              await _saveAll();
              await _syncToFirestore();
              notifyListeners();
            }
          } else {
            // User has CANCELLED the subscription in Google Play!
            // Calculate the exact end date based on purchaseTime + billingPeriod
            final isMonthly = subPurchase.productID == kProductMonthly;
            // If they are monthly, check if they had premium before to see if it was a trial
            final hasTrial = !_activeProfile!.hadPremiumBefore;
            final duration = isMonthly 
                ? (hasTrial ? const Duration(days: 3) : const Duration(days: 30)) 
                : const Duration(days: 365);
            
            final endOfCycleDate = DateTime.fromMillisecondsSinceEpoch(purchaseTime).add(duration);
            
            if (endOfCycleDate.isBefore(DateTime.now())) {
              debugPrint('[ProfileProvider] Subscription was cancelled and the paid cycle ended on: $endOfCycleDate. Deactivating.');
              await updatePremiumStatus(false);
            } else {
              debugPrint('[ProfileProvider] Subscription was cancelled but paid cycle is still valid until: $endOfCycleDate. Keeping active.');
              // Sync this exact end date to profile
              if (_activeProfile!.premiumExpirationDate == null || 
                  !_activeProfile!.premiumExpirationDate!.isAtSameMomentAs(endOfCycleDate)) {
                _activeProfile = _activeProfile!.copyWith(
                  isPremium: true,
                  premiumPlan: isMonthly ? 'monthly' : 'yearly',
                  premiumExpirationDate: endOfCycleDate,
                );
                await _saveAll();
                await _syncToFirestore();
                notifyListeners();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ProfileProvider] Error verifying store subscription (possibly offline): $e');
      }
    }
  }

  Future<void> _saveFriends() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'all_friends',
      _friends.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<UserProfile?> findUserById(String id) async {
    final cleanId = id.trim().toUpperCase();
    if (cleanId.isEmpty) return null;
    
    try {
      final db = FirebaseFirestore.instance;
      // Search for user whose document ID starts with cleanId 
      // (since the short ID is the first 8 chars of the UID)
      // or search by a 'shortId' field if we add it. 
      // For now, let's try searching document IDs.
      
      final query = await db.collection('users').get();
      for (final doc in query.docs) {
        final uid = doc.id.toUpperCase();
        final shortId = uid.length > 8 ? uid.substring(0, 8) : uid;
        if (shortId == cleanId) {
          final data = doc.data();
          final hp = data['health_profile'] as Map<String, dynamic>?;
          if (hp != null) {
            return UserProfile(
              id: shortId,
              name: hp['firstName'] ?? 'Kullanıcı',
              age: hp['age'] ?? 0,
              height: (hp['heightCm'] as num?)?.toDouble() ?? 0.0,
              weight: (hp['weightKg'] as num?)?.toDouble() ?? 0.0,
              gender: _parseGender(hp['gender']),
              activityLevel: _parseActivity(hp['activityLevel']),
              goal: _parseGoal(hp['primaryGoal']),
              createdAt: (data['onboarding']?['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              weeklyWeightDelta: 0.5,
              startingWeight: (hp['weightKg'] as num?)?.toDouble() ?? 70.0,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('findUserById error: $e');
    }
    
    return null;
  }

  Gender _parseGender(String? g) {
    if (g == 'female') return Gender.female;
    return Gender.male;
  }

  ActivityLevel _parseActivity(String? a) {
    switch (a) {
      case 'light': return ActivityLevel.light;
      case 'moderate': return ActivityLevel.moderate;
      case 'active': return ActivityLevel.active;
      case 'veryActive': return ActivityLevel.veryActive;
      default: return ActivityLevel.sedentary;
    }
  }

  Goal _parseGoal(String? g) {
    switch (g) {
      case 'maintain': return Goal.maintain;
      case 'gain': return Goal.gain;
      default: return Goal.lose;
    }
  }

  Future<void> addFriend(UserProfile friend) async {
    if (!_friends.any((f) => f.id == friend.id)) {
      _friends.add(friend.copyWith(createdAt: DateTime.now()));
      await _saveFriends();
      notifyListeners();
    }
  }

  Future<void> addFriendById(String id) async {
    final user = await findUserById(id);
    if (user != null) {
      await addFriend(user);
    }
  }

  Future<void> toggleFavoriteFriend(String id) async {
    final index = _friends.indexWhere((f) => f.id == id);
    if (index != -1) {
      final f = _friends[index];
      final newIsFavorite = !f.isFavorite;
      _friends[index] = f.copyWith(
        isFavorite: newIsFavorite,
        favoritedAt: newIsFavorite ? DateTime.now() : null,
      );
      await _saveFriends();
      notifyListeners();
    }
  }

  Future<void> removeFriend(String id) async {
    _friends.removeWhere((f) => f.id == id);
    await _saveFriends();
    notifyListeners();
  }



  Future<void> addProfile(UserProfile profile) async {
    _profiles.add(profile);
    if (_activeProfile == null) {
      _activeProfile = profile;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_profile_id', profile.id);
    }
    await _saveAll();
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> switchProfile(String profileId) async {
    _activeProfile = _profiles.firstWhere((p) => p.id == profileId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_profile_id', profileId);
    await _saveWaterGoal();
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> setActiveProfile(String id) => switchProfile(id);

  Future<void> updateProfile(UserProfile updated) async {
    _profiles = _profiles.map((p) => p.id == updated.id ? updated : p).toList();
    if (_activeProfile?.id == updated.id) {
      _activeProfile = updated;
      await _saveWaterGoal();
    }
    await _saveAll();
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> updateProfileImage(String profileId, String? imagePath) async {
    final profile = _profiles.firstWhere((p) => p.id == profileId,
        orElse: () => throw StateError('Profile not found'));
    final updated = profile.copyWith(
      imagePath: imagePath,
      clearImagePath: imagePath == null,
    );
    await updateProfile(updated);
  }

  Future<void> deleteProfile(String id) async {
    _profiles = _profiles.where((p) => p.id != id).toList();
    if (_activeProfile?.id == id) {
      _activeProfile = _profiles.isNotEmpty ? _profiles.first : null;
    }
    await _saveAll();
    if (_activeProfile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_profile_id', _activeProfile!.id);
    }
    notifyListeners();
    _syncToFirestore();
  }

  Future<void> save({
    required String name,
    required int age,
    required double height,
    required double weight,
    required Gender gender,
    required ActivityLevel activityLevel,
    required Goal goal,
    String? profileId,
    String? imagePath,
    List<String>? healthConditions,
    String? advancedGoal,
    List<String>? dietaryPreferences,
    double? weeklyWeightDelta,
    DateTime? createdAt,
    double? startingWeight,
  }) async {
    // When profileId is provided → edit existing profile
    // When profileId is null → always create a brand new profile with a unique ID
    final id = (profileId != null && profileId.isNotEmpty)
        ? profileId
        : DateTime.now().millisecondsSinceEpoch.toString();

    // Preserve existing imagePath if no new one provided
    String? existingImagePath;
    String? existingAdvancedGoal;
    List<String> existingHealthConditions = [];
    List<String> existingDietaryPreferences = [];
    double existingWeeklyWeightDelta = 0.5;
    DateTime existingCreatedAt = DateTime.now();
    double existingStartingWeight = weight;

    if (profileId != null) {
      final existing = _profiles.firstWhere(
        (p) => p.id == profileId,
        orElse: () => UserProfile(
          id: '',
          name: '',
          age: 0,
          height: 0,
          weight: 0,
          gender: Gender.male,
          activityLevel: ActivityLevel.sedentary,
          goal: Goal.maintain,
          createdAt: DateTime.now(),
          weeklyWeightDelta: 0.5,
          startingWeight: 0,
        ),
      );
      existingImagePath = existing.imagePath;
      existingAdvancedGoal = existing.advancedGoal;
      existingHealthConditions = existing.healthConditions;
      existingDietaryPreferences = existing.dietaryPreferences;
      existingWeeklyWeightDelta = existing.weeklyWeightDelta;
      existingCreatedAt = existing.createdAt;
      existingStartingWeight = existing.startingWeight;
    }

    final profile = UserProfile(
      id: id,
      name: name,
      age: age,
      height: height,
      weight: weight,
      gender: gender,
      activityLevel: activityLevel,
      goal: goal,
      imagePath: imagePath ?? existingImagePath,
      healthConditions: healthConditions ?? existingHealthConditions,
      advancedGoal: advancedGoal ?? existingAdvancedGoal,
      dietaryPreferences: dietaryPreferences ?? existingDietaryPreferences,
      weeklyWeightDelta: weeklyWeightDelta ?? existingWeeklyWeightDelta,
      createdAt: createdAt ?? existingCreatedAt,
      startingWeight: startingWeight ?? existingStartingWeight,
    );
    if (_profiles.any((p) => p.id == profile.id)) {
      await updateProfile(profile);
    } else {
      await addProfile(profile);
    }
  }

  Future<void> setProfileComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    if (!complete) {
      // Clear data to force onboarding restart
      await prefs.remove('active_profile_id');
      await prefs.remove('onboarding_step');
      await prefs.remove('onboarding_completed_steps');
      await prefs.remove('onboarding_data');
      await prefs.remove('onboarding_done');
      
      _activeProfile = null;
      notifyListeners();
    } else {
      await prefs.setBool('onboarding_done', true);
    }
  }
}
