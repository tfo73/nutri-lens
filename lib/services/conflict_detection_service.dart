import '../models/nutrition_data.dart';
import '../providers/profile_provider.dart';

class NutritionConflict {
  final String message;
  final String severity; // 'warning' | 'info'
  final String icon;

  const NutritionConflict({
    required this.message,
    required this.severity,
    required this.icon,
  });
}

class ConflictDetectionService {
  static List<NutritionConflict> detect({
    required NutritionData consumed,
    required UserProfile profile,
  }) {
    final conflicts = <NutritionConflict>[];
    final calorieGoal = profile.calorieGoal;

    // 1. Kalori doldu ama protein hedefine ulaşılamaz
    final remainingCal = calorieGoal - consumed.calories;
    final remainingProtein = profile.proteinGoal - consumed.protein;
    if (remainingCal < remainingProtein * 4 && remainingProtein > 10) {
      conflicts.add(NutritionConflict(
        message:
            'Bugün protein hedefinize ulaşmak artık mümkün değil. Kalan kalori: ${remainingCal.toInt()} kcal',
        severity: 'warning',
        icon: '⚠️',
      ));
    }

    // 2. Yağ limiti doldu ama Omega-3 alınmadı
    if (consumed.fat >= profile.fatGoal * 0.9 &&
        (consumed.omega3 ?? 0) < profile.omega3Goal * 0.3) {
      conflicts.add(const NutritionConflict(
        message: 'Omega-3 açığınız var. Balık yağı takviyesi düşünün.',
        severity: 'warning',
        icon: '🐟',
      ));
    }

    // 3. Omega-6/Omega-3 oranı bozuk
    final omega3 = consumed.omega3 ?? 0;
    final omega6 = consumed.omega6 ?? 0;
    if (omega3 > 0 && omega6 > 0) {
      final ratio = omega6 / omega3;
      if (ratio > 15) {
        conflicts.add(NutritionConflict(
          message:
              'Omega-6/Omega-3 oranınız ${ratio.toStringAsFixed(0)}:1 (ideal: <10:1)',
          severity: 'warning',
          icon: '⚖️',
        ));
      }
    }

    // 4. Magnezyum var ama D vitamini eksik — absorpsiyon azalır
    if ((consumed.magnesium ?? 0) > profile.magnesiumGoal * 0.5 &&
        (consumed.vitaminD ?? 0) < profile.vitaminDGoal * 0.2) {
      conflicts.add(const NutritionConflict(
        message: 'D vitamini eksik — magnezyum absorpsiyonu azalacak.',
        severity: 'info',
        icon: '☀️',
      ));
    }

    // 5. SIBO + Lif uyarısı
    if (profile.healthConditions.contains('SIBO') &&
        consumed.fiber > 5) {
      conflicts.add(const NutritionConflict(
        message: "SIBO'nuz var: yüksek lif içeriği semptomları artırabilir.",
        severity: 'warning',
        icon: '🔴',
      ));
    }

    // 6. Diyabet / İnsülin Direnci + Şeker uyarısı
    if ((profile.healthConditions.contains('Tip 2 Diyabet') ||
            profile.healthConditions.contains('İnsülin Direnci')) &&
        consumed.sugar > 30) {
      conflicts.add(NutritionConflict(
        message:
            'Bugün ${consumed.sugar.toStringAsFixed(0)}g şeker aldınız. Diyabet için öneri: <25g/gün',
        severity: 'warning',
        icon: '🩸',
      ));
    }

    // 7. Hipertansiyon + Sodyum
    if (profile.healthConditions.contains('Hipertansiyon') &&
        (consumed.sodium ?? 0) > 1500) {
      conflicts.add(NutritionConflict(
        message:
            'Sodyum limitinizi (1500mg) aştınız: ${consumed.sodium?.toStringAsFixed(0)}mg',
        severity: 'warning',
        icon: '❤️',
      ));
    }

    // 8. Böbrek Hastalığı + Potasyum
    if (profile.healthConditions.contains('Böbrek Hastalığı') &&
        (consumed.potassium ?? 0) > 2000) {
      conflicts.add(NutritionConflict(
        message:
            'Böbrek hastaları için potasyum limiti (2000mg) aşıldı: ${consumed.potassium?.toStringAsFixed(0)}mg',
        severity: 'warning',
        icon: '🫘',
      ));
    }

    // 9. Gut Hastalığı + yüksek sodyum (şiddetli tuz) uyarısı
    if (profile.healthConditions.contains('Gut Hastalığı') &&
        (consumed.sodium ?? 0) > 2000) {
      conflicts.add(const NutritionConflict(
        message: 'Gut hastalığında yüksek sodyum inflamasyonu artırabilir.',
        severity: 'info',
        icon: '🦴',
      ));
    }

    // 10. Çölyak + Gluten uyarısı (kullanıcıya genel hatırlatma)
    if (profile.healthConditions.contains('Çölyak') ||
        profile.dietaryPreferences.contains('Gluten-Free')) {
      // Bu kontrol yemek bazlı değil, günlük hatırlatma niteliğinde
      // Sadece bir kez göster (entries varsa)
      if (consumed.calories > 100) {
        // placeholder — gerçek gluten tespiti yemek adı analizine gerek duyar
      }
    }

    return conflicts;
  }
}
