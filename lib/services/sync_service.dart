import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/food_entry.dart';
import '../providers/profile_provider.dart';
import 'auth_service.dart';

class SyncService {
  static SyncService? _instance;
  SyncService._();
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  FirebaseFirestore? _dbInstance;
  FirebaseFirestore get _db => _dbInstance ??= FirebaseFirestore.instance;

  final _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  void init() {
    if (Platform.isWindows) return;
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      // results is a List<ConnectivityResult> in newer versions
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        _handleBackOnline();
      }
    });
  }

  Future<void> _handleBackOnline() async {
    if (_uid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final isSynced = prefs.getBool('onboarding_answers_synced') ?? true;
    
    if (!isSynced) {
      debugPrint('SyncService: Back online, attempting to sync pending onboarding...');
      // We need profile info. We can either store it in prefs specifically for sync 
      // or try to fetch it from the saved profiles list.
      try {
        final answersStr = prefs.getString('onboarding_answers');
        if (answersStr != null) {
          final answers = jsonDecode(answersStr) as Map<String, dynamic>;
          
          // Try to get name from answers or default
          final name = answers['firstName'] ?? 'Kullanıcı';
          
          // We can use a dummy UserProfile for sync since the syncOnboardingData 
          // mostly needs the UID which we have.
          // Or we can just call a modified sync method.
          await _syncOnboardingOnly(answers);
          await prefs.setBool('onboarding_answers_synced', true);
          debugPrint('SyncService: Pending onboarding synced successfully.');
        }
      } catch (e) {
        debugPrint('SyncService: Sync failed, will retry later: $e');
      }
    }
  }

  Future<void> _syncOnboardingOnly(Map<String, dynamic> answers) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    
    final userRef = _db.collection('users').doc(_uid);
    await userRef.set({
      'onboarding': {
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'answers': answers,
      },
    }, SetOptions(merge: true));
  }

  Future<void> syncOnboardingData(
    UserProfile profile,
    Map<String, dynamic> answers,
  ) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    try {
      final batch = _db.batch();
      final userRef = _db.collection('users').doc(_uid);

      batch.set(userRef, {
        'onboarding': {
          'completed': true,
          'completedAt': FieldValue.serverTimestamp(),
          'answers': answers,
        },
        'health_profile': {
          'firstName': profile.name,
          'age': profile.age,
          'heightCm': profile.height,
          'weightKg': profile.weight,
          'gender': profile.gender.name,
          'activityLevel': profile.activityLevel.name,
          'primaryGoal': profile.goal.name,
          'advancedGoal': profile.advancedGoal ?? '',
          'healthConditions': profile.healthConditions,
          'dietaryPreferences': profile.dietaryPreferences,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('SyncService error: $e');
    }
  }

  // İnternet yokken kaydedilen onboarding verilerini senkronize et
  Future<void> checkAndSyncPendingOnboarding(UserProfile profile) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final answersStr = prefs.getString('onboarding_answers');
      final isSynced = prefs.getBool('onboarding_answers_synced') ?? false;

      if (answersStr != null && !isSynced) {
        final answers = jsonDecode(answersStr) as Map<String, dynamic>;
        await syncOnboardingData(profile, answers);
        await prefs.setBool('onboarding_answers_synced', true);
      }
    } catch (e) {
      debugPrint('SyncService checkAndSyncPending error: $e');
    }
  }

  Future<void> syncFoodEntry(FoodEntry entry) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    
    // Scale nutrition values based on portion size (entry.portionSize / 100)
    final scaled = entry.nutritionData.scaleBy(entry.portionSize / 100);
    
    await _db
        .collection('users')
        .doc(_uid)
        .collection('food_entries')
        .doc(entry.id)
        .set({
      'name': entry.name,
      'mealType': entry.mealType,
      'dateTime': Timestamp.fromDate(entry.timestamp),
      'portionGrams': entry.portionSize,
      'portionUnit': entry.portionUnit,
      'imagePath': entry.imagePath ?? '',
      'nutritionData': scaled.toStructuredJson(),
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  // Yemek silinince Firestore'dan da sil
  Future<void> deleteFoodEntry(String entryId) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('food_entries')
        .doc(entryId)
        .delete();
  }

  // Su kaydı
  Future<void> syncWater(DateTime date, double ml) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    final key = DateFormat('yyyy-MM-dd').format(date);
    await _db
        .collection('users')
        .doc(_uid)
        .collection('water_logs')
        .doc(key)
        .set({'ml': ml, 'updatedAt': FieldValue.serverTimestamp()});
  }

  // Streak
  Future<void> syncStreak(DateTime date, bool completed) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    final key = DateFormat('yyyy-MM-dd').format(date);
    await _db
        .collection('users')
        .doc(_uid)
        .collection('streaks')
        .doc(key)
        .set({
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Giriş yapınca Firestore'dan profil verisini SharedPreferences'a çek
  Future<void> pullUserData() async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    try {
      final userDoc = await _db.collection('users').doc(_uid).get();
      final data = userDoc.data();
      if (data == null) return;

      final hp = data['health_profile'] as Map<String, dynamic>?;
      if (hp != null && hp.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        // ProfileProvider'ın beklediği JSON formatında kaydet
        final profileJson = {
          'id': _uid!,
          'name': hp['firstName'] ?? '',
          'age': hp['age'] ?? 0,
          'height': hp['heightCm'] ?? 0.0,
          'weight': hp['weightKg'] ?? 0.0,
          'gender': _genderIndex(hp['gender'] ?? 'male'),
          'activityLevel': _activityIndex(hp['activityLevel'] ?? 'moderate'),
          'goal': _goalIndex(hp['primaryGoal'] ?? 'maintain'),
          'healthConditions': hp['healthConditions'] ?? [],
          'advancedGoal': hp['advancedGoal'],
          'dietaryPreferences': hp['dietaryPreferences'] ?? [],
        };

        // Mevcut profil listesini güncelle
        final existing = prefs.getStringList('profiles') ?? [];
        final updated = existing
            .where((s) {
              try {
                return !s.contains('"id":"$_uid"');
              } catch (_) {
                return true;
              }
            })
            .toList();
        updated.add(_jsonEncode(profileJson));
        await prefs.setStringList('profiles', updated);
        await prefs.setString('active_profile_id', _uid!);
      }
    } catch (_) {
      // Offline veya veri yoksa sessizce geç
    }
  }

  int _genderIndex(String g) {
    switch (g) {
      case 'female':
        return 1;
      default:
        return 0;
    }
  }

  int _activityIndex(String a) {
    switch (a) {
      case 'light':
        return 1;
      case 'moderate':
        return 2;
      case 'active':
        return 3;
      case 'veryActive':
        return 4;
      default:
        return 0;
    }
  }

  int _goalIndex(String g) {
    switch (g) {
      case 'maintain':
        return 1;
      case 'gain':
        return 2;
      default:
        return 0;
    }
  }

  // Adım sayısını Firebase'e kaydet
  Future<void> syncSteps(DateTime date, int steps) async {
    if (Platform.isWindows) return;
    if (_uid == null) return;
    final key = DateFormat('yyyy-MM-dd').format(date);
    await _db
        .collection('users')
        .doc(_uid)
        .collection('step_logs')
        .doc(key)
        .set({
      'steps': steps,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Belirli bir gün için Firebase'den adım sayısını çek
  Future<int?> getStepsForDate(DateTime date) async {
    if (Platform.isWindows) return null;
    if (_uid == null) return null;
    try {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final doc = await _db
          .collection('users')
          .doc(_uid)
          .collection('step_logs')
          .doc(key)
          .get();
      if (doc.exists) {
        return (doc.data()?['steps'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('SyncService getStepsForDate error: $e');
    }
    return null;
  }

  String _jsonEncode(Map<String, dynamic> map) {
    // Basit JSON encode (import dart:convert yerine elle)
    final buffer = StringBuffer('{');
    var first = true;
    map.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$key":');
      if (value == null) {
        buffer.write('null');
      } else if (value is String) {
        buffer.write('"${value.replaceAll('"', '\\"')}"');
      } else if (value is List) {
        buffer.write('[');
        buffer.write(
            value.map((e) => e is String ? '"$e"' : '$e').join(','));
        buffer.write(']');
      } else {
        buffer.write(value);
      }
    });
    buffer.write('}');
    return buffer.toString();
  }
}
