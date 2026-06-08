import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fasting_session.dart';
import '../providers/achievement_provider.dart';

class FastingProvider extends ChangeNotifier {
  static const _activeKey = 'fasting_active_session';
  static const _historyKey = 'fasting_history_v1';

  FastingSession? _activeSession;
  final List<FastingSession> _history = [];

  FastingSession? get activeSession => _activeSession;
  List<FastingSession> get history => List.unmodifiable(_history);

  bool get isFasting => _activeSession != null;

  Future<void> _syncActiveToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('fasting').doc('active');
      if (_activeSession == null) {
        await doc.delete();
      } else {
        await doc.set(_activeSession!.toJson());
      }
    } catch (e) {
      debugPrint('Fasting active cloud sync error: $e');
    }
  }

  Future<void> _syncHistoryToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final batch = FirebaseFirestore.instance.batch();
      
      for (final session in _history) {
        final docRef = userDoc.collection('fasting_history').doc(session.id);
        batch.set(docRef, session.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Fasting history cloud sync error: $e');
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_activeKey);
    if (raw != null) {
      try {
        _activeSession = FastingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    final histRaw = prefs.getString(_historyKey);
    if (histRaw != null) {
      try {
        final list = jsonDecode(histRaw) as List<dynamic>;
        _history.clear();
        for (final item in list) {
          _history.add(FastingSession.fromJson(item as Map<String, dynamic>));
        }
        _history.sort((a, b) => b.startTime.compareTo(a.startTime));
      } catch (_) {}
    }

    notifyListeners();

    // Cloud fetch
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final db = FirebaseFirestore.instance;
        final userDoc = db.collection('users').doc(user.uid);
        
        // Fetch active session
        final activeDoc = await userDoc.collection('fasting').doc('active').get();
        if (activeDoc.exists) {
          _activeSession = FastingSession.fromJson(activeDoc.data()!);
          await prefs.setString(_activeKey, jsonEncode(_activeSession!.toJson()));
        }

        // Fetch history (individual sessions)
        final historyQuery = await userDoc.collection('fasting_history').get();
        if (historyQuery.docs.isNotEmpty) {
          _history.clear();
          for (final doc in historyQuery.docs) {
            _history.add(FastingSession.fromJson(doc.data()));
          }
          _history.sort((a, b) => b.startTime.compareTo(a.startTime));
          await _saveHistory(prefs);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Fasting cloud load error: $e');
      }
    }
  }

  Future<void> startFasting(FastingMode mode, {int? customHours}) async {
    if (_activeSession != null) return;

    final hours = customHours ?? mode.defaultFastingHours;
    _activeSession = FastingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mode: mode,
      startTime: DateTime.now(),
      fastingHours: hours,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, jsonEncode(_activeSession!.toJson()));
    notifyListeners();
    _syncActiveToCloud();
  }

  Future<void> endFasting(AchievementProvider achievementProvider) async {
    if (_activeSession == null) return;

    final completed = _activeSession!.copyWith(endTime: DateTime.now());
    _history.insert(0, completed);
    if (_history.length > 50) _history.removeLast();
    
    // Record achievement
    achievementProvider.recordFastingCompleted(
      hours: completed.elapsed.inMinutes / 60.0,
      endTime: completed.endTime!,
    );

    _activeSession = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await _saveHistory(prefs);
    notifyListeners();
    _syncActiveToCloud();
    _syncHistoryToCloud();
  }

  Future<void> cancelFasting(AchievementProvider achievementProvider) async {
    if (_activeSession == null) return;

    // Save to history as cancelled
    final cancelled = _activeSession!.copyWith(
      endTime: DateTime.now(),
      wasCancelled: true,
    );
    _history.insert(0, cancelled);
    if (_history.length > 50) _history.removeLast();

    _activeSession = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await _saveHistory(prefs);
    notifyListeners();
    _syncActiveToCloud();
    _syncHistoryToCloud();
  }

  void tick() {
    if (_activeSession != null) {
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    _history.removeWhere((s) => s.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveHistory(prefs);
    notifyListeners();
    _syncHistoryToCloud();
  }

  double getWeeklyFastingHours() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    double totalHours = 0;
    for (final s in _history) {
      if (s.endTime != null && s.endTime!.isAfter(weekAgo) && !s.wasCancelled) {
        totalHours += s.elapsed.inMinutes / 60.0;
      }
    }
    return totalHours;
  }

  Future<void> _saveHistory(SharedPreferences prefs) async {
    final encoded = jsonEncode(_history.map((s) => s.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }
}
