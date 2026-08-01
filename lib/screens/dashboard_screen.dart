import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../widgets/food_entry_detail_sheet.dart';
import '../providers/fasting_provider.dart';
import '../services/device_id_service.dart';
import '../services/health_service.dart';
import '../services/saved_foods_service.dart';
import '../services/sync_service.dart';
import '../widgets/animated_widgets.dart';
import '../models/supplement_model.dart';
import '../widgets/supplement_management_sheet.dart';
import '../services/notification_service.dart';
import 'wc_tracking_screen.dart';
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

enum MicroCategory {
  all('Tümü', Color(0xFFD97706)),
  starred('Yıldızlılar', Color(0xFFFFB800)),
  vitamin('Vitaminler', Color(0xFFF59E0B)),
  mineral('Mineraller', Color(0xFF06B6D4)),
  fat('Yağlar', Color(0xFF10B981)),
  antioxidant('Antioksidanlar', Color(0xFF8B5CF6)),
  amino('Amino Asitler', Color(0xFFEC4899)),
  carb('Diğer', Color(0xFF3B82F6));

  final String displayName;
  final Color color;
  const MicroCategory(this.displayName, this.color);
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
  Timer? _updateTimer;
  DateTime _selectedDate = DateTime.now();
  bool _lastHealthSyncEnabled = false;

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final Map<String, Set<String>> _checkedSupplementsPerDate = {};
  final List<String> _supplementList = ['Omega-3', 'C-vitamini', 'D-vitamini'];

  // User Starred Micronutrients List (Max 6)
  List<String> _starredMicroKeys = [];

  // Calorie Bar Percentage Toggle State
  bool _showCaloriePercentage = false;
  Timer? _caloriePercentageTimer;

  // Supplements PageView Controller & Current Page
  int _supplementsPage = 0;
  late PageController _supplementsPageController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _supplementsPageController = PageController();

    final profileProvider = context.read<ProfileProvider>();
    _lastHealthSyncEnabled = profileProvider.healthSyncEnabled;
    profileProvider.addListener(_handleProfileChange);

    _loadStarredMicros();
    _loadSteps();
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _loadSteps();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateChanged?.call(_selectedDate);
    });
  }

  // Load Starred Micronutrients from Database (Firestore) & SharedPreferences
  Future<void> _loadStarredMicros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = prefs.getStringList('starred_micro_keys');
      if (loaded != null && loaded.isNotEmpty) {
        if (mounted) {
          setState(() {
            _starredMicroKeys = loaded.take(6).toList();
          });
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null && doc.data()!['starred_micro_keys'] != null) {
          final remote = List<String>.from(doc.data()!['starred_micro_keys'] as List);
          if (remote.isNotEmpty && mounted) {
            setState(() {
              _starredMicroKeys = remote.take(6).toList();
            });
            await prefs.setStringList('starred_micro_keys', _starredMicroKeys);
          }
        }
      }
    } catch (e) {
      debugPrint('[Dashboard] Error loading starred micros: $e');
    }
  }

  // Save Starred Micronutrients to Database (Firestore) & SharedPreferences
  Future<void> _saveStarredMicros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('starred_micro_keys', _starredMicroKeys);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'starred_micro_keys': _starredMicroKeys,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[Dashboard] Error saving starred micros: $e');
    }
  }

  void _onScroll() {
    if (mounted) {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    }
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

  void _handleProfileChange() {
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.healthSyncEnabled && !_lastHealthSyncEnabled) {
      _loadSteps();
    }
    _lastHealthSyncEnabled = profileProvider.healthSyncEnabled;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _supplementsPageController.dispose();
    context.read<ProfileProvider>().removeListener(_handleProfileChange);
    _updateTimer?.cancel();
    _caloriePercentageTimer?.cancel();
    super.dispose();
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
        
        SyncService.instance.syncSteps(DateTime.now(), data.steps);
      } catch (e) {
        debugPrint('[Dashboard] Health error: $e');
      }
    } else {
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

  void _changeDate(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    widget.onDateChanged?.call(newDate);
    _loadSteps();
  }

  Future<bool> _confirmPastDateAction(BuildContext context, DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gelecek tarihler için kayıt eklenemez veya değiştirilemez.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (target.isAtSameMomentAs(today)) {
      return true;
    }

    final dateStr = DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C2128) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Text('Tarih Değişiklik Onayı', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Değişikliği $dateStr tarihi için yapıyorsunuz. Emin misiniz?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Evet', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _selectDateViaPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomCalendarSheet(
        initialDate: _selectedDate,
        onDateSelected: (date) {
          _changeDate(date);
          Navigator.pop(ctx);
        },
        isDark: isDark,
      ),
    );
  }

  void _showWaterAddSheet(
    BuildContext context,
    NutritionProvider provider,
    DailyLog selectedLog, {
    bool isRemove = false,
  }) async {
    if (!await _confirmPastDateAction(context, _selectedDate)) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WaterAddSheet(
        onAdd: (signedMl) {
          provider.updateWater(
            (selectedLog.waterIntakeMl + signedMl).clamp(0.0, double.infinity),
            date: _selectedDate,
            deltaAmount: signedMl,
          );
        },
        isRemove: isRemove,
        currentWaterMl: selectedLog.waterIntakeMl,
      ),
    );
  }

  void _showAddMealOptions(String mealType) async {
    if (!await _confirmPastDateAction(context, _selectedDate)) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1E2B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${context.tr('Öğün Ekle')} - ${_getMealDisplayName(mealType)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOptionItem(
                    icon: Icons.camera_alt_rounded,
                    label: context.tr('Kamera'),
                    color: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMealAddPressed?.call(mealType, 'camera', _selectedDate);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.qr_code_scanner_rounded,
                    label: context.tr('Barkod'),
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMealAddPressed?.call(mealType, 'barcode', _selectedDate);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.edit_note_rounded,
                    label: context.tr('Manuel'),
                    color: const Color(0xFF16A34A),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMealAddPressed?.call(mealType, 'manual', _selectedDate);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.mic_rounded,
                    label: context.tr('Sesli'),
                    color: const Color(0xFF9333EA),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onMealAddPressed?.call(mealType, 'voice', _selectedDate);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.0),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getMealDisplayName(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'kahvaltı':
      case 'breakfast':
        return context.tr('Kahvaltı');
      case 'kahvaltı sonrası ara öğün':
      case 'morning_snack':
        return context.tr('Kahvaltı sonrası ara öğün');
      case 'öğle yemeği':
      case 'lunch':
        return context.tr('Öğle Yemeği');
      case 'öğle sonrası ara öğün':
      case 'afternoon_snack':
        return context.tr('Öğle sonrası ara öğün');
      case 'akşam yemeği':
      case 'dinner':
        return context.tr('Akşam Yemeği');
      case 'gece atıştırmalığı':
      case 'night_snack':
        return context.tr('Gece Atıştırmalığı');
      default:
        return mealType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutritionProvider = context.watch<NutritionProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final wellnessProvider = context.watch<WellnessProvider>();
    
    final dailyLog = nutritionProvider.getOrCreateLogForDate(_selectedDate);
    final totalNutrition = dailyLog.totalNutrition;
    
    final calorieGoal = profileProvider.activeProfile?.calorieGoal ?? 2000.0;
    final consumedCal = totalNutrition.calories;
    final remainingCal = math.max(0.0, calorieGoal - consumedCal);
    final calorieProgress = calorieGoal > 0 ? (consumedCal / calorieGoal).clamp(0.0, 1.0) : 0.0;

    // Macro targets
    final carbGoal = profileProvider.activeProfile?.carbGoal ?? ((calorieGoal * 0.50) / 4);
    final proteinGoal = profileProvider.activeProfile?.proteinGoal ?? ((calorieGoal * 0.25) / 4);
    final fatGoal = profileProvider.activeProfile?.fatGoal ?? ((calorieGoal * 0.25) / 9);
    final fiberGoal = profileProvider.activeProfile?.fiberGoal ?? 30.0;

    final carbConsumed = totalNutrition.carbohydrates;
    final proteinConsumed = totalNutrition.protein;
    final fatConsumed = totalNutrition.fat;
    final fiberConsumed = totalNutrition.fiber;

    final carbPct = carbGoal > 0 ? (carbConsumed / carbGoal * 100).round() : 0;
    final proteinPct = proteinGoal > 0 ? (proteinConsumed / proteinGoal * 100).round() : 0;
    final fatPct = fatGoal > 0 ? (fatConsumed / fatGoal * 100).round() : 0;
    final fiberPct = fiberGoal > 0 ? (fiberConsumed / fiberGoal * 100).round() : 0;

    final carbRem = math.max(0.0, carbGoal - carbConsumed).round();
    final proteinRem = math.max(0.0, proteinGoal - proteinConsumed).round();
    final fatRem = math.max(0.0, fatGoal - fatConsumed).round();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F121C) : const Color(0xFFF5F6FA);

    // Compute collapse factor (0.0 = top, 1.0 = scrolled down)
    final collapseFactor = (_scrollOffset / 75.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── STICKY UPPER HEADER ──
            _buildStickyHeader(
              context: context,
              consumedCal: consumedCal.round(),
              remainingCal: remainingCal.round(),
              calorieProgress: calorieProgress,
              carbPct: carbPct,
              carbSubtitle: '${carbRem}g kaldı',
              carbProgress: carbGoal > 0 ? carbConsumed / carbGoal : 0.0,
              proteinPct: proteinPct,
              proteinSubtitle: '${proteinRem}g kaldı',
              proteinProgress: proteinGoal > 0 ? proteinConsumed / proteinGoal : 0.0,
              fatPct: fatPct,
              fatSubtitle: '${fatRem}g kaldı',
              fatProgress: fatGoal > 0 ? fatConsumed / fatGoal : 0.0,
              fiberPct: fiberPct,
              fiberSubtitle: '${fiberConsumed.round()}g/${fiberGoal.round()}g',
              fiberProgress: fiberGoal > 0 ? fiberConsumed / fiberGoal : 0.0,
              collapseFactor: collapseFactor,
              isDark: isDark,
            ),
            
            // ── SCROLLABLE BODY ──
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Su Takibi (flex: 2) & Mikro Besinler (flex: 3)
                    SizedBox(
                      height: 165,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildWaterTrackingCard(
                              context: context,
                              dailyLog: dailyLog,
                              nutritionProvider: nutritionProvider,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildMicronutrientsCard(
                              context: context,
                              dailyLog: dailyLog,
                              profileProvider: profileProvider,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ROW 2: Günlük Sağlık (flex: 3) & Takviye (flex: 2) - SU TAKİBİ İLE EŞİT 165px YÜKSEKLİK
                    SizedBox(
                      height: 165,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildDailyHealthCard(
                              context: context,
                              wellnessProvider: wellnessProvider,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildSupplementBox(
                              context: context,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ÖĞÜNLER KISMI
                    _buildMealsSection(
                      context: context,
                      dailyLog: dailyLog,
                      nutritionProvider: nutritionProvider,
                      calorieGoal: calorieGoal,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STICKY HEADER ──
  Widget _buildStickyHeader({
    required BuildContext context,
    required int consumedCal,
    required int remainingCal,
    required double calorieProgress,
    required int carbPct,
    required String carbSubtitle,
    required double carbProgress,
    required int proteinPct,
    required String proteinSubtitle,
    required double proteinProgress,
    required int fatPct,
    required String fatSubtitle,
    required double fatProgress,
    required int fiberPct,
    required String fiberSubtitle,
    required double fiberProgress,
    required double collapseFactor,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF181B28) : Colors.white;
    final headerBg = isDark ? const Color(0xFF0F121C) : const Color(0xFFF5F6FA);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateStr = DateFormat('EEEE, d MMMM', 'tr_TR').format(_selectedDate);

    return Container(
      color: headerBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title & Date & Calendar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LensEat',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isToday ? 'Bugün, $dateStr' : dateStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _selectDateViaPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2333) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black.withValues(alpha: 0.87),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calorie Bar Container (Tap toggles percentage / kcal mode)
          GestureDetector(
            onTap: () {
              setState(() {
                _showCaloriePercentage = !_showCaloriePercentage;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Builder(
                builder: (context) {
                  final goal = context.read<ProfileProvider>().activeProfile?.calorieGoal ?? 2000.0;
                  final isOverLimit = consumedCal > goal;
                  final excessCal = (consumedCal - goal).round();
                  final isTr = AppLocalizations.of(context).isTurkish;

                  final consumedPct = goal > 0 ? (consumedCal / goal * 100).round() : 0;
                  final excessPct = goal > 0 ? ((consumedCal - goal) / goal * 100).round() : 0;
                  final remainingPct = goal > 0 ? ((goal - consumedCal) / goal * 100).round() : 0;

                  String leadVal = _showCaloriePercentage ? '%$consumedPct' : '$consumedCal';
                  String leadUnit = _showCaloriePercentage ? '' : ' kcal';
                  String secondVal = _showCaloriePercentage
                      ? (isOverLimit ? '%$excessPct' : '%$remainingPct')
                      : '${isOverLimit ? excessCal : remainingCal}';
                  String secondUnit = _showCaloriePercentage ? '' : ' kcal';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.9),
                            ),
                            children: isOverLimit
                                ? [
                                    TextSpan(
                                      text: '$leadVal$leadUnit ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: isTr ? 'kalori aldınız, ' : 'consumed, '),
                                    TextSpan(
                                      text: '$secondVal$secondUnit ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text: isTr ? 'kalori fazlanız var!' : 'over target!',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ]
                                : [
                                    TextSpan(
                                      text: '$leadVal$leadUnit ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: isTr ? 'kalori aldınız, ' : 'consumed, '),
                                    TextSpan(
                                      text: '$secondVal$secondUnit ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: isTr ? 'kalori daha yiyebilirsiniz!' : 'remaining!'),
                                  ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: calorieProgress),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (ctx, animVal, child) {
                            return LinearProgressIndicator(
                              value: animVal,
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF2B2F42) : Colors.grey.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4 Macro Items Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroMorphItem(
                label: 'PROTEİN',
                percentTextVal: proteinPct,
                subtitle: proteinSubtitle,
                progress: proteinProgress,
                color: const Color(0xFFE11D48),
                darkBaseColor: const Color(0xFF4C0816),
                collapseFactor: collapseFactor,
                isDark: isDark,
              ),
              _buildMacroMorphItem(
                label: 'KARBONHİDRAT',
                percentTextVal: carbPct,
                subtitle: carbSubtitle,
                progress: carbProgress,
                color: const Color(0xFFD97706),
                darkBaseColor: const Color(0xFF4A2800),
                collapseFactor: collapseFactor,
                isDark: isDark,
              ),
              _buildMacroMorphItem(
                label: 'YAĞ',
                percentTextVal: fatPct,
                subtitle: fatSubtitle,
                progress: fatProgress,
                color: const Color(0xFF8B5CF6),
                darkBaseColor: const Color(0xFF2C1656),
                collapseFactor: collapseFactor,
                isDark: isDark,
              ),
              _buildMacroMorphItem(
                label: 'LİF',
                percentTextVal: fiberPct,
                subtitle: fiberSubtitle,
                progress: fiberProgress,
                color: const Color(0xFF10B981),
                darkBaseColor: const Color(0xFF043825),
                collapseFactor: collapseFactor,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMorphItem({
    required String label,
    required int percentTextVal,
    required String subtitle,
    required double progress,
    required Color color,
    required Color darkBaseColor,
    required double collapseFactor,
    required bool isDark,
  }) {
    final ringBg = isDark ? const Color(0xFF222536) : Colors.black.withValues(alpha: 0.08);

    final barTrackBg = progress > 1.0
        ? darkBaseColor
        : (isDark ? const Color(0xFF1B1E2D) : Colors.black.withValues(alpha: 0.05));

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          SizedBox(
            height: lerpDouble(52.0, 14.0, collapseFactor)!,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (collapseFactor < 0.95)
                  Opacity(
                    opacity: (1.0 - collapseFactor * 1.25).clamp(0.0, 1.0),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: CustomPaint(
                        painter: _RingProgressPainter(
                          progress: progress,
                          color: color,
                          darkBaseColor: darkBaseColor,
                          backgroundColor: ringBg,
                          strokeWidth: 5.0,
                        ),
                        child: Center(
                          child: Text(
                            '%$percentTextVal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (collapseFactor > 0.05)
                  Opacity(
                    opacity: (collapseFactor * 1.25).clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: barTrackBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: color.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress > 1.0
                              ? (progress - 1.0).clamp(0.0, 1.0)
                              : progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: collapseFactor > 0.5 ? FontWeight.w600 : FontWeight.normal,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── WATER TRACKING CARD ──
  Widget _buildWaterTrackingCard({
    required BuildContext context,
    required DailyLog dailyLog,
    required NutritionProvider nutritionProvider,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF181B28) : Colors.white;
    final waterMl = dailyLog.waterIntakeMl;
    final targetMl = 2500.0;
    final pct = (waterMl / targetMl * 100).round();
    final fillRatio = (waterMl / targetMl).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _showWaterAddSheet(context, nutritionProvider, dailyLog),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Su Takibi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => _showWaterAddSheet(context, nutritionProvider, dailyLog),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: fillRatio),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            size: 68,
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          ),
                          ClipRect(
                            clipper: _BottomToTopClipper(val),
                            child: const Icon(
                              Icons.water_drop_rounded,
                              size: 68,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '%$pct',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${waterMl.round()} / ${targetMl.round()} ml',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  // ── LEGACY MICRO SCORE CALCULATION ──
  double _calcLegacyMicroScore(DailyLog dailyLog, ProfileProvider profileProvider) {
    final pp = profileProvider;
    final profile = pp.activeProfile;
    if (profile == null || pp.calorieGoal <= 0) return 0;
    final n = dailyLog.totalNutrition;
    if (n.calories <= 0) return 0;

    double s(double? c, double g) {
      final val = (c != null && c > 0) ? c : 0.0;
      return g <= 0 ? 100 : (val / g).clamp(0.0, 1.0) * 100;
    }

    double si(double? c, double l) {
      final val = (c != null && c > 0) ? c : 0.0;
      return l <= 0 ? 0 : (val / l).clamp(0.0, 1.0) * 100;
    }

    double avg(List<double> list) =>
        list.isEmpty ? 50 : list.reduce((a, b) => a + b) / list.length;

    final vitScore = avg([
      s(n.vitaminC, 90.0),
      s(n.vitaminD, profile.vitaminDGoal),
      s(n.vitaminB12, profile.vitaminB12Goal),
      s(n.vitaminA, 900.0),
      s(n.folate, 400.0),
      s(n.vitaminE, 15.0),
      s(n.vitaminK, 120.0),
      s(n.thiamine, 1.2),
      s(n.riboflavin, 1.3),
      s(n.niacin, 16.0),
      s(n.vitaminB6, 1.7),
      s(n.pantothenic, 5.0),
      s(n.biotin, 30.0),
      s(n.choline, 550.0),
    ]);

    final minScore = avg([
      s(n.iron, profile.ironGoal),
      s(n.calcium, profile.calciumGoal),
      s(n.magnesium, profile.magnesiumGoal),
      s(n.zinc, profile.zincGoal),
      s(n.potassium, profile.potassiumGoal),
      si(n.sodium, profile.sodiumLimit),
      s(n.selenium, profile.seleniumGoal),
      s(n.copper, 0.9),
      s(n.manganese, 2.3),
      s(n.phosphorus, 700.0),
    ]);

    final essentialScore = avg([
      s(n.omega3, 1.6),
      s(n.omega6, 17.0),
      s(n.tryptophan, 0.28),
      s(n.leucine, 2.73),
      s(n.lysine, 2.1),
      s(n.valine, 1.82),
    ]);

    final antioxidantScore = avg([
      s(n.betaCarotene, 3000.0),
      s(n.lycopene, 10000.0),
      s(n.luteinZeaxanthin, 6000.0),
    ]);

    return (vitScore * 0.30 +
            minScore * 0.30 +
            essentialScore * 0.25 +
            antioxidantScore * 0.15)
        .clamp(0.0, 100.0);
  }

  // Get dynamic 6 micro badges with full definitions for Ana Menü
  List<_MicroItemDef> _getDisplaySixMicroDefs(DailyLog dailyLog) {
    final allDefs = _getListOfAllMicros(dailyLog.totalNutrition);
    final result = <_MicroItemDef>[];

    for (final key in _starredMicroKeys) {
      if (result.length >= 6) break;
      final found = allDefs.firstWhere(
        (m) => m.key == key,
        orElse: () => _MicroItemDef(key: key, name: key, code: _getShortCode(key), current: 0, target: 1.0, unit: '', category: MicroCategory.vitamin),
      );
      result.add(found);
    }

    final defaults = ['D-Vit', 'Omega-3', 'B12', 'Demir', 'C-Vit', 'Magnezyum'];
    for (final defKey in defaults) {
      if (result.length >= 6) break;
      final isAlreadyIn = result.any((r) => r.key == defKey);
      if (!isAlreadyIn) {
        final found = allDefs.firstWhere(
          (m) => m.key == defKey,
          orElse: () => _MicroItemDef(key: defKey, name: defKey, code: _getShortCode(defKey), current: 0, target: 1.0, unit: '', category: MicroCategory.vitamin),
        );
        result.add(found);
      }
    }

    return result;
  }

  // ── MICRONUTRIENTS CARD ON ANA MENÜ (ANIMATED PROGRESS RINGS, NO TEXT INSIDE RING) ──
  Widget _buildMicronutrientsCard({
    required BuildContext context,
    required DailyLog dailyLog,
    required ProfileProvider profileProvider,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF181B28) : Colors.white;
    final scoreValue = _calcLegacyMicroScore(dailyLog, profileProvider).round();
    final sixDefs = _getDisplaySixMicroDefs(dailyLog);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Mikro Besinler',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Score Ring Circle (% Score) with smooth value transition
              SizedBox(
                width: 54,
                height: 54,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: scoreValue / 100.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, animProgress, child) {
                    final animScore = (animProgress * 100.0).round();
                    return CustomPaint(
                      painter: _RingProgressPainter(
                        progress: animProgress,
                        color: const Color(0xFFD97706),
                        darkBaseColor: const Color(0xFF4A2800),
                        backgroundColor: isDark ? const Color(0xFF282C3D) : Colors.grey.withValues(alpha: 0.2),
                        strokeWidth: 5.0,
                      ),
                      child: Center(
                        child: Text(
                          '%$animScore',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 6 Animated Mini Progress Rings in 2 Rows of 3 Badges (NO TEXT INSIDE RING)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: sixDefs.take(3).map((itemDef) {
                        return _buildMiniProgressRingBadge(itemDef, isDark);
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: sixDefs.skip(3).take(3).map((itemDef) {
                        return _buildMiniProgressRingBadge(itemDef, isDark);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // "Daha fazlasını göster →" Button
          InkWell(
            onTap: () {
              _showMicronutrientsDetailSheet(context, dailyLog, isDark);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Daha fazlasını göster →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mini progress ring badge without text inside, smoothly animated on food logging
  Widget _buildMiniProgressRingBadge(_MicroItemDef itemDef, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: itemDef.progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (ctx, animVal, child) {
              return CustomPaint(
                painter: _RingProgressPainter(
                  progress: animVal,
                  color: itemDef.category.color,
                  darkBaseColor: itemDef.category.color.withValues(alpha: 0.35),
                  backgroundColor: isDark ? const Color(0xFF232738) : Colors.black.withValues(alpha: 0.08),
                  strokeWidth: 2.8,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Text(
          itemDef.code,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _getShortCode(String key) {
    switch (key) {
      case 'D-Vit': return 'D-Vit';
      case 'C-Vit': return 'C-Vit';
      case 'B12': return 'B12';
      case 'A-Vit': return 'A-Vit';
      case 'E-Vit': return 'E-Vit';
      case 'K-Vit': return 'K-Vit';
      case 'B1': return 'B1';
      case 'B2': return 'B2';
      case 'B3': return 'B3';
      case 'B5': return 'B5';
      case 'B6': return 'B6';
      case 'B7': return 'B7';
      case 'B9': return 'B9';
      case 'Kolin': return 'Kolin';
      case 'Demir': return 'Demir';
      case 'Magnezyum': return 'Mg';
      case 'Kalsiyum': return 'Ca';
      case 'Potasyum': return 'K+';
      case 'Sodyum': return 'Na';
      case 'Çinko': return 'Zn';
      case 'Bakır': return 'Cu';
      case 'Manganez': return 'Mn';
      case 'Selenyum': return 'Se';
      case 'Fosfor': return 'P';
      case 'Omega-3': return 'Omg3';
      case 'Omega-6': return 'Omg6';
      case 'ALA': return 'ALA';
      case 'EPA': return 'EPA';
      case 'DHA': return 'DHA';
      case 'Kolesterol': return 'Chol';
      case 'Doymuş Yağ': return 'Sat';
      case 'Tekli Doymamış': return 'Mono';
      case 'Çoklu Doymamış': return 'Poly';
      case 'Trans Yağ': return 'Trns';
      case 'Beta-Karoten': return 'bCar';
      case 'Likopen': return 'Lyc';
      case 'Lutein-Zea': return 'Lut';
      case 'Alfa-Karoten': return 'aCar';
      case 'Lösin': return 'Leu';
      case 'Lizin': return 'Lys';
      case 'İzolösin': return 'Ile';
      case 'Valin': return 'Val';
      case 'Treonin': return 'Thr';
      case 'Metiyonin': return 'Met';
      case 'Fenilalanin': return 'Phe';
      case 'Triptofan': return 'Trp';
      case 'Histidin': return 'His';
      case 'Lif': return 'Lif';
      case 'Şeker': return 'Şeker';
      default: return key.length > 5 ? key.substring(0, 5) : key;
    }
  }

  // Comprehensive list of all 46 calculable micronutrients
  List<_MicroItemDef> _getListOfAllMicros(NutritionData t, {Map<String, double>? supplementAdditions}) {
    double getVal(String key, double baseVal) {
      final extra = supplementAdditions?[key] ?? 0.0;
      return baseVal + extra;
    }

    return [
      // ── VİTAMİNLER (14) ──
      _MicroItemDef(key: 'D-Vit', name: 'D Vitamini', code: 'D-Vit', current: getVal('D-Vit', t.vitaminD ?? 0), target: 15.0, unit: 'mcg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'C-Vit', name: 'C Vitamini', code: 'C-Vit', current: getVal('C-Vit', t.vitaminC ?? 0), target: 90.0, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B12', name: 'B12 Vitamini', code: 'B12', current: getVal('B12', t.vitaminB12 ?? 0), target: 2.4, unit: 'mcg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'A-Vit', name: 'A Vitamini', code: 'A-Vit', current: getVal('A-Vit', t.vitaminA ?? 0), target: 900.0, unit: 'mcg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'E-Vit', name: 'E Vitamini', code: 'E-Vit', current: getVal('E-Vit', t.vitaminE ?? 0), target: 15.0, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'K-Vit', name: 'K Vitamini', code: 'K-Vit', current: getVal('K-Vit', t.vitaminK ?? 0), target: 120.0, unit: 'mcg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B1', name: 'B1 (Tiamin)', code: 'B1', current: getVal('B1', t.thiamine ?? 0), target: 1.2, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B2', name: 'B2 (Riboflavin)', code: 'B2', current: getVal('B2', t.riboflavin ?? 0), target: 1.3, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B3', name: 'B3 (Niasin)', code: 'B3', current: getVal('B3', t.niacin ?? 0), target: 16.0, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B5', name: 'B5 (Pantotenik)', code: 'B5', current: getVal('B5', t.pantothenic ?? 0), target: 5.0, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B6', name: 'B6 Vitamini', code: 'B6', current: getVal('B6', t.vitaminB6 ?? 0), target: 1.7, unit: 'mg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B7', name: 'B7 (Biyotin)', code: 'B7', current: getVal('B7', t.biotin ?? 0), target: 30.0, unit: 'mcg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'B9', name: 'B9 (Folat)', code: 'B9', current: getVal('B9', t.folate ?? 0), target: 400.0, unit: 'mcg', category: MicroCategory.vitamin),
      _MicroItemDef(key: 'Kolin', name: 'Kolin', code: 'Kolin', current: getVal('Kolin', t.choline ?? 0), target: 550.0, unit: 'mg', category: MicroCategory.vitamin),

      // ── MİNERALLER (10) ──
      _MicroItemDef(key: 'Demir', name: 'Demir', code: 'Demir', current: getVal('Demir', t.iron ?? 0), target: 18.0, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Magnezyum', name: 'Magnezyum', code: 'Mg', current: getVal('Magnezyum', t.magnesium ?? 0), target: 400.0, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Kalsiyum', name: 'Kalsiyum', code: 'Ca', current: getVal('Kalsiyum', t.calcium ?? 0), target: 1000.0, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Potasyum', name: 'Potasyum', code: 'K+', current: getVal('Potasyum', t.potassium ?? 0), target: 4700.0, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Sodyum', name: 'Sodyum', code: 'Na', current: getVal('Sodyum', t.sodium ?? 0), target: 2300.0, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Çinko', name: 'Çinko', code: 'Zn', current: getVal('Çinko', t.zinc ?? 0), target: 11.0, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Bakır', name: 'Bakır', code: 'Cu', current: getVal('Bakır', t.copper ?? 0), target: 0.9, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Manganez', name: 'Manganez', code: 'Mn', current: getVal('Manganez', t.manganese ?? 0), target: 2.3, unit: 'mg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Selenyum', name: 'Selenyum', code: 'Se', current: getVal('Selenyum', t.selenium ?? 0), target: 55.0, unit: 'mcg', category: MicroCategory.mineral),
      _MicroItemDef(key: 'Fosfor', name: 'Fosfor', code: 'P', current: getVal('Fosfor', t.phosphorus ?? 0), target: 700.0, unit: 'mg', category: MicroCategory.mineral),

      // ── YAĞ ASİTLERİ & DİĞER YAĞLAR (10) ──
      _MicroItemDef(key: 'Omega-3', name: 'Omega-3', code: 'Omg3', current: getVal('Omega-3', t.omega3 ?? 0), target: 1.6, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'Omega-6', name: 'Omega-6', code: 'Omg6', current: getVal('Omega-6', t.omega6 ?? 0), target: 14.0, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'ALA', name: 'ALA', code: 'ALA', current: getVal('ALA', t.ala ?? 0), target: 1.6, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'EPA', name: 'EPA', code: 'EPA', current: getVal('EPA', t.epa ?? 0), target: 0.25, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'DHA', name: 'DHA', code: 'DHA', current: getVal('DHA', t.dha ?? 0), target: 0.25, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'Kolesterol', name: 'Kolesterol', code: 'Chol', current: getVal('Kolesterol', t.cholesterol ?? 0), target: 300.0, unit: 'mg', category: MicroCategory.fat),
      _MicroItemDef(key: 'Doymuş Yağ', name: 'Doymuş Yağ', code: 'Sat', current: getVal('Doymuş Yağ', t.saturatedFat), target: 20.0, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'Tekli Doymamış', name: 'Tekli Doymamış', code: 'Mono', current: getVal('Tekli Doymamış', t.monoFat ?? 0), target: 25.0, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'Çoklu Doymamış', name: 'Çoklu Doymamış', code: 'Poly', current: getVal('Çoklu Doymamış', t.polyFat ?? 0), target: 15.0, unit: 'g', category: MicroCategory.fat),
      _MicroItemDef(key: 'Trans Yağ', name: 'Trans Yağ', code: 'Trns', current: getVal('Trans Yağ', t.transFat ?? 0), target: 2.0, unit: 'g', category: MicroCategory.fat),

      // ── KAROTENOİDLER & ANTİOKSİDANLAR (4) ──
      _MicroItemDef(key: 'Beta-Karoten', name: 'Beta-Karoten', code: 'bCar', current: getVal('Beta-Karoten', t.betaCarotene ?? 0), target: 3000.0, unit: 'mcg', category: MicroCategory.antioxidant),
      _MicroItemDef(key: 'Likopen', name: 'Likopen', code: 'Lyc', current: getVal('Likopen', t.lycopene ?? 0), target: 10000.0, unit: 'mcg', category: MicroCategory.antioxidant),
      _MicroItemDef(key: 'Lutein-Zea', name: 'Lutein & Zeaksantin', code: 'Lut', current: getVal('Lutein-Zea', t.luteinZeaxanthin ?? 0), target: 6000.0, unit: 'mcg', category: MicroCategory.antioxidant),
      _MicroItemDef(key: 'Alfa-Karoten', name: 'Alfa-Karoten', code: 'aCar', current: getVal('Alfa-Karoten', t.alphaCarotene ?? 0), target: 500.0, unit: 'mcg', category: MicroCategory.antioxidant),

      // ── AMİNO ASİTLER (9) ──
      _MicroItemDef(key: 'Lösin', name: 'Lösin', code: 'Leu', current: getVal('Lösin', t.leucine ?? 0), target: 2.73, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Lizin', name: 'Lizin', code: 'Lys', current: getVal('Lizin', t.lysine ?? 0), target: 2.10, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'İzolösin', name: 'İzolösin', code: 'Ile', current: getVal('İzolösin', t.isoleucine ?? 0), target: 1.40, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Valin', name: 'Valin', code: 'Val', current: getVal('Valin', t.valine ?? 0), target: 1.82, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Treonin', name: 'Treonin', code: 'Thr', current: getVal('Treonin', t.threonine ?? 0), target: 1.05, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Metiyonin', name: 'Metiyonin', code: 'Met', current: getVal('Metiyonin', t.methionine ?? 0), target: 0.70, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Fenilalanin', name: 'Fenilalanin', code: 'Phe', current: getVal('Fenilalanin', t.phenylalanine ?? 0), target: 1.70, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Triptofan', name: 'Triptofan', code: 'Trp', current: getVal('Triptofan', t.tryptophan ?? 0), target: 0.28, unit: 'g', category: MicroCategory.amino),
      _MicroItemDef(key: 'Histidin', name: 'Histidin', code: 'His', current: getVal('Histidin', t.histidine ?? 0), target: 0.70, unit: 'g', category: MicroCategory.amino),

      // ── DİĞERLERİ (2) ──
      _MicroItemDef(key: 'Lif', name: 'Lif (Fiber)', code: 'Lif', current: getVal('Lif', t.fiber), target: 30.0, unit: 'g', category: MicroCategory.carb),
      _MicroItemDef(key: 'Şeker', name: 'Şeker', code: 'Şeker', current: getVal('Şeker', t.sugar), target: 50.0, unit: 'g', category: MicroCategory.carb),
    ];
  }

  // REDESIGNED 2-COLUMN GRID MICRONUTRIENTS SHEET
  void _showMicronutrientsDetailSheet(BuildContext context, DailyLog log, bool isDark) async {
    final additions = await SupplementManagementSheet.getSupplementMicroAdditions(_selectedDate);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MicronutrientsSheetContent(
          log: log,
          isDark: isDark,
          starredKeys: _starredMicroKeys,
          allMicros: _getListOfAllMicros(log.totalNutrition, supplementAdditions: additions),
          onStarredChanged: () {
            _saveStarredMicros();
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildSupplementBox({
    required BuildContext context,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF181B28) : Colors.white;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        SharedPreferences.getInstance(),
        SupplementManagementSheet.getSupplementMicroAdditions(_selectedDate),
      ]),
      builder: (ctx, snapshot) {
        final prefs = snapshot.data?[0] as SharedPreferences?;
        final jsonStr = prefs?.getString('user_supplements_v2');
        List<SupplementItem> list = jsonStr != null ? SupplementItem.decodeList(jsonStr) : [];

        if (list.isEmpty) {
          final answersStr = prefs?.getString('onboarding_answers');
          if (answersStr != null) {
            try {
              final answers = jsonDecode(answersStr);
              final onboardingList = (answers['supplements'] as List?)?.cast<String>().toList() ?? [];
              final other = answers['supplementsOther'] as String?;
              if (other != null && other.trim().isNotEmpty) {
                onboardingList.add(other.trim());
              }

              if (onboardingList.isNotEmpty) {
                list = onboardingList.map((suppName) {
                  final sName = suppName.trim();
                  return SupplementItem(
                    id: sName.hashCode.toString(),
                    name: sName,
                    timesPerDay: 1,
                  );
                }).toList();
              }
            } catch (_) {}
          }
        }

        final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

        return GestureDetector(
          onTap: () {
            SupplementManagementSheet.show(
              context,
              selectedDate: _selectedDate,
              onDataChanged: () => setState(() {}),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Takviye',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.open_in_new_rounded, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _SupplementBoxPageView(
                    list: list,
                    prefs: prefs,
                    dateKey: dateKey,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getSleepScoreColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFEF4444); // Apple Red
      case 2:
        return const Color(0xFFFF6D00); // Deep Tangerine Orange
      case 3:
        return const Color(0xFFFFC107); // Golden Amber Yellow
      case 4:
        return const Color(0xFF00BCD4); // Cyan / Teal
      case 5:
        return const Color(0xFF34C759); // Apple Mint
      default:
        return const Color(0xFF34C759);
    }
  }

  bool _isValidSymptomInput(String input) {
    final text = input.trim();
    if (text.length < 2) return false;
    final hasLetter = RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜ]').hasMatch(text);
    if (!hasLetter) return false;
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');
    final allSameChar = cleaned.split('').every((c) => c.toLowerCase() == cleaned[0].toLowerCase());
    if (allSameChar) return false;
    final lower = text.toLowerCase();
    final invalidSmashList = ['asdf', 'fdsa', 'qwerty', 'zxcv', '1234'];
    if (invalidSmashList.any((smash) => lower.contains(smash))) return false;
    return true;
  }

  // ── GÜNLÜK SAĞLIK CARD (HORIZONTAL FLEX: 3 - MİKRO BESİNLER İLE AYNI GENİŞLİKTE!) ──
  Widget _buildDailyHealthCard({
    required BuildContext context,
    required WellnessProvider wellnessProvider,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF181B28) : Colors.white;
    final log = wellnessProvider.getLogForDate(_selectedDate);
    final selectedSleep = log.sleepScore; // null if unrecorded by user
    final latestSymptom = log.symptoms.isNotEmpty ? log.symptoms.last : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Günlük Sağlık',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _showWellnessEntrySheet(context, wellnessProvider, log, isDark),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Semptom Row (En son semptom yanında yazar)
          Row(
            children: [
              Text(
                'Semptom: ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
                ),
              ),
              Expanded(
                child: Text(
                  latestSymptom ?? 'Yok',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: latestSymptom != null
                        ? const Color(0xFFD97706)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Uyku Row
          Row(
            children: [
              Text(
                'Uyku',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [5, 4, 3, 2, 1].map((val) {
                    final isSel = selectedSleep == val;
                    final scoreColor = _getSleepScoreColor(val);
                    return GestureDetector(
                      onTap: () async {
                        if (!await SupplementManagementSheet.confirmPastDateAction(context, _selectedDate)) return;
                        wellnessProvider.setSleepScoreForDate(_selectedDate, val);
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSel
                              ? scoreColor
                              : (isDark ? const Color(0xFF262A3B) : Colors.grey.withValues(alpha: 0.18)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$val',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : (isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.6)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          InkWell(
            onTap: () {
              showWcTrackingSheet(context, selectedDate: _selectedDate);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tuvalet takibi',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── GÜNLÜK SAĞLIK BOTTOM SHEET (SEMPTOMLAR, UYKU & TUVALET) ──
  void _showWellnessEntrySheet(
    BuildContext context,
    WellnessProvider wellnessProvider,
    WellnessLog log,
    bool isDark,
  ) {
    final symptomExamples = [
      'Baş ağrısı',
      'Mide bulantısı',
      'Şişkinlik',
      'Halsizlik',
      'Kas ağrısı',
      'Uykusuzluk',
      'Hazımsızlık',
      'Gaz',
    ];
    final customSymptomCtrl = TextEditingController();
    final symptomFocusNode = FocusNode();
    String? inlineError;
    Timer? inlineTimer;
    String? inlineSuccess;
    Timer? inlineSuccessTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final currentLog = wellnessProvider.getLogForDate(_selectedDate);
            final currentSymptoms = List<String>.from(currentLog.symptoms);
            final sleepScore = currentLog.sleepScore; // null if not logged by user

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131520) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Günlük Sağlık Kaydı',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Semptomlar, uyku kalitesi ve tuvalet kaydınızı buradan güncelleyebilirsiniz.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                    const SizedBox(height: 16),

                    // Inline Error Banner Directly Below Subtitle
                    if (inlineError != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inlineError!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Inline Success Banner Directly Below Subtitle
                    if (inlineSuccess != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inlineSuccess!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // SEMPTOMLAR (Yatay Kaydırılabilir Örnekler)
                    const Text(
                      'SEMPTOMLAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: symptomExamples.map((sym) {
                          final isSel = currentSymptoms.contains(sym);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AnimatedScale(
                              scale: isSel ? 1.03 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: FilterChip(
                                label: Text(sym),
                                selected: isSel,
                                showCheckmark: false,
                                backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
                                selectedColor: isDark ? const Color(0xFF1E2235) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(
                                  color: isSel ? const Color(0xFFD97706) : (isDark ? Colors.white24 : Colors.black12),
                                  width: isSel ? 1.8 : 1.0,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel
                                      ? const Color(0xFFD97706)
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                onSelected: (val) async {
                                  // Optimistic 0ms UI update
                                  if (isSel) {
                                    currentSymptoms.remove(sym);
                                  } else {
                                    currentSymptoms.add(sym);
                                  }
                                  setSheetState(() {});
                                  setState(() {});

                                  if (!await SupplementManagementSheet.confirmPastDateAction(context, _selectedDate)) {
                                    if (isSel) {
                                      currentSymptoms.add(sym);
                                    } else {
                                      currentSymptoms.remove(sym);
                                    }
                                    setSheetState(() {});
                                    setState(() {});
                                    return;
                                  }

                                  if (isSel) {
                                    await wellnessProvider.removeSymptomForDate(_selectedDate, sym);
                                    await NotificationService.cancelSymptomCheckNotification(sym);
                                  } else {
                                    await wellnessProvider.addSymptomForDate(_selectedDate, sym);
                                    await NotificationService.scheduleSymptomCheckNotification(
                                      symptomName: sym,
                                      delayHours: 3,
                                    );
                                  }
                                  setSheetState(() {});
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customSymptomCtrl,
                            focusNode: symptomFocusNode,
                            autofocus: false,
                            decoration: InputDecoration(
                              hintText: 'Farklı bir semptom yazın...',
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E2235) : Colors.grey.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            symptomFocusNode.unfocus();
                            FocusScope.of(sheetCtx).unfocus(); // Klavyeyi kapat
                            final text = customSymptomCtrl.text.trim();
                            if (text.isEmpty) return;

                            if (!_isValidSymptomInput(text)) {
                              await Future.delayed(const Duration(milliseconds: 200));
                              inlineTimer?.cancel();
                              setSheetState(() {
                                inlineError = 'Lütfen geçerli bir sağlık/semptom ifadesi giriniz.';
                              });
                              inlineTimer = Timer(const Duration(seconds: 2), () {
                                setSheetState(() {
                                  inlineError = null;
                                });
                              });
                              return;
                            }

                            if (!await SupplementManagementSheet.confirmPastDateAction(context, _selectedDate)) return;
                            await wellnessProvider.addSymptomForDate(_selectedDate, text);
                            await NotificationService.scheduleSymptomCheckNotification(
                              symptomName: text,
                              delayHours: 3,
                            );
                            customSymptomCtrl.clear();
                            setSheetState(() {});
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // UYKU KALİTESİ
                    const Text(
                      'UYKU KALİTESİ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06B6D4),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [5, 4, 3, 2, 1].map((val) {
                        final isSel = sleepScore == val;
                        final scoreColor = _getSleepScoreColor(val);
                        return GestureDetector(
                          onTap: () async {
                            // Optimistic 0ms UI response
                            setSheetState(() {});
                            setState(() {});

                            if (!await SupplementManagementSheet.confirmPastDateAction(context, _selectedDate)) return;
                            await wellnessProvider.setSleepScoreForDate(_selectedDate, val);
                            setSheetState(() {});
                            setState(() {});
                          },
                          child: AnimatedScale(
                            scale: isSel ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? scoreColor
                                        : (isDark ? const Color(0xFF262A3B) : Colors.grey.withValues(alpha: 0.2)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$val',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  val == 5 ? 'Kusursuz' : (val == 1 ? 'Çok Kötü' : '$val Puan'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // TUVALET TAKİBİ
                    const Text(
                      'TUVALET TAKİBİ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: isDark ? const Color(0xFF1C1F2E) : const Color(0xFFF7F8FA),
                      leading: const Icon(Icons.spa_rounded, color: Color(0xFF10B981)),
                      title: const Text('Tuvalet Takibi Ekranını Aç', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Bağırsak hareketleri ve konforlu tuvalet kaydı tutun.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        symptomFocusNode.unfocus();
                        FocusScope.of(sheetCtx).unfocus();
                        final result = await showWcTrackingSheet(context, selectedDate: _selectedDate);
                        if (result == true) {
                          inlineSuccessTimer?.cancel();
                          setSheetState(() {
                            inlineSuccess = 'Tuvalet kaydı başarıyla eklendi.';
                          });
                          inlineSuccessTimer = Timer(const Duration(seconds: 2), () {
                            setSheetState(() {
                              inlineSuccess = null;
                            });
                          });
                        }
                      },
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

  // ── MEALS SECTION ──
  Widget _buildMealsSection({
    required BuildContext context,
    required DailyLog dailyLog,
    required NutritionProvider nutritionProvider,
    required double calorieGoal,
    required bool isDark,
  }) {
    final mealCategories = [
      'Kahvaltı',
      'Kahvaltı sonrası ara öğün',
      'Öğle Yemeği',
      'Öğle sonrası ara öğün',
      'Akşam Yemeği',
      'Gece Atıştırmalığı',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mealCategories.map((mealCategory) {
        final entries = dailyLog.entries.where((e) {
          final m = e.mealType.toLowerCase();
          final c = mealCategory.toLowerCase();
          if (c.contains('kahvaltı') && !c.contains('ara')) {
            return m == 'kahvaltı' || m == 'breakfast';
          } else if (c.contains('kahvaltı sonrası ara')) {
            if (m.contains('kahvaltı') && m.contains('ara')) return true;
            if ((m == 'ara öğün' || m == 'snack') && e.timestamp.hour < 14) return true;
            return m == 'kahvaltı sonrası ara öğün';
          } else if (c.contains('öğle yemeği')) {
            return m == 'öğle' || m == 'öğle yemeği' || m == 'lunch';
          } else if (c.contains('öğle sonrası ara')) {
            if (m.contains('öğle') && m.contains('ara')) return true;
            if ((m == 'ara öğün' || m == 'snack') && e.timestamp.hour >= 14 && e.timestamp.hour < 21) return true;
            return m == 'öğle sonrası ara öğün';
          } else if (c.contains('akşam yemeği')) {
            return m == 'akşam' || m == 'akşam yemeği' || m == 'dinner';
          } else if (c.contains('gece')) {
            return m.contains('gece') || (m.contains('snack') && e.timestamp.hour >= 21);
          }
          return m == c;
        }).toList();

        final mealCalories = entries.fold(0.0, (sum, e) => sum + e.nutritionData.scaleBy(e.portionSize / 100).calories);
        final mealPct = calorieGoal > 0 ? (mealCalories / calorieGoal * 100).round() : 0;
        final timeStr = entries.isNotEmpty
            ? DateFormat('HH:mm').format(entries.first.timestamp)
            : '11:38';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                    Text(
                      mealCategory,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                GestureDetector(
                  onTap: () => _showAddMealOptions(mealCategory),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2333) : Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              '${mealCalories.round()} kcal (%$mealPct)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 10),

            if (entries.isNotEmpty)
              Column(
                children: entries.map((entry) {
                  final itemCal = entry.nutritionData.scaleBy(entry.portionSize / 100).calories.round();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => FoodEntryDetailSheet.show(context, entry: entry, date: _selectedDate),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildFoodAvatar(entry, isDark),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$itemCal kcal, ${entry.portionSize.round()}${entry.portionUnit}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Henüz yiyecek eklenmedi',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFoodAvatar(FoodEntry entry, bool isDark) {
    final imgPath = entry.imagePath;
    final hasImg = imgPath != null && imgPath.isNotEmpty;

    if (hasImg) {
      if (imgPath.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            imgPath,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackFoodIcon(isDark),
          ),
        );
      } else if (imgPath.startsWith('http://') || imgPath.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imgPath,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackFoodIcon(isDark),
          ),
        );
      } else if (File(imgPath).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(imgPath),
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackFoodIcon(isDark),
          ),
        );
      }
    }

    return _buildFallbackFoodIcon(isDark);
  }

  Widget _buildFallbackFoodIcon(bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232738) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.3),
        ),
      ),
      child: const Icon(
        Icons.restaurant_rounded,
        size: 20,
        color: Color(0xFFD97706),
      ),
    );
  }
}

// ── MICRONUTRIENTS SHEET CONTENT ──
class _MicronutrientsSheetContent extends StatefulWidget {
  final DailyLog log;
  final bool isDark;
  final List<String> starredKeys;
  final List<_MicroItemDef> allMicros;
  final VoidCallback onStarredChanged;

  const _MicronutrientsSheetContent({
    required this.log,
    required this.isDark,
    required this.starredKeys,
    required this.allMicros,
    required this.onStarredChanged,
  });

  @override
  State<_MicronutrientsSheetContent> createState() => _MicronutrientsSheetContentState();
}

class _MicronutrientsSheetContentState extends State<_MicronutrientsSheetContent> {
  MicroCategory _selectedCategory = MicroCategory.all;
  String? _warningMessage;
  Timer? _warningTimer;

  void _showWarning(String msg) {
    HapticFeedback.vibrate();
    _warningTimer?.cancel();
    setState(() {
      _warningMessage = msg;
    });
    _warningTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _warningMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesToDisplay = _selectedCategory == MicroCategory.all
        ? MicroCategory.values.where((c) => c != MicroCategory.all && c != MicroCategory.starred).toList()
        : [_selectedCategory];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF131520) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Title & Counter Badge (Neutral Dark Background)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tüm Mikro Besinler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1F2333)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Text(
                  '${widget.starredKeys.length}/6 Yıldızlı',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: widget.starredKeys.isNotEmpty
                        ? const Color(0xFFFFB800)
                        : (widget.isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: MicroCategory.values.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.displayName),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    selectedColor: cat.color.withValues(alpha: 0.25),
                    checkmarkColor: cat.color,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel
                          ? cat.color
                          : (widget.isDark ? Colors.white70 : Colors.black87),
                    ),
                    backgroundColor: widget.isDark
                        ? const Color(0xFF1B1E2D)
                        : Colors.grey.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: isSel ? cat.color : Colors.transparent,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }).toList(),
            ),
          ),

          // In-Sheet Top Alert Warning Banner (100% visible inside the sheet)
          if (_warningMessage != null) ...[
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB800)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB800), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _warningMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Category Group Sections List
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: categoriesToDisplay.length,
              itemBuilder: (ctx, catIndex) {
                final cat = categoriesToDisplay[catIndex];
                final List<_MicroItemDef> catMicros;
                if (cat == MicroCategory.starred) {
                  catMicros = widget.starredKeys.map((key) {
                    return widget.allMicros.firstWhere(
                      (m) => m.key.toLowerCase().trim() == key.toLowerCase().trim() ||
                             m.name.toLowerCase().trim() == key.toLowerCase().trim(),
                      orElse: () => _MicroItemDef(
                        key: key,
                        name: key,
                        code: key,
                        current: 0,
                        target: 1.0,
                        unit: '',
                        category: MicroCategory.starred,
                      ),
                    );
                  }).toList();
                } else {
                  catMicros = widget.allMicros.where((m) => m.category == cat).toList();
                }

                if (catMicros.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Section Header Name
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cat.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: cat.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2-Column Grid for Items in Category
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: catMicros.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (gridCtx, index) {
                        final item = catMicros[index];
                        final isStarred = widget.starredKeys.contains(item.key);

                        return _FlippableMicroCard(
                          key: ValueKey(item.key),
                          item: item,
                          isStarred: isStarred,
                          isDark: widget.isDark,
                          onToggleStar: () {
                            if (isStarred) {
                              widget.starredKeys.remove(item.key);
                              setState(() {});
                              widget.onStarredChanged();
                            } else {
                              if (widget.starredKeys.length >= 6) {
                                _showWarning('En fazla 6 mikro besin ekleyebilirsiniz.');
                              } else {
                                widget.starredKeys.add(item.key);
                                setState(() {});
                                widget.onStarredChanged();
                              }
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3D FLIPPABLE MICRO CARD WIDGET ──
class _FlippableMicroCard extends StatefulWidget {
  final _MicroItemDef item;
  final bool isStarred;
  final bool isDark;
  final VoidCallback onToggleStar;

  const _FlippableMicroCard({
    super.key,
    required this.item,
    required this.isStarred,
    required this.isDark,
    required this.onToggleStar,
  });

  @override
  State<_FlippableMicroCard> createState() => _FlippableMicroCardState();
}

class _FlippableMicroCardState extends State<_FlippableMicroCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _autoFlipTimer;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addListener(() {
      if (_controller.value >= 0.5 && _showFront) {
        setState(() => _showFront = false);
      } else if (_controller.value < 0.5 && !_showFront) {
        setState(() => _showFront = true);
      }
    });
  }

  @override
  void dispose() {
    _autoFlipTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _flipToBack() {
    _controller.forward();
    _startAutoFlipTimer();
  }

  void _flipToFront() {
    _autoFlipTimer?.cancel();
    _controller.reverse();
  }

  void _startAutoFlipTimer() {
    _autoFlipTimer?.cancel();
    _autoFlipTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_showFront) {
        _flipToFront();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catColor = widget.item.category.color;
    final cardBg = widget.isDark ? const Color(0xFF1C1F2E) : const Color(0xFFF7F8FA);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(math.pi * _animation.value);

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {
              if (_showFront) {
                _flipToBack();
              } else {
                _flipToFront();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isStarred
                      ? const Color(0xFFFFB800)
                      : (widget.isDark ? Colors.white10 : Colors.black12),
                  width: widget.isStarred ? 2.0 : 1.0,
                ),
                boxShadow: widget.isStarred
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: _showFront ? _buildFront(catColor) : Transform(
                transform: Matrix4.identity()..rotateY(math.pi),
                alignment: Alignment.center,
                child: _buildBack(catColor),
              ),
            ),
          ),
        );
      },
    );
  }

  // Front View: Larger Font Name & Value, Progress Bar Closer to Text + Adjacent %
  Widget _buildFront(Color catColor) {
    final item = widget.item;
    final progress = item.progress;
    final pct = item.pct;

    final darkBaseColor = catColor.withValues(alpha: 0.25);
    final trackBg = progress > 1.0
        ? darkBaseColor
        : (widget.isDark ? const Color(0xFF282C3D) : Colors.grey.withValues(alpha: 0.15));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Larger Font Name & Amount / Target
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${item.current.toStringAsFixed(1)} / ${item.target.toStringAsFixed(1)} ${item.unit}',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),

        // Progress Bar Closer to Text + Adjacent % Text
        Row(
          children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: trackBg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: catColor.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2.5),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress > 1.0
                        ? (progress - 1.0).clamp(0.0, 1.0)
                        : progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '%$pct',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: widget.isStarred ? const Color(0xFFFFB800) : catColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Back View: Star Icon + Text "Ana menüye ekle" / "Ana menüden çıkar"
  Widget _buildBack(Color catColor) {
    return Center(
      child: GestureDetector(
        onTap: () {
          widget.onToggleStar();
          _startAutoFlipTimer();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFFFB800),
              size: 34,
            ),
            const SizedBox(height: 4),
            Text(
              widget.isStarred ? 'Ana menüden çıkar' : 'Ana menüye ekle',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.isStarred ? const Color(0xFFFFB800) : (widget.isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for micronutrient definitions
class _MicroItemDef {
  final String key;
  final String name;
  final String code;
  final double current;
  final double target;
  final String unit;
  final MicroCategory category;

  _MicroItemDef({
    required this.key,
    required this.name,
    required this.code,
    required this.current,
    required this.target,
    required this.unit,
    required this.category,
  });

  double get progress => target > 0 ? (current / target) : 0.0;
  int get pct => (progress * 100).round();
}

// ── BOTTOM TO TOP ANIMATED CLIPPER FOR WATER DROP ──
class _BottomToTopClipper extends CustomClipper<Rect> {
  final double progress;
  _BottomToTopClipper(this.progress);

  @override
  Rect getClip(Size size) {
    final heightToKeep = size.height * progress;
    return Rect.fromLTRB(0, size.height - heightToKeep, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant _BottomToTopClipper oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ── EXACT LEGACY WATER ADD SHEET ──
class _WaterAddSheet extends StatefulWidget {
  final void Function(double ml) onAdd;
  final bool isRemove;
  final double currentWaterMl;

  const _WaterAddSheet({
    required this.onAdd,
    this.isRemove = false,
    this.currentWaterMl = 0,
  });

  @override
  State<_WaterAddSheet> createState() => _WaterAddSheetState();
}

class _WaterAddSheetState extends State<_WaterAddSheet> {
  final _manualCtrl = TextEditingController();
  String? _errorText;
  Timer? _errorTimer;
  late bool _isRemove;

  @override
  void initState() {
    super.initState();
    _isRemove = widget.isRemove;
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  void _addAndClose(double ml) {
    if (_isRemove && ml > widget.currentWaterMl) {
      HapticFeedback.vibrate();
      final msg = (AppLocalizations.of(context).isTurkish 
          ? 'İçtiğiniz sudan fazlasını çıkaramazsınız! (Mevcut su: ${widget.currentWaterMl.round()} ml)' 
          : 'Cannot remove more than total intake! (Current: ${widget.currentWaterMl.round()} ml)');
      setState(() {
        _errorText = msg;
      });
      _errorTimer?.cancel();
      _errorTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _errorText = null;
          });
        }
      });
      return;
    }
    Navigator.pop(context);
    widget.onAdd(_isRemove ? -ml : ml);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTurkish = l10n.isTurkish;
    final colorScheme = Theme.of(context).colorScheme;

    final accentColor = _isRemove ? const Color(0xFFF43F5E) : colorScheme.primary;
    final btnBgColor = _isRemove ? const Color(0xFFFFE4E6) : colorScheme.primaryContainer;
    final btnTextColor = _isRemove ? const Color(0xFFBE123C) : colorScheme.onPrimaryContainer;

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
              Icon(Icons.water_drop, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isRemove
                      ? (isTurkish ? 'Ne kadar çıkarmak istersiniz?' : 'How much to remove?')
                      : (isTurkish ? 'Ne kadar içtiniz?' : 'How much did you drink?'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _isRemove ? const Color(0xFFE11D48) : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Top-right minus / plus toggle button
              IconButton(
                icon: Icon(
                  _isRemove ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                  color: accentColor,
                  size: 26,
                ),
                tooltip: _isRemove
                    ? (isTurkish ? 'Ekleme Modu' : 'Add Mode')
                    : (isTurkish ? 'Çıkarma Modu' : 'Remove Mode'),
                onPressed: () {
                  setState(() {
                    _isRemove = !_isRemove;
                    _errorText = null;
                  });
                },
              ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF43F5E)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Color(0xFFBE123C), fontSize: 13, fontWeight: FontWeight.bold),
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
                    color: btnBgColor,
                    border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Center(
                    child: Text(
                      '${ml}ml',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: btnTextColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Large icon cards row (Tea glass, Water glass)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _addAndClose(100),
                  child: Card(
                    color: _isRemove ? const Color(0xFFFFF1F2) : colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                    ),
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
                              color: accentColor,
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
                    color: _isRemove ? const Color(0xFFFFF1F2) : colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                    ),
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
                              color: accentColor,
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
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                ),
                onPressed: () {
                  final ml = double.tryParse(_manualCtrl.text);
                  if (ml != null && ml > 0) _addAndClose(ml);
                },
                child: Text(_isRemove ? (isTurkish ? 'Çıkart' : 'Remove') : l10n.tr('Ekle')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── CUSTOM RING PAINTER (Supporting >100% Two-Layer Overlay) ──
class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color darkBaseColor;
  final Color backgroundColor;
  final double strokeWidth;

  _RingProgressPainter({
    required this.progress,
    required this.color,
    required this.darkBaseColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (progress <= 1.0) {
      final bgPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, bgPaint);

      if (progress > 0) {
        final fgPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
        canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, fgPaint);
      }
    } else {
      final darkBasePaint = Paint()
        ..color = darkBaseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, darkBasePaint);

      final excess = (progress - 1.0).clamp(0.0, 1.0);
      if (excess > 0) {
        final overlayPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        final sweepAngle = 2 * math.pi * excess;
        canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, overlayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.darkBaseColor != darkBaseColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

// ── CUSTOM CALENDAR BOTTOM SHEET ─────────────────────────────────────────────

class _CustomCalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool isDark;

  const _CustomCalendarSheet({
    required this.initialDate,
    required this.onDateSelected,
    required this.isDark,
  });

  @override
  State<_CustomCalendarSheet> createState() => _CustomCalendarSheetState();
}

class _CustomCalendarSheetState extends State<_CustomCalendarSheet> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _prefs = p;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
    });
  }

  bool _hasData(DateTime date, NutritionProvider nutrition, WellnessProvider wellness) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final log = nutrition.allLogs[key];
    if (log != null && (log.entries.isNotEmpty || log.waterIntakeMl > 0)) {
      return true;
    }
    final wLog = wellness.getLogForDate(date);
    if (wLog != null && (wLog.symptoms.isNotEmpty || wLog.sleepScore != null || wLog.wcEntries.isNotEmpty || wLog.moods.isNotEmpty)) {
      return true;
    }
    if (_prefs != null) {
      final jsonStr = _prefs!.getString('user_supplements_v2');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = SupplementItem.decodeList(jsonStr);
        for (final item in list) {
          final takenDoses = _prefs!.getInt('supp_dose_${key}_${item.id}') ?? 0;
          if (takenDoses > 0) {
            return true;
          }
        }
      }
    }
    return false;
  }

  List<DateTime> _buildCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon ... 7 = Sun
    final startDate = firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));

    final days = <DateTime>[];
    for (int i = 0; i < 35; i++) {
      days.add(startDate.add(Duration(days: i)));
    }
    if (days.last.month == month.month) {
      for (int i = 35; i < 42; i++) {
        days.add(startDate.add(Duration(days: i)));
      }
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final nutrition = context.watch<NutritionProvider>();
    final wellness = context.watch<WellnessProvider>();
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_focusedMonth);
    final formattedMonthStr = monthStr.isNotEmpty
        ? monthStr[0].toUpperCase() + monthStr.substring(1)
        : monthStr;

    final days = _buildCalendarDays(_focusedMonth);
    final bg = isDark ? const Color(0xFF131622) : Colors.white;
    final navBtnBg = isDark ? const Color(0xFF1F2333) : Colors.grey.withValues(alpha: 0.12);
    final weekDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row: Close Button | Month Year | Prev & Next Month Nav Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: navBtnBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              Text(
                formattedMonthStr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _changeMonth(-1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: navBtnBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _changeMonth(1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: navBtnBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weekday Header Row
          Row(
            children: weekDays
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Grid of Days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (ctx, i) {
              final cellDate = days[i];
              final isCurrentMonth = cellDate.month == _focusedMonth.month;
              final isSelected = DateUtils.isSameDay(cellDate, _selectedDate);
              final hasEntries = _hasData(cellDate, nutrition, wellness);

              Color textColor;
              if (isSelected) {
                textColor = Colors.black;
              } else if (isCurrentMonth) {
                textColor = isDark ? Colors.white : Colors.black87;
              } else {
                textColor = isDark ? Colors.white24 : Colors.black26;
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                  widget.onDateSelected(cellDate);
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  decoration: isSelected
                      ? const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${cellDate.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (hasEntries)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // "Bugüne Dön" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final now = DateTime.now();
                widget.onDateSelected(now);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1F2333) : Colors.grey.shade200,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                context.tr('Bugüne Dön'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplementBoxPageView extends StatefulWidget {
  final List<SupplementItem> list;
  final SharedPreferences? prefs;
  final String dateKey;
  final bool isDark;

  const _SupplementBoxPageView({
    required this.list,
    required this.prefs,
    required this.dateKey,
    required this.isDark,
  });

  @override
  State<_SupplementBoxPageView> createState() => _SupplementBoxPageViewState();
}

class _SupplementBoxPageViewState extends State<_SupplementBoxPageView> {
  int _currentPage = 0;
  bool _isDragging = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? 0.0;
    final isDragging = (page - page.round()).abs() > 0.01;
    if (isDragging != _isDragging) {
      setState(() {
        _isDragging = isDragging;
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildSupplementClassicRow(SupplementItem item) {
    final takenDoses = widget.prefs?.getInt('supp_dose_${widget.dateKey}_${item.id}') ?? 0;
    final targetDoses = item.timesPerDay;

    IconData icon;
    Color iconColor;

    if (takenDoses >= targetDoses) {
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFFD97706);
    } else if (takenDoses > 0) {
      icon = Icons.pie_chart_rounded;
      iconColor = const Color(0xFFD97706);
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      iconColor = widget.isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black.withValues(alpha: 0.87),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.only(left: 4, right: _isDragging ? 6 : 0),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.list.isEmpty) {
      return Center(
        child: Text(
          'Takviye eklemek için dokunun',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white38 : Colors.black38),
        ),
      );
    }

    if (widget.list.length <= 4) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: widget.list.map((item) => _buildSupplementClassicRow(item)).toList(),
      );
    }

    final pageCount = (widget.list.length / 4).ceil();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            onPageChanged: (idx) {
              setState(() {
                _currentPage = idx;
              });
            },
            itemCount: pageCount,
            itemBuilder: (ctx, pageIndex) {
              final startIndex = pageIndex * 4;
              final endIndex = (startIndex + 4 < widget.list.length) ? startIndex + 4 : widget.list.length;
              final chunk = widget.list.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: chunk.map((item) => _buildSupplementClassicRow(item)).toList(),
                ),
              );
            },
          ),
        ),
        if (pageCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (idx) {
                final isActive = idx == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isActive ? 10 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFD97706)
                        : (widget.isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
