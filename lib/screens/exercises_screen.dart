import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../l10n/app_localizations.dart';

import '../services/health_service.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen>
    with WidgetsBindingObserver {
  int _steps = 0;
  double _stepCalories = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSyncData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plandan ön plana gelince veriyi yenile
    // (Health Connect izin ekranından döndükten sonra da tetiklenir)
    if (state == AppLifecycleState.resumed) {
      _loadSyncData();
    }
  }

  Future<void> _loadSyncData() async {
    try {
      // Ensure permissions and fetch
      final hasPerms = await HealthService.requestPermissions();
      if (hasPerms) {
        final data = await HealthService.getTodayHealthData();
        if (mounted) {
          setState(() {
            _steps = data.steps;
            _stepCalories = data.totalBurnedCalories;
          });
          // Also sync to provider for other screens
          context.read<NutritionProvider>().updateHealthSyncData(
            steps: data.steps,
            burnedCalories: data.totalBurnedCalories,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading health data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final surface = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    
    final exerciseCalories = provider.totalBurnedCaloriesFromExercises;
    final totalBurned = _stepCalories + exerciseCalories;
    final stepGoal = profileProvider.stepGoal;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(l10n.isTurkish ? 'Egzersizler' : 'Exercises', 
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        centerTitle: false,
        backgroundColor: surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // ── Adımlar Kartı ──
            _Card(
              cardBg: cardBg,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_walk, size: 18, color: Color(0xFF58A6FF)),
                      const SizedBox(width: 8),
                      Text(
                        l10n.isTurkish ? 'ADIMLAR' : 'STEPS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_steps',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ ${stepGoal >= 1000 ? '${(stepGoal / 1000).toStringAsFixed(stepGoal % 1000 == 0 ? 0 : 1)}K' : '$stepGoal'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 60,
                    child: _HourlyStepBars(
                      totalSteps: _steps,
                      stepGoal: stepGoal,
                      cs: cs,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Yakılan Kalori Kartı ──
            _Card(
              cardBg: cardBg,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 18, color: Color(0xFFFF9F0A)),
                      const SizedBox(width: 8),
                      Text(
                        l10n.isTurkish ? 'YAKILAN KALORİ' : 'CALORIES BURNED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalBurned.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (exerciseCalories > 0)
                    _DetailRow(
                      label: l10n.isTurkish ? 'Egzersizlerden' : 'From exercises',
                      value: '${exerciseCalories.toStringAsFixed(0)} kcal',
                      cs: cs,
                    ),
                  if (_stepCalories > 0)
                    _DetailRow(
                      label: l10n.isTurkish ? 'Adımlardan' : 'From steps',
                      value: '${_stepCalories.toStringAsFixed(0)} kcal',
                      cs: cs,
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            // Placeholder for exercise history or similar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Icon(Icons.fitness_center_rounded, size: 48, color: cs.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.isTurkish ? 'Egzersiz Takibi Yakında!' : 'Exercise Tracking Coming Soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.isTurkish 
                      ? 'Yaptığın antrenmanları detaylı analiz etmek için bu bölümü geliştiriyoruz.'
                      : 'We are developing this section to analyze your workouts in detail.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color cardBg;
  final bool isDark;

  const _Card({required this.child, required this.cardBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _DetailRow({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
        ],
      ),
    );
  }
}

// Reuse the bars widget but internal to this file to avoid conflicts
class _HourlyStepBars extends StatelessWidget {
  final int totalSteps;
  final int stepGoal;
  final ColorScheme cs;
  final bool isDark;

  const _HourlyStepBars({
    required this.totalSteps, 
    required this.stepGoal,
    required this.cs,
    required this.isDark,
  });

  static const _weights = [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, // 0–5
    0.3, 0.8, 1.0, 0.9, 0.7, 0.8, // 6–11
    0.6, 0.7, 0.6, 0.7, 0.8, 0.9, // 12–17
    1.0, 0.8, 0.6, 0.4, 0.2, 0.1, // 18–23
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().hour;
    const barColor = Color(0xFF58A6FF);
    final ghostColor = cs.outlineVariant;

    final scale = stepGoal > 0 ? (totalSteps / stepGoal).clamp(0.0, 1.0) : 0.0;

    final bars = List.generate(24, (h) {
      if (h > now) return 0.0;
      return (_weights[h] * scale).clamp(0.0, 1.0);
    });

    const minFraction = 0.08;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final totalW = constraints.maxWidth;
        final totalH = constraints.maxHeight;
        final barW = ((totalW - 23) / 24).clamp(1.0, 20.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(24, (h) {
            final isPast = h <= now;
            final fraction = isPast
                ? (bars[h] < minFraction ? minFraction : bars[h])
                : minFraction * 0.5;
            final barH = (totalH * fraction).clamp(1.0, totalH);

            return Container(
              width: barW,
              height: barH,
              decoration: BoxDecoration(
                color: isPast && bars[h] >= minFraction ? barColor : ghostColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
