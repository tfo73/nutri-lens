import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      id: 'carb_master',
      emoji: '🍝',
      name: 'Karbonhidrat Ustası',
      description: '7 gün üst üste karbonhidrat hedefini tut',
      requirement: 7,
      progressKey: 'carbStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'fat_master',
      emoji: '🥑',
      name: 'Yağ Ustası',
      description: '7 gün üst üste yağ hedefini tut',
      requirement: 7,
      progressKey: 'fatStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'fiber_fan',
      emoji: '🥬',
      name: 'Lif Meraklısı',
      description: '7 gün üst üste lif hedefini tut',
      requirement: 7,
      progressKey: 'fiberStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'consistency_king',
      emoji: '👑',
      name: 'İstikrar Kralı',
      description: '100 öğün kaydet',
      requirement: 100,
      progressKey: 'totalMeals',
      unit: 'öğün',
    ),
    AchievementDef(
      id: 'marathoner',
      emoji: '🏃',
      name: 'Maratoncu',
      description: '90 gün üst üste kayıt yap',
      requirement: 90,
      progressKey: 'logStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'fasting_beginner',
      emoji: '🧘',
      name: 'İlk Oruç',
      description: 'İlk orucunu başarıyla tamamla',
      requirement: 1,
      progressKey: 'totalFasts',
      unit: 'adet',
    ),
    AchievementDef(
      id: 'fasting_regular',
      emoji: '⏱️',
      name: 'Oruç Müdavimi',
      description: '10 adet oruç tamamla',
      requirement: 10,
      progressKey: 'totalFasts',
      unit: 'adet',
    ),
    AchievementDef(
      id: 'fasting_endurance',
      emoji: '🌌',
      name: 'Derin Otonomi',
      description: 'En az 24 saatlik bir oruç tamamla',
      requirement: 1,
      progressKey: 'longFasts',
      unit: 'adet',
    ),
    AchievementDef(
      id: 'fasting_streak',
      emoji: '🔥',
      name: 'Oruç Serisi',
      description: '3 gün üst üste oruç yap',
      requirement: 3,
      progressKey: 'fastingStreak',
      unit: 'gün',
    ),
    AchievementDef(
      id: 'fasting_pro',
      emoji: '🥇',
      name: 'Oruç Ustası',
      description: 'Toplam 100 saat oruç yap',
      requirement: 100,
      progressKey: 'totalFastingHours',
      unit: 'saat',
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
    'carbStreak': 0,
    'fatStreak': 0,
    'fiberStreak': 0,
    'totalFasts': 0,
    'longFasts': 0,
    'fastingStreak': 0,
    'totalFastingHours': 0,
    'lastFastingDate': 0, // Using timestamp for streak check
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

    // Cloud fetch
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('achievements').doc('data').get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data['progress'] != null) {
            final cloudProgress = data['progress'] as Map<String, dynamic>;
            cloudProgress.forEach((k, v) => _progress[k] = (v as num).toInt());
            await prefs.setString('ach_progress', jsonEncode(_progress));
          }
          if (data['earned'] != null) {
            final cloudEarned = List<String>.from(data['earned']);
            _earned.addAll(cloudEarned);
            await prefs.setStringList('ach_earned', _earned.toList());
          }
          if (data['lastCheckDate'] != null) {
            _lastCheckDate = data['lastCheckDate'];
            await prefs.setString('ach_last_check_date', _lastCheckDate);
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Achievements cloud load error: $e');
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ach_progress', jsonEncode(_progress));
    await prefs.setStringList('ach_earned', _earned.toList());
    await prefs.setString('ach_last_check_date', _lastCheckDate);

    // Cloud sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('achievements').doc('data').set({
          'progress': _progress,
          'earned': _earned.toList(),
          'lastCheckDate': _lastCheckDate,
          'lastSync': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Achievements cloud sync error: $e');
      }
    }
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
  
  void recordFastingCompleted({required double hours, required DateTime endTime}) {
    if (!_loaded) return;

    _progress['totalFasts'] = (_progress['totalFasts'] ?? 0) + 1;
    _progress['totalFastingHours'] = (_progress['totalFastingHours'] ?? 0) + hours.toInt();
    
    if (hours >= 24) {
      _progress['longFasts'] = (_progress['longFasts'] ?? 0) + 1;
    }

    // Streak logic
    final lastFastingTs = _progress['lastFastingDate'] ?? 0;
    if (lastFastingTs > 0) {
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastFastingTs);
      final diff = endTime.difference(lastDate).inDays;
      if (diff == 1) {
        _progress['fastingStreak'] = (_progress['fastingStreak'] ?? 0) + 1;
      } else if (diff > 1) {
        _progress['fastingStreak'] = 1;
      }
    } else {
      _progress['fastingStreak'] = 1;
    }
    _progress['lastFastingDate'] = endTime.millisecondsSinceEpoch;

    _checkAndAward();
    _save();
  }

  void onNutritionUpdated({
    required double calorieGoal,
    required double proteinGoal,
    required double carbGoal,
    required double fatGoal,
    required double fiberGoal,
    required double waterGoalMl,
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
    required double totalFiber,
    required double waterIntakeMl,
    required int mealCount,
  }) {
    if (!_loaded) return;

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    if (_lastCheckDate == todayStr) return;

    // Check if yesterday was missed
    if (_lastCheckDate.isNotEmpty) {
      final lastDate = DateTime.tryParse(_lastCheckDate);
      if (lastDate != null) {
        final diff = today.difference(lastDate).inDays;
        if (diff > 1) {
          _progress['logStreak'] = 0;
          _progress['calorieStreak'] = 0;
          _progress['proteinStreak'] = 0;
          _progress['carbStreak'] = 0;
          _progress['fatStreak'] = 0;
          _progress['fiberStreak'] = 0;
          _progress['waterStreak'] = 0;
        }
      }
    }

    _lastCheckDate = todayStr;

    final calorieGoalMet = calorieGoal > 0 &&
        totalCalories >= calorieGoal * 0.9 &&
        totalCalories <= calorieGoal * 1.1;
    final proteinGoalMet = proteinGoal > 0 && totalProtein >= proteinGoal * 0.9;
    final carbGoalMet = carbGoal > 0 && totalCarbs >= carbGoal * 0.9 && totalCarbs <= carbGoal * 1.1;
    final fatGoalMet = fatGoal > 0 && totalFat >= fatGoal * 0.9 && totalFat <= fatGoal * 1.1;
    final fiberGoalMet = fiberGoal > 0 && totalFiber >= fiberGoal * 0.9;
    final waterGoalMet = waterGoalMl > 0 && waterIntakeMl >= waterGoalMl;
    final hasLogs = mealCount > 0;
    
    final allGoalsMet = calorieGoalMet && proteinGoalMet && carbGoalMet && fatGoalMet && fiberGoalMet && waterGoalMet && hasLogs;

    if (hasLogs) {
      final oldStreak = _progress['logStreak'] ?? 0;
      _progress['logStreak'] = oldStreak + 1;
      // Vibrate for streak increase
      HapticFeedback.lightImpact();
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

    if (carbGoalMet) {
      _progress['carbStreak'] = (_progress['carbStreak'] ?? 0) + 1;
    } else {
      _progress['carbStreak'] = 0;
    }

    if (fatGoalMet) {
      _progress['fatStreak'] = (_progress['fatStreak'] ?? 0) + 1;
    } else {
      _progress['fatStreak'] = 0;
    }

    if (fiberGoalMet) {
      _progress['fiberStreak'] = (_progress['fiberStreak'] ?? 0) + 1;
    } else {
      _progress['fiberStreak'] = 0;
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
          // Vibrate for achievement
          HapticFeedback.mediumImpact();
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
