import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import '../models/daily_log.dart';
import '../models/wellness_log.dart';
import '../providers/language_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/wellness_provider.dart';
import '../providers/coach_provider.dart';
import '../providers/fasting_provider.dart';
import '../services/device_id_service.dart';
import '../services/health_service.dart';
import '../services/saved_foods_service.dart';
import '../services/sync_service.dart';
import '../services/conflict_detection_service.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/combined_chart.dart';
import '../widgets/wave_background.dart';
import 'fasting_screen.dart'; // To use FastingClockWidget
import 'wc_tracking_screen.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';
import 'manual_entry_screen.dart';

bool isDateEditable(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final compareDate = DateTime(date.year, date.month, date.day);
  
  if (compareDate.isAtSameMomentAs(today)) {
    return true;
  }
  
  final yesterday = today.subtract(const Duration(days: 1));
  if (compareDate.isAtSameMomentAs(yesterday)) {
    if (now.hour < 2 || (now.hour == 2 && now.minute < 30)) {
      return true;
    }
  }
  
  return false;
}

class DashboardScreen extends StatefulWidget {
  final void Function(String meal, String mode, DateTime date)? onMealAddPressed;
  final VoidCallback? onProfileSetupPressed;
  final VoidCallback? onCoachPressed;
  final VoidCallback? onFastingPressed;
  final ValueChanged<DateTime>? onDateChanged;
  final bool isCurrentTab;

  const DashboardScreen({
    super.key,
    this.onMealAddPressed,
    this.onProfileSetupPressed,
    this.onCoachPressed,
    this.onFastingPressed,
    this.onDateChanged,
    this.isCurrentTab = true,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _steps = 0;
  // Not: kalori verisi NutritionProvider üzerinden (updateHealthSyncData) yönetiliyor.
  // _stepCalories ayrı tutulmaz — çift sayım önlemek için.

  Timer? _updateTimer;
  DateTime _selectedDate = DateTime.now();
  bool _lastHealthSyncEnabled = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    // Initialize health sync

    // Set initial state
    final profileProvider = context.read<ProfileProvider>();
    _lastHealthSyncEnabled = profileProvider.healthSyncEnabled;

    // Listen for changes
    profileProvider.addListener(_handleProfileChange);

    _loadSteps();
    _loadDeviceInfo();
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _loadSteps();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateChanged?.call(_selectedDate);
    });
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentTab && !oldWidget.isCurrentTab) {
      setState(() {
        _selectedDate = DateTime.now();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onDateChanged?.call(_selectedDate);
        }
      });
      _loadSteps();
    }
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final uid = await DeviceIdService.instance.ensureFirebaseUser();
      if (mounted) {
        setState(() {
          // Show first 8 characters of the UID as the short device ID
          _deviceId = uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();
        });
      }
    } catch (_) {}
  }

  void _handleProfileChange() {
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.healthSyncEnabled && !_lastHealthSyncEnabled) {
      // User just enabled health sync
      _loadSteps();
    }
    _lastHealthSyncEnabled = profileProvider.healthSyncEnabled;
  }

  @override
  void dispose() {
    context.read<ProfileProvider>().removeListener(_handleProfileChange);
    _updateTimer?.cancel();
    super.dispose();
  }

  void _showPremiumScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _PremiumPlaceholderScreen()),
    );
  }

  void _showStreakSheet(
    BuildContext context,
    NutritionProvider provider,
    ProfileProvider profileProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StreakBottomSheet(
        provider: provider,
        profileProvider: profileProvider,
      ),
    );
  }

  Future<void> _loadSteps() async {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final healthSyncEnabled = context.read<ProfileProvider>().healthSyncEnabled;
    
    if (isToday) {
      if (!healthSyncEnabled) {
        if (mounted) setState(() => _steps = 0);
        return;
      }
      try {
        final hasPerms = await HealthService.hasPermissionsOnly();
        if (!hasPerms) return;

        final data = await HealthService.getTodayHealthData();
        if (!mounted) return;

        setState(() => _steps = data.steps);

        context.read<NutritionProvider>().updateHealthSyncData(
          steps: data.steps,
          burnedCalories: data.totalBurnedCalories,
        );
        
        // Sync to Firebase
        SyncService.instance.syncSteps(DateTime.now(), data.steps);
      } catch (e) {
        debugPrint('[Dashboard] Health error: $e');
      }
    } else {
      // Historical date: Get from Firebase
      try {
        final steps = await SyncService.instance.getStepsForDate(_selectedDate);
        if (mounted) {
          setState(() => _steps = steps ?? 0);
        }
      } catch (e) {
        debugPrint('[Dashboard] Historical steps load error: $e');
        if (mounted) setState(() => _steps = 0);
      }
    }
  }

  void _showWcHistoryFromWater(BuildContext context, WellnessProvider wellness) {
    final provider = context.read<NutritionProvider>();
    final selectedLog = provider.getOrCreateLogForDate(_selectedDate);
    final waterLogs = selectedLog.waterEntries;
    if (waterLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Bugün henüz su girişi yapmadınız'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
        final maxHour = isToday ? DateTime.now().hour : 23;
        final allHours = List.generate(maxHour + 1, (i) => maxHour - i);

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.tr('Su Geçmişi'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  itemCount: allHours.length,
                  itemBuilder: (context, index) {
                    final hour = allHours[index];
                    final entries = waterLogs
                        .where((e) => e.time.hour == hour)
                        .toList();
                    // Sıralama: En yeni giriş en üstte (Newest first)
                    entries.sort((a, b) => b.time.compareTo(a.time));

                    final isCurrentHour = isToday && DateTime.now().hour == hour;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: TextStyle(
                                fontSize: entries.isNotEmpty ? 15 : 12,
                                fontWeight: isCurrentHour
                                    ? FontWeight.w800
                                    : (entries.isNotEmpty ? FontWeight.w600 : FontWeight.w400),
                                color: isCurrentHour
                                    ? cs.primary
                                    : (entries.isNotEmpty ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Divider(
                                color: cs.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                        if (entries.isNotEmpty) const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            children: entries.map((log) {
                              final isOutput = log.amount < 0;
                              final itemColor = isOutput ? Colors.red : Colors.blue;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: itemColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: itemColor.withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: itemColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text('💧', style: TextStyle(fontSize: 20)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${log.amount.toStringAsFixed(0)} ml',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isOutput 
                                                ? (isDark ? Colors.redAccent : Colors.red.shade700)
                                                : (isDark ? Colors.white : Colors.black87),
                                            ),
                                          ),
                                          Text(
                                            '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (entries.isNotEmpty)
                          const SizedBox(height: 6)
                        else
                          const SizedBox(height: 0),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWeightPickerSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wellness = context.read<WellnessProvider>();
    final profile = context.read<ProfileProvider>();
    final lastRecorded = wellness.lastRecordedWeight;
    final profileWeight = profile.weight;
    final current = wellness.thisWeekWeight ?? lastRecorded ?? (profileWeight > 0 ? profileWeight : 70.0);
    double selected = current;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('Bu Haftanın Kilosu'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 48,
                  perspective: 0.003,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: ((selected - 30) * 10).round(),
                  ),
                  onSelectedItemChanged: (i) =>
                      setSheetState(() => selected = 30 + i / 10),
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (_, i) {
                      final v = 30 + i / 10;
                      final isSel = ((v - selected).abs() < 0.05);
                      return Center(
                        child: Text(
                          '${v.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: isSel ? 22 : 16,
                            fontWeight: isSel
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: isSel
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    },
                    childCount: 1201,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    await ctx.read<WellnessProvider>().logWeight(selected);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '${selected.toStringAsFixed(1)} kg ${context.tr('Kaydet')}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Consumer2<NutritionProvider, ProfileProvider>(
      builder: (context, provider, profileProvider, _) {
        final l10n = AppLocalizations.of(context);
        final selectedLog = provider.getOrCreateLogForDate(_selectedDate);
        final nutrition = selectedLog.totalNutrition;
        final nutrition65 = selectedLog.totalNutrition65;
        final calorieGoal = profileProvider.calorieGoal;
        final proteinGoal = profileProvider.proteinGoal;
        final carbGoal = profileProvider.carbGoal;
        final fatGoal = profileProvider.fatGoal;
        final now = DateTime.now();
        final isToday = DateUtils.isSameDay(_selectedDate, now);
        final isPast = _selectedDate.isBefore(DateTime(now.year, now.month, now.day));
        
        final double accumulatedBmr;
        if (isPast) {
          accumulatedBmr = profileProvider.bmr;
        } else if (isToday) {
          // Gün içindeki dakikayı baz alarak daha hassas bir bazal kalori hesabı (gece yarısı 0 olmasını da engeller)
          final minutesPassed = (now.hour * 60 + now.minute).clamp(1, 1440);
          accumulatedBmr = (profileProvider.bmr / 1440) * minutesPassed;
        } else {
          accumulatedBmr = 0;
        }
        
        final exerciseBurned = selectedLog.totalBurnedFromExercises;
        final totalBurned = exerciseBurned + accumulatedBmr;
        final remaining = calorieGoal - nutrition.calories + totalBurned;
        
        final currentStreak = provider.currentStreak(
          calorieGoal: calorieGoal,
          proteinGoal: proteinGoal,
          carbGoal: carbGoal,
          fatGoal: fatGoal,
          waterGoalMl: profileProvider.waterGoalMl.toDouble(),
          stepGoal: profileProvider.stepGoal,
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface2 = isDark
            ? const Color(0xFF21262D)
            : const Color(0xFFE5E5EA);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  'LensEat',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                ),
                if (profileProvider.isPremium)
                  const Positioned(
                    top: -4,
                    right: -10,
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: Color(0xFFFFD700), // Gold
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
              ],
            ),
            centerTitle: false,
            actions: [

              
              // Streak UI (Suspended for now)
              if (false)
              GestureDetector(
                onTap: () => _showStreakSheet(context, provider, profileProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFA000).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFA000), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$currentStreak',
                        style: const TextStyle(
                          color: Color(0xFFFFA000),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (false)
              const SizedBox(width: 8),
              // Premium butonu
              if (!profileProvider.isPremium)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaywallScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD700), // Gold
                        Color(0xFFFFA000), // Amber
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.isTurkish ? 'PREMIUM' : 'PREMIUM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          body: WaveBackground(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CalendarStrip(
                  selectedDate: _selectedDate,
                  onDateSelected: (date) {
                    setState(() => _selectedDate = date);
                    widget.onDateChanged?.call(date);
                    _loadSteps(); // Refresh steps for selected date
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                  if (context.watch<FastingProvider>().isFasting)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Builder(
                        builder: (ctx) {
                          final fasting = ctx.watch<FastingProvider>();
                          final now = DateTime.now();
                          final session = fasting.activeSession!;
                          final goalHours = session.fastingHours;
                          final fastStart = session.startTime;
                          final fastEnd = fastStart.add(Duration(hours: goalHours));
                          final primary = Theme.of(ctx).colorScheme.primary;
                          final isDark = Theme.of(ctx).brightness == Brightness.dark;
                          final trackColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE8EAED);

                          return GestureDetector(
                            onTap: () => widget.onFastingPressed?.call(),
                            child: FadeInSlide(
                              delay: const Duration(milliseconds: 0),
                              child: FastingClockWidget(
                                now: now,
                                fastStart: fastStart,
                                fastEnd: fastEnd,
                                goalHours: goalHours,
                                isActive: true,
                                elapsed: session.elapsed,
                                primaryColor: primary,
                                trackColor: trackColor,
                                compact: true,
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  if (context.watch<FastingProvider>().isFasting)
                    const SizedBox(height: 12),
                  FadeInSlide(
                    delay: const Duration(milliseconds: 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 400, // Reduced from 480 to make it more compact
                        child: _DashboardPage1(
                          remaining: remaining,
                          calorieGoal: calorieGoal,
                          nutrition: nutrition,
                          proteinGoal: proteinGoal,
                          carbGoal: carbGoal,
                          fatGoal: fatGoal,
                          fiberGoal:
                              profileProvider.activeProfile?.fiberGoal ?? 25,
                          waterGoal: profileProvider.waterGoalMl.toDouble(),
                          waterConsumed: selectedLog.waterIntakeMl,
                          totalBurned: totalBurned,
                          steps: _steps,
                          stepGoal: profileProvider.stepGoal,
                          isAnalyzing: provider.isAnalyzing,
                          streak: provider.currentStreak(
                            calorieGoal: profileProvider.calorieGoal,
                            proteinGoal: profileProvider.proteinGoal,
                            carbGoal: profileProvider.carbGoal,
                            fatGoal: profileProvider.fatGoal,
                            waterGoalMl: profileProvider.waterGoalMl.toDouble(),
                            stepGoal: profileProvider.stepGoal,
                          ),
                          onStreakTap: () => _showStreakSheet(
                            context,
                            provider,
                            profileProvider,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Kilo girişi hatırlatıcısı
                  Builder(
                    builder: (_) {
                      final wellness = context.watch<WellnessProvider>();
                      if (wellness.weightEnteredThisWeek) return const SizedBox.shrink();
                      // Only show on the first day of the current week AND if we are looking at today
                      final now = DateTime.now();
                      if (!DateUtils.isSameDay(_selectedDate, now)) return const SizedBox.shrink();
                      
                      final weekStartDay = context.read<ProfileProvider>().weekStartDay;
                      final diff = (now.weekday - weekStartDay + 7) % 7;
                      final isFirstDayOfWeek = diff == 0;
                      if (!isFirstDayOfWeek) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: GestureDetector(
                          onTap: () => _showWeightPickerSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFCC00,
                              ).withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFFFCC00,
                                ).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '⚖️',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr('Bu haftalık kilo kaydınızı henüz yapmadınız. Eklemek için dokunun.'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFFFE066)
                                          : const Color(0xFF8B6800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Uyarı kartları — mikro besinlerin üstünde
                  Builder(
                    builder: (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildConflictCards(context, provider, profileProvider, selectedLog),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeInSlide(
                      delay: const Duration(milliseconds: 80),
                      child: _NutrientLandscapeCard(
                        nutrition65: nutrition65,
                        nutrition: nutrition,
                        profileProvider: profileProvider,
                        onShowAll: () {
                          final card = _NutrientLandscapeCard(
                            nutrition65: nutrition65,
                            nutrition: nutrition,
                            profileProvider: profileProvider,
                            onShowAll: () {},
                          );
                          final score = card._calcScore();
                          final scoreColor = score >= 75
                              ? const Color(0xFF7EE787)
                              : score >= 50
                              ? const Color(0xFFF0A500)
                              : const Color(0xFFF85149);
                          _showNutritionScoreDetail(
                            context,
                            score,
                            scoreColor,
                            l10n,
                            nutrition,
                            nutrition65,
                            profileProvider,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeInSlide(
                      delay: const Duration(milliseconds: 320),
                      child: GestureDetector(
                        onTap: () {
                          final wellness = context.read<WellnessProvider>();
                          _showWcHistoryFromWater(context, wellness);
                        },
                        child: _WaterSummaryCard(
                        consumed: selectedLog.waterIntakeMl,
                        goal: profileProvider.waterGoalMl,
                        isReadOnly: !isDateEditable(_selectedDate),
                        onAdd: (ml) => provider.updateWater(
                          selectedLog.waterIntakeMl + ml,
                          deltaAmount: ml,
                        ),
                        onAddTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) => _WaterAddSheet(
                              onAdd: (ml) async {
                                provider.updateWater(
                                  selectedLog.waterIntakeMl + ml,
                                  deltaAmount: ml,
                                );
                                setState(() {});
                              },
                              isRemove: false,
                            ),
                          );
                        },
                        onRemoveTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) => _WaterAddSheet(
                              onAdd: (ml) async {
                                provider.updateWater(
                                  (selectedLog.waterIntakeMl - ml).clamp(
                                    0.0,
                                    double.infinity,
                                  ),
                                  deltaAmount: -ml,
                                );
                                setState(() {});
                              },
                              isRemove: true,
                              currentWaterMl: selectedLog.waterIntakeMl,
                            ),
                          );
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeInSlide(
                      delay: const Duration(milliseconds: 340),
                      child: CombinedChartCard(provider: provider, referenceDate: _selectedDate),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeInSlide(
                      delay: const Duration(milliseconds: 420),
                      child: _WellnessSection(selectedDate: _selectedDate),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeInSlide(
                      delay: const Duration(milliseconds: 460),
                      child: _buildMealSections(context, provider, l10n, selectedLog, isDateEditable(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 160),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
        );
      },
    );
  }

  Widget _buildProfileWarning(BuildContext context, AppLocalizations l10n) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onProfileSetupPressed?.call(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.person_add_outlined,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
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
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMealDetail(
    BuildContext context,
    String meal,
    String mealName,
    List<FoodEntry> entries,
    AppLocalizations l10n,
    DateTime selectedDate,
  ) {
    final now = selectedDate;
    const trMonths = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final monthName = l10n.tr(trMonths[now.month - 1]);
    final dateStr = '${now.day} $monthName';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Consumer<NutritionProvider>(
          builder: (ctx, provider, _) {
            // Always read fresh entries from provider
            final liveEntries = provider
                .getOrCreateLogForDate(selectedDate)
                .entriesByMeal[meal] ?? [];

            final reversedEntries = liveEntries.reversed.toList();
            final rows = <List<FoodEntry>>[];
            for (int i = 0; i < reversedEntries.length; i += 2) {
              rows.add(reversedEntries.sublist(i, math.min(i + 2, reversedEntries.length)));
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollCtrl) => Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          Text(
                            '$mealName — $dateStr',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: liveEntries.isEmpty
                          ? Center(
                              child: Text(
                                l10n.tr('Bu öğünde henüz yemek yok'),
                              ),
                            )
                          : ListView(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              children: [
                                ...rows.map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _DashboardFoodCard(
                                            entry: row[0],
                                            selectedDate: selectedDate,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        row.length > 1
                                            ? Expanded(
                                                child: _DashboardFoodCard(
                                                  entry: row[1],
                                                  selectedDate: selectedDate,
                                                ),
                                              )
                                            : const Expanded(
                                                child: SizedBox.shrink(),
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 100),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMealSections(
    BuildContext context,
    NutritionProvider provider,
    AppLocalizations l10n,
    DailyLog selectedLog,
    bool isToday,
  ) {
    final meals = selectedLog.entriesByMeal;
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
    final cs = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              l10n.tr('Öğünler'),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          ...mealOrder.asMap().entries.map((entry) {
            final idx = entry.key;
            final meal = entry.value;
            final entries = meals[meal] ?? [];
            final mealName = mealNames[meal] ?? meal;
            final totalCal = entries.fold<double>(
              0,
              (sum, e) =>
                  sum + e.nutritionData.scaleBy(e.portionSize / 100).calories,
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: idx == mealOrder.length - 1 ? 0 : 10,
              ),
              child: _MealSection(
                meal: meal,
                mealName: mealName,
                mealIcon: mealIcons[meal] ?? Icons.restaurant,
                entries: entries,
                totalCal: totalCal,
                cs: cs,
                l10n: l10n,
                isToday: isDateEditable(_selectedDate),
                onAddPressed: (mode) => widget.onMealAddPressed?.call(meal, mode, _selectedDate),
                onTap: () =>
                    _showMealDetail(context, meal, mealName, entries, l10n, _selectedDate),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConflictCards(
    BuildContext context,
    NutritionProvider provider,
    ProfileProvider pp,
    DailyLog log,
  ) {
    final isTurkish = context.read<LanguageProvider>().isTurkish;
    final now = DateTime.now();
    final isToday = log.date.year == now.year && log.date.month == now.month && log.date.day == now.day;
    if (!isToday) return const SizedBox.shrink();
    
    final conflicts = provider.getConflicts(pp.activeProfile, log: log, isTurkish: isTurkish);
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const redBg = Color(0xFFFF3B30);
    return Column(
      children: [
        ...conflicts.map((c) {
          return GestureDetector(
            onTap: () {
              final prompt = _getPromptForConflict(c, isTurkish);
              context.read<CoachProvider>().setPrefilledMessage(prompt);
              widget.onCoachPressed?.call();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: redBg.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: redBg.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Text(c.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFFCC2200),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.7)
                        : const Color(0xFFCC2200).withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  String _getPromptForConflict(NutritionConflict c, bool isTurkish) {
    if (isTurkish) {
      if (c.icon == '🌾' || c.message.contains('Lif')) {
        return 'Lif alımımı artırmak için bana nasıl bir beslenme önerirsin?';
      }
      if (c.icon == '💪' || c.message.contains('Protein')) {
        return 'Günlük protein ihtiyacımı karşılamak için pratik ve sağlıklı hangi gıdaları eklemeliyim?';
      }
      if (c.icon == '☀️' || c.message.contains('D vitamini')) {
        return 'D vitamini eksikliğimi gidermek için neler yapabilirim? Beslenme veya yaşam tarzı önerilerin nelerdir?';
      }
      if (c.icon == '🩸' || c.message.contains('Demir')) {
        return 'Demir alımımı artırmak ve vücudumdaki demir emilimini desteklemek için ne tür besinler tüketmeliyim?';
      }
      if (c.icon == '🦷' || c.message.contains('Kalsiyum')) {
        return 'Kalsiyum alımımı doğal yollarla artırmak için beslenmeme neler ekleyebilirim?';
      }
      if (c.icon == '🌿' || c.message.contains('Magnezyum')) {
        return 'Magnezyum eksikliğimi gidermek için hangi sağlıklı besinleri tüketmemi önerirsin?';
      }
      if (c.icon == '⚡' || c.message.contains('Çinko')) {
        return 'Çinko alımımı desteklemek için beslenme düzenime hangi gıdaları eklemeliyim?';
      }
      if (c.icon == '🍌' || c.message.contains('Potasyum')) {
        return 'Potasyum alımımı artırmak için bana hangi potasyum zengini besinleri önerirsin?';
      }
      if (c.icon == '💊' || c.message.contains('B12')) {
        return 'B12 vitamini alımımı artırmak için hangi gıdaları tüketmeliyim?';
      }
      if (c.icon == '🐟' || c.message.contains('Omega-3')) {
        return 'Omega-3 alımımı artırmak için ceviz, keten tohumu veya balık dışında neler tüketebilirim?';
      }
      return 'Bugün aldığım şu uyarı hakkında beslenme önerileri alabilir miyim: "${c.message}"';
    } else {
      if (c.icon == '🌾' || c.message.toLowerCase().contains('fiber')) {
        return 'How can I increase my fiber intake? What do you recommend?';
      }
      if (c.icon == '💪' || c.message.toLowerCase().contains('protein')) {
        return 'What are some practical and healthy foods to help me meet my daily protein needs?';
      }
      if (c.icon == '☀️' || c.message.toLowerCase().contains('vitamin d')) {
        return 'What can I do to improve my Vitamin D levels? What are your diet or lifestyle suggestions?';
      }
      if (c.icon == '🩸' || c.message.toLowerCase().contains('iron')) {
        return 'What foods should I eat to boost my iron intake and improve absorption?';
      }
      if (c.icon == '🦷' || c.message.toLowerCase().contains('calcium')) {
        return 'What can I add to my diet to naturally increase my calcium intake?';
      }
      if (c.icon == '🌿' || c.message.toLowerCase().contains('magnesium')) {
        return 'What healthy foods do you recommend to boost my magnesium levels?';
      }
      if (c.icon == '⚡' || c.message.toLowerCase().contains('zinc')) {
        return 'Which foods should I include in my diet to support my zinc intake?';
      }
      if (c.icon == '🍌' || c.message.toLowerCase().contains('potassium')) {
        return 'What potassium-rich foods do you suggest to increase my intake?';
      }
      if (c.icon == '💊' || c.message.toLowerCase().contains('b12')) {
        return 'What foods should I consume to increase my Vitamin B12 intake?';
      }
      if (c.icon == '🐟' || c.message.toLowerCase().contains('omega-3')) {
        return 'Besides fish and walnuts, what can I consume to boost my omega-3 intake?';
      }
      return 'Can you give me nutrition advice regarding this warning: "${c.message}"';
    }
  }
}

// ─── Meal Section Widget (Restored Summary Style) ───────────────────────────────

class _MealSection extends StatefulWidget {
  final String meal;
  final String mealName;
  final IconData mealIcon;
  final List<FoodEntry> entries;
  final double totalCal;
  final ColorScheme cs;
  final AppLocalizations l10n;
  final Function(String mode) onAddPressed;
  final VoidCallback onTap;
  final bool isToday;

  const _MealSection({
    required this.meal,
    required this.mealName,
    required this.mealIcon,
    required this.entries,
    required this.totalCal,
    required this.cs,
    required this.l10n,
    required this.onAddPressed,
    required this.onTap,
    required this.isToday,
  });

  @override
  State<_MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<_MealSection> {
  bool _isExpanded = false;
  Timer? _collapseTimer;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    _collapseTimer?.cancel();
    if (_isExpanded) {
      _collapseTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isExpanded) {
          setState(() {
            _isExpanded = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmpty = widget.entries.isEmpty;

    FoodEntry? photoEntry;
    for (final e in widget.entries.reversed) {
      final hasLocal = e.imagePath != null &&
          e.imagePath!.isNotEmpty &&
          File(e.imagePath!).existsSync();
      final hasRemote = e.imageUrl != null && e.imageUrl!.isNotEmpty;
      if (hasLocal || hasRemote) {
        photoEntry = e;
        break;
      }
    }

    final itemBg = isDark
        ? const Color(0xFF21262D).withValues(alpha: 0.6)
        : const Color(0xFFF6F8FA);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: photoEntry != null
                      ? (photoEntry.imagePath != null &&
                              photoEntry.imagePath!.isNotEmpty &&
                              File(photoEntry.imagePath!).existsSync()
                          ? Image.file(File(photoEntry.imagePath!),
                              fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: photoEntry.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _MealPlaceholder(
                                icon: widget.mealIcon,
                                isDark: isDark,
                                isEmpty: isEmpty,
                              ),
                            ))
                      : _MealPlaceholder(
                          icon: widget.mealIcon,
                          isDark: isDark,
                          isEmpty: isEmpty,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _isExpanded
                      ? SingleChildScrollView(
                          key: const ValueKey('actions'),
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionCircle(
                                icon: Icons.qr_code_scanner_rounded,
                                color: Colors.orange,
                                onTap: () => widget.onAddPressed('barcode'),
                                delay: 0,
                              ),
                              const SizedBox(width: 7),
                              _buildActionCircle(
                                icon: Icons.edit_note_rounded,
                                color: Colors.green,
                                onTap: () async {
                                  widget.onAddPressed('manual');
                                  setState(() {});
                                },
                                delay: 50,
                              ),
                              const SizedBox(width: 7),
                              _buildActionCircle(
                                icon: Icons.mic_rounded,
                                color: Colors.purple,
                                onTap: () => widget.onAddPressed('voice'),
                                delay: 100,
                              ),
                              const SizedBox(width: 7),
                              _buildActionCircle(
                                icon: Icons.camera_alt_rounded,
                                color: Colors.blue,
                                onTap: () => widget.onAddPressed('camera'),
                                delay: 150,
                              ),
                              const SizedBox(width: 7),
                            ],
                          ),
                        )
                      : Column(
                          key: const ValueKey('info'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.mealName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: widget.cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (widget.totalCal > 0)
                              Text(
                                '${widget.totalCal.toStringAsFixed(0)} kcal',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: widget.cs.primary,
                                ),
                              )
                            else
                              Text(
                                context.tr('Henüz eklenmedi'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.cs.onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              if (widget.isToday)
                GestureDetector(
                  onTap: _toggleExpanded,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isExpanded ? 0.125 : 0.0,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isExpanded ? Colors.grey : widget.cs.primary)
                            .withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: _isExpanded ? Colors.grey : widget.cs.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(
            scale: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          onTap();
          setState(() => _isExpanded = false);
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _MealPlaceholder extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool isEmpty;
  const _MealPlaceholder({
    required this.icon,
    required this.isDark,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 26,
          color: isEmpty
              ? cs.onSurface.withValues(alpha: 0.25)
              : cs.primary,
        ),
      ),
    );
  }
}

// ─── Dashboard PageView Page 1 ────────────────────────────────────────────────

class _DashboardPage1 extends StatefulWidget {
  final double remaining;
  final double calorieGoal;
  final NutritionData nutrition;
  final double proteinGoal;
  final double carbGoal;
  final double fatGoal;
  final double fiberGoal;
  final double waterGoal;
  final double waterConsumed;
  final double totalBurned;
  final int steps;
  final int stepGoal;
  final int streak;
  final VoidCallback? onStreakTap;
  final bool isAnalyzing;

  const _DashboardPage1({
    required this.remaining,
    required this.calorieGoal,
    required this.nutrition,
    required this.proteinGoal,
    required this.carbGoal,
    required this.fatGoal,
    required this.fiberGoal,
    required this.waterGoal,
    required this.waterConsumed,
    required this.totalBurned,
    this.steps = 0,
    this.stepGoal = 10000,
    this.streak = 0,
    this.onStreakTap,
    this.isAnalyzing = false,
  });

  @override
  State<_DashboardPage1> createState() => _DashboardPage1State();
}

class _DashboardPage1State extends State<_DashboardPage1> {
  @override
  Widget build(BuildContext context) {
    final remaining = widget.remaining.clamp(0.0, double.infinity);
    final calorieRatio = widget.calorieGoal > 0
        ? (widget.nutrition.calories / widget.calorieGoal)
        : 0.0;
    final hasCalorieLap = calorieRatio >= 1.0;
    final calorieDisplayPct = calorieRatio >= 1.0 ? calorieRatio % 1.0 : calorieRatio;

    final proteinPct = widget.proteinGoal > 0
        ? (widget.nutrition.protein / widget.proteinGoal).clamp(0.0, 1.0)
        : 0.0;
    final carbPct = widget.carbGoal > 0
        ? (widget.nutrition.carbohydrates / widget.carbGoal).clamp(0.0, 1.0)
        : 0.0;
    final fatPct = widget.fatGoal > 0
        ? (widget.nutrition.fat / widget.fatGoal).clamp(0.0, 1.0)
        : 0.0;
    final fiberPct = widget.fiberGoal > 0
        ? (widget.nutrition.fiber / widget.fiberGoal).clamp(0.0, 1.0)
        : 0.0;
    final waterPct = widget.waterGoal > 0
        ? (widget.waterConsumed / widget.waterGoal).clamp(0.0, 1.0)
        : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFE6EDF3)
        : const Color(0xFF1F2328);
    final textSub = isDark ? const Color(0xFF8B949E) : const Color(0xFF656D76);
    final barBg = isDark ? const Color(0xFF30363D) : const Color(0xFFEEEEEE);

    // Kalan kaloriyi binlik virgüllü formatla
    final remainingStr = remaining
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

    // Burned progress relative to calorie goal (matching the intake ring's scale)
    final burnedProgress = widget.calorieGoal > 0
        ? widget.totalBurned / widget.calorieGoal
        : 0.0;
    final burnedDisplayPct = burnedProgress % 1.0;
    final hasBurnedLap = burnedProgress >= 1.0;

    // ── Ring centre content ────────────────────────────────────────────────
    final ringCenter = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          remainingStr,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            height: 1.0,
            letterSpacing: -1.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('KALAN KCAL'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textSub,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    return Builder(
      builder: (ctx) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.09),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                children: [
                  Expanded(
                    flex: 55,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Row(
                        children: [
                          // Alınan (Left)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.nutrition.calories.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      context.tr('ALINAN'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7EE787),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Circle (Center)
                          SizedBox(
                            width: 155,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Intake Ring (Outer-most)
                                    SizedBox.expand(
                                      child: Stack(
                                        children: [
                                          if (hasCalorieLap)
                                            SizedBox.expand(
                                              child: CircularProgressIndicator(
                                                value: 1.0,
                                                strokeWidth: 14,
                                                backgroundColor: Colors.transparent,
                                                valueColor: AlwaysStoppedAnimation(
                                                  const Color(0xFF2ECC71).withValues(alpha: 0.25),
                                                ),
                                                strokeCap: StrokeCap.round,
                                              ),
                                            ),
                                          SizedBox.expand(
                                            child: TweenAnimationBuilder<double>(
                                              tween: Tween<double>(begin: 0, end: calorieDisplayPct),
                                              duration: const Duration(milliseconds: 1000),
                                              curve: Curves.easeOutCubic,
                                              builder: (context, value, _) => CircularProgressIndicator(
                                                value: value,
                                                strokeWidth: 14,
                                                backgroundColor: hasCalorieLap ? Colors.transparent : barBg,
                                                valueColor: const AlwaysStoppedAnimation(
                                                  Color(0xFF2ECC71), // Green
                                                ),
                                                strokeCap: StrokeCap.round,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Burned Ring (Middle)
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: SizedBox.expand(
                                        child: Stack(
                                          children: [
                                            // Completed Laps Background (Faded)
                                            if (hasBurnedLap)
                                              SizedBox.expand(
                                                child: CircularProgressIndicator(
                                                  value: 1.0,
                                                  strokeWidth: 10,
                                                  backgroundColor: Colors.transparent,
                                                  valueColor: AlwaysStoppedAnimation(
                                                    const Color(0xFFFFA726).withValues(alpha: 0.25),
                                                  ),
                                                  strokeCap: StrokeCap.round,
                                                ),
                                              ),
                                            // Current Lap Progress
                                            SizedBox.expand(
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0, end: burnedDisplayPct),
                                                duration: const Duration(milliseconds: 1100),
                                                curve: Curves.easeOutCubic,
                                                builder: (context, value, _) => CircularProgressIndicator(
                                                  value: value,
                                                  strokeWidth: 10,
                                                  backgroundColor: hasBurnedLap ? Colors.transparent : barBg,
                                                  valueColor: const AlwaysStoppedAnimation(
                                                    Color(0xFFFFA726), // Orange
                                                  ),
                                                  strokeCap: StrokeCap.round,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    ringCenter,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Yakılan (Right)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.totalBurned.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      context.tr('Yakılan').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFFFA726), // Changed to orange/burned color
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Makro Barlar ───────────────────────────────────
                  Expanded(
                    flex: 45,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MacroBar(
                          label: context.tr('Protein').toUpperCase(),
                          consumed: widget.nutrition.protein,
                          goal: widget.proteinGoal,
                          pct: proteinPct,
                          color: const Color(0xFF7EE787),
                          textPrimary: textPrimary,
                          textSub: textSub,
                          barBg: barBg,
                        ),
                        _MacroBar(
                          label: context.tr('Karbonhidrat').toUpperCase(),
                          consumed: widget.nutrition.carbohydrates,
                          goal: widget.carbGoal,
                          pct: carbPct,
                          color: const Color(0xFF58A6FF),
                          textPrimary: textPrimary,
                          textSub: textSub,
                          barBg: barBg,
                        ),
                        _MacroBar(
                          label: context.tr('Yağ').toUpperCase(),
                          consumed: widget.nutrition.fat,
                          goal: widget.fatGoal,
                          pct: fatPct,
                          color: const Color(0xFFFFA726),
                          textPrimary: textPrimary,
                          textSub: textSub,
                          barBg: barBg,
                        ),
                        _MacroBar(
                          label: context.tr('Lif').toUpperCase(),
                          consumed: widget.nutrition.fiber,
                          goal: widget.fiberGoal,
                          pct: fiberPct,
                          color: const Color(0xFFBC8CF2),
                          textPrimary: textPrimary,
                          textSub: textSub,
                          barBg: barBg,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Streak overlay top-left ──────────────────────────────
            if (false)
              Positioned(
                top: 12,
                left: 16,
                child: GestureDetector(
                  onTap: widget.onStreakTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF21262D)
                          : const Color(0xFFF0F6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 13,
                          color: Color(0xFFFF9F0A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.streak}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'gün',
                          style: TextStyle(fontSize: 11, color: textSub),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Makro Bar (yeni tasarım) ─────────────────────────────────────────────────

class _MacroBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double goal;
  final double pct;
  final Color color;
  final String unit;
  final Color textPrimary;
  final Color textSub;
  final Color barBg;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.pct,
    required this.color,
    this.unit = 'g',
    required this.textPrimary,
    required this.textSub,
    required this.barBg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textSub,
                letterSpacing: 0.6,
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${consumed.toStringAsFixed(0)}$unit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${goal.toStringAsFixed(0)}$unit',
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: pct),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              backgroundColor: barBg,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 9,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Nutrient Landscape Card ─────────────────────────────────────────────────

class _NutrientLandscapeCard extends StatefulWidget {
  final NutritionData65? nutrition65;
  final ProfileProvider profileProvider;
  final NutritionData nutrition;
  final VoidCallback onShowAll;

  const _NutrientLandscapeCard({
    super.key,
    required this.nutrition65,
    required this.profileProvider,
    required this.nutrition,
    required this.onShowAll,
  });

  double _calcScore() {
    final pp = profileProvider;
    final profile = pp.activeProfile;
    if (profile == null || pp.calorieGoal <= 0) return 0;
    if (nutrition.calories <= 0) return 0;
    final n = nutrition;
    final n65 = nutrition65;

    double s(double? c, double? c65, double g) {
      final val = (c != null && c > 0) ? c : (c65 ?? 0.0);
      return g <= 0 ? 100 : (val / g).clamp(0.0, 1.0) * 100;
    }
    double si(double? c, double? c65, double l) {
      final val = (c != null && c > 0) ? c : (c65 ?? 0.0);
      return l <= 0 ? 0 : (val / l).clamp(0.0, 1.0) * 100;
    }
    double avg(List<double> list) =>
        list.isEmpty ? 50 : list.reduce((a, b) => a + b) / list.length;

    // 1. Vitaminler (%30)
    final vitScore = avg([
      s(n.vitaminC, n65?.vitC, 90.0),
      s(n.vitaminD, n65?.vitD_mcg, profile.vitaminDGoal),
      s(n.vitaminB12, n65?.vitB12, profile.vitaminB12Goal),
      s(n.vitaminA, n65?.vitA_RAE, 900.0),
      s(n.folate, n65?.folate, 400.0),
      s(n.vitaminE, n65?.vitE, 15.0),
      s(n.vitaminK, n65?.vitK, 120.0),
      s(n.thiamine, n65?.thiamine, 1.2),
      s(n.riboflavin, n65?.riboflavin, 1.3),
      s(n.niacin, n65?.niacin, 16.0),
      s(n.vitaminB6, n65?.vitB6, 1.7),
      s(n.pantothenic, n65?.pantothenic, 5.0),
      s(n.biotin, n65?.biotin, 30.0),
      s(n.choline, n65?.choline, 550.0),
    ]);

    // 2. Mineraller (%30)
    final minScore = avg([
      s(n.iron, n65?.iron, profile.ironGoal),
      s(n.calcium, n65?.calcium, profile.calciumGoal),
      s(n.magnesium, n65?.magnesium, profile.magnesiumGoal),
      s(n.zinc, n65?.zinc, profile.zincGoal),
      s(n.potassium, n65?.potassium, profile.potassiumGoal),
      si(n.sodium, n65?.sodium, profile.sodiumLimit),
      s(n.selenium, n65?.selenium, profile.seleniumGoal),
      s(n.copper, n65?.copper, 0.9),
      s(n.manganese, n65?.manganese, 2.3),
      s(n.phosphorus, n65?.phosphorus, 700.0),
      s(null, n65?.iodine, 150.0),
      s(null, n65?.molybdenum, 45.0),
      s(null, n65?.chromium, 35.0),
    ]);

    // 3. Sağlıklı Yağlar & Amino Asitler (%25)
    final essentialScore = avg([
      s(n.omega3, n65?.omega3, 1.6),
      s(n.omega6, n65?.omega6, 17.0),
      s(n.tryptophan, n65?.tryptophan, 0.28),
      s(n.leucine, n65?.leucine, 2.73),
      s(n.lysine, n65?.lysine, 2.1),
      s(n.valine, n65?.valine, 1.82),
    ]);

    // 4. Antioksidanlar & Karotenoidler (%15)
    final antioxidantScore = avg([
      s(null, n65?.betaCarot, 3000.0), // ~3000mcg est.
      s(null, n65?.lycopene, 10000.0),    // ~10mg est.
      s(null, n65?.luteinZea, 6000.0),
      s(null, n65?.betaCrypt, 200.0),
    ]);

    return (vitScore * 0.30 +
            minScore * 0.30 +
            essentialScore * 0.25 +
            antioxidantScore * 0.15)
        .clamp(0.0, 100.0);
  }

  @override
  State<_NutrientLandscapeCard> createState() => _NutrientLandscapeCardState();
}

class _NutrientLandscapeCardState extends State<_NutrientLandscapeCard> {
  String _getScoreStatus(BuildContext context, double score) {
    if (score >= 90) return context.tr('Kusursuz');
    if (score >= 70) return context.tr('Çok İyi');
    if (score >= 40) return context.tr('Orta');
    return context.tr('Geliştirilmeli');
  }

  void _showScoreExplanation(
    BuildContext context,
    double score,
    Color scoreColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Skor: ${score.toInt()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Mikro Besin Skoru Nasıl Hesaplanır?'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Bu skor, tükettiğiniz mikro besinlerin (vitaminler, mineraller, yağ asitleri ve amino asitler) günlük hedeflerinize oranına göre hesaplanır. Makro besinler bu skora dahil edilmez.'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 12),
              _scoreRow(
                '🍊',
                context.tr('Vitamin Dengesi'),
                context.tr('Temel vitaminlerin (A, C, D, E, K, B grubu) ortalaması (%30)'),
              ),
              _scoreRow(
                '🧂',
                context.tr('Mineral Dengesi'),
                context.tr('Kalsiyum, demir, magnezyum, iyot, krom vb. mineraller (%30)'),
              ),
              _scoreRow(
                '🧬',
                context.tr('Esansiyel Besinler'),
                context.tr('Omega-3, Omega-6 ve temel amino asitlerin karşılanma oranı (%25)'),
              ),
              _scoreRow(
                '🥕',
                context.tr('Karotenoidler & Antioksidanlar'),
                context.tr('Likopen, Beta-karoten, Lutein gibi koruyucu bileşenler (%15)'),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    children: [
                      _scoreBadge('90+', const Color(0xFF7EE787), context.tr('Kusursuz')),
                      const SizedBox(width: 8),
                      _scoreBadge('70-89', const Color(0xFF3FB950), context.tr('Çok İyi')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _scoreBadge('40-69', const Color(0xFFF0A500), context.tr('Orta')),
                      const SizedBox(width: 8),
                      _scoreBadge('0-39', const Color(0xFFF85149), context.tr('Geliştir.')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRow(String emoji, String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _scoreBadge(String label, Color color, String text) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final sectionBg = isDark
        ? const Color(0xFF21262D)
        : const Color(0xFFF6F8FA);
    final n65 = widget.nutrition65;
    final profile = widget.profileProvider.activeProfile;
    final score = widget._calcScore();

    final scoreColor = score >= 75
        ? const Color(0xFF7EE787)
        : score >= 50
        ? const Color(0xFFF0A500)
        : const Color(0xFFF85149);

    // Vitaminler grubu
    final vitamins = <_LandscapeItem>[];
    // Mineraller grubu
    final minerals = <_LandscapeItem>[];

    const vitaminColor = Color(0xFFFF9F0A); // amber — tüm vitaminler
    const mineralColor = Color(0xFF26D0CE); // teal — tüm mineraller

    final n = widget.nutrition;
    final showPct = widget.profileProvider.showMicroPercentage;
    vitamins.addAll([
      _LandscapeItem('C Vitamini', n.vitaminC ?? n65?.vitC ?? 0, 90.0, 'mg', vitaminColor, showAsPercentage: showPct),
      _LandscapeItem('D Vitamini', n.vitaminD ?? n65?.vitD_mcg ?? 0, profile?.vitaminDGoal ?? 15.0, 'µg', vitaminColor, showAsPercentage: showPct),
      _LandscapeItem('B12 Vitamini', n.vitaminB12 ?? n65?.vitB12 ?? 0, profile?.vitaminB12Goal ?? 2.4, 'µg', vitaminColor, showAsPercentage: showPct),
      _LandscapeItem('A Vitamini', n.vitaminA ?? n65?.vitA_RAE ?? 0, 900.0, 'µg', vitaminColor, showAsPercentage: showPct),
      _LandscapeItem('K Vitamini', n.vitaminK ?? n65?.vitK ?? 0, 120.0, 'µg', vitaminColor, showAsPercentage: showPct),
      _LandscapeItem('E Vitamini', n.vitaminE ?? n65?.vitE ?? 0, 15.0, 'mg', vitaminColor, showAsPercentage: showPct),
    ]);

    minerals.addAll([
      _LandscapeItem('Demir', n.iron ?? n65?.iron ?? 0, profile?.ironGoal ?? 14.0, 'mg', mineralColor, showAsPercentage: showPct),
      _LandscapeItem('Kalsiyum', n.calcium ?? n65?.calcium ?? 0, profile?.calciumGoal ?? 1000.0, 'mg', mineralColor, showAsPercentage: showPct),
      _LandscapeItem('Potasyum', n.potassium ?? n65?.potassium ?? 0, profile?.potassiumGoal ?? 4700.0, 'mg', mineralColor, showAsPercentage: showPct),
      _LandscapeItem('Magnezyum', n.magnesium ?? n65?.magnesium ?? 0, profile?.magnesiumGoal ?? 350.0, 'mg', mineralColor, showAsPercentage: showPct),
      _LandscapeItem('Çinko', n.zinc ?? n65?.zinc ?? 0, profile?.zincGoal ?? 10.0, 'mg', mineralColor, showAsPercentage: showPct),
      _LandscapeItem('Sodyum', n.sodium ?? n65?.sodium ?? 0, profile?.sodiumLimit ?? 2300.0, 'mg', mineralColor, showAsPercentage: showPct),
    ]);

    // Yağ asitleri grubu
    const fattyAcidColor = Color(0xFF3FB950); // green
    final fattyAcids = <_LandscapeItem>[
      _LandscapeItem('Omega-3', n.omega3 ?? n65?.omega3 ?? 0, 1.6, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('Omega-6', n.omega6 ?? n65?.omega6 ?? 0, 17.0, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('Doymuş Yağ', n.saturatedFat > 0 ? n.saturatedFat : (n65?.satFat ?? 0), 20.0, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('Tekli Doymamış', n.monoFat ?? n65?.monoFat ?? 0, 25.0, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('Çoklu Doymamış', n.polyFat ?? n65?.polyFat ?? 0, 15.0, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('ALA', n.ala ?? n65?.ala ?? 0, 1.6, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('EPA', n.epa ?? n65?.epa ?? 0, 0.25, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('DHA', n.dha ?? n65?.dha ?? 0, 0.25, 'g', fattyAcidColor, showAsPercentage: showPct),
      _LandscapeItem('Kolesterol', n.cholesterol ?? n65?.cholesterol ?? 0, 300.0, 'mg', fattyAcidColor, showAsPercentage: showPct),
    ];

    // Amino asitler grubu
    const aminoColor = Color(0xFFD2A8FF); // purple
    final aminoAcids = <_LandscapeItem>[
      _LandscapeItem('Lösin', n.leucine ?? n65?.leucine ?? 0, 2.73, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Lizin', n.lysine ?? n65?.lysine ?? 0, 2.10, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('İzolösin', n.isoleucine ?? n65?.isoleucine ?? 0, 1.40, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Valin', n.valine ?? n65?.valine ?? 0, 1.82, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Treonin', n.threonine ?? n65?.threonine ?? 0, 1.05, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Metionin', n.methionine ?? n65?.methionine ?? 0, 1.04, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Fenilalanin', n.phenylalanine ?? n65?.phenylalanine ?? 0, 2.31, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Triptofan', n.tryptophan ?? n65?.tryptophan ?? 0, 0.28, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Histidin', n.histidine ?? n65?.histidine ?? 0, 0.98, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Sistein', n65?.cystine ?? 0, 0.28, 'g', aminoColor, showAsPercentage: showPct),
      _LandscapeItem('Tirozin', n65?.tyrosine ?? 0, 0.87, 'g', aminoColor, showAsPercentage: showPct),
    ];

    final hasData = vitamins.isNotEmpty || minerals.isNotEmpty || fattyAcids.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + Skor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                context.tr('Mikro Besinler'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => _showScoreExplanation(context, score, scoreColor),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      score.toInt().toString(),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Vitaminler grubu
          _GroupLabel(context.tr('VİTAMİNLER'), cs),
          const SizedBox(height: 8),
          _NutrientGrid(
            items: vitamins,
            isDark: isDark,
            cs: cs,
            sectionBg: sectionBg,
            onFavoriteToggled: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Mineraller grubu
          _GroupLabel(context.tr('MİNERALLER'), cs),
          const SizedBox(height: 8),
          _NutrientGrid(
            items: minerals,
            isDark: isDark,
            cs: cs,
            sectionBg: sectionBg,
            onFavoriteToggled: () => setState(() {}),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: widget.onShowAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              minimumSize: const Size(double.infinity, 0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr('Tüm besin değerlerini gör'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16, color: cs.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _GroupLabel(this.text, this.cs);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: cs.onSurfaceVariant,
      letterSpacing: 0.8,
    ),
  );
}

class _NutrientGrid extends StatelessWidget {
  final List<_LandscapeItem> items;
  final bool isDark;
  final ColorScheme cs;
  final Color sectionBg;
  final VoidCallback? onFavoriteToggled;

  const _NutrientGrid({
    required this.items,
    required this.isDark,
    required this.cs,
    required this.sectionBg,
    this.onFavoriteToggled,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _LandscapeItemCard(
                item: items[i],
                isDark: isDark,
                cs: cs,
                bgColor: sectionBg,
                onFavoriteToggled: onFavoriteToggled,
              ),
            ),
            const SizedBox(width: 10),
            i + 1 < items.length
                ? Expanded(
                    child: _LandscapeItemCard(
                      item: items[i + 1],
                      isDark: isDark,
                      cs: cs,
                      bgColor: sectionBg,
                      onFavoriteToggled: onFavoriteToggled,
                    ),
                  )
                : const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (i + 2 < items.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

class _LandscapeItem {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final Color color;
  final bool showAsPercentage;

  const _LandscapeItem(
    this.label,
    this.value,
    this.goal,
    this.unit,
    this.color, {
    this.showAsPercentage = false,
  });

  double get pct => goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
  String get valueStr {
    if (showAsPercentage) {
      final p = goal > 0 ? (value / goal) * 100 : 0.0;
      return '%${p.toStringAsFixed(0)}';
    }
    if (value >= 100) return value.toStringAsFixed(0);
    if (value >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }
}

class _LandscapeItemCard extends StatefulWidget {
  final _LandscapeItem item;
  final bool isDark;
  final ColorScheme cs;
  final Color? bgColor;
  final VoidCallback? onFavoriteToggled;

  const _LandscapeItemCard({
    required this.item,
    required this.isDark,
    required this.cs,
    this.bgColor,
    this.onFavoriteToggled,
  });

  @override
  State<_LandscapeItemCard> createState() => _LandscapeItemCardState();
}

class _LandscapeItemCardState extends State<_LandscapeItemCard> {
  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.bgColor ??
        (widget.isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA));
    final cs = widget.cs;
    final item = widget.item;

    return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.tr(item.label).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                        item.showAsPercentage
                            ? item.valueStr
                            : '${item.valueStr}${item.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.pct,
                      minHeight: 5,
                      backgroundColor: widget.isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE0E0E0),
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                ],
              ),
        );
  }
}

// ─── Beslenme Skoru Detay ────────────────────────────────────────────────────

void _showNutritionScoreDetail(
  BuildContext context,
  double score,
  Color scoreColor,
  AppLocalizations l10n,
  NutritionData nutrition,
  NutritionData65? nutrition65,
  ProfileProvider profileProvider,
) {
  final pp = profileProvider;
  final profile = pp.activeProfile;
  final n65 = nutrition65;

  double pct(double c, double g) =>
      (c <= 0) ? 0.0 : (g <= 0 ? 1.0 : (c / g).clamp(0.0, 1.0));

  String fmtG(double v, [int d = 1]) => '${v.toStringAsFixed(d)} g';
  String fmtMg(double v, [int d = 1]) => '${v.toStringAsFixed(d)} mg';
  String fmtMcg(double v, [int d = 1]) => '${v.toStringAsFixed(d)} mcg';

  final items = <Object>[];

  const clrMineral = Color(0xFF26D0CE);
  const clrVitamin = Color(0xFFFF9F0A);
  const clrFat = Color(0xFF0A84FF);
  const clrAmino = Color(0xFFBF5AF2);
  const clrCarotenoid = Color(0xFFFF6B00); // Özel renk — Turuncu/Mercan
  const clrMisc = Color(0xFF8E8E93);

  final showPct = profileProvider.showMicroPercentage;
  String rVal(double v, double g, String u) {
    if (showPct && g > 0) return '%${((v / g) * 100).toStringAsFixed(0)}';
    if (u == 'g') return fmtG(v);
    if (u == 'mg') return fmtMg(v);
    return fmtMcg(v);
  }

  items.add(
    _ScoreRow(
      '🐓',
      l10n.isTurkish ? 'Kolesterol' : 'Cholesterol',
      rVal(n65?.cholesterol ?? 0, 300.0, 'mg'),
      pct(n65?.cholesterol ?? 0, 300.0),
      clrMisc,
    ),
  );

  items.add(_ScoreSection(l10n.isTurkish ? 'MİNERALLER' : 'MINERALS'));
  final caG = profile?.calciumGoal ?? 1000.0;
  final feG = profile?.ironGoal ?? 14.0;
  final mgG = profile?.magnesiumGoal ?? 350.0;
  final znG = profile?.zincGoal ?? 10.0;
  final kG = profile?.potassiumGoal ?? 4700.0;
  final naL = profile?.sodiumLimit ?? 2300.0;
  final seG = profile?.seleniumGoal ?? 55.0;
  items.add(
    _ScoreRow(
      '🦴',
      l10n.isTurkish ? 'Kalsiyum' : 'Calcium',
      rVal(n65?.calcium ?? 0, caG, 'mg'),
      pct(n65?.calcium ?? 0, caG),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🩸',
      l10n.isTurkish ? 'Demir' : 'Iron',
      rVal(n65?.iron ?? 0, feG, 'mg'),
      pct(n65?.iron ?? 0, feG),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '⚡',
      l10n.isTurkish ? 'Magnezyum' : 'Magnesium',
      rVal(n65?.magnesium ?? 0, mgG, 'mg'),
      pct(n65?.magnesium ?? 0, mgG),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🔵',
      l10n.isTurkish ? 'Fosfor' : 'Phosphorus',
      rVal(n65?.phosphorus ?? 0, 700.0, 'mg'),
      pct(n65?.phosphorus ?? 0, 700.0),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🫀',
      l10n.isTurkish ? 'Potasyum' : 'Potassium',
      rVal(n65?.potassium ?? 0, kG, 'mg'),
      pct(n65?.potassium ?? 0, kG),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🧂',
      l10n.tr('Sodyum'),
      rVal(n65?.sodium ?? 0, naL, 'mg'),
      pct(n65?.sodium ?? 0, naL),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🔩',
      l10n.isTurkish ? 'Çinko' : 'Zinc',
      rVal(n65?.zinc ?? 0, znG, 'mg'),
      pct(n65?.zinc ?? 0, znG),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🔶',
      l10n.isTurkish ? 'Bakır' : 'Copper',
      rVal(n65?.copper ?? 0, 0.9, 'mg'),
      pct(n65?.copper ?? 0, 0.9),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🔘',
      l10n.isTurkish ? 'Manganez' : 'Manganese',
      rVal(n65?.manganese ?? 0, 2.3, 'mg'),
      pct(n65?.manganese ?? 0, 2.3),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🌟',
      l10n.isTurkish ? 'Selenyum' : 'Selenium',
      rVal(n65?.selenium ?? 0, seG, 'mcg'),
      pct(n65?.selenium ?? 0, seG),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '💧',
      l10n.isTurkish ? 'İyot' : 'Iodine',
      rVal(n65?.iodine ?? 0, 150.0, 'mcg'),
      pct(n65?.iodine ?? 0, 150.0),
      clrMineral,
    ),
  );
  items.add(
    _ScoreRow(
      '🔷',
      l10n.isTurkish ? 'Krom' : 'Chromium',
      rVal(n65?.chromium ?? 0, 35.0, 'mcg'),
      pct(n65?.chromium ?? 0, 35.0),
      clrMineral,
    ),
  );

  items.add(_ScoreSection(l10n.isTurkish ? 'VİTAMİNLER' : 'VITAMINS'));
  final vdG = profile?.vitaminDGoal ?? 15.0;
  final vb12G = profile?.vitaminB12Goal ?? 2.4;
  items.add(
    _ScoreRow(
      '🍊',
      l10n.isTurkish ? 'C Vitamini' : 'Vitamin C',
      rVal(n65?.vitC ?? 0, 90.0, 'mg'),
      pct(n65?.vitC ?? 0, 90.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '☀️',
      l10n.isTurkish ? 'D Vitamini' : 'Vitamin D',
      rVal(n65?.vitD_mcg ?? 0, vdG, 'mcg'),
      pct(n65?.vitD_mcg ?? 0, vdG),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🥑',
      l10n.isTurkish ? 'E Vitamini' : 'Vitamin E',
      rVal(n65?.vitE ?? 0, 15.0, 'mg'),
      pct(n65?.vitE ?? 0, 15.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🥬',
      l10n.isTurkish ? 'K Vitamini' : 'Vitamin K',
      rVal(n65?.vitK ?? 0, 120.0, 'mcg'),
      pct(n65?.vitK ?? 0, 120.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🥕',
      l10n.isTurkish ? 'A Vitamini (RAE)' : 'Vitamin A',
      rVal(n65?.vitA_RAE ?? 0, 900.0, 'mcg'),
      pct(n65?.vitA_RAE ?? 0, 900.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🌾',
      l10n.isTurkish ? 'B1 (Tiamin)' : 'B1 (Thiamin)',
      rVal(n65?.thiamine ?? 0, 1.2, 'mg'),
      pct(n65?.thiamine ?? 0, 1.2),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🥛',
      l10n.isTurkish ? 'B2 (Riboflavin)' : 'B2',
      rVal(n65?.riboflavin ?? 0, 1.3, 'mg'),
      pct(n65?.riboflavin ?? 0, 1.3),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🐟',
      l10n.isTurkish ? 'B3 (Niasin)' : 'B3 (Niacin)',
      rVal(n65?.niacin ?? 0, 16.0, 'mg'),
      pct(n65?.niacin ?? 0, 16.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🥦',
      l10n.isTurkish ? 'B5 (Pantotenik)' : 'B5',
      rVal(n65?.pantothenic ?? 0, 5.0, 'mg'),
      pct(n65?.pantothenic ?? 0, 5.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🐔',
      l10n.isTurkish ? 'B6 Vitamini' : 'Vitamin B6',
      rVal(n65?.vitB6 ?? 0, 1.7, 'mg'),
      pct(n65?.vitB6 ?? 0, 1.7),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🌿',
      l10n.isTurkish ? 'Folat' : 'Folate',
      rVal(n65?.folate ?? 0, 400.0, 'mcg'),
      pct(n65?.folate ?? 0, 400.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🥩',
      l10n.isTurkish ? 'B12 Vitamini' : 'Vitamin B12',
      rVal(n65?.vitB12 ?? 0, vb12G, 'mcg'),
      pct(n65?.vitB12 ?? 0, vb12G),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '🧠',
      l10n.isTurkish ? 'Kolin' : 'Choline',
      rVal(n65?.choline ?? 0, 550.0, 'mg'),
      pct(n65?.choline ?? 0, 550.0),
      clrVitamin,
    ),
  );
  items.add(
    _ScoreRow(
      '💊',
      'Biotin',
      rVal(n65?.biotin ?? 0, 30.0, 'mcg'),
      pct(n65?.biotin ?? 0, 30.0),
      clrVitamin,
    ),
  );
  items.add(_ScoreSection(l10n.isTurkish ? 'KAROTENOİDLER' : 'CAROTENOIDS'));
  items.add(
    _ScoreRow(
      '🧡',
      l10n.isTurkish ? 'Beta-Karoten' : 'Beta-Carotene',
      rVal(n65?.betaCarot ?? 0, 15000.0, 'mcg'),
      pct(n65?.betaCarot ?? 0, 15000.0),
      clrCarotenoid,
    ),
  );
  items.add(
    _ScoreRow(
      '🍅',
      l10n.isTurkish ? 'Likopen' : 'Lycopene',
      rVal(n65?.lycopene ?? 0, 10000.0, 'mcg'),
      pct(n65?.lycopene ?? 0, 10000.0),
      clrCarotenoid,
    ),
  );
  items.add(
    _ScoreRow(
      '👁️',
      'Lutein+Zea',
      rVal(n65?.luteinZea ?? 0, 10000.0, 'mcg'),
      pct(n65?.luteinZea ?? 0, 10000.0),
      clrCarotenoid,
    ),
  );
  items.add(
    _ScoreRow(
      '🥕',
      l10n.isTurkish ? 'Alfa-Karoten' : 'Alpha-Carotene',
      rVal(n65?.alphaCarot ?? 0, 5000.0, 'mcg'),
      pct(n65?.alphaCarot ?? 0, 5000.0),
      clrCarotenoid,
    ),
  );

  items.add(_ScoreSection(l10n.isTurkish ? 'YAĞ ASİTLERİ' : 'FATTY ACIDS'));
  final o3G = profile?.omega3Goal ?? 1.6;
  final o6G = profile?.omega6Goal ?? 17.0;
  items.add(
    _ScoreRow(
      '🐟',
      'Omega-3',
      rVal(n65?.omega3 ?? 0, o3G, 'g'),
      pct(n65?.omega3 ?? 0, o3G),
      clrFat,
    ),
  );
  items.add(
    _ScoreRow(
      '🌻',
      'Omega-6',
      rVal(n65?.omega6 ?? 0, o6G, 'g'),
      pct(n65?.omega6 ?? 0, o6G),
      clrFat,
    ),
  );
  items.add(
    _ScoreRow(
      '🦈',
      'EPA',
      rVal(n65?.epa ?? 0, 0.25, 'g'),
      pct(n65?.epa ?? 0, 0.25),
      clrFat,
    ),
  );
  items.add(
    _ScoreRow(
      '🐬',
      'DHA',
      rVal(n65?.dha ?? 0, 0.25, 'g'),
      pct(n65?.dha ?? 0, 0.25),
      clrFat,
    ),
  );
  items.add(
    _ScoreRow(
      '🥑',
      'ALA',
      rVal(n65?.ala ?? 0, 1.6, 'g'),
      pct(n65?.ala ?? 0, 1.6),
      clrFat,
    ),
  );
  items.add(
    _ScoreRow(
      '🍳',
      l10n.isTurkish ? 'Doymuş Yağ' : 'Saturated Fat',
      rVal(n65?.satFat ?? 0, 20.0, 'g'),
      pct(n65?.satFat ?? 0, 20.0),
      clrFat,
    ),
  );
  items.add(
    _ScoreRow(
      '🫒',
      l10n.isTurkish ? 'Tekli Doymamış' : 'Monounsaturated',
      rVal(n65?.monoFat ?? 0, 25.0, 'g'),
      pct(n65?.monoFat ?? 0, 25.0),
      clrFat,
    ),
  );

  items.add(_ScoreSection(l10n.isTurkish ? 'AMİNO ASİTLER' : 'AMINO ACIDS'));
  void aa(String ico, String l, double v, double ref) {
    items.add(_ScoreRow(ico, l, rVal(v, ref, 'g'), pct(v, ref), clrAmino));
  }

  aa('💪', l10n.isTurkish ? 'Lösin' : 'Leucine', n65?.leucine ?? 0, 2.7);
  aa('🔗', l10n.isTurkish ? 'Lizin' : 'Lysine', n65?.lysine ?? 0, 2.1);
  aa('🏃', l10n.isTurkish ? 'Valin' : 'Valine', n65?.valine ?? 0, 1.8);
  aa(
    '⚡',
    l10n.isTurkish ? 'İzolösin' : 'Isoleucine',
    n65?.isoleucine ?? 0,
    1.4,
  );
  aa('🌱', l10n.isTurkish ? 'Treonin' : 'Threonine', n65?.threonine ?? 0, 1.0);
  aa(
    '🔸',
    l10n.isTurkish ? 'Metionin' : 'Methionine',
    n65?.methionine ?? 0,
    0.7,
  );
  aa(
    '🔹',
    l10n.isTurkish ? 'Fenilalanin' : 'Phenylalanine',
    n65?.phenylalanine ?? 0,
    1.4,
  );
  aa(
    '😴',
    l10n.isTurkish ? 'Triptofan' : 'Tryptophan',
    n65?.tryptophan ?? 0,
    0.28,
  );
  aa('🔬', l10n.isTurkish ? 'Histidin' : 'Histidine', n65?.histidine ?? 0, 0.7);
  aa('🧪', l10n.isTurkish ? 'Sistin' : 'Cystine', n65?.cystine ?? 0, 0.5);
  aa('🌀', l10n.isTurkish ? 'Tirozin' : 'Tyrosine', n65?.tyrosine ?? 0, 1.1);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.isTurkish ? 'Besin Değerleri' : 'Nutritional Values',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is _ScoreSection) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 6),
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withValues(alpha: 0.45),
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }
                  final r = item as _ScoreRow;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              r.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: r.pct >= 0.8
                                    ? r.color
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: r.pct,
                            minHeight: 5,
                            color: r.color,
                            backgroundColor: cs.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ScoreSection {
  final String title;
  const _ScoreSection(this.title);
}

class _ScoreRow {
  final String icon;
  final String label;
  final String value;
  final double pct;
  final Color color;
  const _ScoreRow(this.icon, this.label, this.value, this.pct, this.color);
}

// ─── Su Özeti Kartı (Anasayfa için) ──────────────────────────────────────────

class _WaterSummaryCard extends StatelessWidget {
  final double consumed;
  final int goal;
  final Function(double) onAdd;
  final VoidCallback onRemoveTap;
  final VoidCallback onAddTap;
  final bool isReadOnly;

  const _WaterSummaryCard({
    required this.consumed,
    required this.goal,
    required this.onAdd,
    required this.onRemoveTap,
    required this.onAddTap,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final surface2 = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E5EA);
    final cs = Theme.of(context).colorScheme;
    final progress = (consumed / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('SU'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF8B949E)
                            : const Color(0xFF656D76),
                        letterSpacing: 0.6,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          consumed.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          ' / $goal ml',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isReadOnly)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: consumed > 0 ? onRemoveTap : null,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: surface2,
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAddTap,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: surface2,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Saatlik Adım Çubukları ───────────────────────────────────────────────────

class _HourlyStepBars extends StatelessWidget {
  final int totalSteps;
  final int stepGoal;

  const _HourlyStepBars({required this.totalSteps, required this.stepGoal});

  // Typical activity weight per hour (0–23)
  static const _weights = [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, // 0–5  sleep
    0.3, 0.8, 1.0, 0.9, 0.7, 0.8, // 6–11 morning
    0.6, 0.7, 0.6, 0.7, 0.8, 0.9, // 12–17 afternoon
    1.0, 0.8, 0.6, 0.4, 0.2, 0.1, // 18–23 evening
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now().hour;
    const barColor = Color(0xFF58A6FF);
    final ghostColor = cs.outlineVariant;

    // Scale factor: how far through the step goal we are (capped at 1)
    final scale = stepGoal > 0 ? (totalSteps / stepGoal).clamp(0.0, 1.0) : 0.0;

    // For each hour build a fractional bar height (0.0–1.0)
    final bars = List.generate(24, (h) {
      if (h > now) return 0.0;
      return (_weights[h] * scale).clamp(0.0, 1.0);
    });

    const minFraction = 0.06; // always visible tick even at 0 steps

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final totalW = constraints.maxWidth;
        final totalH = constraints.maxHeight;
        // 24 bars with 1 px gap between each → barW = (totalW − 23) / 24
        final barW = ((totalW - 23) / 24).clamp(1.0, double.infinity);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (h) {
            final isPast = h <= now;
            final fraction = isPast
                ? (bars[h] < minFraction ? minFraction : bars[h])
                : minFraction * 0.5;
            final barH = (totalH * fraction).clamp(1.0, totalH);

            return Padding(
              padding: EdgeInsets.only(right: h < 23 ? 1.0 : 0.0),
              child: Container(
                width: barW,
                height: barH,
                decoration: BoxDecoration(
                  color: isPast && bars[h] >= minFraction
                      ? barColor
                      : ghostColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Sayfa Göstergesi ─────────────────────────────────────────────────────────

class _DashboardPageIndicator extends StatelessWidget {
  final int currentPage;

  const _DashboardPageIndicator({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (i) {
          final isActive = i == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 20 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive ? cs.primary : cs.outline,
            ),
          );
        }),
      ),
    );
  }
}

// ─── Yiyecek Düzenleme Sayfası ────────────────────────────────────────────────

class _FoodEditSheet extends StatefulWidget {
  final FoodEntry entry;
  final NutritionProvider provider;
  final DateTime selectedDate;

  const _FoodEditSheet({
    required this.entry,
    required this.provider,
    required this.selectedDate,
  });

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
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final n = e.nutritionData.scaleBy(e.portionSize / 100);
    _nameCtrl = TextEditingController(text: e.name);
    _portionCtrl = TextEditingController(
      text: e.portionSize.toStringAsFixed(0),
    );
    _calorieCtrl = TextEditingController(text: n.calories.toStringAsFixed(0));
    _proteinCtrl = TextEditingController(text: n.protein.toStringAsFixed(0));
    _carbCtrl = TextEditingController(text: n.carbohydrates.toStringAsFixed(0));
    _fatCtrl = TextEditingController(text: n.fat.toStringAsFixed(0));
    _imagePath = e.imagePath;
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
      imagePath: _imagePath,
      nutritionData: NutritionData(
        calories: factor > 0 ? calories / factor : 0,
        protein: factor > 0 ? protein / factor : 0,
        carbohydrates: factor > 0 ? carbs / factor : 0,
        fat: factor > 0 ? fat / factor : 0,
      ),
    );

    widget.provider.updateFoodEntry(updated, date: widget.selectedDate);
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
            child: Text(l10n.tr('İptal')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.tr('Sil'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      widget.provider.removeFoodEntry(widget.entry.id, date: widget.selectedDate);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
            Text(
              l10n.isTurkish ? 'Yiyeceği Düzenle' : 'Edit Food',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            if (_imagePath != null) ...[
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() {
                      _imagePath = picked.path;
                    });
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_imagePath!),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, e, s) => const SizedBox.shrink(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 24),
                    ),
                  ],
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
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish
                          ? 'Porsiyon (g)'
                          : 'Portion (g)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _calorieCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.isTurkish
                          ? 'Kalori (kcal)'
                          : 'Calories (kcal)',
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
                      decimal: true,
                    ),
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
                      decimal: true,
                    ),
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
                      decimal: true,
                    ),
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
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      l10n.tr('Sil'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
  final int waterGoalMl;

  const _WaterCard({required this.provider, required this.waterGoalMl});

  @override
  State<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<_WaterCard> with SingleTickerProviderStateMixin {
  double get _waterGoalMl => widget.waterGoalMl.toDouble();
  double get _waterGoalL => widget.waterGoalMl / 1000.0;
  double _lastAddedMl = 250;

  late final AnimationController _waterCtrl;
  double _fromProgress = 0.0;
  double _toProgress = 0.0;

  double get _currentAnimProgress =>
      _fromProgress + (_toProgress - _fromProgress) * _waterCtrl.value;

  @override
  void initState() {
    super.initState();
    _waterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _waterCtrl.addListener(() => setState(() {}));
    // Initialize to current progress
    final waterMl = widget.provider.todayLog.waterIntakeMl;
    _toProgress = (waterMl / _waterGoalMl).clamp(0.0, 1.0);
    _fromProgress = _toProgress;
  }

  @override
  void didUpdateWidget(_WaterCard old) {
    super.didUpdateWidget(old);
    final waterMl = widget.provider.todayLog.waterIntakeMl;
    final newProgress = (waterMl / _waterGoalMl).clamp(0.0, 1.0);
    if ((newProgress - _toProgress).abs() > 0.001) {
      _fromProgress = _currentAnimProgress;
      _toProgress = newProgress;
      _waterCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _waterCtrl.dispose();
    super.dispose();
  }

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
          content: Text(
            l10n.isTurkish
                ? 'Günlük su hedefinize ulaştınız! 💧'
                : 'You reached your daily water goal! 💧',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeLastWater() {
    final currentMl = widget.provider.todayLog.waterIntakeMl;
    if (_lastAddedMl > currentMl) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isTurkish
                ? 'Girilen sudan fazla çıkartamazsınız.'
                : 'Cannot remove more than total intake.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
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
                    Icon(
                      Icons.water_drop,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.tr('Su Tüketimi'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${waterLiters.toStringAsFixed(1)} / ${_waterGoalL}L',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        onPressed: waterMl > 0 ? _removeLastWater : null,
                        tooltip: l10n.isTurkish
                            ? 'Son eklemeyi geri al'
                            : 'Undo last add',
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
            LinearProgressIndicator(
              value: MediaQuery.of(context).disableAnimations ? progress : _currentAnimProgress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF29B6F6),
              backgroundColor: const Color(0xFF29B6F6).withValues(alpha: 0.15),
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
  final bool isRemove;
  final double currentWaterMl;

  const _WaterAddSheet({required this.onAdd, this.isRemove = false, this.currentWaterMl = 0});

  @override
  State<_WaterAddSheet> createState() => _WaterAddSheetState();
}

class _WaterAddSheetState extends State<_WaterAddSheet> {
  final _manualCtrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _addAndClose(double ml) {
    if (widget.isRemove && ml > widget.currentWaterMl) {
      HapticFeedback.vibrate();
      final msg = (AppLocalizations.of(context).isTurkish 
          ? 'Alınan su miktarından fazla çıkaramazsınız.' 
          : 'Cannot remove more than total intake.');
      setState(() {
        _errorText = msg;
      });
      final isTurkish = AppLocalizations.of(context).isTurkish;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (ctx) => AlertDialog(
            title: Text(isTurkish ? 'Hatalı İşlem' : 'Invalid Action'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).tr('Tamam')),
              ),
            ],
          ),
        );
      });
      return;
    }
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
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
              Expanded(
                child: Text(
                  widget.isRemove
                      ? (isTurkish
                            ? 'Ne kadar çıkarmak istersiniz?'
                            : 'How much to remove?')
                      : (isTurkish
                            ? 'Ne kadar içtiniz?'
                            : 'How much did you drink?'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.isRemove)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (isTurkish ? 'Alınan: ' : 'Intake: ') + '${widget.currentWaterMl.toStringAsFixed(0)} ml',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
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
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
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
                child: Text(widget.isRemove ? (isTurkish ? 'Çıkart' : 'Remove') : l10n.tr('Ekle')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ─── Premium Placeholder ──────────────────────────────────────────────────────

class _PremiumPlaceholderScreen extends StatefulWidget {
  const _PremiumPlaceholderScreen();

  @override
  State<_PremiumPlaceholderScreen> createState() =>
      _PremiumPlaceholderScreenState();
}

class _PremiumPlaceholderScreenState extends State<_PremiumPlaceholderScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Design System Tokens
    const primaryGradient = LinearGradient(
      colors: [Color(0xFF006e28), Color(0xFF34c759)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final surfaceColor = isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFFAF9F9);
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                stretch: true,
                backgroundColor: surfaceColor,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBouZO0_M7aiDhjRttLCunjh1h67j9Fb0Cs5hlaRew7M0epWKdalcWduEToTd5ZSakaBYzDSTnA4nCUmZgOuQtiVW9j5snfRtwPzXMupUdt6tLbi2UW4Cy_JSbKsTwYjcwTaDXZ5QyCVeuMqiQzIXkr-j5L7Q8tEE2P2HdAaUujbIgyU2jbfi5RKsaTF-0l-BKbek0uGVIwY3Uxn05A-gRv71BSTYyq2Wu7U3hDXwcuGvQo35dqu0nfUG26oFBDpiRv25J_GeFCm5E',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              surfaceColor.withValues(alpha: 0.8),
                              surfaceColor,
                            ],
                            stops: const [0.5, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Text(
                          context.tr('Premium Özellikleri Aç'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            height: 1.1,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Sağlığınızı hassas araçlarla geliştirin.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Features List
                    _buildFeatureItem(
                      context,
                      icon: Icons.biotech_outlined,
                      color: const Color(0xFF006e28),
                      title: context.tr('65+ Besin Analizi'),
                      subtitle: context.tr('Mikro besinleri ve mineralleri takip edin'),
                    ),
                    _buildFeatureItem(
                      context,
                      icon: Icons.camera_alt_outlined,
                      color: const Color(0xFF006687),
                      title: context.tr('AI Fotoğraf Tarama'),
                      subtitle: context.tr('Gelişmiş vizyon AI ile anında günlük kaydı'),
                    ),
                    _buildFeatureItem(
                      context,
                      icon: Icons.auto_awesome_outlined,
                      color: const Color(0xFF8c5000),
                      title: context.tr('Gelişmiş Sağlık Takibi'),
                      subtitle:
                          context.tr('Ruh hali, uyku ve vücut kompozisyonunu senkronize edin'),
                    ),
                    _buildFeatureItem(
                      context,
                      icon: Icons.restaurant_menu_outlined,
                      color: const Color(0xFF34c759),
                      title: context.tr('Kişiselleştirilmiş Öğünler'),
                      subtitle: context.tr('Biyolojinize göre kürate edilmiş tarifler'),
                    ),
                    _buildFeatureItem(
                      context,
                      icon: Icons.block_outlined,
                      color: cs.onSurfaceVariant,
                      title: context.tr('Reklamsız Deneyim'),
                      subtitle: context.tr('Odaklanmış ve dikkat dağıtmayan bir alan'),
                    ),

                    const SizedBox(height: 40),

                    // Pricing Section
                    _buildPricingCard(
                      index: 0,
                      label: context.tr('Haftalık'),
                      price: '₺169,99',
                      period: context.tr('Her hafta faturalandırılır'),
                      cardColor: cardColor,
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    _buildPricingCard(
                      index: 1,
                      label: context.tr('Yıllık'),
                      price: '₺1.699,99',
                      period: context.tr('₺8.800 yerine — %80 Tasarruf'),
                      isPopular: true,
                      cardColor: cardColor,
                      cs: cs,
                      gradient: primaryGradient,
                    ),
                    const SizedBox(height: 12),
                    _buildPricingCard(
                      index: 2,
                      label: context.tr('Ömür Boyu'),
                      price: '₺6.999,99',
                      period: context.tr('Bir kez öde, sınırsız kullan'),
                      isLimited: true,
                      cardColor: cardColor,
                      cs: cs,
                    ),

                    const SizedBox(height: 48),

                    // Action Button
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: primaryGradient,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF006e28,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(32),
                          child: Center(
                            child: Text(
                              context.tr('Devam Et'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Footer Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink(context.tr('Geri Yükle')),
                        _buildDivider(),
                        _buildFooterLink(context.tr('Gizlilik')),
                        _buildDivider(),
                        _buildFooterLink(context.tr('Kullanım')),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
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

  Widget _buildPricingCard({
    required int index,
    required String label,
    required String price,
    required String period,
    required Color cardColor,
    required ColorScheme cs,
    bool isPopular = false,
    bool isLimited = false,
    LinearGradient? gradient,
  }) {
    final isSelected = _selectedPlanIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF006e28) : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF006e28).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: isSelected
                                  ? const Color(0xFF006e28)
                                  : cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          if (isLimited) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF8c5000,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SINIRLI',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF8c5000),
                                ),
                              ),
                            ),
                          ],
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF006e28)
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (isPopular)
              Positioned(
                top: -12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EN POPÜLER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
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

  Widget _buildFooterLink(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
    ),
  );

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ─── Streak Bottom Sheet ──────────────────────────────────────────────────────

class _StreakBottomSheet extends StatelessWidget {
  final NutritionProvider provider;
  final ProfileProvider profileProvider;

  const _StreakBottomSheet({
    required this.provider,
    required this.profileProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    final currentStreak = provider.currentStreak(
      calorieGoal: profileProvider.calorieGoal,
      proteinGoal: profileProvider.proteinGoal,
      carbGoal: profileProvider.carbGoal,
      fatGoal: profileProvider.fatGoal,
      waterGoalMl: profileProvider.waterGoalMl.toDouble(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Icon(
            Icons.local_fire_department_rounded,
            size: 64,
            color: Color(0xFFFF9F0A),
          ),
          const SizedBox(height: 12),
          Text(
            '$currentStreak',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF9F0A),
              height: 1.0,
            ),
          ),
          Text(
            'gün',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Nasıl Streak Yapılır?'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('Seriyi (streak) korumak ve artırmak için günlük kalori, makro, su ve adım hedeflerinize her gün ulaşmanız gerekmektedir. Tüm hedeflerinize ulaştığınız her gün serinize eklenir.'),
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wellness Section ─────────────────────────────────────────────────────────

class _WellnessSection extends StatefulWidget {
  final DateTime selectedDate;
  const _WellnessSection({required this.selectedDate});

  @override
  State<_WellnessSection> createState() => _WellnessSectionState();
}

class _WellnessSectionState extends State<_WellnessSection> {
  // (key, label, openHour, closeHour)
  static const _slots = [
    ('sabah', 'Sabah', 0, 7),
    ('öğle', 'Öğle', 7, 12),
    ('akşam', 'Akşam', 12, 17),
    ('gece', 'Gece', 17, 24),
  ];

  late final _timer = Stream.periodic(const Duration(minutes: 1)).listen((_) {
    if (mounted) setState(() {});
  });

  final _symptomCtrl = TextEditingController();

  static const _symptomKeywords = [
    // Ağrı
    'ağrı', 'sancı', 'kramp', 'zonklama', 'yanma', 'batma', 'baskı',
    // Genel belirtiler
    'baş', 'karın', 'mide', 'göğüs', 'sırt', 'boyun', 'kas', 'eklem', 'bacak', 'kol',
    'boğaz', 'kulak', 'göz', 'burun', 'diz', 'bel', 'beden',
    // Semptom türleri
    'bulantı', 'kusma', 'ishal', 'kabızlık', 'şişkinlik', 'gaz', 'hazımsızlık',
    'yorgunluk', 'halsizlik', 'baş dönmesi', 'bayılma', 'titreme', 'ateş',
    'öksürük', 'nefes', 'çarpıntı', 'terleme', 'uyuşma', 'kaşıntı', 'kızarıklık',
    'şişme', 'ödem', 'döküntü', 'alerjik', 'alerji', 'grip', 'soğuk algınlığı',
    'uykusuzluk', 'uyku', 'iştahsızlık', 'iştah', 'kilo', 'tansiyon', 'şeker',
    'anksiyete', 'panik', 'stres', 'depresyon', 'migren', 'vertigo',
    'reflü', 'ülser', 'gastrit', 'kolit', 'irritabl', 'disbiyoz',
    'demir', 'vitamin', 'mineral', 'anemi', 'osteoporoz', 'diyabet',
    'hipertansiyon', 'kolesterol', 'trigliserit', 'fibromiyalji',
    // English symptoms
    'pain', 'ache', 'headache', 'stomachache', 'nausea', 'vomiting', 'diarrhea',
    'constipation', 'bloating', 'fatigue', 'dizziness', 'fever', 'cough',
    'cramp', 'swelling', 'rash', 'itch', 'allergy', 'insomnia', 'anxiety',
    'stress', 'migraine', 'vertigo', 'reflux', 'gastritis', 'anemia',
    'hypertension', 'diabetes', 'inflammation', 'infection', 'weakness',
    'chest pain', 'back pain', 'joint pain', 'muscle pain', 'sore throat',
    'runny nose', 'shortness of breath', 'palpitation', 'numbness', 'tingling',
    'loss of appetite', 'weight loss', 'weight gain', 'dehydration', 'heartburn',
  ];

  bool _isValidSymptom(String text) {
    if (text.length < 3) return false;
    final lower = text.toLowerCase();
    return _symptomKeywords.any((kw) => lower.contains(kw));
  }

  @override
  void dispose() {
    _symptomCtrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  // 'past' | 'current' | 'future'
  String _slotStatus(int openH, int closeH) {
    final now = DateTime.now().subtract(const Duration(hours: 5));
    final h = now.hour;
    if (openH > closeH) {
      // overnight slot (gece: 22-05)
      return (h >= openH || h < closeH)
          ? 'current'
          : (h < openH ? 'future' : 'past');
    }
    if (h < openH) return 'future';
    if (h >= closeH) return 'past';
    return 'current';
  }

  String _countdown(int openH) {
    final now = DateTime.now().subtract(const Duration(hours: 5));
    var openTime = DateTime(now.year, now.month, now.day, openH);
    if (openTime.isBefore(now))
      openTime = openTime.add(const Duration(days: 1));
    final diff = openTime.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0 ? '$h${context.tr('s')} $m${context.tr('dk')}' : '$m${context.tr('dk')}';
  }

  Color _sleepColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFF85149);
      case 2:
        return const Color(0xFFFF8C42);
      case 3:
        return const Color(0xFFFFCC00);
      case 4:
        return const Color(0xFF7EE787);
      case 5:
        return const Color(0xFF3FB950);
      default:
        return const Color(0xFF3FB950);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wellness = context.watch<WellnessProvider>();
    final log = wellness.getLogForDate(widget.selectedDate);
    final isToday = isDateEditable(widget.selectedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    Widget subCard({
      required String title,
      required Widget body,
      VoidCallback? onHistoryTap,
      double spacing = 10,
      EdgeInsetsGeometry? padding,
      Widget? titleAction,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF21262D).withValues(alpha: 0.4)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
              if (titleAction != null)
                titleAction
              else if (onHistoryTap != null)
                GestureDetector(
                  onTap: onHistoryTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF58A6FF).withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 22,
                      color: Color(0xFF58A6FF),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing),
          body,
        ],
      ),
    );

    Widget card({required String title, required Widget body}) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );

    return card(
      title: context.tr('Günlük Sağlık'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ruh Hali Takibi ────────────────────────────────────────────────
          subCard(
            title: context.tr('RUH HALİ TAKİBİ'),
            body: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _slots.map((s) {
                final slot = s.$1;
                final label = s.$2;
                final openH = s.$3;
                final closeH = s.$4;
                final status = _slotStatus(openH, closeH);
                final current = log.moodFor(slot);
                final cd = status == 'future' ? _countdown(openH) : null;
                return Expanded(
                  child: _MoodSlotButton(
                    label: context.tr('mood_$slot'),
                    mood: current,
                    status: isToday ? status : 'past',
                    isToday: isToday,
                    countdown: isToday ? cd : null,
                    onTap: isToday
                        ? () {
                            if (status == 'future') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr('{} sonra ruh hali girişi yapabilirsiniz').replaceFirst('{}', cd ?? ""),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            _showMoodPicker(context, wellness, slot);
                          }
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          // ── Tuvalet Takibi ─────────────────────────────────────────────────
          subCard(
            title: context.tr('TUVALET TAKİBİ'),
            onHistoryTap: () => _showWcHistorySheet(context, wellness, widget.selectedDate),
            body: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showWcHistorySheet(context, wellness, widget.selectedDate),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.wcCount > 0
                              ? (isToday
                                  ? context.tr('Bugün {} tane girdi yaptınız').replaceFirst('{}', log.wcCount.toString())
                                  : (AppLocalizations.of(context).isTurkish
                                      ? 'O gün ${log.wcCount} tane girdi yapıldı'
                                      : 'You logged ${log.wcCount} entries that day'))
                              : (isToday
                                  ? context.tr('Bugün hiç girdi yapmadınız')
                                  : (AppLocalizations.of(context).isTurkish
                                      ? 'O gün hiç girdi yapılmadı'
                                      : 'No entries logged that day')),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isToday)
                  GestureDetector(
                    onTap: () => showWcTrackingSheet(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF58A6FF),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Uyku Kalitesi Takibi ───────────────────────────────────────────
          subCard(
            title: context.tr('UYKU KALİTESİ TAKİBİ'),
            body: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (i) {
                    final score = i + 1;
                    final selected = log.sleepScore == score;
                    final col = _sleepColor(score);
                    return GestureDetector(
                      onTap: isToday
                          ? () =>
                              context.read<WellnessProvider>().setSleepScore(score)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? col
                              : (isToday
                                  ? col.withValues(alpha: isDark ? 0.15 : 0.10)
                                  : col.withValues(alpha: isDark ? 0.05 : 0.03)),
                          border: Border.all(
                            color: selected
                                ? col
                                : (isToday
                                    ? col.withValues(alpha: 0.25)
                                    : col.withValues(alpha: 0.08)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : (isToday
                                      ? col.withValues(alpha: 0.7)
                                      : col.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Kötü'),
                      style: TextStyle(
                        fontSize: 11,
                        color: _sleepColor(1).withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      context.tr('Harika'),
                      style: TextStyle(
                        fontSize: 11,
                        color: _sleepColor(5).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                if (isToday && wellness.getLogForDate(widget.selectedDate.subtract(const Duration(days: 1))).sleepScore != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          '${context.tr('Dünkü uyku puanı:')} ${wellness.getLogForDate(widget.selectedDate.subtract(const Duration(days: 1))).sleepScore}/5',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ── Semptom Takibi ────────────────────────────────────────────────
          subCard(
            title: context.tr('SEMPTOM TAKİBİ'),
            spacing: 4,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            titleAction: Padding(
              padding: const EdgeInsets.only(right: 3),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(context.tr('Semptom Takibi Nedir?'), style: const TextStyle(fontWeight: FontWeight.w700))),
                        ],
                      ),
                      content: Text(
                        context.tr('Semptom Takibi; gün içinde yaşadığınız baş ağrısı, şişkinlik, yorgunluk gibi belirtileri kaydetmenizi sağlar. Bu sayede, tükettiğiniz gıdalar ile vücudunuzun gösterdiği tepkiler arasındaki ilişkiyi gözlemleyebilirsiniz.')
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(context.tr('Tamam')),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isToday)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _symptomCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: context.tr('Semptom girin...'),
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF21262D)
                                : const Color(0xFFF5F5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onSubmitted: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isEmpty) return;
                            if (!_isValidSymptom(trimmed)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('Lütfen geçerli bir semptom girin (örn: baş ağrısı, bulantı, yorgunluk)')),
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            wellness.addSymptom(trimmed);
                            _symptomCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('Semptom kaydedildi')),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          final val = _symptomCtrl.text.trim();
                          if (val.isEmpty) return;
                          if (!_isValidSymptom(val)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('Lütfen geçerli bir semptom girin (örn: baş ağrısı, bulantı, yorgunluk)')),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          wellness.addSymptom(val);
                          _symptomCtrl.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.tr('Semptom kaydedildi')),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (log.symptoms.isNotEmpty) ...[
                  if (isToday) const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: log.symptoms.map((symptom) {
                      return Chip(
                        label: Text(symptom, style: const TextStyle(fontSize: 12)),
                        onDeleted: isToday
                            ? () => wellness.removeSymptom(symptom)
                            : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ] else if (!isToday)
                  Text(
                    context.tr('Semptom girilmedi'),
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWcHistorySheet(BuildContext context, WellnessProvider wellness, DateTime selectedDate) {
    final log = wellness.getLogForDate(selectedDate);
    final logs = log.wcEntries;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Bugün hiç girdi yapmadınız'))),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
        final maxHour = isToday ? DateTime.now().hour : 23;
        final allHours = List.generate(maxHour + 1, (i) => maxHour - i);

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.tr('Giriş Detayları'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (context) {
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      itemCount: allHours.length,
                      itemBuilder: (context, index) {
                        final hour = allHours[index];
                        final entries = logs
                            .where((e) => e.time.hour == hour)
                            .toList();
                        final isCurrentHour = isToday && DateTime.now().hour == hour;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    fontSize: entries.isNotEmpty ? 15 : 12,
                                    fontWeight: isCurrentHour
                                        ? FontWeight.w800
                                        : (entries.isNotEmpty ? FontWeight.w600 : FontWeight.w400),
                                    color: isCurrentHour
                                        ? cs.primary
                                        : (entries.isNotEmpty ? cs.onSurface : cs.onSurface.withValues(alpha: 0.4)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Divider(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (entries.isNotEmpty) const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                children: entries.map((log) {
                                  final type = wcStoolTypes(context).firstWhere(
                                    (t) => t.value == log.stoolType,
                                    orElse: () => wcStoolTypes(context)[3],
                                  );
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: type.color.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: type.color.withValues(alpha: 0.5),
                                          width: 1.2,
                                        ),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            width: 58,
                                            height: 58,
                                            padding: const EdgeInsets.all(4),
                                            color: type.color.withValues(
                                              alpha: 0.1,
                                            ),
                                            child: type.assetPath != null
                                                ? Image.asset(
                                                    type.assetPath!,
                                                    fit: BoxFit.contain,
                                                  )
                                                : Center(
                                                    child: Text(
                                                      type.emoji,
                                                      style: const TextStyle(
                                                        fontSize: 28,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                type.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')} — ${log.stoolType == 0 ? context.tr('wc_stool_type_4_name') : (log.stoolType < 0 ? context.tr('Kabızlık') : context.tr('İshal'))}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white70 : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            if (entries.isNotEmpty)
                              const SizedBox(height: 6)
                            else
                              const SizedBox(height: 0),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoodPicker(
    BuildContext context,
    WellnessProvider wellness,
    String slot,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoodPickerSheet(
        slot: slot,
        current: wellness.today.moodFor(slot),
        onSelect: (mood) {
          context.read<WellnessProvider>().setMood(slot, mood);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _MoodSlotButton extends StatelessWidget {
  final String label;
  final MoodType? mood;
  // 'past' | 'current' | 'future'
  final String status;
  final String? countdown;
  final VoidCallback? onTap;
  final bool isToday;

  const _MoodSlotButton({
    required this.label,
    required this.mood,
    required this.status,
    this.countdown,
    this.onTap,
    this.isToday = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPast = status == 'past';
    final isFuture = status == 'future';

    final statusColor = isPast
        ? const Color(0xFFF85149)
        : isFuture
        ? const Color(0xFF58A6FF)
        : cs.primary;

    final hasMood = mood != null;

    String iconText;
    if (isFuture) {
      iconText = '🔒';
    } else if (hasMood) {
      iconText = mood!.emoji;
    } else if (!isToday) {
      iconText = '—';
    } else {
      iconText = '+';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        height: 80,
        decoration: BoxDecoration(
          color: isFuture
              ? (isDark ? const Color(0xFF1A1F28) : const Color(0xFFF0F0F5))
              : (hasMood
                    ? cs.primary.withValues(alpha: 0.10)
                    : (!isToday
                          ? (isDark ? const Color(0xFF161B22).withValues(alpha: 0.3) : const Color(0xFFF5F5F7).withValues(alpha: 0.5))
                          : (isDark
                                ? const Color(0xFF21262D)
                                : const Color(0xFFF5F5F7)))),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFuture
                ? statusColor.withValues(alpha: 0.25)
                : (hasMood
                      ? cs.primary.withValues(alpha: 0.3)
                      : (!isToday
                            ? cs.outline.withValues(alpha: 0.1)
                            : cs.outline.withValues(alpha: 0.2))),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              iconText,
              style: TextStyle(
                fontSize: hasMood ? 28 : 18,
                color: isFuture ? statusColor.withValues(alpha: 0.6) : (!isToday && !hasMood ? cs.onSurface.withValues(alpha: 0.3) : null),
              ),
            ),
            if (!hasMood) const SizedBox(height: 3),
            Text(
              hasMood ? mood!.label : label,
              style: TextStyle(
                fontSize: hasMood ? 11 : 10,
                fontWeight: hasMood ? FontWeight.w700 : FontWeight.w600,
                color: isFuture
                    ? cs.onSurface.withValues(alpha: 0.4)
                    : (hasMood
                          ? cs.primary
                          : (!isToday
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.onSurface.withValues(alpha: 0.7))),
              ),
            ),
            if (!hasMood && isFuture && countdown != null) ...[
              const SizedBox(height: 2),
              Text(
                countdown!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: statusColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoodPickerSheet extends StatelessWidget {
  final String slot;
  final MoodType? current;
  final void Function(MoodType?) onSelect;

  const _MoodPickerSheet({
    required this.slot,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32),
              Text(
                context.tr('Nasıl hissediyorsun?'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: MoodType.values.map((mood) {
              final selected = current == mood;
              return GestureDetector(
                onTap: () => onSelect(selected ? null : mood),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mood.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        context.tr(mood.label),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected ? Colors.white : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Swipeable Meal Entry Item ────────────────────────────────────────────────

class _SwipeMealItem extends StatefulWidget {
  final FoodEntry entry;
  final NutritionData scaled;
  final ColorScheme cs;
  final bool isTurkish;
  final VoidCallback onDelete;

  const _SwipeMealItem({
    super.key,
    required this.entry,
    required this.scaled,
    required this.cs,
    required this.isTurkish,
    required this.onDelete,
  });

  @override
  State<_SwipeMealItem> createState() => _SwipeMealItemState();
}

class _SwipeMealItemState extends State<_SwipeMealItem> {
  bool _isSaved = false;
  String? _savedFoodId;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final list = await SavedFoodsService.load();
    final idx = list.indexWhere((f) => f.name == widget.entry.name);
    if (mounted) {
      setState(() {
        _isSaved = idx >= 0;
        _savedFoodId = idx >= 0 ? list[idx].id : null;
      });
    }
  }

  Future<void> _toggleSaved() async {
    if (_isSaved && _savedFoodId != null) {
      await SavedFoodsService.remove(_savedFoodId!);
      if (mounted) {
        setState(() {
          _isSaved = false;
          _savedFoodId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTurkish
                  ? '${widget.entry.name} kaydedilenlerden çıkarıldı'
                  : '${widget.entry.name} removed from saved',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      final e = widget.entry;
      final newId = e.id;
      final food = SavedFood(
        id: newId,
        name: e.name,
        portionGrams: e.portionSize,
        nutritionPer100g: e.nutritionData,
        sources: const ['Geçmiş'],
        savedAt: DateTime.now(),
        imagePath: e.imagePath,
      );
      await SavedFoodsService.save(food);
      if (mounted) {
        setState(() {
          _isSaved = true;
          _savedFoodId = newId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTurkish
                  ? '${e.name} kaydedilenlere eklendi'
                  : '${e.name} added to saved',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final scaled = widget.scaled;
    final cs = widget.cs;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(e.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.40,
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: CustomSlidableAction(
                onPressed: (_) async {
                  await _toggleSaved();
                },
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(13),
                padding: EdgeInsets.zero,
                child: Icon(
                  _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomSlidableAction(
                onPressed: (_) => widget.onDelete(),
                backgroundColor: const Color(0xFFF85149),
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.circular(13),
                padding: EdgeInsets.zero,
                child: const Icon(Icons.delete_rounded, size: 24),
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                child: e.imagePath != null && File(e.imagePath!).existsSync()
                    ? Image.file(
                        File(e.imagePath!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        cacheWidth: 128,
                        cacheHeight: 128,
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: cs.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.restaurant,
                          color: cs.primary.withValues(alpha: 0.5),
                          size: 26,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${scaled.calories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _macroChip(
                            'P',
                            scaled.protein.toStringAsFixed(0),
                            const Color(0xFF7EE787),
                          ),
                          const SizedBox(width: 5),
                          _macroChip(
                            widget.isTurkish ? 'K' : 'C',
                            scaled.carbohydrates.toStringAsFixed(0),
                            const Color(0xFF58A6FF),
                          ),
                          const SizedBox(width: 5),
                          _macroChip(
                            'Y',
                            scaled.fat.toStringAsFixed(0),
                            const Color(0xFFFFCC00),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Text(
        '$label ${value}g',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DashboardFoodCard extends StatefulWidget {
  final FoodEntry entry;
  final DateTime selectedDate;
  const _DashboardFoodCard({
    required this.entry,
    required this.selectedDate,
  });

  @override
  State<_DashboardFoodCard> createState() => _DashboardFoodCardState();
}

class _DashboardFoodCardState extends State<_DashboardFoodCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_flipped) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaled = widget.entry.nutritionData.scaleBy(
      widget.entry.portionSize / 100,
    );
    final hasImage =
        widget.entry.imagePath != null &&
        widget.entry.imagePath!.isNotEmpty &&
        File(widget.entry.imagePath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _anim,
              builder: (context, _) {
                final angle = _anim.value * math.pi;
                final showBack = angle > math.pi / 2;
              final cs = Theme.of(context).colorScheme;
              final placeholderColor = isDark 
                  ? const Color(0xFF2D333B) 
                  : const Color(0xFFF0F4F8);
              final labelColor = isDark ? Colors.white70 : cs.onSurfaceVariant;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: Container(
                              color: placeholderColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  _nutriRow(
                                    context,
                                    'Protein',
                                    '${scaled.protein.toStringAsFixed(1)}g',
                                    const Color(0xFF7EE787),
                                  ),
                                  _nutriRow(
                                    context,
                                    'Karb',
                                    '${scaled.carbohydrates.toStringAsFixed(1)}g',
                                    const Color(0xFF58A6FF),
                                  ),
                                  _nutriRow(
                                    context,
                                    'Yağ',
                                    '${scaled.fat.toStringAsFixed(1)}g',
                                    const Color(0xFFFFA726),
                                  ),
                                  _nutriRow(
                                    context,
                                    'Lif',
                                    '${scaled.fiber.toStringAsFixed(1)}g',
                                    const Color(0xFFA855F7),
                                  ),

                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _showMoreNutrients(context),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          context.tr('Daha Fazla'),
                                          style: TextStyle(
                                            color: Color(0xFF58A6FF),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (isDateEditable(widget.selectedDate))
                                        IconButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ManualEntryScreen(
                                                existingEntry: widget.entry,
                                                date: widget.selectedDate,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: Color(0xFF58A6FF),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : widget.entry.imagePath != null &&
                                widget.entry.imagePath!.isNotEmpty &&
                                File(widget.entry.imagePath!).existsSync()
                            ? Image.file(
                                File(widget.entry.imagePath!),
                                fit: BoxFit.cover,
                              )
                            : widget.entry.imageUrl != null &&
                                    widget.entry.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.entry.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: placeholderColor,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary.withValues(alpha: 0.5)),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: placeholderColor,
                                      child: Center(
                                        child: Icon(
                                          Icons.restaurant_rounded,
                                          size: 48,
                                          color: cs.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: placeholderColor,
                                    child: Center(
                                      child: Icon(
                                        Icons.restaurant_rounded,
                                        size: 48,
                                        color: cs.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),

                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.entry.name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${scaled.calories.toStringAsFixed(0)} kcal',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }

  void _showMoreNutrients(BuildContext context) {
    final scaled65 = widget.entry.nutrition65per100g?.scaleBy(
      widget.entry.portionSize / 100,
    );
    final scaled = widget.entry.nutritionData.scaleBy(
      widget.entry.portionSize / 100,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        Widget section(String title, Color color) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            ctx.tr(title),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
              letterSpacing: 1.1,
            ),
          ),
        );

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.entry.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (scaled.sugar > 0)
                      _detailRow(
                        ctx,
                        'Şeker',
                        '${scaled.sugar.toStringAsFixed(1)}g',
                        const Color(0xFFFFA726),
                      ),
                    if (scaled.sodium != null && scaled.sodium! > 0)
                      _detailRow(
                        ctx,
                        'Sodyum',
                        '${scaled.sodium!.toStringAsFixed(1)}mg',
                        const Color(0xFF58A6FF),
                      ),

                    ...(() {
                        // Merge entries from both scaled (NutritionData) and scaled65 (NutritionData65)
                        final Map<String, String> allEntries = {};
                        
                        void addIfValid(String label, double? value, String unit) {
                          if (value != null && value > 0.001) {
                            String formattedVal = value.toStringAsFixed(value < 0.1 ? 3 : (value < 1 ? 2 : 1));
                            if (formattedVal.endsWith('.0')) {
                              formattedVal = formattedVal.substring(0, formattedVal.length - 2);
                            }
                            allEntries[label] = '$formattedVal$unit';
                          }
                        }

                        // Yağlar & Kolesterol
                        addIfValid('Tekli Doymamış Yağ', scaled.monoFat ?? scaled65?.monoFat, 'g');
                        addIfValid('Çoklu Doymamış Yağ', scaled.polyFat ?? scaled65?.polyFat, 'g');
                        addIfValid('Trans Yağ', scaled.transFat ?? scaled65?.transFat, 'g');
                        addIfValid('Kolesterol', scaled.cholesterol ?? scaled65?.cholesterol, 'mg');

                        // Mineraller
                        addIfValid('Selenyum', scaled.selenium ?? scaled65?.selenium, 'µg');
                        addIfValid('Magnezyum', scaled.magnesium ?? scaled65?.magnesium, 'mg');
                        addIfValid('Demir', scaled.iron ?? scaled65?.iron, 'mg');
                        addIfValid('Çinko', scaled.zinc ?? scaled65?.zinc, 'mg');
                        addIfValid('Kalsiyum', scaled.calcium ?? scaled65?.calcium, 'mg');
                        addIfValid('Potasyum', scaled.potassium ?? scaled65?.potassium, 'mg');
                        addIfValid('Fosfor', scaled.phosphorus ?? scaled65?.phosphorus, 'mg');
                        addIfValid('Bakır', scaled.copper ?? scaled65?.copper, 'mg');
                        addIfValid('Manganez', scaled.manganese ?? scaled65?.manganese, 'mg');
                        addIfValid('İyot', scaled65?.iodine, 'µg');
                        addIfValid('Krom', scaled65?.chromium, 'µg');
                        addIfValid('Molibden', scaled65?.molybdenum, 'µg');
                        addIfValid('Florür', scaled65?.fluoride, 'µg');

                        // Vitaminler
                        addIfValid('A Vitamini', scaled.vitaminA ?? scaled65?.vitA_RAE, 'µg RAE');
                        addIfValid('C Vitamini', scaled.vitaminC ?? scaled65?.vitC, 'mg');
                        addIfValid('D Vitamini', scaled.vitaminD ?? scaled65?.vitD_mcg, 'µg');
                        addIfValid('E Vitamini', scaled.vitaminE ?? scaled65?.vitE, 'mg');
                        addIfValid('K Vitamini', scaled.vitaminK ?? scaled65?.vitK, 'µg');
                        addIfValid('B12 Vitamini', scaled.vitaminB12 ?? scaled65?.vitB12, 'µg');
                        addIfValid('B1 Vitamini (Tiamin)', scaled.thiamine ?? scaled65?.thiamine, 'mg');
                        addIfValid('B2 Vitamini (Riboflavin)', scaled.riboflavin ?? scaled65?.riboflavin, 'mg');
                        addIfValid('B3 Vitamini (Niasin)', scaled.niacin ?? scaled65?.niacin, 'mg');
                        addIfValid('B5 Vitamini (Pantotenik)', scaled.pantothenic ?? scaled65?.pantothenic, 'mg');
                        addIfValid('B6 Vitamini', scaled.vitaminB6 ?? scaled65?.vitB6, 'mg');
                        addIfValid('Folat', scaled.folate ?? scaled65?.folate, 'µg');
                        addIfValid('Kolin', scaled.choline ?? scaled65?.choline, 'mg');
                        addIfValid('Biyotin', scaled.biotin ?? scaled65?.biotin, 'µg');

                        // Yağ Asitleri
                        addIfValid('Omega-3', scaled.omega3 ?? scaled65?.omega3, 'g');
                        addIfValid('Omega-6', scaled.omega6 ?? scaled65?.omega6, 'g');
                        addIfValid('ALA', scaled.ala ?? scaled65?.ala, 'g');
                        addIfValid('EPA', scaled.epa ?? scaled65?.epa, 'g');
                        addIfValid('DHA', scaled.dha ?? scaled65?.dha, 'g');

                        // Amino Asitler
                        addIfValid('Triptofan', scaled.tryptophan ?? scaled65?.tryptophan, 'g');
                        addIfValid('Treonin', scaled.threonine ?? scaled65?.threonine, 'g');
                        addIfValid('İzolösin', scaled.isoleucine ?? scaled65?.isoleucine, 'g');
                        addIfValid('Lösin', scaled.leucine ?? scaled65?.leucine, 'g');
                        addIfValid('Lisin', scaled.lysine ?? scaled65?.lysine, 'g');
                        addIfValid('Metiyonin', scaled.methionine ?? scaled65?.methionine, 'g');
                        addIfValid('Fenilalanin', scaled.phenylalanine ?? scaled65?.phenylalanine, 'g');
                        addIfValid('Valin', scaled.valine ?? scaled65?.valine, 'g');
                        addIfValid('Histidin', scaled.histidine ?? scaled65?.histidine, 'g');

                        // Karotenoidler
                        addIfValid('Beta-Karoten', scaled.betaCarotene ?? scaled65?.betaCarot, 'µg');
                        addIfValid('Likopen', scaled.lycopene ?? scaled65?.lycopene, 'µg');
                        addIfValid('Lutein & Zeaksantin', scaled.luteinZeaxanthin ?? scaled65?.luteinZea, 'µg');
                        addIfValid('Alfa-Karoten', scaled.alphaCarotene ?? scaled65?.alphaCarot, 'µg');

                        final minerals = [
                          'Kalsiyum', 'Demir', 'Magnezyum', 'Fosfor', 'Potasyum', 'Çinko', 'Bakır',
                          'Manganez', 'Selenyum', 'İyot', 'Krom', 'Molibden', 'Florür',
                        ];

                        final mineralEntries = allEntries.entries
                            .where((e) => minerals.contains(e.key))
                            .toList();
                        final vitaminEntries = allEntries.entries
                            .where((e) => e.key.contains('Vitamini') || 
                                         ['Folat', 'Biotin', 'Kolin', 'Betain'].contains(e.key))
                            .toList();
                        final otherEntries = allEntries.entries
                            .where((e) => !minerals.contains(e.key) && 
                                         !e.key.contains('Vitamini') &&
                                         !['Folat', 'Biotin', 'Kolin', 'Betain'].contains(e.key))
                            .toList();

                        return [
                          if (mineralEntries.isNotEmpty) ...[
                            section('MİNERALLER', const Color(0xFF58A6FF)),
                            ...mineralEntries.map(
                              (e) => _detailRow(
                                ctx,
                                e.key,
                                e.value,
                                const Color(0xFF58A6FF),
                              ),
                            ),
                          ],
                          if (vitaminEntries.isNotEmpty) ...[
                            section('VİTAMİNLER', const Color(0xFFFFA726)),
                            ...vitaminEntries.map(
                              (e) => _detailRow(
                                ctx,
                                e.key,
                                e.value,
                                const Color(0xFFFFA726),
                              ),
                            ),
                          ],
                          if (otherEntries.isNotEmpty) ...[
                            section('DİĞER BESİNLER', const Color(0xFF7EE787)),
                            ...otherEntries.map(
                              (e) => _detailRow(
                                ctx,
                                e.key,
                                e.value,
                                const Color(0xFF7EE787),
                              ),
                            ),
                          ],
                        ];
                      })(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, [Color? color]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = (color != null) 
        ? (isDark ? color : Color.lerp(color, Colors.black, 0.4) ?? color)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr(label),
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutriRow(BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final valueColor = isDark ? color : Color.lerp(color, Colors.black, 0.45) ?? color;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(center: Offset(radius, radius), radius: radius);

    // simple dashed circle using path metric or manual arc
    // For simplicity, draw dotted path around circle
    final Path path = Path()..addOval(rect);
    
    // Let's use standard dash drawing via dash segments
    final metrics = path.computeMetrics().toList()[0];
    final Path dashedPath = Path();
    double distance = 0.0;
    while (distance < metrics.length) {
      dashedPath.addPath(
        metrics.extractPath(distance, distance + dashWidth),
        Offset.zero,
      );
      distance += dashWidth + dashSpace;
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _CalendarStrip({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  late PageController _pageController;
  final int _maxWeeksBack = 4;
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final weekStartDay = context.read<ProfileProvider>().weekStartDay;
    int diff = now.weekday - weekStartDay;
    if (diff < 0) diff += 7;
    _currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: diff));

    // Calculate initial page based on widget.selectedDate
    int selDiff = widget.selectedDate.weekday - weekStartDay;
    if (selDiff < 0) selDiff += 7;
    final selectedWeekStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day).subtract(Duration(days: selDiff));
    final weekOffset = selectedWeekStart.difference(_currentWeekStart).inDays ~/ 7;
    final initialPage = (_maxWeeksBack + weekOffset).clamp(0, _maxWeeksBack);

    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void didUpdateWidget(covariant _CalendarStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      final weekStartDay = context.read<ProfileProvider>().weekStartDay;
      int selDiff = widget.selectedDate.weekday - weekStartDay;
      if (selDiff < 0) selDiff += 7;
      final selectedWeekStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day).subtract(Duration(days: selDiff));
      final weekOffset = selectedWeekStart.difference(_currentWeekStart).inDays ~/ 7;
      final targetPage = (_maxWeeksBack + weekOffset).clamp(0, _maxWeeksBack);

      if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Consumer2<NutritionProvider, ProfileProvider>(
      builder: (context, provider, profileProvider, _) {
        final calorieGoal = profileProvider.calorieGoal;
        final proteinGoal = profileProvider.proteinGoal;
        final carbGoal = profileProvider.carbGoal;
        final fatGoal = profileProvider.fatGoal;
        final waterGoalMl = profileProvider.waterGoalMl.toDouble();

        return Container(
          height: 125,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8F9FA),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _maxWeeksBack + 1,
            itemBuilder: (context, pageIndex) {
              final weekOffset = pageIndex - _maxWeeksBack;
              final weekStart = _currentWeekStart.add(Duration(days: weekOffset * 7));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double totalWidth = constraints.maxWidth;
                  final double dayWidth = 46.0;
                  final double totalDayWidth = 7 * dayWidth;
                  final double remainingSpace = totalWidth - totalDayWidth;
                  final double gap = remainingSpace / 8; // spacing between days

                  final List<Widget> rowChildren = [];

                  for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
                    final date = weekStart.add(Duration(days: dayIndex));
                    
                    // Strip time from 'now' to compare dates properly
                    final todayDate = DateTime(now.year, now.month, now.day);
                    final compareDate = DateTime(date.year, date.month, date.day);
                    
                    final isSelected = compareDate.year == widget.selectedDate.year && compareDate.month == widget.selectedDate.month && compareDate.day == widget.selectedDate.day;
                    final isToday = compareDate.isAtSameMomentAs(todayDate);
                    final isFuture = compareDate.isAfter(todayDate);
                    final isPast = compareDate.isBefore(todayDate);
                    
                    final goalMet = provider.isGoalMet(
                      date,
                      calorieGoal: calorieGoal,
                      proteinGoal: proteinGoal,
                      carbGoal: carbGoal,
                      fatGoal: fatGoal,
                      waterGoalMl: waterGoalMl,
                    );

                    final bool isFirstDay = compareDate.day == 1;

                    Widget selectionContainer = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E', AppLocalizations.of(context).isTurkish ? 'tr_TR' : 'en_US').format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.black54 : Colors.grey.shade500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CustomPaint(
                            painter: isSelected && isPast
                              ? _DashedBorderPainter(
                                  color: const Color(0xFF58A6FF),
                                  strokeWidth: 2.0,
                                )
                              : null,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: isToday 
                                    ? Border.all(color: const Color(0xFFFFA000), width: 2.0)
                                    : (!isSelected && isPast) 
                                        ? Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.3), width: 1.5)
                                        : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                DateFormat('dd').format(date),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected 
                                      ? Colors.black 
                                      : (isToday 
                                          ? (isDark ? const Color(0xFFFFB300) : const Color(0xFFE65100))
                                          : (isDark ? const Color(0xFFC9D1D9) : Colors.black87)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );

                    Widget clickableDay = GestureDetector(
                      onTap: isFuture ? null : () => widget.onDateSelected(date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: dayWidth,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? (isDark ? const Color(0xFFC9D1D9) : Colors.white) 
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
                        ),
                        child: selectionContainer,
                      ),
                    );

                    Widget dayCell = Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        clickableDay,
                        if (isFirstDay)
                          Positioned(
                            left: -gap / 2 - 3.0,
                            top: 8,
                            bottom: 8,
                            width: 6,
                            child: CustomPaint(
                              painter: _WavyLinePainter(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                            ),
                          ),
                      ],
                    );

                    Widget fullDayColumn = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 14,
                          width: dayWidth,
                          child: (dayIndex == 0)
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  DateFormat('MMMM', AppLocalizations.of(context).isTurkish ? 'tr_TR' : 'en_US').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark ? const Color(0xFF8B949E) : Colors.black54,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            : const SizedBox(height: 14),
                        ),
                        const SizedBox(height: 4),
                        dayCell,
                      ],
                    );

                    rowChildren.add(fullDayColumn);
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: rowChildren,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _WavyLinePainter extends CustomPainter {
  final Color color;
  _WavyLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width / 2, 0);

    double y = 0;
    double amplitude = 2.0;
    double wavelength = 12.0;

    while (y < size.height) {
      path.relativeQuadraticBezierTo(
        amplitude,
        wavelength / 4,
        0,
        wavelength / 2,
      );
      path.relativeQuadraticBezierTo(
        -amplitude,
        wavelength / 4,
        0,
        wavelength / 2,
      );
      y += wavelength;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
