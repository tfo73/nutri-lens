import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Gender { male, female }

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

  static const all = [
    vegan, vegetarian, halal, glutenFree, lactoseFree,
    kosher, lowCarb, mediterranean, paleo, keto,
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
      );

  // ─── Kalori / makro hesaplama ───────────────────────────────────────────────

  double get bmr {
    if (weight <= 0 || height <= 0 || age <= 0) return 2000;
    if (gender == Gender.male) {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      return 10 * weight + 6.25 * height - 5 * age - 161;
    }
  }

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

  double get proteinGoal => weight > 0 ? weight * 2 : 150;
  double get fatGoal => calorieGoal * 0.25 / 9;
  double get carbGoal {
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
    if (healthConditions.contains('SIBO')) return 0.0;
    return gender == Gender.male ? 38.0 : 25.0;
  } // g

  // ─── Etiketler ─────────────────────────────────────────────────────────────

  String get goalLabel {
    if (advancedGoal != null) return AdvancedGoals.label(advancedGoal!);
    switch (goal) {
      case Goal.lose: return 'Kilo Ver';
      case Goal.maintain: return 'Koru';
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

  ProfileProvider() {
    loadProfiles();
  }

  List<UserProfile> get profiles => _profiles;
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

  double get bmr => activeProfile?.bmr ?? 2000;
  double get tdee => activeProfile?.tdee ?? 2000;
  double get calorieGoal => activeProfile?.calorieGoal ?? 2000;
  double get proteinGoal => activeProfile?.proteinGoal ?? 150;
  double get fatGoal => activeProfile?.fatGoal ?? 55;
  double get carbGoal => activeProfile?.carbGoal ?? 250;

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
    }
    notifyListeners();
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'all_profiles',
      _profiles.map((e) => jsonEncode(e.toJson())).toList(),
    );
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
  }

  Future<void> switchProfile(String profileId) async {
    _activeProfile = _profiles.firstWhere((p) => p.id == profileId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_profile_id', profileId);
    notifyListeners();
  }

  Future<void> setActiveProfile(String id) => switchProfile(id);

  Future<void> updateProfile(UserProfile updated) async {
    _profiles = _profiles.map((p) => p.id == updated.id ? updated : p).toList();
    if (_activeProfile?.id == updated.id) _activeProfile = updated;
    await _saveAll();
    notifyListeners();
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
        ),
      );
      existingImagePath = existing.imagePath;
      existingAdvancedGoal = existing.advancedGoal;
      existingHealthConditions = existing.healthConditions;
      existingDietaryPreferences = existing.dietaryPreferences;
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
    );
    if (_profiles.any((p) => p.id == profile.id)) {
      await updateProfile(profile);
    } else {
      await addProfile(profile);
    }
  }
}
