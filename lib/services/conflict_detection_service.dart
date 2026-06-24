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
    bool isTurkish = true,
  }) {
    // ── Health condition-specific warnings (highest priority) ──────────────
    final hasSIBO = profile.healthConditions.contains('SIBO');
    final hasDiabetes = profile.healthConditions.contains('Tip 2 Diyabet') ||
        profile.healthConditions.contains('Type 2 Diabetes') ||
        profile.healthConditions.contains('İnsülin Direnci') ||
        profile.healthConditions.contains('Insulin Resistance');
    final hasHypertension = profile.healthConditions.contains('Hipertansiyon') ||
        profile.healthConditions.contains('Hypertension');
    final hasKidney = profile.healthConditions.contains('Böbrek Hastalığı') ||
        profile.healthConditions.contains('Kidney Disease') ||
        profile.healthConditions.contains('Kronik Böbrek Yetmezliği') ||
        profile.healthConditions.contains('Chronic Kidney Failure');
    final hasGout = profile.healthConditions.contains('Gut Hastalığı') ||
        profile.healthConditions.contains('Gout') ||
        profile.healthConditions.contains('Gout Disease');

    if (hasSIBO && consumed.fiber > 5) {
      return [NutritionConflict(
        message: isTurkish 
            ? "SIBO'nuz var: yüksek lif içeriği semptomları artırabilir."
            : "You have SIBO: high fiber content may increase symptoms.",
        severity: 'warning',
        icon: '🔴',
      )];
    }

    if (hasDiabetes && consumed.sugar > 30) {
      return [NutritionConflict(
        message: isTurkish
            ? 'Bugün ${consumed.sugar.toStringAsFixed(0)}g şeker aldınız. Diyabet için öneri: <25g/gün'
            : 'You consumed ${consumed.sugar.toStringAsFixed(0)}g of sugar today. Recommendation for diabetes: <25g/day',
        severity: 'warning',
        icon: '🩸',
      )];
    }

    if (hasHypertension && (consumed.sodium ?? 0) > 1500) {
      return [NutritionConflict(
        message: isTurkish
            ? 'Sodyum limitinizi (1500mg) aştınız: ${consumed.sodium?.toStringAsFixed(0)}mg'
            : 'You exceeded your sodium limit (1500mg): ${consumed.sodium?.toStringAsFixed(0)}mg',
        severity: 'warning',
        icon: '❤️',
      )];
    }

    if (hasKidney && (consumed.potassium ?? 0) > 2000) {
      return [NutritionConflict(
        message: isTurkish
            ? 'Böbrek hastaları için potasyum limiti (2000mg) aşıldı: ${consumed.potassium?.toStringAsFixed(0)}mg'
            : 'Potassium limit (2000mg) for kidney disease exceeded: ${consumed.potassium?.toStringAsFixed(0)}mg',
        severity: 'warning',
        icon: '🫘',
      )];
    }

    if (hasGout && (consumed.sodium ?? 0) > 2000) {
      return [NutritionConflict(
        message: isTurkish
            ? 'Gut hastalığında yüksek sodyum inflamasyonu artırabilir.'
            : 'High sodium may increase inflammation in gout disease.',
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
      NutritionConflict(
        message: isTurkish
            ? 'Omega-3 açığınız var. Balık, ceviz veya keten tohumu ekleyin.'
            : 'You have an omega-3 deficiency. Add fish, walnuts, or flaxseed.',
        severity: 'warning',
        icon: '🐟',
      ),
    );

    // Protein
    addIfDeficient(consumed.protein, profile.proteinGoal,
      NutritionConflict(
        message: isTurkish
            ? 'Protein alımınız düşük (${consumed.protein.toStringAsFixed(0)}g / ${profile.proteinGoal.toStringAsFixed(0)}g). Tavuk, balık veya baklagil ekleyin.'
            : 'Your protein intake is low (${consumed.protein.toStringAsFixed(0)}g / ${profile.proteinGoal.toStringAsFixed(0)}g). Add chicken, fish, or legumes.',
        severity: 'info',
        icon: '💪',
      ),
      threshold: 0.35,
    );

    if (consumed.calories > 800) {
      // D Vitamini
      addIfDeficient(consumed.vitaminD ?? 0, profile.vitaminDGoal,
        NutritionConflict(
          message: isTurkish
              ? 'D vitamini çok düşük. Güneş ışığı veya takviye düşünün.'
              : 'Vitamin D is very low. Consider sunlight or supplements.',
          severity: 'warning',
          icon: '☀️',
        ),
      );

      // Demir
      final ironC = consumed.iron ?? 0;
      addIfDeficient(ironC, profile.ironGoal,
        NutritionConflict(
          message: isTurkish
              ? 'Demir alımınız düşük (${ironC.toStringAsFixed(1)}mg / ${profile.ironGoal.toStringAsFixed(0)}mg). Kırmızı et veya baklagil ekleyin.'
              : 'Your iron intake is low (${ironC.toStringAsFixed(1)}mg / ${profile.ironGoal.toStringAsFixed(0)}mg). Add red meat or legumes.',
          severity: 'warning',
          icon: '🩸',
        ),
      );

      // Kalsiyum
      final calcC = consumed.calcium ?? 0;
      addIfDeficient(calcC, profile.calciumGoal,
        NutritionConflict(
          message: isTurkish
              ? 'Kalsiyum alımınız düşük (${calcC.toStringAsFixed(0)}mg / ${profile.calciumGoal.toStringAsFixed(0)}mg). Süt ürünleri veya yeşil yapraklı sebzeler ekleyin.'
              : 'Your calcium intake is low (${calcC.toStringAsFixed(0)}mg / ${profile.calciumGoal.toStringAsFixed(0)}mg). Add dairy or leafy greens.',
          severity: 'info',
          icon: '🦷',
        ),
      );

      // Magnezyum
      final mgC = consumed.magnesium ?? 0;
      addIfDeficient(mgC, profile.magnesiumGoal,
        NutritionConflict(
          message: isTurkish
              ? 'Magnezyum alımınız düşük (${mgC.toStringAsFixed(0)}mg / ${profile.magnesiumGoal.toStringAsFixed(0)}mg). Fındık, tohumlar veya koyu yeşil sebzeler ekleyin.'
              : 'Your magnesium intake is low (${mgC.toStringAsFixed(0)}mg / ${profile.magnesiumGoal.toStringAsFixed(0)}mg). Add nuts, seeds, or dark leafy greens.',
          severity: 'info',
          icon: '🌿',
        ),
      );

      // Çinko
      final zincC = consumed.zinc ?? 0;
      addIfDeficient(zincC, profile.zincGoal,
        NutritionConflict(
          message: isTurkish
              ? 'Çinko alımınız düşük (${zincC.toStringAsFixed(1)}mg / ${profile.zincGoal.toStringAsFixed(0)}mg). Et, kabuklu deniz ürünleri veya baklagil ekleyin.'
              : 'Your zinc intake is low (${zincC.toStringAsFixed(1)}mg / ${profile.zincGoal.toStringAsFixed(0)}mg). Add meat, shellfish, or legumes.',
          severity: 'info',
          icon: '⚡',
        ),
      );

      // Potasyum
      final potC = consumed.potassium ?? 0;
      addIfDeficient(potC, profile.potassiumGoal,
        NutritionConflict(
          message: isTurkish
              ? 'Potasyum alımınız düşük (${potC.toStringAsFixed(0)}mg / ${profile.potassiumGoal.toStringAsFixed(0)}mg). Muz, patates veya domates ekleyin.'
              : 'Your potassium intake is low (${potC.toStringAsFixed(0)}mg / ${profile.potassiumGoal.toStringAsFixed(0)}mg). Add bananas, potatoes, or tomatoes.',
          severity: 'info',
          icon: '🍌',
        ),
      );

      // B12 Vitamini
      final b12C = consumed.vitaminB12 ?? 0;
      addIfDeficient(b12C, profile.vitaminB12Goal,
        NutritionConflict(
          message: isTurkish
              ? 'B12 vitamini düşük (${b12C.toStringAsFixed(1)}mcg / ${profile.vitaminB12Goal.toStringAsFixed(1)}mcg). Et, yumurta veya süt ürünleri ekleyin.'
              : 'Vitamin B12 is low (${b12C.toStringAsFixed(1)}mcg / ${profile.vitaminB12Goal.toStringAsFixed(1)}mcg). Add meat, eggs, or dairy.',
          severity: 'warning',
          icon: '💊',
        ),
      );
    }

    // Lif (SIBO yoksa)
    if (!hasSIBO) {
      addIfDeficient(consumed.fiber, profile.fiberGoal,
        NutritionConflict(
          message: isTurkish
              ? 'Lif alımınız düşük (${consumed.fiber.toStringAsFixed(1)}g / ${profile.fiberGoal.toStringAsFixed(0)}g). Sebze ve tahıl ekleyin.'
              : 'Your fiber intake is low (${consumed.fiber.toStringAsFixed(1)}g / ${profile.fiberGoal.toStringAsFixed(0)}g). Add vegetables and whole grains.',
          severity: 'info',
          icon: '🌾',
        ),
      );
    }

    if (candidates.isEmpty) return [];
    candidates.sort((a, b) => b.deficit.compareTo(a.deficit));
    return [candidates.first.conflict];
  }

  /// OFF ürününün alerjenlerini kullanıcı sağlık koşullarıyla karşılaştırır.
  static List<NutritionConflict> checkAllergens({
    required List<String> userConditions,
    required OFFProduct? product,
    bool isTurkish = true,
  }) {
    if (product == null || product.allergens.isEmpty) return [];

    const allergenMap = <String, List<String>>{
      'Çölyak':    ['gluten', 'wheat', 'barley', 'rye', 'oat'],
      'Celiac':    ['gluten', 'wheat', 'barley', 'rye', 'oat'],
      'Gluten-Free': ['gluten', 'wheat', 'barley', 'rye', 'oat'],
      'Süt Alerjisi': ['milk', 'dairy', 'lactose', 'casein'],
      'Milk Allergy': ['milk', 'dairy', 'lactose', 'casein'],
      'Yumurta Alerjisi': ['egg', 'eggs'],
      'Egg Allergy': ['egg', 'eggs'],
      'Fıstık Alerjisi': ['peanut', 'peanuts', 'nut', 'nuts', 'almond', 'hazelnut'],
      'Peanut Allergy': ['peanut', 'peanuts', 'nut', 'nuts', 'almond', 'hazelnut'],
      'Deniz Ürünleri Alerjisi': ['fish', 'shellfish', 'crustacean', 'mollusc'],
      'Seafood Allergy': ['fish', 'shellfish', 'crustacean', 'mollusc'],
      'Soya Alerjisi': ['soy', 'soya', 'soybean'],
      'Soy Allergy': ['soy', 'soya', 'soybean'],
    };

    final conflicts = <NutritionConflict>[];
    final allergenLower = product.allergens.map((a) => a.toLowerCase()).toList();

    for (final condition in userConditions) {
      final keywords = allergenMap[condition];
      if (keywords == null) continue;
      for (final keyword in keywords) {
        if (allergenLower.any((a) => a.contains(keyword))) {
          conflicts.add(NutritionConflict(
            message: isTurkish
                ? '$condition uyarısı: "${product.name}" ürününde $keyword içeriği tespit edildi.'
                : '$condition warning: $keyword detected in "${product.name}".',
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
