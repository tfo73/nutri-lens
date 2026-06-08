import '../models/nutrition_data.dart';
import '../providers/profile_provider.dart';
import 'open_food_facts_service.dart';

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

class _DeficiencyCandidate {
  final double deficit; // fraction 0–1, higher = worse
  final NutritionConflict conflict;
  const _DeficiencyCandidate({required this.deficit, required this.conflict});
}

class ConflictDetectionService {
  static List<NutritionConflict> detect({
    required NutritionData consumed,
    required UserProfile profile,
  }) {
    // ── Health condition-specific warnings (highest priority) ──────────────
    if (profile.healthConditions.contains('SIBO') && consumed.fiber > 5) {
      return [const NutritionConflict(
        message: "SIBO'nuz var: yüksek lif içeriği semptomları artırabilir.",
        severity: 'warning',
        icon: '🔴',
      )];
    }

    if ((profile.healthConditions.contains('Tip 2 Diyabet') ||
            profile.healthConditions.contains('İnsülin Direnci')) &&
        consumed.sugar > 30) {
      return [NutritionConflict(
        message: 'Bugün ${consumed.sugar.toStringAsFixed(0)}g şeker aldınız. Diyabet için öneri: <25g/gün',
        severity: 'warning',
        icon: '🩸',
      )];
    }

    if (profile.healthConditions.contains('Hipertansiyon') &&
        (consumed.sodium ?? 0) > 1500) {
      return [NutritionConflict(
        message: 'Sodyum limitinizi (1500mg) aştınız: ${consumed.sodium?.toStringAsFixed(0)}mg',
        severity: 'warning',
        icon: '❤️',
      )];
    }

    if (profile.healthConditions.contains('Böbrek Hastalığı') &&
        (consumed.potassium ?? 0) > 2000) {
      return [NutritionConflict(
        message: 'Böbrek hastaları için potasyum limiti (2000mg) aşıldı: ${consumed.potassium?.toStringAsFixed(0)}mg',
        severity: 'warning',
        icon: '🫘',
      )];
    }

    if (profile.healthConditions.contains('Gut Hastalığı') &&
        (consumed.sodium ?? 0) > 2000) {
      return [const NutritionConflict(
        message: 'Gut hastalığında yüksek sodyum inflamasyonu artırabilir.',
        severity: 'info',
        icon: '🦴',
      )];
    }

    // ── Micro-nutrient deficiency: pick single worst ───────────────────────
    if (consumed.calories < 600) return [];

    final candidates = <_DeficiencyCandidate>[];

    void addIfDeficient(double consumedVal, double goal, NutritionConflict conflict, {double threshold = 0.3}) {
      if (goal <= 0) return;
      final deficit = consumedVal < goal ? (goal - consumedVal) / goal : 0.0;
      if (deficit > threshold) candidates.add(_DeficiencyCandidate(deficit: deficit, conflict: conflict));
    }

    // Omega-3
    addIfDeficient(consumed.omega3 ?? 0, profile.omega3Goal,
      const NutritionConflict(message: 'Omega-3 açığınız var. Balık, ceviz veya keten tohumu ekleyin.', severity: 'warning', icon: '🐟'));

    // Protein
    addIfDeficient(consumed.protein, profile.proteinGoal,
      NutritionConflict(message: 'Protein alımınız düşük (${consumed.protein.toStringAsFixed(0)}g / ${profile.proteinGoal.toStringAsFixed(0)}g). Tavuk, balık veya baklagil ekleyin.', severity: 'info', icon: '💪'),
      threshold: 0.35);

    if (consumed.calories > 800) {
      // D Vitamini
      addIfDeficient(consumed.vitaminD ?? 0, profile.vitaminDGoal,
        const NutritionConflict(message: 'D vitamini çok düşük. Güneş ışığı veya takviye düşünün.', severity: 'warning', icon: '☀️'));

      // Demir
      final ironC = consumed.iron ?? 0;
      addIfDeficient(ironC, profile.ironGoal,
        NutritionConflict(message: 'Demir alımınız düşük (${ironC.toStringAsFixed(1)}mg / ${profile.ironGoal.toStringAsFixed(0)}mg). Kırmızı et veya baklagil ekleyin.', severity: 'warning', icon: '🩸'));

      // Kalsiyum
      final calcC = consumed.calcium ?? 0;
      addIfDeficient(calcC, profile.calciumGoal,
        NutritionConflict(message: 'Kalsiyum alımınız düşük (${calcC.toStringAsFixed(0)}mg / ${profile.calciumGoal.toStringAsFixed(0)}mg). Süt ürünleri veya yeşil yapraklı sebzeler ekleyin.', severity: 'info', icon: '🦷'));

      // Magnezyum
      final mgC = consumed.magnesium ?? 0;
      addIfDeficient(mgC, profile.magnesiumGoal,
        NutritionConflict(message: 'Magnezyum alımınız düşük (${mgC.toStringAsFixed(0)}mg / ${profile.magnesiumGoal.toStringAsFixed(0)}mg). Fındık, tohumlar veya koyu yeşil sebzeler ekleyin.', severity: 'info', icon: '🌿'));

      // Çinko
      final zincC = consumed.zinc ?? 0;
      addIfDeficient(zincC, profile.zincGoal,
        NutritionConflict(message: 'Çinko alımınız düşük (${zincC.toStringAsFixed(1)}mg / ${profile.zincGoal.toStringAsFixed(0)}mg). Et, kabuklu deniz ürünleri veya baklagil ekleyin.', severity: 'info', icon: '⚡'));

      // Potasyum
      final potC = consumed.potassium ?? 0;
      addIfDeficient(potC, profile.potassiumGoal,
        NutritionConflict(message: 'Potasyum alımınız düşük (${potC.toStringAsFixed(0)}mg / ${profile.potassiumGoal.toStringAsFixed(0)}mg). Muz, patates veya domates ekleyin.', severity: 'info', icon: '🍌'));

      // B12 Vitamini
      final b12C = consumed.vitaminB12 ?? 0;
      addIfDeficient(b12C, profile.vitaminB12Goal,
        NutritionConflict(message: 'B12 vitamini düşük (${b12C.toStringAsFixed(1)}mcg / ${profile.vitaminB12Goal.toStringAsFixed(1)}mcg). Et, yumurta veya süt ürünleri ekleyin.', severity: 'warning', icon: '💊'));
    }

    // Lif (SIBO yoksa)
    if (!profile.healthConditions.contains('SIBO')) {
      addIfDeficient(consumed.fiber, profile.fiberGoal,
        NutritionConflict(message: 'Lif alımınız düşük (${consumed.fiber.toStringAsFixed(1)}g / ${profile.fiberGoal.toStringAsFixed(0)}g). Sebze ve tahıl ekleyin.', severity: 'info', icon: '🌾'));
    }

    if (candidates.isEmpty) return [];
    candidates.sort((a, b) => b.deficit.compareTo(a.deficit));
    return [candidates.first.conflict];
  }

  /// OFF ürününün alerjenlerini kullanıcı sağlık koşullarıyla karşılaştırır.
  static List<NutritionConflict> checkAllergens({
    required List<String> userConditions,
    required OFFProduct? product,
  }) {
    if (product == null || product.allergens.isEmpty) return [];

    const allergenMap = <String, List<String>>{
      'Çölyak':    ['gluten', 'wheat', 'barley', 'rye', 'oat'],
      'Gluten-Free': ['gluten', 'wheat', 'barley', 'rye', 'oat'],
      'Süt Alerjisi': ['milk', 'dairy', 'lactose', 'casein'],
      'Yumurta Alerjisi': ['egg', 'eggs'],
      'Fıstık Alerjisi': ['peanut', 'peanuts', 'nut', 'nuts', 'almond', 'hazelnut'],
      'Deniz Ürünleri Alerjisi': ['fish', 'shellfish', 'crustacean', 'mollusc'],
      'Soya Alerjisi': ['soy', 'soya', 'soybean'],
    };

    final conflicts = <NutritionConflict>[];
    final allergenLower = product.allergens.map((a) => a.toLowerCase()).toList();

    for (final condition in userConditions) {
      final keywords = allergenMap[condition];
      if (keywords == null) continue;
      for (final keyword in keywords) {
        if (allergenLower.any((a) => a.contains(keyword))) {
          conflicts.add(NutritionConflict(
            message: '$condition uyarısı: "${product.name}" ürününde $keyword içeriği tespit edildi.',
            severity: 'warning',
            icon: '⚠️',
          ));
          break;
        }
      }
    }

    return conflicts;
  }
}
