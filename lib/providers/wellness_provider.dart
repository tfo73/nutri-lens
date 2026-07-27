import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wellness_log.dart';

class WellnessProvider extends ChangeNotifier {
  static const _prefix = 'wellness_';
  static const _weightKey = 'weight_log_v1';

  final Map<String, WellnessLog> _logs = {};

  // week key 'YYYY-WXX' → weight in kg
  final Map<String, double> _weightLogs = {};

  WellnessLog get today => _logs[_dateKey(_shiftedNow)] ?? WellnessLog(date: _shiftedNow);
  
  static DateTime get _shiftedNow => DateTime.now().subtract(const Duration(hours: 5));

  static String get _todayKey => _dateKey(_shiftedNow);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      final raw = prefs.getString(k);
      if (raw == null) continue;
      try {
        final log = WellnessLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _logs[log.dateKey] = log;
      } catch (_) {}
    }
    // Load weight logs
    final rawW = prefs.getString(_weightKey);
    if (rawW != null) {
      try {
        final map = jsonDecode(rawW) as Map<String, dynamic>;
        _weightLogs.clear();
        map.forEach((k, v) => _weightLogs[k] = (v as num).toDouble());
      } catch (_) {}
    }
    notifyListeners();

    // Cloud fetch
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final db = FirebaseFirestore.instance;
        final userDoc = db.collection('users').doc(user.uid);
        
        // Fetch weight history
        final weightSnap = await userDoc.collection('weight_history').get();
        if (weightSnap.docs.isNotEmpty) {
          for (final doc in weightSnap.docs) {
            _weightLogs[doc.id] = (doc.data()['weight'] as num).toDouble();
          }
          await prefs.setString(_weightKey, jsonEncode(_weightLogs));
        }

        // Fetch wellness logs
        final wellnessSnap = await userDoc.collection('wellness_logs').get();
        if (wellnessSnap.docs.isNotEmpty) {
          for (final doc in wellnessSnap.docs) {
            final log = WellnessLog.fromJson(doc.data());
            _logs[log.dateKey] = log;
            await prefs.setString('$_prefix${log.dateKey}', jsonEncode(log.toJson()));
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Wellness cloud load error: $e');
      }
    }
  }

  // ── Weight ──────────────────────────────────────────────────────────────────

  // key = Monday's date string 'YYYY-MM-DD'
  static String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return _dateKey(monday);
  }

  Future<void> logWeight(double kg) async {
    final key = _weekKey(_shiftedNow);
    _weightLogs[key] = kg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weightKey, jsonEncode(_weightLogs));
    notifyListeners();

    // Cloud sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('weight_history')
            .doc(key)
            .set({'weight': kg, 'timestamp': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('Weight cloud sync error: $e');
      }
    }
  }

  double? get thisWeekWeight => _weightLogs[_weekKey(_shiftedNow)];

  bool get weightEnteredThisWeek => thisWeekWeight != null;

  double? get lastRecordedWeight {
    if (_weightLogs.isEmpty) return null;
    final sortedKeys = _weightLogs.keys.toList()..sort();
    return _weightLogs[sortedKeys.last];
  }

  /// Returns (weight kg, isEstimated) for last [weeks] weeks, oldest first.
  /// Missing weeks are estimated by subtracting [weeklyDelta] from the last known value.
  List<(double?, bool)> weightForWeeks(
    int weeks, {
    double weeklyDelta = 0,
    double? startWeight,
    DateTime? startDate,
  }) {
    final now = _shiftedNow;
    final dates = List.generate(
        weeks, (i) => now.subtract(Duration(days: (weeks - 1 - i) * 7)));
    final keys = dates.map((d) => _weekKey(d)).toList();
    final raw = keys.map((k) => _weightLogs[k]).toList();

    final result = <(double?, bool)>[];
    for (int i = 0; i < weeks; i++) {
      if (raw[i] != null) {
        result.add((raw[i], false));
      } else {
        // Try to estimate
        double? prev;
        int prevIdx = -1;
        for (int j = i - 1; j >= 0; j--) {
          if (result[j].$1 != null) {
            prev = result[j].$1;
            prevIdx = j;
            break;
          }
        }
        if (prev != null) {
          result.add((prev, true));
        } else if (startWeight != null) {
          result.add((startWeight, true));
        } else {
          result.add((null, false));
        }
      }
    }
    return result;
  }

  /// Monthly average weight for last [months] months, oldest first.
  List<double?> weightAvgForMonths(
    int months, {
    double weeklyDelta = 0,
    double? startWeight,
    DateTime? startDate,
  }) {
    final now = _shiftedNow;
    final result = <double?>[];

    for (int i = 0; i < months; i++) {
        // Target month
        final monthDate = DateTime(now.year, now.month - (months - 1 - i), 1);
        
        // Let's identify the real logs for this month
        final monthLogs = _weightLogs.entries.where((e) {
          final d = DateTime.tryParse(e.key);
          return d != null && d.year == monthDate.year && d.month == monthDate.month;
        }).map((e) => e.value).toList();
        
        if (monthLogs.isNotEmpty) {
          result.add(monthLogs.reduce((a, b) => a + b) / monthLogs.length);
        } else {
          result.add(startWeight);
        }
    }
    return result;
  }

  Future<void> _save(WellnessLog log) async {
    _logs[log.dateKey] = log;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${log.dateKey}', jsonEncode(log.toJson()));
    notifyListeners();

    // Cloud sync
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('wellness_logs')
            .doc(log.dateKey)
            .set(log.toJson());
      } catch (e) {
        debugPrint('Wellness cloud sync error: $e');
      }
    }
  }

  WellnessLog getLogForDate(DateTime date) {
    final key = _dateKey(date);
    return _logs[key] ?? WellnessLog(date: date);
  }

  Future<void> setSleepScore(int score) async {
    await _save(today.copyWith(sleepScore: score));
  }

  Future<void> setMood(String timeSlot, MoodType? mood) async {
    final updated = List<MoodEntry>.from(today.moods)
      ..removeWhere((m) => m.timeSlot == timeSlot);
    if (mood != null) {
      updated.add(MoodEntry(timeSlot: timeSlot, mood: mood));
    }
    await _save(today.copyWith(moods: updated));
  }

  Future<void> logWc({int stoolType = 0, DateTime? time}) async {
    final updated = List<WcEntry>.from(today.wcEntries)
      ..add(WcEntry(time: time ?? DateTime.now(), stoolType: stoolType));
    await _save(today.copyWith(wcEntries: updated));
  }

  Future<void> addSymptom(String symptom) async {
    final updated = List<String>.from(today.symptoms)..add(symptom);
    await _save(today.copyWith(symptoms: updated));
  }

  Future<void> removeSymptom(String symptom) async {
    final updated = List<String>.from(today.symptoms)..remove(symptom);
    await _save(today.copyWith(symptoms: updated));
  }

  /// Son [days] günün uyku puanlarını döndürür (null = girilmemiş).
  List<int?> sleepScoresForDays(int days) {
    return List.generate(days, (i) {
      final d = _shiftedNow.subtract(Duration(days: days - 1 - i));
      final key = _dateKey(d);
      return _logs[key]?.sleepScore;
    });
  }

  /// Geçerli haftanın Pazartesi→Pazar uyku puanlarını döndürür.
  List<int?> sleepScoresThisWeek() {
    final now = _shiftedNow;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return _logs[_dateKey(d)]?.sleepScore;
    });
  }

  /// Son [months] ay için aylık ortalama uyku puanı (null = veri yok).
  List<double?> sleepAvgForMonths(int months) {
    final now = _shiftedNow;
    return List.generate(months, (i) {
      final target = DateTime(now.year, now.month - (months - 1 - i));
      final entries = _logs.entries.where((e) {
        final d = DateTime.tryParse(e.key);
        return d != null && d.year == target.year && d.month == target.month;
      }).map((e) => e.value.sleepScore).whereType<int>().toList();
      return entries.isEmpty ? null : entries.reduce((a, b) => a + b) / entries.length;
    });
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, WellnessLog> get allLogs => Map.unmodifiable(_logs);

  void reset() {
    _logs.clear();
    _weightLogs.clear();
    notifyListeners();
  }
}
