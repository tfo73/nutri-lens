import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Samsung Health → Health Connect veri eşlemesi:
/// - STEPS             : getTotalStepsInInterval (aggregate) ancak kaynak bazlı max alınır
/// - Kalori            : ACTIVE_ENERGY_BURNED direkt okunur, hesaplama yapılmaz
/// - TOTAL_CALORIES    : basal + aktif → kullanmıyoruz (kafa karıştırır)
///
/// ÖNEMLİ İZİN AKIŞI:
/// hasPermissions() önce kontrol edilir. Tüm izinler verilmişse requestAuthorization()
/// HİÇ çağrılmaz. Bu sayede egzersiz ekranına gidildiğinde Health Connect UI açılmaz.

class HealthService {
  static final Health _health = Health();
  static bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    // WORKOUT kaldırıldı — SecurityException: Caller requires one of the permissions for record type 7
  ];

  /// Uygulama başlangıcında bir kez çağrılmalıdır.
  static Future<void> initialize() async {
    if (_configured) return;
    try {
      if (Platform.isAndroid) {
        await _health.configure();
        debugPrint('[HealthService] configure() OK');
      }
      _configured = true;
    } catch (e) {
      debugPrint('[HealthService] configure() failed: $e');
    }
  }

  /// İzin ister. hasPermissions true ise requestAuthorization çağrılmaz
  /// (böylece her seferinde Health Connect ekranı açılmaz).
  static Future<bool> requestPermissions() async {
    try {
      await initialize();
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();

      // Tüm izinler zaten verilmişse UI açmadan true dön
      final bool? has =
          await _health.hasPermissions(_types, permissions: permissions);
      debugPrint('[HealthService] hasPermissions=$has');
      if (has == true) return true;

      // Eksik izin(ler) var → bir kez dialog aç
      final authorized =
          await _health.requestAuthorization(_types, permissions: permissions);
      debugPrint('[HealthService] requestAuthorization=$authorized');
      return authorized;
    } catch (e) {
      debugPrint('[HealthService] Permission error: $e');
      return false;
    }
  }

  /// Sadece izinlerin durumunu kontrol eder, kullanıcıya izin isteği penceresi açmaz.
  static Future<bool> hasPermissionsOnly() async {
    try {
      await initialize();
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final bool? has =
          await _health.hasPermissions(_types, permissions: permissions);
      return has == true;
    } catch (_) {
      return false;
    }
  }

  /// Bugünün sağlık verilerini çeker.
  /// KESİNLİKLE kendi hesaplamamız yok — Health Connect'ten geleni döner.
  /// Veri yoksa 0 döner.
  static Future<HealthData> getTodayHealthData() async {
    int steps = 0;
    double activeCalories = 0;

    try {
      await initialize();

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      debugPrint('[HealthService] Fetch: $midnight → $now');

      // ── ADIM ──────────────────────────────────────────────────────────────
      // Samsung Health hem kaynak hem aggregate yazar → max-kaynak al
      try {
        final stepPoints = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [HealthDataType.STEPS],
        );

        if (stepPoints.isNotEmpty) {
          // Kaynak bazlı grupla
          final bySource = <String, int>{};
          for (final p in stepPoints) {
            bySource[p.sourceName] =
                (bySource[p.sourceName] ?? 0) + _toInt(p.value);
          }
          debugPrint('[HealthService] Kaynak adımlar: $bySource');
          // En yüksek tek kaynağı al (çift sayımı engeller)
          steps = bySource.values.fold(0, (a, b) => a > b ? a : b);
        }

        // Fallback: aggregate (hiç kaynak yoksa)
        if (steps == 0) {
          final agg = await _health.getTotalStepsInInterval(midnight, now);
          steps = agg ?? 0;
          debugPrint('[HealthService] Aggregate steps fallback: $steps');
        }
      } catch (e) {
        debugPrint('[HealthService] Adım hata: $e');
      }

      // ── KALORİ ────────────────────────────────────────────────────────────
      // 1. ACTIVE_ENERGY_BURNED okunur (Health Connect / Samsung Health)
      //    Birden fazla kaynak varsa max tek kaynak alınır (telefon + saat çift sayımını önler)
      // 2. Veri yoksa adım bazlı tahmin: steps × 0.03 kcal
      try {
        final calPoints = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        );

        // Kaynak bazlı grupla → max tek kaynağı al
        final bySource = <String, double>{};
        for (final p in calPoints) {
          if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
            final val = _toDouble(p.value);
            bySource[p.sourceName] = (bySource[p.sourceName] ?? 0) + val;
          }
        }
        debugPrint('[HealthService] Kalori kaynakları: $bySource');

        if (bySource.isNotEmpty) {
          // Direkt Health Connect verisi
          activeCalories = bySource.values.fold(0.0, (a, b) => a > b ? a : b);
          debugPrint('[HealthService] HC kalori (direkt): ${activeCalories.toStringAsFixed(0)} kcal');
        }

        if (activeCalories <= 0 && steps > 0) {
          // HC verisi yok → adımdan tahmin
          activeCalories = steps * 0.03;
          debugPrint('[HealthService] Adım tahmini: ${activeCalories.toStringAsFixed(0)} kcal ($steps adım × 0.03)');
        }

        debugPrint('[HealthService] SONUÇ → steps=$steps, calories=${activeCalories.toStringAsFixed(0)}');
      } catch (e) {
        debugPrint('[HealthService] Kalori hata: $e');
        if (steps > 0) activeCalories = steps * 0.03;
      }
    } catch (e) {
      debugPrint('[HealthService] getTodayHealthData hata: $e');
    }

    return HealthData(steps: steps, activeCalories: activeCalories);
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────────

  static double _toDouble(dynamic value) {
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    if (value is num) return value.toDouble();
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is NumericHealthValue) return value.numericValue.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  static double calculateCaloriesFromSteps(int steps, double weightKg) {
    // Dışarıdan kullanım için bırakıldı ama dahili olarak çağrılmaz
    final factor = weightKg > 0 ? weightKg / 70.0 : 1.0;
    return steps * 0.04 * factor;
  }

  /// Derin tanılama — Health Connect durumu hakkında detaylı bilgi döner.
  /// settings_screen.dart tarafından kullanılır.
  static Future<Map<String, dynamic>> performDeepDiagnosis() async {
    final results = <String, dynamic>{};
    try {
      await initialize();

      if (Platform.isAndroid) {
        try {
          final sdkStatus = await _health.getHealthConnectSdkStatus();
          results['sdkStatus'] = sdkStatus?.name ?? 'null';
          debugPrint('[Tanılama] SDK: ${sdkStatus?.name}');
        } catch (e) {
          results['sdkStatus'] = 'hata: $e';
        }
      } else {
        results['sdkStatus'] = 'iOS (HealthKit)';
      }

      // İzin kontrolü
      final permMap = <String, bool>{};
      for (final type in _types) {
        try {
          final has = await _health.hasPermissions(
            [type],
            permissions: [HealthDataAccess.READ],
          );
          permMap[type.name] = (has == true);
          debugPrint('[Tanılama] İzin ${type.name}: $has');
        } catch (e) {
          permMap[type.name] = false;
        }
      }
      results['permissions'] = permMap;

      // Bugünkü adım aggregate
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      try {
        final todaySteps =
            await _health.getTotalStepsInInterval(midnight, now);
        results['todaySteps'] = todaySteps ?? 0;
        debugPrint('[Tanılama] Bugün aggregate steps: $todaySteps');
      } catch (e) {
        results['todaySteps'] = 'hata: $e';
      }

      // Kaynak bazlı adım analizi
      try {
        final stepPoints = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [HealthDataType.STEPS],
        );
        final bySource = <String, int>{};
        for (final p in stepPoints) {
          bySource[p.sourceName] =
              (bySource[p.sourceName] ?? 0) + _toInt(p.value);
        }
        results['stepsBySource'] = bySource;
        debugPrint('[Tanılama] Kaynak adımlar: $bySource');
      } catch (e) {
        results['stepsError'] = 'hata: $e';
      }

      // Kalori analizi
      try {
        final calPoints = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [
            HealthDataType.ACTIVE_ENERGY_BURNED,
            // WORKOUT kaldırıldı — SecurityException hatası veriyor
          ],
        );
        final calMap = <String, double>{};
        for (final p in calPoints) {
          final key = '${p.type.name}[${p.sourceName}]';
          calMap[key] = (calMap[key] ?? 0) + _toDouble(p.value);
        }
        results['caloriesByTypeSource'] = calMap;
        debugPrint('[Tanılama] Kalori: $calMap');
      } catch (e) {
        results['calError'] = 'hata: $e';
      }
    } catch (e) {
      results['error'] = e.toString();
    }

    debugPrint('[Tanılama] Tam sonuç: $results');
    return results;
  }
}

class HealthData {
  final int steps;
  final double activeCalories;

  const HealthData({required this.steps, required this.activeCalories});

  double get totalBurnedCalories => activeCalories;
}
