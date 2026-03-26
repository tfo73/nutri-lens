import 'dart:io';
import 'package:flutter/services.dart';

/// iOS HealthKit entegrasyonu için servis.
/// Android'de bu servis devre dışı kalır.
class HealthKitService {
  static const MethodChannel _channel = MethodChannel('nutrilens/health_kit');

  static bool get isAvailable => Platform.isIOS;

  /// HealthKit izinlerini iste
  Future<bool> requestPermissions() async {
    if (!isAvailable) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } on PlatformException catch (e) {
      throw Exception('HealthKit izin hatası: ${e.message}');
    }
  }

  /// Bugünkü adım sayısını getir
  Future<int?> getTodaySteps() async {
    if (!isAvailable) return null;
    try {
      return await _channel.invokeMethod<int>('getTodaySteps');
    } on PlatformException catch (e) {
      throw Exception('Adım verisi alınamadı: ${e.message}');
    }
  }

  /// Aktif kalori yakımını getir (kcal)
  Future<double?> getActiveCaloriesBurned() async {
    if (!isAvailable) return null;
    try {
      final value = await _channel.invokeMethod<double>('getActiveCalories');
      return value;
    } on PlatformException catch (e) {
      throw Exception('Kalori verisi alınamadı: ${e.message}');
    }
  }

  /// Kilo verisini HealthKit'e kaydet (kg)
  Future<bool> saveWeight(double weightKg) async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('saveWeight', {
        'weightKg': weightKg,
        'date': DateTime.now().toIso8601String(),
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Kilo kaydedilemedi: ${e.message}');
    }
  }

  /// Günlük kalori alımını HealthKit'e kaydet
  Future<bool> saveDietaryCalories(double calories) async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('saveDietaryCalories', {
        'calories': calories,
        'date': DateTime.now().toIso8601String(),
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Kalori kaydedilemedi: ${e.message}');
    }
  }

  /// Su tüketimini HealthKit'e kaydet (ml)
  Future<bool> saveWaterIntake(double ml) async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('saveWaterIntake', {
        'milliliters': ml,
        'date': DateTime.now().toIso8601String(),
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Su tüketimi kaydedilemedi: ${e.message}');
    }
  }

  /// Son kaydedilen kiloleri getir
  Future<List<Map<String, dynamic>>> getWeightHistory({int days = 30}) async {
    if (!isAvailable) return [];
    try {
      final result = await _channel.invokeMethod<List>('getWeightHistory', {
        'days': days,
      });
      return (result ?? []).cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      throw Exception('Kilo geçmişi alınamadı: ${e.message}');
    }
  }
}
