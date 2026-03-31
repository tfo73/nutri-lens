import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../providers/language_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../services/health_service.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/macro_card.dart';
import '../widgets/meal_card.dart';
import '../widgets/profile_switcher_button.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(String meal)? onMealAddPressed;

  const DashboardScreen({super.key, this.onMealAddPressed});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _steps = 0;
  double _stepCalories = 0;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadSteps();
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _loadSteps();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSteps() async {
    final steps = await HealthService.getTodaySteps();
    if (!mounted) return;
    final profileProvider = context.read<ProfileProvider>();
    final weightKg = profileProvider.activeProfile?.weight ?? 70.0;
    final calories = HealthService.calculateCaloriesFromSteps(steps, weightKg);
    setState(() {
      _steps = steps;
      _stepCalories = calories;
    });
    if (steps > 0) {
      context.read<NutritionProvider>().updateSteps(steps);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Consumer2<NutritionProvider, ProfileProvider>(
      builder: (context, provider, profileProvider, _) {
        final l10n = AppLocalizations.of(context);
        final nutrition = provider.totalNutrition;
        final calorieGoal = profileProvider.calorieGoal;
        final proteinGoal = profileProvider.proteinGoal;
        final carbGoal = profileProvider.carbGoal;
        final fatGoal = profileProvider.fatGoal;
        final exerciseBurned = provider.totalBurnedCaloriesFromExercises;
        final totalBurned = _stepCalories + exerciseBurned;
        final remaining = calorieGoal - nutrition.calories + totalBurned;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NutriLens'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              const ProfileSwitcherButton(),
            ],
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateHeader(context),
                const SizedBox(height: 16),
                if (!profileProvider.isProfileComplete)
                  _buildProfileWarning(context, l10n),
                if (!profileProvider.isProfileComplete)
                  const SizedBox(height: 16),
                FadeInSlide(
                  delay: const Duration(milliseconds: 0),
                  child: _buildNutritionScore(
                      context, nutrition, profileProvider),
                ),
                const SizedBox(height: 16),
                FadeInSlide(
                  delay: const Duration(milliseconds: 40),
                  child: _buildCalorieRing(context, nutrition, remaining,
                      calorieGoal, totalBurned, l10n),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delay: const Duration(milliseconds: 80),
                  child: _buildMacroRow(context, nutrition, proteinGoal,
                      carbGoal, fatGoal, l10n),
                ),
                const SizedBox(height: 12),
                FadeInSlide(
                  delay: const Duration(milliseconds: 120),
                  child: _buildBesinKarnesi(
                      context, nutrition, profileProvider),
                ),
                const SizedBox(height: 12),
                FadeInSlide(
                  delay: const Duration(milliseconds: 140),
                  child: _buildConflictCards(
                      context, provider, profileProvider),
                ),
                const SizedBox(height: 12),
                FadeInSlide(
                  delay: const Duration(milliseconds: 160),
                  child: _buildStepsCard(context, l10n),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delay: const Duration(milliseconds: 240),
                  child: _WaterCard(provider: provider),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delay: const Duration(milliseconds: 320),
                  child: _CalorieChartCard(provider: provider),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delay: const Duration(milliseconds: 400),
                  child: _buildMealSections(context, provider, l10n),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTurkish = l10n.isTurkish;
    final now = DateTime.now();
    const daysTr = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];
    const daysEn = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const monthsTr = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    const monthsEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final days = isTurkish ? daysTr : daysEn;
    final months = isTurkish ? monthsTr : monthsEn;
    return Text(
      '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildProfileWarning(BuildContext context, AppLocalizations l10n) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.isTurkish
                  ? 'Kişisel hedefler için Profil sekmesini doldurun.'
                  : 'Fill the Profile tab for personal goals.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.person_add_outlined,
                  color: Theme.of(context).colorScheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.isTurkish
                      ? 'Profilinizi doldurun — kalori ve makro hedefleriniz otomatik hesaplansın.'
                      : 'Fill your profile — calorie and macro goals will be calculated automatically.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieRing(BuildContext context, NutritionData nutrition,
      double remaining, double calorieGoal, double burnedCalories,
      AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Card(
      elevation: 3,
      shadowColor: colorScheme.primary.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: nutrition.calories),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 1500),
              curve: Curves.easeOut,
              builder: (context, animCalories, _) {
                final animProgress =
                    calorieGoal > 0
                        ? (animCalories / calorieGoal).clamp(0.0, 1.0)
                        : 0.0;
                return SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: animProgress == 0 ? 0.001 : animProgress,
                              color: const Color(0xFF4CAF50),
                              radius: 22,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value:
                                  1 - (animProgress == 0 ? 0.001 : animProgress),
                              color: colorScheme.surfaceVariant,
                              radius: 22,
                              showTitle: false,
                            ),
                          ],
                          centerSpaceRadius: 50,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            animCalories.toStringAsFixed(0),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                          ),
                          Text(
                            'kcal',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow(
                    context,
                    label: l10n.tr('Günlük Hedef'),
                    value: '${calorieGoal.toStringAsFixed(0)} kcal',
                    color: colorScheme.onSurface,
                    isLarge: true,
                  ),
                  const SizedBox(height: 6),
                  _statRow(
                    context,
                    label: l10n.isTurkish ? 'Alınan' : 'Consumed',
                    value: '${nutrition.calories.toStringAsFixed(0)} kcal',
                    color: const Color(0xFF4CAF50),
                  ),
                  if (burnedCalories > 0) ...[
                    const SizedBox(height: 4),
                    _statRow(
                      context,
                      label: l10n.isTurkish ? 'Yakılan' : 'Burned',
                      value: '${burnedCalories.toStringAsFixed(0)} kcal',
                      color: Colors.orange,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _statRow(
                    context,
                    label: l10n.tr('Kalan'),
                    value:
                        '${remaining.clamp(0, calorieGoal + burnedCalories).toStringAsFixed(0)} kcal',
                    color: remaining > 0 ? colorScheme.primary : colorScheme.error,
                    isLarge: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool isLarge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.8),
                  letterSpacing: 0.3,
                )),
        Text(
          value,
          style: (isLarge
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildMacroRow(BuildContext context, NutritionData nutrition,
      double proteinGoal, double carbGoal, double fatGoal, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: MacroCard(
            label: l10n.tr('Protein'),
            current: nutrition.protein,
            goal: proteinGoal,
            unit: 'g',
            color: const Color(0xFF1976D2),
            icon: Icons.fitness_center,
            animDelay: Duration.zero,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MacroCard(
            label: l10n.isTurkish ? 'Karb.' : 'Carbs',
            current: nutrition.carbohydrates,
            goal: carbGoal,
            unit: 'g',
            color: Colors.orange,
            icon: Icons.grain,
            animDelay: const Duration(milliseconds: 200),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MacroCard(
            label: l10n.tr('Yağ'),
            current: nutrition.fat,
            goal: fatGoal,
            unit: 'g',
            color: const Color(0xFF2E7D32),
            icon: Icons.water_drop_outlined,
            animDelay: const Duration(milliseconds: 400),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text('👟', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} adım',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (_stepCalories > 0)
              Text(
                '~${_stepCalories.toStringAsFixed(0)} kcal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, FoodEntry entry, NutritionProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FoodEditSheet(entry: entry, provider: provider),
    );
  }

  Widget _buildMealSections(
      BuildContext context, NutritionProvider provider, AppLocalizations l10n) {
    final meals = provider.todayLog.entriesByMeal;
    const mealOrder = ['kahvaltı', 'öğle', 'akşam', 'ara öğün'];
    const mealIcons = {
      'kahvaltı': Icons.wb_sunny_outlined,
      'öğle': Icons.wb_cloudy_outlined,
      'akşam': Icons.nights_stay_outlined,
      'ara öğün': Icons.coffee_outlined,
    };
    final mealNames = {
      'kahvaltı': l10n.tr('Kahvaltı'),
      'öğle': l10n.tr('Öğle'),
      'akşam': l10n.tr('Akşam'),
      'ara öğün': l10n.tr('Ara Öğün'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.tr('Öğünler'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...mealOrder.map((meal) => MealCard(
              mealName: mealNames[meal] ?? meal[0].toUpperCase() + meal.substring(1),
              entries: meals[meal] ?? [],
              icon: mealIcons[meal] ?? Icons.restaurant,
              onAddPressed: widget.onMealAddPressed != null
                  ? () => widget.onMealAddPressed!(meal)
                  : null,
              onEntryTap: (entry) =>
                  _showEditSheet(context, entry, provider),
              onEntryDelete: (entry) => provider.removeFoodEntry(entry.id),
            )),
      ],
    );
  }

  // ─── Beslenme Skoru ────────────────────────────────────────────────────────

  double _calcNutritionScore(
      NutritionData n, ProfileProvider pp) {
    final profile = pp.activeProfile;
    if (profile == null || pp.calorieGoal <= 0) return 0;

    double score(double consumed, double goal) {
      if (goal <= 0) return 100;
      return (consumed / goal).clamp(0.0, 1.0) * 100;
    }

    double scoreInverse(double consumed, double limit) {
      if (limit <= 0) return 100;
      return ((1 - consumed / limit).clamp(0.0, 1.0)) * 100;
    }

    // Makrolar %60
    final calScore = score(n.calories, pp.calorieGoal) * 0.20;
    final protScore = score(n.protein, pp.proteinGoal) * 0.20;
    final carbScore = score(n.carbohydrates, pp.carbGoal) * 0.10;
    final fatScore = score(n.fat, pp.fatGoal) * 0.10;

    // Mikro besinler %40 (eşit ağırlıklı 8 besin = %5 her biri)
    final micros = [
      score(n.selenium ?? 0, profile.seleniumGoal),
      score(n.magnesium ?? 0, profile.magnesiumGoal),
      score(n.omega3 ?? 0, profile.omega3Goal),
      score(n.iron ?? 0, profile.ironGoal),
      score(n.zinc ?? 0, profile.zincGoal),
      score(n.vitaminD ?? 0, profile.vitaminDGoal),
      score(n.calcium ?? 0, profile.calciumGoal),
      scoreInverse(n.sodium ?? 0, profile.sodiumLimit),
    ];
    final microScore =
        micros.reduce((a, b) => a + b) / micros.length * 0.40;

    return (calScore + protScore + carbScore + fatScore + microScore)
        .clamp(0.0, 100.0);
  }

  Widget _buildNutritionScore(
      BuildContext context, NutritionData nutrition, ProfileProvider pp) {
    final score = _calcNutritionScore(nutrition, pp);
    final colorScheme = Theme.of(context).colorScheme;
    final Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF40916C);
    } else if (score >= 50) {
      scoreColor = const Color(0xFFF9A825);
    } else {
      scoreColor = colorScheme.error;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor:
                        colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                  Text(
                    score.toInt().toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beslenme Skoru',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    score >= 80
                        ? 'Harika gidiyorsunuz!'
                        : score >= 50
                            ? 'Eksik besinleriniz var'
                            : 'Beslenmenizi geliştirin',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Besin Karnesi ────────────────────────────────────────────────────────

  Widget _buildBesinKarnesi(
      BuildContext context, NutritionData n, ProfileProvider pp) {
    final profile = pp.activeProfile;
    if (profile == null) return const SizedBox.shrink();

    final items = <_MicroItem>[
      _MicroItem('Selenyum', n.selenium, profile.seleniumGoal, 'μg'),
      _MicroItem('Magnezyum', n.magnesium, profile.magnesiumGoal, 'mg'),
      _MicroItem('Omega-3', n.omega3, profile.omega3Goal, 'g'),
      _MicroItem('Omega-6', n.omega6, profile.omega6Goal, 'g'),
      _MicroItem('Demir', n.iron, profile.ironGoal, 'mg'),
      _MicroItem('Çinko', n.zinc, profile.zincGoal, 'mg'),
      _MicroItem('D Vitamini', n.vitaminD, profile.vitaminDGoal, 'μg'),
      _MicroItem('B12 Vitamini', n.vitaminB12, profile.vitaminB12Goal, 'μg'),
      _MicroItem('Kalsiyum', n.calcium, profile.calciumGoal, 'mg'),
      _MicroItem('Potasyum', n.potassium, profile.potassiumGoal, 'mg'),
      if (profile.fiberGoal > 0)
        _MicroItem('Lif', n.fiber, profile.fiberGoal, 'g'),
      _MicroItem('Sodyum', n.sodium, profile.sodiumLimit, 'mg',
          isMaxNutrient: true),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              const Text('🧬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Besin Karnesi',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: items
                    .map((item) => _buildMicroRow(context, item))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroRow(BuildContext context, _MicroItem item) {
    final consumed = item.consumed ?? 0;
    final ratio = item.goal > 0
        ? (item.isMaxNutrient
            ? (1 - consumed / item.goal).clamp(0.0, 1.0)
            : (consumed / item.goal).clamp(0.0, 1.0))
        : 0.0;

    final Color barColor;
    final String statusIcon;
    if (ratio >= 0.8) {
      barColor = const Color(0xFF40916C);
      statusIcon = '✓';
    } else if (ratio >= 0.5) {
      barColor = const Color(0xFFF9A825);
      statusIcon = '!';
    } else {
      barColor = Theme.of(context).colorScheme.error;
      statusIcon = '✗';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusIcon,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: barColor),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: Text(
              item.consumed != null
                  ? '${consumed.toStringAsFixed(item.unit == 'g' || item.unit == 'μg' ? 1 : 0)} ${item.unit}'
                  : '— ${item.unit}',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Çakışma Kartları ─────────────────────────────────────────────────────

  Widget _buildConflictCards(
      BuildContext context, NutritionProvider provider, ProfileProvider pp) {
    final conflicts =
        provider.getConflicts(pp.activeProfile);
    if (conflicts.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: conflicts.map((c) {
        final isWarning = c.severity == 'warning';
        final bgColor = isWarning
            ? colorScheme.errorContainer.withValues(alpha: 0.5)
            : colorScheme.tertiaryContainer.withValues(alpha: 0.5);
        final textColor = isWarning
            ? colorScheme.onErrorContainer
            : colorScheme.onTertiaryContainer;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(c.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.message,
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Micro Item ────────────────────────────────────────────────────────────────

class _MicroItem {
  final String label;
  final double? consumed;
  final double goal;
  final String unit;
  final bool isMaxNutrient;

  const _MicroItem(this.label, this.consumed, this.goal, this.unit,
      {this.isMaxNutrient = false});
}

// ─── Calorie Chart Card ───────────────────────────────────────────────────────

class _CalorieChartCard extends StatefulWidget {
  final NutritionProvider provider;

  const _CalorieChartCard({required this.provider});

  @override
  State<_CalorieChartCard> createState() => _CalorieChartCardState();
}

class _CalorieChartCardState extends State<_CalorieChartCard>
    with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'week'; // 'week', 'month', 'year'
  String _selectedChartType = 'bar'; // 'bar', 'line'
  int _touchedIndex = -1;

  late final AnimationController _barAnimCtrl;
  late final Animation<double> _barAnim;

  static const double _maxY = 3500;
  static const double _minBarValue = 75;

  @override
  void initState() {
    super.initState();
    _barAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnim = CurvedAnimation(parent: _barAnimCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _barAnimCtrl.value = 1.0;
      } else {
        _barAnimCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _barAnimCtrl.dispose();
    super.dispose();
  }

  Map<int, double> _getWeeklyCalories() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final result = <int, double>{};
    for (int i = 0; i < 7; i++) {
      final date = DateTime(monday.year, monday.month, monday.day + i);
      final log = widget.provider.getLogForDate(date);
      result[i] = log?.totalNutrition.calories ?? 0;
    }
    return result;
  }

  Map<int, double> _getMonthlyCalories() {
    // Group last 30 days into 4 weeks
    final now = DateTime.now();
    final result = <int, double>{0: 0, 1: 0, 2: 0, 3: 0};
    for (int i = 0; i < 28; i++) {
      final date = now.subtract(Duration(days: 27 - i));
      final log = widget.provider.getLogForDate(date);
      final calories = log?.totalNutrition.calories ?? 0;
      final weekIndex = i ~/ 7;
      result[weekIndex] = (result[weekIndex] ?? 0) + calories / 7;
    }
    return result;
  }

  Map<int, double> _getYearlyCalories() {
    // Group last 12 months, calculate average daily calories per month
    final now = DateTime.now();
    final result = <int, double>{};
    for (int m = 0; m < 12; m++) {
      final month = DateTime(now.year, now.month - 11 + m, 1);
      double total = 0;
      int count = 0;
      for (int d = 1; d <= 31; d++) {
        try {
          final date = DateTime(month.year, month.month, d);
          if (date.month != month.month) break;
          final log = widget.provider.getLogForDate(date);
          if (log != null && log.entries.isNotEmpty) {
            total += log.totalNutrition.calories;
            count++;
          }
        } catch (_) {}
      }
      result[m] = count > 0 ? total / count : 0;
    }
    return result;
  }

  void _toggleChartType() {
    setState(() {
      _selectedChartType = _selectedChartType == 'bar' ? 'line' : 'bar';
    });
  }

  Widget _buildPeriodChip(String label, String period) {
    final isSelected = _selectedPeriod == period;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPeriod = period);
        _barAnimCtrl.forward(from: 0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<int, double> data,
      [double animFactor = 1.0]) {
    final todayIndex =
        _selectedPeriod == 'week' ? DateTime.now().weekday - 1 : -1;
    return List.generate(data.length, (i) {
      final actual = data[i] ?? 0;
      final rawY = actual > 0 ? actual : _minBarValue;
      final displayY = rawY * animFactor;
      final isToday = i == todayIndex;
      Color barColor;
      if (actual <= 0) {
        barColor = Colors.grey.withOpacity(0.25);
      } else {
        barColor = isToday ? const Color(0xFF2E7D32) : const Color(0xFF66BB6A);
        if (_touchedIndex == i) barColor = barColor.withOpacity(0.65);
      }
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: displayY.clamp(0, _maxY),
            color: barColor,
            width: _selectedPeriod == 'year' ? 14 : 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  List<FlSpot> _buildLineSpots(Map<int, double> data) {
    return List.generate(data.length, (i) {
      final v = data[i] ?? 0;
      return FlSpot(i.toDouble(), v);
    });
  }

  List<String> _getLabels() {
    final isTurkish = AppLocalizations.of(context).isTurkish;
    if (_selectedPeriod == 'week') {
      return isTurkish
          ? ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz']
          : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    } else if (_selectedPeriod == 'month') {
      return isTurkish
          ? ['1.H', '2.H', '3.H', '4.H']
          : ['W1', 'W2', 'W3', 'W4'];
    } else {
      // year — last 12 months abbreviated
      final now = DateTime.now();
      const monthsTr = ['Oc', 'Şb', 'Mr', 'Ns', 'My', 'Hz', 'Tm', 'Ag', 'Ey', 'Ek', 'Ks', 'Ar'];
      const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final months = isTurkish ? monthsTr : monthsEn;
      return List.generate(12, (i) {
        final month = DateTime(now.year, now.month - 11 + i, 1);
        return months[month.month - 1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final Map<int, double> data;
    if (_selectedPeriod == 'week') {
      data = _getWeeklyCalories();
    } else if (_selectedPeriod == 'month') {
      data = _getMonthlyCalories();
    } else {
      data = _getYearlyCalories();
    }

    final labels = _getLabels();
    final todayIndex = _selectedPeriod == 'week' ? DateTime.now().weekday - 1 : -1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.isTurkish ? 'Kalori Grafiği' : 'Calorie Chart',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    _buildPeriodChip('7G', 'week'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('1A', 'month'),
                    const SizedBox(width: 4),
                    _buildPeriodChip('1Y', 'year'),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _toggleChartType,
                      icon: Icon(
                        _selectedChartType == 'bar'
                            ? Icons.show_chart
                            : Icons.bar_chart,
                      ),
                      color: colorScheme.primary,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: AnimatedBuilder(
                animation: _barAnim,
                builder: (context, _) => _selectedChartType == 'bar'
                  ? BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _maxY,
                        barGroups: _buildBarGroups(data, _barAnim.value),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                final isToday = idx == todayIndex;
                                return Text(
                                  labels[idx],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isToday
                                        ? colorScheme.primary
                                        : Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.color,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          enabled: true,
                          handleBuiltInTouches: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.black87,
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final actual = data[group.x] ?? 0;
                              if (actual <= 0) return null;
                              return BarTooltipItem(
                                '${actual.toStringAsFixed(0)} kcal',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                          touchCallback:
                              (FlTouchEvent event, BarTouchResponse? response) {
                            setState(() {
                              if (response == null || response.spot == null) {
                                _touchedIndex = -1;
                              } else {
                                _touchedIndex =
                                    response.spot!.touchedBarGroupIndex;
                              }
                            });
                          },
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: _buildLineSpots(data),
                            isCurved: true,
                            color: colorScheme.primary,
                            barWidth: 2.5,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withOpacity(0.3),
                                  colorScheme.primary.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                radius: 3,
                                color: colorScheme.primary,
                                strokeWidth: 0,
                                strokeColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                final isToday = idx == todayIndex;
                                return Text(
                                  labels[idx],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isToday
                                        ? colorScheme.primary
                                        : Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.color,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: _maxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => Colors.black87,
                            getTooltipItems: (spots) => spots
                                .map((s) => LineTooltipItem(
                                      '${s.y.toStringAsFixed(0)} kcal',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yiyecek Düzenleme Sayfası ────────────────────────────────────────────────

class _FoodEditSheet extends StatefulWidget {
  final FoodEntry entry;
  final NutritionProvider provider;

  const _FoodEditSheet({required this.entry, required this.provider});

  @override
  State<_FoodEditSheet> createState() => _FoodEditSheetState();
}

class _FoodEditSheetState extends State<_FoodEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _portionCtrl;
  late final TextEditingController _calorieCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _fatCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final n = e.nutritionData.scaleBy(e.portionSize / 100);
    _nameCtrl = TextEditingController(text: e.name);
    _portionCtrl =
        TextEditingController(text: e.portionSize.toStringAsFixed(0));
    _calorieCtrl =
        TextEditingController(text: n.calories.toStringAsFixed(0));
    _proteinCtrl =
        TextEditingController(text: n.protein.toStringAsFixed(0));
    _carbCtrl =
        TextEditingController(text: n.carbohydrates.toStringAsFixed(0));
    _fatCtrl = TextEditingController(text: n.fat.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final portionSize =
        double.tryParse(_portionCtrl.text) ?? widget.entry.portionSize;
    final factor = portionSize / 100;
    final calories = double.tryParse(_calorieCtrl.text) ?? 0.0;
    final protein = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final carbs = double.tryParse(_carbCtrl.text) ?? 0.0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0.0;

    final updated = widget.entry.copyWith(
      name: _nameCtrl.text.trim().isEmpty
          ? widget.entry.name
          : _nameCtrl.text.trim(),
      portionSize: portionSize,
      nutritionData: NutritionData(
        calories: factor > 0 ? calories / factor : 0,
        protein: factor > 0 ? protein / factor : 0,
        carbohydrates: factor > 0 ? carbs / factor : 0,
        fat: factor > 0 ? fat / factor : 0,
      ),
    );

    widget.provider.updateFoodEntry(updated);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('Sil')),
        content: Text('${widget.entry.name} silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.tr('İptal'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tr('Sil'),
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      widget.provider.removeFoodEntry(widget.entry.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(l10n.isTurkish ? 'Yiyeceği Düzenle' : 'Edit Food',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            if (widget.entry.imagePath != null) ...[
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      body: Center(
                        child: InteractiveViewer(
                          child: Image.file(
                            File(widget.entry.imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, e, s) => const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.entry.imagePath!),
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, e, s) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.isTurkish ? 'Yiyecek Adı' : 'Food Name',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portionCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish ? 'Porsiyon (g)' : 'Portion (g)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _calorieCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish ? 'Kalori (kcal)' : 'Calories (kcal)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish ? 'Protein (g)' : 'Protein (g)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish ? 'Karb. (g)' : 'Carbs (g)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish ? 'Yağ (g)' : 'Fat (g)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    label: Text(l10n.tr('Sil'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.tr('Kaydet')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Su Tüketimi Kartı ────────────────────────────────────────────────────────

class _WaterCard extends StatefulWidget {
  final NutritionProvider provider;

  const _WaterCard({required this.provider});

  @override
  State<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<_WaterCard> {
  static const double _waterGoalL = 2.5;
  static const double _waterGoalMl = 2500;
  double _lastAddedMl = 250;

  void _addWater(double ml) {
    final currentMl = widget.provider.todayLog.waterIntakeMl;
    final wasUnderGoal = currentMl < _waterGoalMl;
    final newMl = currentMl + ml;
    widget.provider.updateWater(newMl);
    setState(() => _lastAddedMl = ml);

    if (wasUnderGoal && newMl >= _waterGoalMl) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.isTurkish
              ? 'Günlük su hedefinize ulaştınız! 💧'
              : 'You reached your daily water goal! 💧'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeLastWater() {
    final currentMl = widget.provider.todayLog.waterIntakeMl;
    final newMl = (currentMl - _lastAddedMl).clamp(0.0, double.infinity);
    widget.provider.updateWater(newMl);
  }

  void _showWaterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WaterAddSheet(onAdd: _addWater),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final waterMl = widget.provider.todayLog.waterIntakeMl;
    final waterLiters = waterMl / 1000;
    final progress = (waterLiters / _waterGoalL).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.tr('Su Tüketimi'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${waterLiters.toStringAsFixed(1)} / ${_waterGoalL}L',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        onPressed:
                            waterMl > 0 ? _removeLastWater : null,
                        tooltip: l10n.isTurkish ? 'Son eklemeyi geri al' : 'Undo last add',
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: _showWaterSheet,
                        tooltip: l10n.isTurkish ? 'Su ekle' : 'Add water',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (context, animProgress, _) => LinearProgressIndicator(
                value: animProgress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF29B6F6),
                backgroundColor:
                    const Color(0xFF29B6F6).withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Su Ekleme Bottom Sheet ───────────────────────────────────────────────────

class _WaterAddSheet extends StatefulWidget {
  final void Function(double ml) onAdd;

  const _WaterAddSheet({required this.onAdd});

  @override
  State<_WaterAddSheet> createState() => _WaterAddSheetState();
}

class _WaterAddSheetState extends State<_WaterAddSheet> {
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _addAndClose(double ml) {
    Navigator.pop(context);
    widget.onAdd(ml);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTurkish = l10n.isTurkish;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.water_drop, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                isTurkish ? 'Ne kadar içtiniz?' : 'How much did you drink?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ML quick buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [100, 200, 300, 400, 500].map((ml) {
              return GestureDetector(
                onTap: () => _addAndClose(ml.toDouble()),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Center(
                    child: Text(
                      '${ml}ml',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Large icon cards row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _addAndClose(100),
                  child: Card(
                    color: colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
                      child: Column(
                        children: [
                          const Text('🍵', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            isTurkish ? 'Çay bardağı' : 'Tea glass',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            '100ml',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _addAndClose(200),
                  child: Card(
                    color: colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
                      child: Column(
                        children: [
                          const Text('🥛', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            isTurkish ? 'Su bardağı' : 'Water glass',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            '200ml',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.tr('Manuel Gir'),
                    border: const OutlineInputBorder(),
                    suffixText: 'ml',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final ml = double.tryParse(_manualCtrl.text);
                  if (ml != null && ml > 0) _addAndClose(ml);
                },
                child: Text(l10n.tr('Ekle')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

