import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart' as notif_svc;

class AchievementDef {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final int requirement;
  final String progressKey;
  final String unit;

  const AchievementDef({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.requirement,
    required this.progressKey,
    required this.unit,
  });
}

class AchievementProvider extends ChangeNotifier {
  static const List<AchievementDef> achievements = [
    AchievementDef(
      id: 'water_champion',
      emoji: '💧',
      name: 'Su Şampiyonu',
      description: '7 gün üst üste su hedefine ulaş',
      requirement: 7,
      progressKey: 'waterStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'calorie_master',
      emoji: '🔥',
      name: 'Kalori Ustası',
      description: '7 gün üst üste kalori hedefini tut',
      requirement: 7,
      progressKey: 'calorieStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'protein_streak',
      emoji: '💪',
      name: 'Protein Şeridi',
      description: '5 gün üst üste protein hedefini tut',
      requirement: 5,
      progressKey: 'proteinStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'photo_enthusiast',
      emoji: '📸',
      name: 'Fotoğraf Meraklısı',
      description: '10 yemek fotoğrafı analiz et',
      requirement: 10,
      progressKey: 'photoCount',
      unit: 'fotoğraf',
    ),
    AchievementDef(
      id: 'healthy_start',
      emoji: '🥗',
      name: 'Sağlıklı Başlangıç',
      description: 'İlk yemeği kaydet',
      requirement: 1,
      progressKey: 'totalMeals',
      unit: 'öğün',
    ),
    AchievementDef(
      id: 'weekly_tracker',
      emoji: '📅',
      name: 'Haftalık Takip',
      description: '7 gün üst üste kayıt yap',
      requirement: 7,
      progressKey: 'logStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'goal_hunter',
      emoji: '🎯',
      name: 'Hedef Avcısı',
      description: 'Günlük tüm hedeflere ulaş',
      requirement: 1,
      progressKey: 'allGoalsDays',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'month_champion',
      emoji: '🏆',
      name: 'Ay Şampiyonu',
      description: '30 gün üst üste kayıt yap',
      requirement: 30,
      progressKey: 'logStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'hydration_expert',
      emoji: '🌊',
      name: 'Hidrasyon Uzmanı',
      description: '30 gün su hedefine ulaş',
      requirement: 30,
      progressKey: 'waterGoalDays',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'nutrition_sage',
      emoji: '🍎',
      name: 'Beslenme Bilgesi',
      description: '50 öğün kaydet',
      requirement: 50,
      progressKey: 'totalMeals',
      unit: 'öğün',
    ),
  ];

  Map<String, int> _progress = {
    'waterStreak': 0,
    'calorieStreak': 0,
    'proteinStreak': 0,
    'logStreak': 0,
    'photoCount': 0,
    'totalMeals': 0,
    'allGoalsDays': 0,
    'waterGoalDays': 0,
  };

  Set<String> _earned = {};
  Set<String> _newlyEarned = {};
  String _lastCheckDate = '';
  bool _loaded = false;

  Map<String, int> get progress => Map.unmodifiable(_progress);
  Set<String> get earned => Set.unmodifiable(_earned);
  Set<String> get newlyEarned => Set.unmodifiable(_newlyEarned);

  bool isEarned(String id) => _earned.contains(id);
  int getProgress(String progressKey) => _progress[progressKey] ?? 0;

  void clearNewlyEarned() {
    if (_newlyEarned.isNotEmpty) {
      _newlyEarned = {};
      notifyListeners();
    }
  }

  AchievementProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString('ach_progress');
    if (progressJson != null) {
      try {
        final decoded = jsonDecode(progressJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _progress[entry.key] = (entry.value as num).toInt();
        }
      } catch (_) {}
    }
    _earned = Set<String>.from(prefs.getStringList('ach_earned') ?? []);
    _lastCheckDate = prefs.getString('ach_last_check_date') ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ach_progress', jsonEncode(_progress));
    await prefs.setStringList('ach_earned', _earned.toList());
    await prefs.setString('ach_last_check_date', _lastCheckDate);
  }

  void recordPhotoAnalyzed() {
    if (!_loaded) return;
    _progress['photoCount'] = (_progress['photoCount'] ?? 0) + 1;
    _checkAndAward();
    _save();
  }

  void recordMealLogged() {
    if (!_loaded) return;
    _progress['totalMeals'] = (_progress['totalMeals'] ?? 0) + 1;
    _checkAndAward();
    _save();
  }

  void onNutritionUpdated({
    required double calorieGoal,
    required double proteinGoal,
    required double waterGoalMl,
    required double totalCalories,
    required double totalProtein,
    required double waterIntakeMl,
    required int mealCount,
  }) {
    if (!_loaded) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastCheckDate == today) return;

    _lastCheckDate = today;

    final calorieGoalMet = calorieGoal > 0 &&
        totalCalories >= calorieGoal * 0.9 &&
        totalCalories <= calorieGoal * 1.1;
    final proteinGoalMet =
        proteinGoal > 0 && totalProtein >= proteinGoal * 0.9;
    final waterGoalMet = waterGoalMl > 0 && waterIntakeMl >= waterGoalMl;
    final hasLogs = mealCount > 0;
    final allGoalsMet =
        calorieGoalMet && proteinGoalMet && waterGoalMet && hasLogs;

    if (hasLogs) {
      _progress['logStreak'] = (_progress['logStreak'] ?? 0) + 1;
    } else {
      _progress['logStreak'] = 0;
    }

    if (calorieGoalMet) {
      _progress['calorieStreak'] = (_progress['calorieStreak'] ?? 0) + 1;
    } else {
      _progress['calorieStreak'] = 0;
    }

    if (proteinGoalMet) {
      _progress['proteinStreak'] = (_progress['proteinStreak'] ?? 0) + 1;
    } else {
      _progress['proteinStreak'] = 0;
    }

    if (waterGoalMet) {
      _progress['waterStreak'] = (_progress['waterStreak'] ?? 0) + 1;
      _progress['waterGoalDays'] = (_progress['waterGoalDays'] ?? 0) + 1;
    } else {
      _progress['waterStreak'] = 0;
    }

    if (allGoalsMet) {
      _progress['allGoalsDays'] = (_progress['allGoalsDays'] ?? 0) + 1;
    }

    _checkAndAward();
    _save();
  }

  void _checkAndAward() {
    bool changed = false;
    for (final ach in achievements) {
      if (!_earned.contains(ach.id)) {
        final prog = _progress[ach.progressKey] ?? 0;
        if (prog >= ach.requirement) {
          _earned.add(ach.id);
          _newlyEarned.add(ach.id);
          changed = true;
          _sendNotification(ach);
        }
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> _sendNotification(AchievementDef ach) async {
    try {
      await notif_svc.NotificationService.showAchievementNotification(
        title: '🎉 Yeni rozet kazandın!',
        body: '${ach.emoji} ${ach.name}',
      );
    } catch (_) {}
  }
}
