import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../services/conflict_detection_service.dart';
import 'profile_provider.dart';

class NutritionProvider extends ChangeNotifier {
  DailyLog _todayLog = DailyLog(
    id: 'init',
    date: DateTime.now(),
    entries: [],
    waterIntakeMl: 0,
  );

  final Map<String, DailyLog> _historyLogs = {};
  String _profileId = '';

  DailyLog get todayLog => _todayLog;
  NutritionData get totalNutrition => _todayLog.totalNutrition;
  String get currentProfileId => _profileId;

  double get totalBurnedCaloriesFromExercises =>
      _todayLog.totalBurnedFromExercises;

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
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(_todayLog.date);
    await prefs.setString(_storageKey(key), jsonEncode(_todayLog.toJson()));

    final keys = prefs.getStringList(_historyKeysKey) ?? [];
    if (!keys.contains(key)) {
      keys.add(key);
      await prefs.setStringList(_historyKeysKey, keys);
    }

    _historyLogs[key] = _todayLog;
  }

  void addFoodEntry(FoodEntry entry) {
    final updatedEntries = List<FoodEntry>.from(_todayLog.entries)..add(entry);
    _todayLog = _todayLog.copyWith(entries: updatedEntries);
    _saveToday();
    notifyListeners();
  }

  void removeFoodEntry(String id) {
    final updatedEntries =
        _todayLog.entries.where((e) => e.id != id).toList();
    _todayLog = _todayLog.copyWith(entries: updatedEntries);
    _saveToday();
    notifyListeners();
  }

  void updateFoodEntry(FoodEntry updatedEntry) {
    final updatedEntries = _todayLog.entries.map((e) {
      return e.id == updatedEntry.id ? updatedEntry : e;
    }).toList();
    _todayLog = _todayLog.copyWith(entries: updatedEntries);
    _saveToday();
    notifyListeners();
  }

  void updateWater(double ml) {
    _todayLog = _todayLog.copyWith(waterIntakeMl: ml);
    _saveToday();
    notifyListeners();
  }

  void addExercise(ExerciseEntry entry) {
    final updatedExercises = List<ExerciseEntry>.from(_todayLog.exercises)
      ..add(entry);
    _todayLog = _todayLog.copyWith(exercises: updatedExercises);
    _saveToday();
    notifyListeners();
  }

  void updateSteps(int steps) {
    _todayLog = _todayLog.copyWith(stepsCount: steps);
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

  List<NutritionConflict> getConflicts(UserProfile? profile) {
    if (profile == null) return [];
    return ConflictDetectionService.detect(
      consumed: totalNutrition,
      profile: profile,
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
}
