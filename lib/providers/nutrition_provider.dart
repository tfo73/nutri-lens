import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/food_analysis_result.dart';
import '../services/food_analysis_service.dart';
import '../services/conflict_detection_service.dart';
import 'profile_provider.dart';

class NutritionProvider extends ChangeNotifier {
  static const _savedMealsKey = 'saved_meals_v1';
  final List<FoodEntry> _savedMeals = [];
  List<FoodEntry> get savedMeals => List.unmodifiable(_savedMeals);
  DailyLog _todayLog = DailyLog(
    id: 'init',
    date: DateTime.now(),
    entries: [],
    waterIntakeMl: 0,
  );

  final Map<String, DailyLog> _historyLogs = {};
  String _profileId = '';
  
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  FoodAnalysisResult? _lastResult;
  FoodAnalysisResult? get lastResult => _lastResult;
  File? _lastAnalyzedImage;
  File? get lastAnalyzedImage => _lastAnalyzedImage;
  String? _lastMealType;
  String? get lastMealType => _lastMealType;
  String? _lastExtraContext;
  String? get lastExtraContext => _lastExtraContext;

  final FoodAnalysisService _analysisService = FoodAnalysisService();

  DailyLog get todayLog => _todayLog;
  NutritionData get totalNutrition => _todayLog.totalNutrition;
  String get currentProfileId => _profileId;

  bool _showResultOnHome = false;
  bool get showResultOnHome => _showResultOnHome;

  String? _analysisError;
  String? get analysisError => _analysisError;

  void clearAnalysisError() {
    _analysisError = null;
    notifyListeners();
  }

  void clearLastResult() {
    _lastResult = null;
    _lastAnalyzedImage = null;
    _lastMealType = null;
    _lastExtraContext = null;
    _showResultOnHome = false;
    _analysisError = null;
    notifyListeners();
  }

  void enableHomeResult() {
    _showResultOnHome = true;
    notifyListeners();
  }

  Future<void> analyzeAndAddImage(File image, String mealType, {String? extraContext}) async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;
    _lastAnalyzedImage = image;
    _lastMealType = mealType;
    _lastExtraContext = extraContext;
    _lastResult = null;
    _analysisError = null;
    _showResultOnHome = false;
    notifyListeners();

    try {
      final result = await _analysisService.analyze(image: image, hint: extraContext);
      _lastResult = result;
    } catch (e) {
      debugPrint('Background analysis error: $e');
      _analysisError = e.toString();
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> analyzeText(String description, String mealType) async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;
    _lastAnalyzedImage = null;
    _lastMealType = mealType;
    _lastResult = null;
    _analysisError = null;
    _showResultOnHome = false;
    notifyListeners();

    try {
      final result = await _analysisService.analyzeText(description);
      _lastResult = result;
    } catch (e) {
      debugPrint('Background text analysis error: $e');
      _analysisError = e.toString();
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  double get totalBurnedCaloriesFromExercises =>
      _todayLog.totalBurnedFromExercises;

  /// Ardışık gün sayısını hesaplar (dün'den geriye).
  /// Build metodundan güvenle çağrılabilir — state değiştirmez.
  int currentStreak({
    required double calorieGoal,
    required double proteinGoal,
    required double carbGoal,
    required double fatGoal,
    required double waterGoalMl,
    int stepGoal = 0,
  }) {
    if (calorieGoal <= 0) return 0;
    int streak = 0;
    final now = DateTime.now();
    for (int i = 1; i <= 365; i++) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final log = getLogForDate(date);
      if (log == null || log.entries.isEmpty) break;
      final n = log.totalNutrition;
      final ok = n.calories >= calorieGoal * 0.9 &&
          (proteinGoal <= 0 || n.protein >= proteinGoal * 0.9) &&
          (carbGoal <= 0 || n.carbohydrates >= carbGoal * 0.9) &&
          (fatGoal <= 0 || n.fat >= fatGoal * 0.9) &&
          (waterGoalMl <= 0 || log.waterIntakeMl >= waterGoalMl * 0.9) &&
          (stepGoal <= 0 || (log.stepsCount ?? 0) >= stepGoal * 0.9);
      if (!ok) break;
      streak++;
    }
    return streak;
  }

  /// Belirli bir gün için hedeflerin karşılanıp karşılanmadığını döner.
  bool isGoalMet(
    DateTime date, {
    required double calorieGoal,
    required double proteinGoal,
    required double carbGoal,
    required double fatGoal,
    required double waterGoalMl,
    int stepGoal = 0,
  }) {
    if (calorieGoal <= 0) return false;
    final log = getLogForDate(date);
    if (log == null || log.entries.isEmpty) return false;
    final n = log.totalNutrition;
    return n.calories >= calorieGoal * 0.9 &&
        (proteinGoal <= 0 || n.protein >= proteinGoal * 0.9) &&
        (carbGoal <= 0 || n.carbohydrates >= carbGoal * 0.9) &&
        (fatGoal <= 0 || n.fat >= fatGoal * 0.9) &&
        (waterGoalMl <= 0 || log.waterIntakeMl >= waterGoalMl * 0.9) &&
        (stepGoal <= 0 || (log.stepsCount ?? 0) >= stepGoal * 0.9);
  }

  NutritionProvider() {
    final todayKey = _dateKey(DateTime.now());
    _todayLog = DailyLog(
      id: todayKey,
      date: DateTime.now(),
      entries: [],
      waterIntakeMl: 0,
    );
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _storageKey(String dateKey) =>
      _profileId.isEmpty ? 'log_$dateKey' : 'profile_${_profileId}_log_$dateKey';

  String get _historyKeysKey =>
      _profileId.isEmpty ? 'history_keys' : 'profile_${_profileId}_history_keys';

  void switchProfile(String profileId) {
    if (_profileId == profileId) return;
    _profileId = profileId;
    _historyLogs.clear();
    final todayKey = _dateKey(DateTime.now());
    _todayLog = DailyLog(
      id: todayKey,
      date: DateTime.now(),
      entries: [],
      waterIntakeMl: 0,
    );
    notifyListeners();
    _loadData();
    _loadSavedMeals();
  }

  Future<void> forceCloudSync() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());

    // For migrated profile, check if we need to migrate old data
    if (_profileId == 'profile_migrated') {
      await _migrateOldData(prefs);
    }

    // Load history logs
    final historyKeys = prefs.getStringList(_historyKeysKey) ?? [];
    for (final key in historyKeys) {
      final json = prefs.getString(_storageKey(key));
      if (json != null) {
        try {
          _historyLogs[key] =
              DailyLog.fromJson(jsonDecode(json) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Geçmiş veri yükleme hatası ($key): $e');
        }
      }
    }

    // Load today's log
    final todayJson = prefs.getString(_storageKey(todayKey));
    if (todayJson != null) {
      try {
        _todayLog =
            DailyLog.fromJson(jsonDecode(todayJson) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Bugünün verisi yükleme hatası: $e');
      }
    }

    notifyListeners();

    // Cloud fetch if authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final db = FirebaseFirestore.instance;
        final userDoc = db.collection('users').doc(user.uid);
        
        // Fetch core logs
        final logsQuery = await userDoc.collection('logs').get();
        
        // Fetch water and steps in parallel for better performance
        final waterSnap = await userDoc.collection('water_logs').get();
        final stepsSnap = await userDoc.collection('step_logs').get();

        // Build map of water and steps for easy lookup
        final waterMap = {for (var doc in waterSnap.docs) doc.id: doc.data()};
        final stepsMap = {for (var doc in stepsSnap.docs) doc.id: doc.data()};

        if (logsQuery.docs.isNotEmpty) {
          bool updated = false;
          final keys = prefs.getStringList(_historyKeysKey) ?? [];

          for (final doc in logsQuery.docs) {
            final key = doc.id;
            final data = Map<String, dynamic>.from(doc.data());
            
            // Merge water data if exists
            if (waterMap.containsKey(key)) {
              data['waterIntakeMl'] = waterMap[key]!['ml'];
              data['waterEntries'] = waterMap[key]!['entries'] ?? [];
            }
            
            // Merge steps data if exists
            if (stepsMap.containsKey(key)) {
              data['stepsCount'] = stepsMap[key]!['steps'];
            }

            // Preprocess and unscale/repair entries if they are in the old scaled format
            if (data['entries'] != null) {
              final entriesList = List<dynamic>.from(data['entries'] as List);
              for (var i = 0; i < entriesList.length; i++) {
                final entryMap = Map<String, dynamic>.from(entriesList[i] as Map);
                final portionSize = (entryMap['portionSize'] as num?)?.toDouble() ?? 100.0;
                final factor = portionSize / 100.0;

                if (factor > 0 && factor != 1.0) {
                  // If it doesn't have nutritionDataScaled, it is the old format (where nutritionData was stored scaled)
                  if (!entryMap.containsKey('nutritionDataScaled')) {
                    final nutritionJson = entryMap['nutritionData'] as Map<String, dynamic>?;
                    if (nutritionJson != null) {
                      var currentND = NutritionData.fromJson(nutritionJson);
                      
                      // 1. Unscale by dividing by factor once (reversing the normal scaleBy done on save)
                      currentND = currentND.scaleBy(1.0 / factor);
                      
                      // 2. Self-Repair Heuristic: if portion calories are still abnormally high (> 1500 kcal),
                      // it was scaled multiple times. Divide by factor until portion calories <= 1000 kcal.
                      while ((currentND.calories * factor) > 1000.0) {
                        currentND = currentND.scaleBy(1.0 / factor);
                      }
                      
                      entryMap['nutritionData'] = currentND.toStructuredJson();
                    }
                  }
                }
                entriesList[i] = entryMap;
              }
              data['entries'] = entriesList;
            }

            final cloudLog = DailyLog.fromJson(data);
            
            final localLog = _historyLogs[key];
            final needsRepair = localLog != null && 
                localLog.entries.isNotEmpty && 
                localLog.entries.any((e) => e.nutritionData.potassium == null && e.nutritionData.calcium == null);

            if (localLog == null || needsRepair) {
              _historyLogs[key] = cloudLog;
              await prefs.setString(_storageKey(key), jsonEncode(cloudLog.toJson()));
              if (!keys.contains(key)) keys.add(key);
              updated = true;
            }
          }

          if (updated) {
            await prefs.setStringList(_historyKeysKey, keys);
            // Refresh today's log from cloud if available
            final todayKey = _dateKey(DateTime.now());
            if (_historyLogs.containsKey(todayKey)) {
              _todayLog = _historyLogs[todayKey]!;
            }
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Logs cloud fetch error: $e');
      }
    }
  }

  Future<void> _migrateOldData(SharedPreferences prefs) async {
    final migratedFlag = 'profile_${_profileId}_data_migrated';
    if (prefs.getBool(migratedFlag) ?? false) return;

    final oldKeys = prefs.getStringList('history_keys') ?? [];
    for (final key in oldKeys) {
      final oldJson = prefs.getString('log_$key');
      if (oldJson != null) {
        await prefs.setString(_storageKey(key), oldJson);
      }
    }
    if (oldKeys.isNotEmpty) {
      await prefs.setStringList(_historyKeysKey, oldKeys);
    }
    await prefs.setBool(migratedFlag, true);
  }

  Future<void> _saveToday() async {
    await _saveLog(_todayLog);
  }

  Future<void> _saveLog(DailyLog log) async {
    final key = _dateKey(log.date);
    
    // Update local state synchronously first
    _historyLogs[key] = log;
    if (key == _dateKey(DateTime.now())) {
      _todayLog = log;
    }

    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(log.toJson());
    await prefs.setString(_storageKey(key), json);

    final keys = prefs.getStringList(_historyKeysKey) ?? [];
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList(_historyKeysKey, keys);
    }

    // Cloud sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final db = FirebaseFirestore.instance;
        final userDoc = db.collection('users').doc(user.uid);
        
        // 1. Save core nutrition log (entries, exercises)
        final logData = log.toJson();
        logData.remove('waterIntakeMl');
        logData.remove('waterEntries');
        logData.remove('stepsCount');
        
        // Save both original and portion-scaled values for display and analytics
        if (logData['entries'] != null) {
          logData['entries'] = log.entries.map((entry) {
            final scaled = entry.nutritionData.scaleBy(entry.portionSize / 100);
            return {
              'id': entry.id,
              'name': entry.name,
              'brand': entry.brand,
              'portionSize': entry.portionSize,
              'portionUnit': entry.portionUnit,
              'mealType': entry.mealType,
              'timestamp': entry.timestamp.toIso8601String(),
              'imageUrl': entry.imageUrl,
              'imagePath': entry.imagePath,
              'notes': entry.notes,
              'novaGroup': entry.novaGroup,
              'nutritionData': entry.nutritionData.toStructuredJson(), // Store original unscaled
              'nutritionDataScaled': scaled.toStructuredJson() // Store scaled version separately
            };
          }).toList();
        }
        
        await userDoc.collection('logs').doc(key).set(logData);

        // 2. Save water log separately
        if (log.waterIntakeMl > 0 || log.waterEntries.isNotEmpty) {
          await userDoc.collection('water_logs').doc(key).set({
            'ml': log.waterIntakeMl,
            'entries': log.waterEntries.map((e) => e.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 3. Save steps log separately
        if (log.stepsCount != null && log.stepsCount! > 0) {
          await userDoc.collection('step_logs').doc(key).set({
            'steps': log.stepsCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Log cloud sync error: $e');
      }
    }
  }

  Future<void> _saveSavedMeals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _savedMealsKey, jsonEncode(_savedMeals.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadSavedMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_savedMealsKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        _savedMeals.clear();
        for (final item in list) {
          _savedMeals.add(FoodEntry.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  void toggleFavoriteMeal(FoodEntry entry) {
    final name = entry.name.trim();
    if (name.isEmpty) return;

    final index = _savedMeals.indexWhere((e) => e.name.trim() == name);
    if (index >= 0) {
      _savedMeals.removeAt(index);
    } else {
      // Save a clean copy for future use
      _savedMeals.add(entry.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
      ));
    }
    _saveSavedMeals();
    notifyListeners();
  }

  bool isFavorite(String name) {
    return _savedMeals.any((e) => e.name.trim() == name.trim());
  }

  void removeSavedMeal(String id) {
    _savedMeals.removeWhere((e) => e.id == id);
    _saveSavedMeals();
    notifyListeners();
  }

  DailyLog getOrCreateLogForDate(DateTime date) {
    final key = _dateKey(date);
    if (key == _dateKey(DateTime.now())) return _todayLog;
    return _historyLogs[key] ??
        DailyLog(id: key, date: date, entries: [], waterIntakeMl: 0);
  }

  void addFoodEntry(FoodEntry entry, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    DailyLog log = getOrCreateLogForDate(targetDate);
    final updatedEntries = List<FoodEntry>.from(log.entries)..add(entry);
    log = log.copyWith(entries: updatedEntries);
    _saveLog(log);
    notifyListeners();
  }

  void removeFoodEntry(String id, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    DailyLog log = getOrCreateLogForDate(targetDate);
    final updatedEntries = log.entries.where((e) => e.id != id).toList();
    log = log.copyWith(entries: updatedEntries);
    _saveLog(log);
    notifyListeners();
  }

  void updateFoodEntry(FoodEntry updatedEntry, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    DailyLog log = getOrCreateLogForDate(targetDate);
    final updatedEntries = log.entries.map((e) {
      return e.id == updatedEntry.id ? updatedEntry : e;
    }).toList();
    log = log.copyWith(entries: updatedEntries);
    _saveLog(log);
    notifyListeners();
  }

  void updateWater(double ml, {DateTime? date, double? deltaAmount}) {
    final targetDate = date ?? DateTime.now();
    DailyLog log = getOrCreateLogForDate(targetDate);
    // Track individual water entry if deltaAmount provided
    List<WaterEntry> updatedWaterEntries = List<WaterEntry>.from(log.waterEntries);
    if (deltaAmount != null && deltaAmount != 0) {
      updatedWaterEntries.add(WaterEntry(time: DateTime.now(), amount: deltaAmount));
    }
    log = log.copyWith(waterIntakeMl: ml, waterEntries: updatedWaterEntries);
    _saveLog(log);
    notifyListeners();
  }

  void addExercise(ExerciseEntry entry, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    DailyLog log = getOrCreateLogForDate(targetDate);
    final updatedExercises = List<ExerciseEntry>.from(log.exercises)..add(entry);
    log = log.copyWith(exercises: updatedExercises);
    _saveLog(log);
    notifyListeners();
  }

  void updateSteps(int steps) {
    _todayLog = _todayLog.copyWith(stepsCount: steps);
    _saveToday();
    notifyListeners();
  }

  void updateHealthSyncData({required int steps, required double burnedCalories}) {
    // Create or update a special exercise entry for synced calories
    final healthExerciseId = 'health_sync_calories';
    
    List<ExerciseEntry> updatedExercises = List<ExerciseEntry>.from(_todayLog.exercises);
    
    // Remove if exists
    updatedExercises.removeWhere((e) => e.id == healthExerciseId);
    
    // Add new if calories > 0
    if (burnedCalories > 0) {
      updatedExercises.add(ExerciseEntry(
        id: healthExerciseId,
        name: 'Sağlık Senkronizasyonu',
        burnedCalories: burnedCalories,
        durationMinutes: 0,
        timestamp: DateTime.now(),
      ));
    }
    
    _todayLog = _todayLog.copyWith(
      stepsCount: steps,
      exercises: updatedExercises,
    );
    
    _saveToday();
    notifyListeners();
  }

  DailyLog? getLogForDate(DateTime date) {
    final key = _dateKey(date);
    final todayKey = _dateKey(DateTime.now());
    if (key == todayKey) return _todayLog;
    return _historyLogs[key];
  }

  List<DateTime> getDatesWithData() {
    final result = <DateTime>[];
    if (_todayLog.entries.isNotEmpty) {
      result.add(_todayLog.date);
    }
    for (final log in _historyLogs.values) {
      if (log.entries.isNotEmpty) {
        result.add(log.date);
      }
    }
    return result;
  }

  List<NutritionConflict> getConflicts(UserProfile? profile, {DailyLog? log, bool isTurkish = true}) {
    if (profile == null) return [];
    return ConflictDetectionService.detect(
      consumed: log?.totalNutrition ?? totalNutrition,
      profile: profile,
      isTurkish: isTurkish,
    );
  }

  Map<String, DailyLog> get allLogs {
    final all = Map<String, DailyLog>.from(_historyLogs);
    all[_dateKey(_todayLog.date)] = _todayLog;
    return all;
  }

  /// Load logs for a specific profile (used by detail/export screens).
  static Future<List<DailyLog>> loadLogsForProfile(
    String profileId, {
    int days = 7,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keysKey = profileId == 'profile_migrated' || profileId.isEmpty
        ? 'history_keys'
        : 'profile_${profileId}_history_keys';
    final historyKeys = prefs.getStringList(keysKey) ?? [];

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final logs = <DailyLog>[];

    for (final key in historyKeys) {
      final storageKey = profileId.isEmpty
          ? 'log_$key'
          : (profileId == 'profile_migrated'
              ? 'log_$key'
              : 'profile_${profileId}_log_$key');
      final json = prefs.getString(storageKey);
      if (json != null) {
        try {
          final log = DailyLog.fromJson(jsonDecode(json) as Map<String, dynamic>);
          if (!log.date.isBefore(cutoff)) {
            logs.add(log);
          }
        } catch (_) {}
      }
    }

    // Also include today
    final todayKey = _dateKey(DateTime.now());
    final todayStorageKey = profileId.isEmpty
        ? 'log_$todayKey'
        : (profileId == 'profile_migrated'
            ? 'log_$todayKey'
            : 'profile_${profileId}_log_$todayKey');
    final todayJson = prefs.getString(todayStorageKey);
    if (todayJson != null) {
      try {
        final log = DailyLog.fromJson(jsonDecode(todayJson) as Map<String, dynamic>);
        if (!logs.any((l) => _dateKey(l.date) == todayKey)) {
          logs.add(log);
        }
      } catch (_) {}
    }

    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  void reset() {
    _historyLogs.clear();
    _savedMeals.clear();
    _profileId = '';
    final todayKey = _dateKey(DateTime.now());
    _todayLog = DailyLog(
      id: todayKey,
      date: DateTime.now(),
      entries: [],
      waterIntakeMl: 0,
    );
    _lastResult = null;
    _lastAnalyzedImage = null;
    _lastMealType = null;
    _showResultOnHome = false;
    notifyListeners();
  }
}
