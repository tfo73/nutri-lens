import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import '../services/device_id_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/health_service.dart';
import '../widgets/wave_background.dart';
import 'home_screen.dart';
import 'paywall_screen.dart';

// =============================================================================
// DATA MODEL
// =============================================================================

class OnboardingData {
  OnboardingData();

  // Section 2
  String firstName = '';
  String? primaryGoalsOther;
  final Set<String> primaryGoals = {};
  String? howHeard;
  String? howHeardOther;

  // Short questions
  int age = 25;
  bool useMetricHeight = true;
  bool useMetricWeight = true;
  double heightCm = 170;
  double weightKg = 70;
  Gender? gender;
  Goal? weightGoal;
  double targetWeightKg = 65;
  double weeklyChangeDelta = 0.5;
  ActivityLevel? activityLevel;
  String? dietaryPlan;
  double customCarbPct = 45;
  double customFatPct = 30;
  double customProteinPct = 25;
  double customFiberPct = 0;
  String? alcoholHabit;
  bool? pastWeightLoss;
  String? weightLossExp;
  String? bodyType;
  bool? hasSunlight;
  String? sleepHours;
  String? cookingTime;
  final Set<String> motivations = {};
  String? hungerTime;
  String? mealCount;
  String? waterHabit;
  String? eatingOut;
  String? energyTime;
  String? emotionalEating;
  bool? regularSleep;
  String? progressIndicator; // kept for backwards compat
  final Set<String> progressIndicators = {};
  String? exerciseFreq;

  // Complex questions
  final Set<String> diseases = {};
  String? diseasesOther;
  final Set<String> foodSensitivities = {};
  String? foodSensitivitiesOther;
  final Set<String> supplements = {};
  String? supplementsOther;
  final Set<String> challenges = {};
  String? challengesOther;
  final Set<String> specificGoals = {};
  String? specificGoalsOther;

  // ID Management
  String? onboardingId; // New

  // ── Calculations ─────────────────────────────────────────────────────────
  double get bmr => UserProfile.calculateBmr(
        weight: weightKg,
        height: heightCm,
        age: age,
        gender: gender ?? Gender.male,
      );

  double get tdee {
    // If exercise frequency is specified, use a more granular multiplier
    if (exerciseFreq != null) {
      if (exerciseFreq!.contains('Düzenli')) return bmr * 1.55;
      if (exerciseFreq!.contains('Bazen')) return bmr * 1.375;
      if (exerciseFreq!.contains('Nadiren')) return bmr * 1.25;
      if (exerciseFreq!.contains('Hiç')) return bmr * 1.15;
    }

    const m = {
      ActivityLevel.sedentary: 1.2,
      ActivityLevel.light: 1.375,
      ActivityLevel.moderate: 1.55,
      ActivityLevel.active: 1.725,
      ActivityLevel.veryActive: 1.9,
    };
    return bmr * (m[activityLevel ?? ActivityLevel.moderate] ?? 1.55);
  }

  double get calorieTarget {
    final kcalPerDay = weeklyChangeDelta * 1100;
    switch (weightGoal ?? Goal.maintain) {
      case Goal.lose:
        return (tdee - kcalPerDay).clamp(1200.0, 9999.0);
      case Goal.gain:
        return tdee + kcalPerDay;
      case Goal.maintain:
        return tdee;
    }
  }

  double get proteinG => weightKg * 2;
  double get carbG => calorieTarget * (customCarbPct / 100) / 4;
  double get fatG => calorieTarget * (customFatPct / 100) / 9;
  double get fiberG => (gender ?? Gender.male) == Gender.male ? 38.0 : 25.0;
  double get waterMl => weightKg * 35;

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'primaryGoals': primaryGoals.toList(),
        'primaryGoalsOther': primaryGoalsOther,
        'howHeard': howHeard,
        'howHeardOther': howHeardOther,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'gender': gender?.index,
        'weightGoal': weightGoal?.index,
        'targetWeightKg': targetWeightKg,
        'weeklyChangeDelta': weeklyChangeDelta,
        'activityLevel': activityLevel?.index,
        'dietaryPlan': dietaryPlan,
        'customCarbPct': customCarbPct,
        'customFatPct': customFatPct,
        'customProteinPct': customProteinPct,
        'customFiberPct': customFiberPct,
        'alcoholHabit': alcoholHabit,
        'pastWeightLoss': pastWeightLoss,
        'weightLossExp': weightLossExp,
        'bodyType': bodyType,
        'hasSunlight': hasSunlight,
        'sleepHours': sleepHours,
        'cookingTime': cookingTime,
        'motivations': motivations.toList(),
        'hungerTime': hungerTime,
        'mealCount': mealCount,
        'waterHabit': waterHabit,
        'eatingOut': eatingOut,
        'energyTime': energyTime,
        'emotionalEating': emotionalEating,
        'regularSleep': regularSleep,
        'progressIndicator': progressIndicator,
        'progressIndicators': progressIndicators.toList(),
        'exerciseFreq': exerciseFreq,
        'diseases': diseases.toList(),
        'diseasesOther': diseasesOther,
        'foodSensitivities': foodSensitivities.toList(),
        'foodSensitivitiesOther': foodSensitivitiesOther,
        'supplements': supplements.toList(),
        'supplementsOther': supplementsOther,
        'challenges': challenges.toList(),
        'challengesOther': challengesOther,
        'specificGoals': specificGoals.toList(),
        'specificGoalsOther': specificGoalsOther,
      };

  factory OnboardingData.fromJson(Map<String, dynamic> j) {
    final d = OnboardingData();
    d.firstName = j['firstName'] as String? ?? '';
    d.primaryGoalsOther = j['primaryGoalsOther'] as String?;
    d.primaryGoals.addAll((j['primaryGoals'] as List? ?? []).cast<String>());
    d.howHeard = j['howHeard'] as String?;
    d.howHeardOther = j['howHeardOther'] as String?;
    d.age = j['age'] as int? ?? 25;
    d.heightCm = (j['heightCm'] as num?)?.toDouble() ?? 170;
    d.weightKg = (j['weightKg'] as num?)?.toDouble() ?? 70;
    d.gender = j['gender'] != null ? Gender.values[j['gender'] as int] : null;
    d.weightGoal = j['weightGoal'] != null ? Goal.values[j['weightGoal'] as int] : null;
    d.targetWeightKg = (j['targetWeightKg'] as num?)?.toDouble() ?? 65;
    d.weeklyChangeDelta = (j['weeklyChangeDelta'] as num?)?.toDouble() ?? 0.5;
    d.activityLevel = j['activityLevel'] != null ? ActivityLevel.values[j['activityLevel'] as int] : null;
    d.dietaryPlan = j['dietaryPlan'] as String?;
    d.customCarbPct = (j['customCarbPct'] as num?)?.toDouble() ?? 45;
    d.customFatPct = (j['customFatPct'] as num?)?.toDouble() ?? 30;
    d.customProteinPct = (j['customProteinPct'] as num?)?.toDouble() ?? 25;
    d.customFiberPct = (j['customFiberPct'] as num?)?.toDouble() ?? 0;
    d.alcoholHabit = j['alcoholHabit'] as String?;
    d.pastWeightLoss = j['pastWeightLoss'] as bool?;
    d.weightLossExp = j['weightLossExp'] as String?;
    d.bodyType = j['bodyType'] as String?;
    d.hasSunlight = j['hasSunlight'] as bool?;
    d.sleepHours = j['sleepHours'] as String?;
    d.cookingTime = j['cookingTime'] as String?;
    d.motivations.addAll((j['motivations'] as List? ?? []).cast<String>());
    d.hungerTime = j['hungerTime'] as String?;
    d.mealCount = j['mealCount'] as String?;
    d.waterHabit = j['waterHabit'] as String?;
    d.eatingOut = j['eatingOut'] as String?;
    d.energyTime = j['energyTime'] as String?;
    d.emotionalEating = j['emotionalEating'] as String?;
    d.regularSleep = j['regularSleep'] as bool?;
    d.progressIndicator = j['progressIndicator'] as String?;
    d.progressIndicators.addAll(
        (j['progressIndicators'] as List? ?? []).cast<String>());
    d.exerciseFreq = j['exerciseFreq'] as String?;
    d.diseases.addAll((j['diseases'] as List? ?? []).cast<String>());
    d.diseasesOther = j['diseasesOther'] as String?;
    d.foodSensitivities
        .addAll((j['foodSensitivities'] as List? ?? []).cast<String>());
    d.foodSensitivitiesOther = j['foodSensitivitiesOther'] as String?;
    d.supplements.addAll((j['supplements'] as List? ?? []).cast<String>());
    d.supplementsOther = j['supplementsOther'] as String?;
    d.challenges.addAll((j['challenges'] as List? ?? []).cast<String>());
    d.challengesOther = j['challengesOther'] as String?;
    d.specificGoals.addAll((j['specificGoals'] as List? ?? []).cast<String>());
    d.specificGoalsOther = j['specificGoalsOther'] as String?;
    return d;
  }
}

// =============================================================================
// ENUMS
// =============================================================================

enum _StepId {
  // Section 1 – Karşılama
  welcome, login, accountNotFound, longevity, comparison, comparisonTable, recipeFeature,
  // Section 2 – Tanışma
  name, primaryGoals, goalConfirm, howHeard,
  // Section 3 – Kişiselleştirme 1
  age, height, weight, gender, goal,
  targetWeight, weeklyChange,
  activityLevel, dietaryPlan,
  alcohol,
  pastWeightLoss,
  weightLossExp,
  bodyType, sunlight, sleepHours,
  // Section 4 – Kişiselleştirme 2
  cookingTime, motivation, hungerTime, mealCount,
  waterHabit, eatingOut, energyTime, emotionalEating,
  sleepSchedule, progressIndicator, exerciseFreq, notifications, healthConnect,
  // Section 6 – Özelleştirilmiş Program
  diseases, foodSensitivities, supplements, mainChallenge, healthGoals,
  // Section 7 – İşleniyor + Hesaplama + Paywall
  processing, planReady, rateUs, paywall, signUp, calculatedValues,
  // Section 8 – Tamamlandı
  completion,
}

enum _Section {
  s1Welcome,
  s2Meeting,
  s3Personal1,
  s4Personal2,
  s6Program,
  s7Processing,
  s8Done,
}

enum _RowState { check, cross, dash }


// =============================================================================
// MODE
// =============================================================================

enum OnboardingMode {
  fresh,      // İlk kurulum: tüm adımlar
  newProfile, // Profil ekranından: hesap + isim'den başlar
}

// =============================================================================
// SCREEN
// =============================================================================

class OnboardingScreen extends StatefulWidget {
  final OnboardingMode mode;
  final bool isFromProfileAdd;

  const OnboardingScreen({
    super.key,
    this.mode = OnboardingMode.fresh,
    this.isFromProfileAdd = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // ── Picker infinite-scroll multiplier ────────────────────────────────────
  static const int _kPickerMul = 9999;

  // ── Renk Paleti: Deep Void × Nebula Gray × Ice Cobalt × Bio-Mint ─────────
  static const _kBg      = Color(0xFF0D1117); // Deep Void
  static const _kCard    = Color(0xFF161B22); // Nebula Gray
  static const _kBorder  = Color(0xFF30363D); // Kenarlık
  static const _kGreen   = Color(0xFF58A6FF); // Changed to Blue as per request
  static const _kBlue    = Color(0xFF58A6FF); // Ice Cobalt (vurgu)
  static const _kGreenBg = Color(0xFF0D1622); // Deep Space Blue for selected items
  static const _kTextSub = Color(0xFF8B949E); // İkincil metin (Starlight dim)

  // Theme-aware white: dark mode → white, light mode → near-black
  Color get _tw => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1F2328);

  // Theme-aware selected card bg
  Color get _kSelBg => Theme.of(context).brightness == Brightness.dark
      ? _kGreenBg
      : const Color(0xFFEBF5FF);

  bool get _isTr => Provider.of<LanguageProvider>(context, listen: false).isTurkish;
  String _t(String tr, String en) => _isTr ? tr : en;

  // ── Core state ────────────────────────────────────────────────────────────
  OnboardingData _data = OnboardingData();
  _StepId _current = _StepId.welcome;
  final _pageCtrl = PageController();
  int _completedSteps = 0;
  bool _googleLoading = false;
  bool _signUpLoading = false;
  bool _finishLoading = false;
  bool _paywallPremiumSelected = true;
  bool _signUpObscure = true;
  bool _isLangExpanded = false;
  final TextEditingController _signUpEmailCtrl = TextEditingController();
  final TextEditingController _signUpPasswordCtrl = TextEditingController();

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // ── Text controllers ──────────────────────────────────────────────────────
  late final TextEditingController _firstNameCtrl;
  final _nameFocusNode = FocusNode();
  late final TextEditingController _pgOtherCtrl;
  late final TextEditingController _hdOtherCtrl;
  late final TextEditingController _diseaseOtherCtrl;
  late final TextEditingController _foodSensOtherCtrl;
  late final TextEditingController _suppOtherCtrl;
  late final TextEditingController _challOtherCtrl;
  late final TextEditingController _sgOtherCtrl;

  // Custom macro TextControllers
  final TextEditingController _carbPctCtrl = TextEditingController(text: '45');
  final TextEditingController _fatPctCtrl = TextEditingController(text: '30');
  final TextEditingController _proteinPctCtrl = TextEditingController(text: '25');
  final TextEditingController _fiberPctCtrl = TextEditingController(text: '0');
  bool _macroPctError = false;

  // ── Picker controllers ────────────────────────────────────────────────────
  // Age – day/month/year
  late final FixedExtentScrollController _dayPicker;
  late final FixedExtentScrollController _monthPicker;
  late final FixedExtentScrollController _yearPicker;
  int _selectedDay = 1;
  int _selectedMonth = 1;
  int _selectedYear = 2000;

  late final FixedExtentScrollController _heightCmPicker;
  late final FixedExtentScrollController _heightFtPicker;
  late final FixedExtentScrollController _heightInPicker;
  late final FixedExtentScrollController _weightKgPicker;
  late final FixedExtentScrollController _weightLbPicker;

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  late final AnimationController _completionCtrl;
  late final Animation<double> _completionScale;

  // Goal confirm – shown as system Overlay (not a PageView page)
  OverlayEntry? _goalConfirmEntry;

  // Section-complete overlay
  bool _showSectionComplete = false;
  String _sectionCompleteMessage = '';
  String _sectionCompleteFirstName = '';
  late final AnimationController _sectionCompleteCtrl;
  late final Animation<double> _sectionCompleteScale;
  late final AnimationController _comparisonCtrl;
  bool _comparisonPlayed = false;
  int _goalConfirmVisitCount = 0;

  // App intro
  final _introCtrl = PageController();
  int _introPage = 0;
  Timer? _introTimer;

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Ensure every device has a Firebase identity (anonymous if not signed in)
    DeviceIdService.instance.ensureFirebaseUser();

    // Generate a fresh ID for this onboarding session
    _data.onboardingId = 'user_${DateTime.now().millisecondsSinceEpoch}_${_generateShortId()}';

    // Set theme to system default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final brightness = MediaQuery.of(context).platformBrightness;
        context.read<ThemeProvider>().setDark(brightness == Brightness.dark);
      }
      if (widget.mode == OnboardingMode.newProfile) {
        // newProfile modunda kayıtlı ilerlemeyi yükleme, login adımından başla
        setState(() => _current = _StepId.login);
        _pageCtrl.jumpToPage(_StepId.values.indexOf(_StepId.login));
      } else {
        _loadProgress();
      }
    });

    _firstNameCtrl = TextEditingController()
      ..addListener(() {
        _data.firstName = _firstNameCtrl.text;
        if (mounted) setState(() {});
      });
    _pgOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.primaryGoalsOther = _pgOtherCtrl.text;
        if (mounted) setState(() {});
      });
    _hdOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.howHeardOther = _hdOtherCtrl.text;
        if (mounted) setState(() {});
      });
    _diseaseOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.diseasesOther = _diseaseOtherCtrl.text;
        if (mounted) setState(() {});
      });
    _foodSensOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.foodSensitivitiesOther = _foodSensOtherCtrl.text;
        if (mounted) setState(() {});
      });
    _suppOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.supplementsOther = _suppOtherCtrl.text;
        if (mounted) setState(() {});
      });
    _challOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.challengesOther = _challOtherCtrl.text;
        if (mounted) setState(() {});
      });
    _sgOtherCtrl = TextEditingController()
      ..addListener(() {
        _data.specificGoalsOther = _sgOtherCtrl.text;
        if (mounted) setState(() {});
      });

    _carbPctCtrl.addListener(_onMacroPctChanged);
    _fatPctCtrl.addListener(_onMacroPctChanged);
    _proteinPctCtrl.addListener(_onMacroPctChanged);
    _fiberPctCtrl.addListener(_onMacroPctChanged);

    // Age date pickers – default 2000-01-01 (offset by multiplier for infinite scroll)
    const kMinYear = 1926;
    final maxYear = DateTime.now().year - 13;
    final yearCount = maxYear - kMinYear + 1;
    _dayPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * 31 + 0); // day 1
    _monthPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * 12 + 0); // Jan
    _yearPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * yearCount + (2000 - kMinYear)); // year 2000

    _heightCmPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * 151 + 70); // 170 cm
    _heightFtPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * 5 + 2); // 5 ft
    _heightInPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * 12 + 7); // 7 in
    _weightKgPicker = FixedExtentScrollController(
        initialItem: _kPickerMul * 171 + 40); // 70 kg
    _weightLbPicker = FixedExtentScrollController(
        initialItem: (_data.weightKg * 2.20462).round().clamp(70, 550) - 70);

    // Logo
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4)));

    // Shake
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));

    // Completion
    _completionCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _completionScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _completionCtrl, curve: Curves.elasticOut));

    // Section-complete overlay
    _sectionCompleteCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _sectionCompleteScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _sectionCompleteCtrl, curve: Curves.elasticOut));

    // Comparison
    _comparisonCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    // Goal confirm is shown as a system Overlay (see _showGoalConfirmOverlay)
  }

  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    // Precache all images used throughout onboarding & paywall — runs once only
    for (final path in const [
      'assets/onboarding/intro.webp',
      'assets/onboarding/onboarding1.webp',
      'assets/onboarding/onboarding2.webp',
      'assets/onboarding/onboarding3.webp',
      'assets/onboarding/premium.webp',
      'assets/onboarding/suggest.webp',
      'assets/icon/icon.webp',
      'assets/profilepic/pp1.webp',
      'assets/profilepic/pp2.webp',
      'assets/profilepic/pp3.webp',
    ]) {
      precacheImage(AssetImage(path), context);
    }
  }

  void _onMacroPctChanged() {
    final carb = int.tryParse(_carbPctCtrl.text) ?? 0;
    final fat = int.tryParse(_fatPctCtrl.text) ?? 0;
    final protein = int.tryParse(_proteinPctCtrl.text) ?? 0;
    final fiber = int.tryParse(_fiberPctCtrl.text) ?? 0;
    final total = carb + fat + protein + fiber;
    setState(() {
      _macroPctError = total != 100;
      if (!_macroPctError) {
        _data.customCarbPct = carb.toDouble();
        _data.customFatPct = fat.toDouble();
        _data.customProteinPct = protein.toDouble();
        _data.customFiberPct = fiber.toDouble();
      }
    });
  }

  // ── Progress save/load ────────────────────────────────────────────────────

  Future<void> _saveProgress() async {
    if (widget.mode != OnboardingMode.fresh) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onboarding_step', _StepId.values.indexOf(_current));
    await prefs.setInt('onboarding_completed_steps', _completedSteps);
    await prefs.setString('onboarding_data', jsonEncode(_data.toJson()));
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final stepIdx = prefs.getInt('onboarding_step') ?? 0;
    final completed = prefs.getInt('onboarding_completed_steps') ?? 0;
    final raw = prefs.getString('onboarding_data');
    if (raw != null) {
      try {
        final loaded = OnboardingData.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        setState(() {
          _data = loaded;
          _completedSteps = completed;
          _current = _StepId.values[stepIdx.clamp(0, _StepId.values.length - 1)];
        });
        _firstNameCtrl.text = _data.firstName;
        _pageCtrl.jumpToPage(_StepId.values.indexOf(_current));
      } catch (_) {}
    }
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_step');
    await prefs.remove('onboarding_completed_steps');
    await prefs.remove('onboarding_data');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _introCtrl.dispose();
    _firstNameCtrl.dispose();
    _nameFocusNode.dispose();
    _pgOtherCtrl.dispose();
    _hdOtherCtrl.dispose();
    _diseaseOtherCtrl.dispose();
    _foodSensOtherCtrl.dispose();
    _suppOtherCtrl.dispose();
    _challOtherCtrl.dispose();
    _sgOtherCtrl.dispose();
    _carbPctCtrl.dispose();
    _fatPctCtrl.dispose();
    _proteinPctCtrl.dispose();
    _fiberPctCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _dayPicker.dispose();
    _monthPicker.dispose();
    _yearPicker.dispose();
    _heightCmPicker.dispose();
    _heightFtPicker.dispose();
    _heightInPicker.dispose();
    _weightKgPicker.dispose();
    _weightLbPicker.dispose();
    _logoCtrl.dispose();
    _shakeCtrl.dispose();
    _completionCtrl.dispose();
    _sectionCompleteCtrl.dispose();
    _introTimer?.cancel();
    _goalConfirmEntry?.remove();
    super.dispose();
  }

  // ── Active steps ──────────────────────────────────────────────────────────

  bool _shouldShowStep(_StepId step) {
    if (widget.mode == OnboardingMode.newProfile) {
      const skipped = {
        _StepId.welcome,   // Selamlama
        _StepId.howHeard,  // Nereden duydun
      };
      if (skipped.contains(step)) return false;
    }
    switch (step) {
      case _StepId.targetWeight:
      case _StepId.weeklyChange:
        return _data.weightGoal == Goal.lose ||
            _data.weightGoal == Goal.gain;
      case _StepId.alcohol:
        return _data.age > 18;
      case _StepId.pastWeightLoss:
        return _data.weightGoal == Goal.lose;
      case _StepId.weightLossExp:
        return _data.weightGoal == Goal.lose &&
            _data.pastWeightLoss == true;
      case _StepId.accountNotFound:
      case _StepId.recipeFeature:
      case _StepId.comparison:
        return false;
      default:
        return true;
    }
  }

  List<_StepId> get _activeSteps {
    return _StepId.values.where(_shouldShowStep).toList();
  }

  // ── Section helpers ───────────────────────────────────────────────────────

  _Section _sectionOf(_StepId step) {
    switch (step) {
      case _StepId.welcome:
      case _StepId.login:
      case _StepId.accountNotFound:
      case _StepId.comparison:
      case _StepId.comparisonTable:
      case _StepId.longevity:
      case _StepId.recipeFeature:
        return _Section.s1Welcome;
      case _StepId.name:
      case _StepId.primaryGoals:
      case _StepId.goalConfirm:
      case _StepId.howHeard:
        return _Section.s2Meeting;
      case _StepId.age:
      case _StepId.height:
      case _StepId.weight:
      case _StepId.gender:
      case _StepId.goal:
      case _StepId.targetWeight:
      case _StepId.weeklyChange:
      case _StepId.activityLevel:
      case _StepId.dietaryPlan:
      case _StepId.alcohol:
      case _StepId.pastWeightLoss:
      case _StepId.weightLossExp:
      case _StepId.bodyType:
      case _StepId.sunlight:
      case _StepId.sleepHours:
        return _Section.s3Personal1;
      case _StepId.cookingTime:
      case _StepId.motivation:
      case _StepId.hungerTime:
      case _StepId.mealCount:
      case _StepId.waterHabit:
      case _StepId.eatingOut:
      case _StepId.energyTime:
      case _StepId.emotionalEating:
      case _StepId.sleepSchedule:
      case _StepId.progressIndicator:
      case _StepId.exerciseFreq:
      case _StepId.notifications:
      case _StepId.healthConnect:
        return _Section.s4Personal2;
      case _StepId.diseases:
      case _StepId.foodSensitivities:
      case _StepId.supplements:
      case _StepId.mainChallenge:
      case _StepId.healthGoals:
        return _Section.s6Program;
      case _StepId.processing:
      case _StepId.planReady:
      case _StepId.signUp:
      case _StepId.calculatedValues:
      case _StepId.paywall:
      case _StepId.rateUs:
        return _Section.s7Processing;
      case _StepId.completion:
        return _Section.s8Done;
    }
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  double _sectionProgress(_Section section) {
    final steps =
        _activeSteps.where((s) => _sectionOf(s) == section).toList();
    if (steps.isEmpty) return 0;
    // Include the current step so the bar always shows at least 1/N progress
    // the moment the user arrives on that section, giving continuous movement.
    final inCurrentSection = _sectionOf(_current) == section;
    final countUpTo = _completedSteps + (inCurrentSection ? 1 : 0);
    final sectionCompleted =
        _activeSteps.take(countUpTo).where((s) => _sectionOf(s) == section).length;
    return (sectionCompleted / steps.length).clamp(0.0, 1.0);
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _isCurrentStepAnswered() {
    switch (_current) {
      case _StepId.name:
        return _data.firstName.trim().isNotEmpty;
      case _StepId.gender:
        return _data.gender != null;
      case _StepId.goal:
        return _data.weightGoal != null;
      case _StepId.primaryGoals:
        return _data.primaryGoals.isNotEmpty &&
            (!_data.primaryGoals.contains(_t('Diğer', 'Other')) || _pgOtherCtrl.text.trim().isNotEmpty);
      case _StepId.motivation:
        return _data.motivations.isNotEmpty;
      case _StepId.activityLevel:
        return _data.activityLevel != null;
      case _StepId.dietaryPlan:
        if (_data.dietaryPlan == null) return false;
        if (_data.dietaryPlan == _t('Özel', 'Custom')) return !_macroPctError;
        return true;
      // Required questions — cannot proceed without an answer
      case _StepId.howHeard:
        return _data.howHeard != null &&
            (_data.howHeard != _t('Diğer', 'Other') || _hdOtherCtrl.text.trim().isNotEmpty);
      case _StepId.alcohol:
        return _data.alcoholHabit != null;
      case _StepId.pastWeightLoss:
        return _data.pastWeightLoss != null;
      case _StepId.weightLossExp:
        return _data.weightLossExp != null;
      case _StepId.bodyType:
        return _data.bodyType != null;
      case _StepId.sunlight:
        return _data.hasSunlight != null;
      case _StepId.sleepHours:
        return _data.sleepHours != null;
      case _StepId.cookingTime:
        return _data.cookingTime != null;
      case _StepId.hungerTime:
        return _data.hungerTime != null;
      case _StepId.mealCount:
        return _data.mealCount != null;
      case _StepId.waterHabit:
        return _data.waterHabit != null;
      case _StepId.eatingOut:
        return _data.eatingOut != null;
      case _StepId.energyTime:
        return _data.energyTime != null;
      case _StepId.emotionalEating:
        return _data.emotionalEating != null;
      case _StepId.sleepSchedule:
        return _data.regularSleep != null;
      case _StepId.progressIndicator:
        return _data.progressIndicators.isNotEmpty;
      case _StepId.exerciseFreq:
        return _data.exerciseFreq != null;
      case _StepId.mainChallenge:
        return _data.challenges.isNotEmpty;
      case _StepId.healthGoals:
        return _data.specificGoals.isNotEmpty;
      default:
        return true;
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _navigateTo(_StepId step) {
    FocusManager.instance.primaryFocus?.unfocus();
    final steps = _activeSteps;
    final idx = steps.indexOf(step);
    setState(() {
      _current = step;
      if (idx >= 0) {
        _completedSteps = idx;
      }
    });

    if (step == _StepId.name) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _current == _StepId.name) {
          _nameFocusNode.requestFocus();
        }
      });
    }
    _pageCtrl.jumpToPage(_StepId.values.indexOf(step));
    if (step == _StepId.welcome) {
      _startIntroTimer();
    } else {
      _introTimer?.cancel();
      _introTimer = null;
    }

    if (step == _StepId.goalConfirm) {
      _goalConfirmVisitCount++;
    }
    if (step == _StepId.comparison || step == _StepId.comparisonTable) {
      _comparisonCtrl.forward(from: 0.0);
    }
    if (step == _StepId.completion) {
      _completionCtrl.forward();
    }
  }

  void _startIntroTimer() {
    _introTimer?.cancel();
    _introTimer = Timer.periodic(const Duration(milliseconds: 5000), (_) {
      if (!mounted) return;
      final next = (_introPage + 1) % 3;
      _introCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_isCurrentStepAnswered()) {
      _shakeCtrl.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir seçenek seç'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final steps = _activeSteps;
    final idx = steps.indexOf(_current);
    if (idx < 0) return;

    final oldSection = _sectionOf(_current);
    setState(() {
      if (_completedSteps <= idx) _completedSteps = idx + 1;
    });
    if (_current == _StepId.primaryGoals) {
      _navigateTo(steps[idx + 1]);
      return;
    }
    // calculatedValues navigates normally to signUp (account creation step)
    if (idx < steps.length - 1) {
      final nextStep = steps[idx + 1];
      final newSection = _sectionOf(nextStep);
      if (newSection != oldSection &&
          oldSection != _Section.s1Welcome &&
          oldSection != _Section.s7Processing &&
          oldSection != _Section.s8Done) {
        _onSectionComplete(oldSection, nextStep);
        return;
      }
      _navigateTo(nextStep);
    } else {
      _finish();
    }
  }

  // ── Auth handlers ─────────────────────────────────────────────────────────

  void _showAuthErrorDialog(String message, {String title = 'Uyarı'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam', style: TextStyle(color: Color(0xFF58A6FF))),
          ),
        ],
      ),
    );
  }

  // Kullanılan yer: _stepLogin – giriş yap akışı (hesap yoksa popup, varsa premium kontrolü)
  Future<void> _handleGoogleSignInForLogin() async {
    setState(() => _googleLoading = true);
    final result = await AuthService().signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);

    if (result.cancelled) return;

    if (!result.success) {
      _showAuthErrorDialog(result.errorMessage ?? 'Google girişi başarısız. Lütfen tekrar deneyin.');
      return;
    }

    // Hesap yok veya onboarding tamamlanmamış → kayıtlı hesap yok
    if (!result.onboardingComplete) {
      _showAuthErrorDialog(
        'Bu Google hesabına kayıtlı bir profil bulunamadı.',
        title: _t('Hesap Bulunamadı', 'Account Not Found'),
      );
      return;
    }

    // Onboarding tamamlanmış → premium kontrolü
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    SyncService.instance.pullUserData();
    final profileProv = context.read<ProfileProvider>();
    await profileProv.loadProfiles();
    if (!mounted) return;

    if (profileProv.isPremium) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PaywallScreen(fromOnboarding: true)),
      );
    }
  }

  // Kullanılan yer: _stepSignUp – hesap oluştur akışı
  Future<void> _handleGoogleSignIn() async {
    setState(() => _googleLoading = true);
    final result = await AuthService().signInWithGoogle();
    if (!mounted) return;

    if (result.cancelled) {
      setState(() => _googleLoading = false);
      return;
    }

    if (!result.success) {
      setState(() => _googleLoading = false);
      _showAuthErrorDialog(result.errorMessage ?? 'Google girişi başarısız.');
      return;
    }

    if (result.user != null) {
      DeviceIdService.instance.migrateAnonDataToUser(result.user!.uid);
    }

    setState(() => _googleLoading = false);

    if (result.onboardingComplete) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
      if (!mounted) return;
      SyncService.instance.pullUserData();
      final profileProv = context.read<ProfileProvider>();
      await profileProv.loadProfiles();
      if (!mounted) return;

      if (profileProv.isPremium) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaywallScreen(fromOnboarding: true)),
        );
      }
      return;
    }

    // Yeni Google hesabı → ID'yi Firebase UID ile değiştir
    _data.onboardingId = FirebaseAuth.instance.currentUser?.uid;
    if (_current == _StepId.signUp) {
      // Onboarding sonu → profili kaydet, plan özetini göster
      await _saveProfile();
      if (!mounted) return;
      _navigateTo(_StepId.completion);
    } else {
      // Login adımı → onboarding'e devam
      _navigateTo(_StepId.name);
    }
  }

  void _handleEmailTap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmailAuthSheet(
        onSuccess: (bool onboardingDone) async {
          Navigator.pop(ctx);
          final profileProv = context.read<ProfileProvider>();
          await profileProv.loadProfiles();
          
          if (onboardingDone) {
            if (profileProv.isPremium) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PaywallScreen(fromOnboarding: true)),
              );
            }
          } else {
            // New account, update ID to the user's UID
            _data.onboardingId = FirebaseAuth.instance.currentUser?.uid;
            _navigateTo(_StepId.name);
          }
        },
        onUserNotFound: null,
      ),
    );
  }

  Future<void> _onSectionComplete(_Section section, _StepId nextStep, {String? overrideMessage}) async {
    // s6Program has no overlay — navigate directly
    const noOverlay = {_Section.s6Program, _Section.s1Welcome, _Section.s7Processing, _Section.s8Done};
    if (noOverlay.contains(section) && overrideMessage == null) {
      _navigateTo(nextStep);
      return;
    }
    final firstName = _data.firstName.trim();
    String msg;
    if (overrideMessage != null) {
      msg = overrideMessage;
    } else if (section == _Section.s2Meeting) {
      msg = 'meeting'; // special RichText case
    } else if (section == _Section.s3Personal1) {
      msg = _t('Verileriniz işleniyor; biyolojik modeliniz yapılandırılıyor... ⚙️', 'Processing your data; configuring your biological model... ⚙️');
    } else {
      msg = 'Neredeyse bitti! 🎯';
    }
    setState(() {
      _showSectionComplete = true;
      _sectionCompleteMessage = msg;
      _sectionCompleteFirstName = firstName;
    });
    _sectionCompleteCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    await _sectionCompleteCtrl.reverse();
    if (!mounted) return;
    setState(() => _showSectionComplete = false);
    _navigateTo(nextStep);
  }

  bool _isTransitionStep(_StepId step) {
    return step == _StepId.goalConfirm || step == _StepId.processing;
  }

  void _back() {
    final steps = _activeSteps;
    final idx = steps.indexOf(_current);
    if (idx > 0) {
      if (_current == _StepId.signUp) {
        _navigateTo(_StepId.rateUs);
        return;
      }
      if (_current == _StepId.longevity) {
        _navigateTo(_StepId.login);
        return;
      }
      if (_current == _StepId.comparisonTable) {
        _navigateTo(_StepId.longevity);
        return;
      }
      int prevIdx = idx - 1;
      while (prevIdx > 0 && (
        _isTransitionStep(steps[prevIdx]) || 
        steps[prevIdx] == _StepId.login || 
        steps[prevIdx] == _StepId.accountNotFound
      )) {
        prevIdx--;
      }
      _navigateTo(steps[prevIdx]);
    }
  }

  bool get _showBottomNav {
    switch (_current) {
      case _StepId.processing:
      case _StepId.login:
      case _StepId.signUp:
      case _StepId.paywall:
      case _StepId.completion:
      case _StepId.goalConfirm:
      case _StepId.notifications:
      case _StepId.healthConnect:
        return false;
      default:
        return true;
    }
  }

  String get _nextButtonLabel {
    if (_current == _StepId.welcome) return _t('Hadi Başlayalım!', 'Let\'s Get Started!');
    if (_current == _StepId.planReady) return _t('İlerle', 'Next');
    if (_current == _StepId.calculatedValues) return _t('Devam et', 'Continue');

    final steps = _activeSteps;
    final idx = steps.indexOf(_current);
    if (idx == steps.length - 1) return _t('Tamamla', 'Complete');
    return _t('Devam Et', 'Continue');
  }

  // ── Finish ────────────────────────────────────────────────────────────────

  /// Profili SQLite'a kaydeder ve prefs/Firebase arka plan işlerini başlatır.
  /// Navigasyon yapmaz — [_goHome] ile birlikte kullanılır.
  Future<void> _saveProfile() async {
    final profileProvider = context.read<ProfileProvider>();
    final name = _data.firstName.trim();

    final goal = _data.weightGoal ?? Goal.maintain;
    double savedDelta = 0;
    if (goal == Goal.lose) {
      savedDelta = _data.weeklyChangeDelta;
    } else if (goal == Goal.gain) {
      savedDelta = -_data.weeklyChangeDelta;
    }

    await profileProvider.save(
      profileId: _data.onboardingId,
      name: name.isEmpty ? 'Kullanıcı' : name,
      age: _data.age,
      height: _data.heightCm,
      weight: _data.weightKg,
      gender: _data.gender ?? Gender.male,
      activityLevel: _data.activityLevel ?? ActivityLevel.moderate,
      goal: goal,
      healthConditions: _data.diseases.toList(),
      dietaryPreferences: [if (_data.dietaryPlan != null) _data.dietaryPlan!],
      weeklyWeightDelta: savedDelta,
      createdAt: DateTime.now(),
      startingWeight: _data.weightKg,
    );

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    final answersJson = jsonEncode(_data.toJson());
    await prefs.setString('onboarding_answers', answersJson);
    await prefs.setBool('onboarding_answers_synced', false);
    await _clearProgress();

    final signedInUser = FirebaseAuth.instance.currentUser;
    if (signedInUser != null && !signedInUser.isAnonymous) {
      await _saveOnboardingToFirestore(signedInUser);
    } else {
      _saveOnboardingAnonymously();
    }

    if (!Platform.isWindows && profileProvider.activeProfile != null) {
      SyncService.instance.checkAndSyncPendingOnboarding(profileProvider.activeProfile!);
    }
  }

  /// Profil zaten kaydedilmiş, sadece HomeScreen'e geçer.
  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _finish() async {
    try {
      if (widget.isFromProfileAdd) {
        final name = _data.firstName.trim();
        await _saveProfile();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${name.isEmpty ? 'Kullanıcı' : name} ${ _t('profili oluşturuldu', 'profile was created') }'),
          ),
        );
      } else {
        await _saveProfile();
        if (!mounted) return;
        _goHome();
      }
    } catch (e) {
      debugPrint('Onboarding _finish error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(_t('Bir hata oluştu: $e', 'An error occurred: $e'), 'An error occurred: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _finishLoading = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final section = _sectionOf(_current);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: WavePainter(isDark: isDark),
              ),
            ),
            Column(
              children: [
                // Section bar takes real layout space — content never goes behind it
                _buildSectionBar(theme, primary, section),
                // Pages
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) {
                      final dx =
                          sin(_shakeAnim.value * pi * 5) * 6 * (1 - _shakeAnim.value);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: PageView.builder(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _StepId.values.length,
                      itemBuilder: (_, i) =>
                          _KeepAlivePage(child: _buildStep(_StepId.values[i])),
                    ),
                  ),
                ),
                // Bottom nav
                if (_showBottomNav) _buildBottomNav(theme, primary),
              ],
            ),
            // Section complete overlay
            if (_showSectionComplete)
              _buildSectionCompleteOverlay(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBar(ThemeData theme, Color primary, _Section section) {
    final sections = _Section.values;
    final sectionIdx = sections.indexOf(section);
    final isDark = theme.brightness == Brightness.dark;
    final showBack = !_showSectionComplete &&
        _current != _StepId.welcome &&
        _current != _StepId.processing &&
        _current != _StepId.goalConfirm &&
        _current != _StepId.paywall &&
        _current != _StepId.completion;
    final showThemeToggle = _current == _StepId.welcome;

    final barBg = isDark ? _kBorder : const Color(0xFFD0D7DE);
    final barFill = isDark ? _kGreen : const Color(0xFF0969DA);

    // First 3 sections are wider (flex 14 vs flex 10)
    int flexFor(int i) => i < 3 ? 14 : 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack)
            GestureDetector(
              onTap: _back,
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isDark ? _kCard : const Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chevron_left, color: _tw, size: 20),
              ),
            ),
          Expanded(
            child: Row(
              children: List.generate(sections.length, (i) {
                double fillPct = 0;
                if (i < sectionIdx) {
                  fillPct = 1.0;
                } else if (i == sectionIdx) {
                  fillPct = _sectionProgress(sections[i]);
                }
                return Expanded(
                  flex: flexFor(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 3,
                    decoration: BoxDecoration(
                      color: barBg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: LayoutBuilder(
                      builder: (_, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          width: constraints.maxWidth * fillPct.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: barFill,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (showThemeToggle) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<ThemeProvider>().toggleTheme();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? _kCard : const Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? _kBorder : const Color(0xFFD0D7DE),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      key: ValueKey(isDark),
                      color: isDark ? const Color(0xFFFFB800) : const Color(0xFF4A5568),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme, Color primary) {
    final answered = _isCurrentStepAnswered();
    final isWelcome = _current == _StepId.welcome;
    final isDark = theme.brightness == Brightness.dark;

    final btnColor = isDark
        ? (answered ? Colors.white : Colors.white.withValues(alpha: 0.35))
        : (answered ? const Color(0xFF1F2328) : const Color(0xFFCDD5DE));
    final textColor = isDark
        ? Colors.black
        : (answered ? Colors.white : const Color(0xFF8B949E));

    final button = GestureDetector(
      onTap: answered
          ? () {
              HapticFeedback.mediumImpact();
              if (isWelcome) {
                _navigateTo(_StepId.longevity);
              } else {
                _next();
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: _finishLoading && _current == _StepId.calculatedValues
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
              Text(
                _nextButtonLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: textColor, size: 18),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: isWelcome
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<LanguageProvider>(
                  builder: (context, lp, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isLangExpanded = !_isLangExpanded),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(lp.isTurkish ? '🇹🇷' : '🇺🇸', style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                lp.isTurkish ? 'TR' : 'EN',
                                style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isLangExpanded) ...[
                        const SizedBox(width: 12),
                        _langItemSmall(lp, lp.isTurkish ? 'en' : 'tr', lp.isTurkish ? '🇺🇸' : '🇹🇷', lp.isTurkish ? 'EN' : 'TR'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _navigateTo(_StepId.login),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _t('Zaten tanışıyoruz!', 'Already met!'),
                          style: TextStyle(fontSize: 13, color: _tw),
                        ),
                        Spacer(),
                        Text(
                          _t('Giriş Yap', 'Log In'),
                          style: TextStyle(
                            color: _kGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                button,
              ],
            )
          : (_current == _StepId.comparisonTable
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t(
                        '* Değerler piyasadaki ortalama uygulamalar temel alınarak gösterilmiştir.',
                        '* Values are shown based on average applications on the market.'
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: _kTextSub,
                        height: 1.3,
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    button,
                  ],
                )
              : button),
    );
  }


  Widget _langItemSmall(LanguageProvider lp, String code, String flag, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        lp.toggleLanguage();
        setState(() => _isLangExpanded = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE8EDF2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFD0D7DE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: isDark ? Colors.white70 : _kTextSub, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildLangMenuItem(String code, String flag, String name) {
    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Text(
            name,
            style: TextStyle(color: _tw, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCompleteOverlay(ThemeData theme, bool isDark) {
    return Positioned.fill(
      child: Container(
        color: isDark ? _kBg : theme.scaffoldBackgroundColor,
        child: CustomPaint(
          painter: WavePainter(isDark: isDark),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _sectionCompleteScale,
                  builder: (context2, child) => Transform.scale(
                    scale: _sectionCompleteScale.value,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: (_sectionCompleteMessage == 'goalConfirm' ? _kGreen : _kGreen).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _sectionCompleteMessage == 'goalConfirm' ? Icons.check_rounded : Icons.check_rounded,
                        color: _kGreen,
                        size: 52,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _sectionCompleteMessage == 'goalConfirm'
                      ? const SizedBox.shrink()
                      : _sectionCompleteMessage == 'meeting'
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: _tw,
                                      height: 1.3,
                                    ),
                                    children: [
                                      TextSpan(text: _t('Memnun olduk, ', 'Nice to meet you, ')),
                                      TextSpan(
                                        text: _sectionCompleteFirstName.isNotEmpty
                                            ? '$_sectionCompleteFirstName!'
                                            : _t('seni!', 'you!'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          foreground: Paint()
                                            ..shader = const LinearGradient(
                                              colors: [
                                                Color(0xFF58A6FF),
                                                Color(0xFFC0E0FF),
                                                Color(0xFF58A6FF),
                                              ],
                                            ).createShader(
                                            const Rect.fromLTWH(0, 0, 200, 40)),
                                      shadows: [
                                        Shadow(
                                          color: _kBlue.withValues(alpha: 0.5),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t('Beraber harika işler çıkaracağız.', 'We will do great things together.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                color: _tw,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t('Hadi, detaylara inelim.', 'Let\'s dive into the details.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                color: _tw,
                                height: 1.3,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _sectionCompleteMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _tw,
                            height: 1.3,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step router ───────────────────────────────────────────────────────────

  Widget _buildStep(_StepId id) {
    switch (id) {
      case _StepId.welcome:
        return _stepWelcome();
      case _StepId.login:
        return _stepLogin();
      case _StepId.accountNotFound:
        return _stepAccountNotFound();
      case _StepId.comparison:
        return _stepComparison();
      case _StepId.comparisonTable:
        return _stepComparisonTable();
      case _StepId.longevity:
        return _stepLongevity();
      case _StepId.recipeFeature:
        return _stepRecipeFeature();
      case _StepId.name:
        return _stepName();
      case _StepId.primaryGoals:
        return _stepPrimaryGoals();
      case _StepId.goalConfirm:
        return _stepGoalConfirm();
      case _StepId.howHeard:
        return _stepHowHeard();
      case _StepId.age:
        return _stepAge();
      case _StepId.height:
        return _stepHeight();
      case _StepId.weight:
        return _stepWeight();
      case _StepId.gender:
        return _stepGender();
      case _StepId.goal:
        return _stepGoal();
      case _StepId.targetWeight:
        return _stepTargetWeight();
      case _StepId.weeklyChange:
        return _stepWeeklyChange();
      case _StepId.activityLevel:
        return _stepActivityLevel();
      case _StepId.dietaryPlan:
        return _stepDietaryPlan();
      case _StepId.alcohol:
        return _stepAlcohol();
      case _StepId.pastWeightLoss:
        return _stepPastWeightLoss();
      case _StepId.weightLossExp:
        return _stepWeightLossExp();
      case _StepId.bodyType:
        return _stepBodyType();
      case _StepId.sunlight:
        return _stepSunlight();
      case _StepId.sleepHours:
        return _stepSleepHours();
      case _StepId.cookingTime:
        return _stepCookingTime();
      case _StepId.motivation:
        return _stepMotivation();
      case _StepId.hungerTime:
        return _stepHungerTime();
      case _StepId.mealCount:
        return _stepMealCount();
      case _StepId.waterHabit:
        return _stepWaterHabit();
      case _StepId.eatingOut:
        return _stepEatingOut();
      case _StepId.energyTime:
        return _stepEnergyTime();
      case _StepId.emotionalEating:
        return _stepEmotionalEating();
      case _StepId.sleepSchedule:
        return _stepSleepSchedule();
      case _StepId.progressIndicator:
        return _stepProgressIndicator();
      case _StepId.exerciseFreq:
        return _stepExerciseFreq();
      case _StepId.notifications:
        return _stepNotifications();
      case _StepId.healthConnect:
        return _stepHealthConnect();
      case _StepId.rateUs:
        return _stepRateUs();
      case _StepId.diseases:
        return _stepDiseases();
      case _StepId.foodSensitivities:
        return _stepFoodSensitivities();
      case _StepId.supplements:
        return _stepSupplements();
      case _StepId.mainChallenge:
        return _stepMainChallenge();
      case _StepId.healthGoals:
        return _stepHealthGoals();
      case _StepId.processing:
        return _stepProcessing();
      case _StepId.planReady:
        return _stepPlanReady();
      case _StepId.signUp:
        return _stepSignUp();
      case _StepId.calculatedValues:
        return _stepCalculatedValues();
      case _StepId.paywall:
        return _stepPaywall();
      case _StepId.completion:
        return _stepCompletion();
    }
  }

  // ==========================================================================
  // STEP WIDGETS
  // ==========================================================================

  // ── S1: Welcome ────────────────────────────────────────────────────────────

  Widget _stepWelcome() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = theme.colorScheme.onSurface;
    final accentColor = theme.colorScheme.primary;
    final gradientColors = isDark
        ? const [Color(0xFF58A6FF), Color(0xFFC0E0FF), Color(0xFF58A6FF)]
        : const [Color(0xFF0969DA), Color(0xFF4393E4), Color(0xFF0969DA)];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _logoCtrl,
                builder: (_, child) => Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset('assets/onboarding/intro.webp', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Title with standard text style (no blue gradient for yaşam/longevity)
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(
                      text: _t(
                        'Hücresel gençlik ve uzun yaşam yolculuğuna hoş\u{00A0}geldin!\u{00A0}✨',
                        'Welcome to your\ncellular youth and\nlongevity journey! ✨'
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    color: textMain.withValues(alpha: 0.85),
                    height: 1.6,
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                  ),
                  children: [
                    TextSpan(text: _t('Kulaktan dolma bilgilerle değil, ', 'Move forward with your ')),
                    TextSpan(
                      text: _t('vücudunun gerçek ihtiyaçlarıyla', 'body\'s real needs'),
                      style: TextStyle(color: textMain, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _t(' ilerle.', ', not guesswork.')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── S1: Login ──────────────────────────────────────────────────────────────

  Widget _stepLogin() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _t('Giriş Yap', 'Log In'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _tw),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 15, color: _kTextSub, height: 1.5),
              children: [
                TextSpan(text: _t('Daha önce de mi bizimleydin? Hesabına ', 'Were you with us before? ')),
                TextSpan(
                  text: _t('giriş yap', 'Log in'),
                  style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '\nve '),
                TextSpan(
                  text: _t('kaldığın yerden devam et.', 'continue where you left off.'),
                  style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _authButton(
            useGoogleIcon: true,
            label: _t('Google ile giriş yap', 'Log in with Google'),
            onTap: _googleLoading ? null : _handleGoogleSignInForLogin,
            loading: _googleLoading,
          ),
          const SizedBox(height: 12),
          _authButton(
            icon: '✉️',
            label: _t('E-posta ile giriş yap', 'Log in with Email'),
            onTap: _handleEmailTap,
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 12),
            _authButton(icon: '🍎', label: _t('Apple ile giriş yap', 'Log in with Apple'), onTap: _next),
          ],
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => _navigateTo(_StepId.longevity),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _kGreen),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _t('Hesabın yok mu? Yolculuğa başla →', 'Don\'t have an account? Start the journey →'),
                  style: TextStyle(
                    fontSize: 13,
                    color: _kGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepAccountNotFound() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_circle_outlined, size: 64, color: _kGreen),
          ),
          const SizedBox(height: 32),
          Text(
            _t('Hesap Bulunamadı', 'Account Not Found'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _tw),
          ),
          const SizedBox(height: 16),
          Text(
            _t('Bu e-posta adresi ile kayıtlı bir hesap bulamadık. Yeni bir yolculuğa başlamaya ne dersin?', 'We couldn\'t find an account registered with this email address. How about starting a new journey?'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: _kTextSub, height: 1.6),
          ),
          const SizedBox(height: 48),
          _authButton(
            label: _t('Yolculuğa Başla →', 'Start Journey →'),
            onTap: () => _navigateTo(_StepId.longevity),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _navigateTo(_StepId.login),
            child: Text(
              _t('Farklı bir hesapla dene', 'Try a different account'),
              style: TextStyle(
                fontSize: 14,
                color: _kTextSub,
                decoration: TextDecoration.underline,
                decorationColor: _kTextSub.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── S1: Comparison ────────────────────────────────────────────────────────
  
  // ── S1: Longevity ──────────────────────────────────────────────────────────

  Widget _stepLongevity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _t('Hücresel sağlığın ile\ndaha uzun yaşa', 'Live longer with your\ncellular health'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _tw,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 15, color: _kTextSub, height: 1.6),
              children: [
                TextSpan(
                  text: 'LensEat ',
                  style: TextStyle(color: _kBlue, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: _t('sadece kalori takibiyle değil,\nmikro besin analiziyle de ', 'is not just about calorie tracking, but also with micro nutrient analysis,\n')),
                TextSpan(
                  text: _t('hücresel sağlığını', 'your cellular health'),
                  style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' ve '),
                TextSpan(
                  text: _t('uzun ömürlülüğünü', 'your longevity'),
                  style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: _t(' artırmayı hedefler.', '\naims to increase.')),
              ],
            ),
          ),
          const SizedBox(height: 50),
          // Chart Area
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBlue, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _LongevityChart(active: _current == _StepId.longevity),
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              '* Bu grafik, beslenme takibinin uzun vadeli etkilerini inceleyen PREMIER Klinik Araştırması ve literatürdeki mikro besin yeterlilik verileri temel alınarak simüle edilmiştir.',
              '* This graph is simulated based on the PREMIER Clinical Trial studying the long-term effects of nutrition tracking and micro-nutrient sufficiency data in literature.'
            ),
            style: const TextStyle(
              fontSize: 10,
              color: _kTextSub,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _stepRecipeFeature() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imgWidth = constraints.maxWidth - 48;
        final imgHeight = imgWidth / (2448 / 1374);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _t('50\'den fazla\nsağlıklı tarif', 'More than 50\nhealthy recipes'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _tw,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(fontSize: 15, color: _kTextSub, height: 1.6),
                  children: [
                    TextSpan(
                      text: 'LensEat ',
                      style: TextStyle(color: _kBlue, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _t('her öğün için uzman onaylı', 'expert-approved')),
                    TextSpan(
                      text: _t(' tarif önerileri ', ' recipe suggestions '),
                      style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: _t('sunar.\nKahvaltıdan akşam yemeğine, ara öğünden\n', 'for every meal.\nFrom breakfast to dinner, snack to\n')),
                    TextSpan(
                      text: _t('makro ve mikro besin değerleriyle', 'macro and micro nutrient values,'),
                      style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: _t(' her tarif sana özel.', ' every recipe is personalized for you.')),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/onboarding/suggest.webp',
                  width: imgWidth,
                  height: imgHeight,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _chartLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: _kTextSub)),
      ],
    );
  }

  Widget _stepComparison() {
    return AnimatedBuilder(
      animation: _comparisonCtrl,
      builder: (context, child) {
        final progress = _comparisonCtrl.value;
        final showSad = progress > 0.3;
        final showHappy = progress > 0.6;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 52), // Offset for progress bar
              Text(
                _t('Besin analizinde 8 kat\ndaha fazlasını keşfet', 'Discover 8 times more\nin nutrient analysis'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _tw,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    color: _kTextSub,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(text: _t('Diğer uygulamalar sadece temel verileri sunarken,\n', 'While other apps only offer basic data,\n')),
                    const TextSpan(
                      text: 'LensEat ',
                      style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: 'mikro',
                      style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' ve '),
                    TextSpan(
                      text: 'makro besin analiziyle\n',
                      style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: _t('hücresel sağlığını derinlemesine takip eder.', 'deeply tracks your cellular health.')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 320, // Fixed height for the comparison area
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Diğer Uygulamalar
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _kBorder, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _t('Diğer\nUygulamalar', 'Other\nApps'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 220, // Match LensEat height area
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    height: 60 * progress,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFBDBDBD),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.bottomCenter,
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: showSad 
                                      ? TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 400),
                                          builder: (context, val, child) => Transform.scale(
                                            scale: val,
                                            child: const Text('😔', style: TextStyle(fontSize: 28)),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // LensEat
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _kBlue, width: 2.0),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _t('LensEat\nile', 'With\nLensEat'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.w900, 
                                color: Color(0xFF0056B3),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    height: 220 * progress,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF58A6FF),
                                          Color(0xFF0056B3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        const Center(
                                          child: Text(
                                            'x8',
                                            style: TextStyle(
                                              fontSize: 44,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          left: 0,
                                          right: 0,
                                          child: showHappy 
                                            ? TweenAnimationBuilder<double>(
                                                tween: Tween(begin: 0.0, end: 1.0),
                                                duration: const Duration(milliseconds: 400),
                                                builder: (context, val, child) => Transform.scale(
                                                  scale: val,
                                                  child: const Text(
                                                    '😎',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(fontSize: 28),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _stepComparisonTable() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMain = theme.colorScheme.onSurface;

    // CurvedAnimations for staggered Row item entrances
    final anim1 = CurvedAnimation(
      parent: _comparisonCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );
    final anim2 = CurvedAnimation(
      parent: _comparisonCtrl,
      curve: const Interval(0.12, 0.52, curve: Curves.easeOutBack),
    );
    final anim3 = CurvedAnimation(
      parent: _comparisonCtrl,
      curve: const Interval(0.24, 0.64, curve: Curves.easeOutBack),
    );
    final anim4 = CurvedAnimation(
      parent: _comparisonCtrl,
      curve: const Interval(0.36, 0.76, curve: Curves.easeOutBack),
    );
    final anim5 = CurvedAnimation(
      parent: _comparisonCtrl,
      curve: const Interval(0.48, 0.88, curve: Curves.easeOutBack),
    );
    final anim6 = CurvedAnimation(
      parent: _comparisonCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // Disable vertical scroll
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36), // Offset for progress bar (reduced from 52)
              Text(
                _t('Diğerleri gibi değiliz!', "We're not like the others!"),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: textMain,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10), // Reduced from 16
              Text(
                _t(
                  'Sağlık yolculuğunda sıradan uygulamalar gibi değiliz!',
                  'We are not like ordinary health apps on your journey!'
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: _kTextSub,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16), // Reduced from 28
              
              // Table Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? _kCard : const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE1E4E8),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Header Row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: const SizedBox()),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'LENSEAT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                _t('DİĞER*', 'OTHERS*'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: _kTextSub,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 16),
 
                    // Row 1: 4 Different Meal Analyses
                    _buildComparisonRow(
                      title: _t('4 Farklı Yemek Analizi', '4 Different Meal Analyses'),
                      subtitle: _t('Görsel, anlatım, barkod veya manuel giriş', 'Image, description, barcode or manual entry'),
                      anim: anim1,
                      isTr: true,
                      otherState: _RowState.cross,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12), // Reduced from 16
 
                    // Row 2: Micro-nutrient tracking
                    _buildComparisonRow(
                      title: _t('Mikro Besin Analizi', 'Micro-nutrient Analysis'),
                      subtitle: _t('Vitamin, mineral vb. mikro besin takibi', 'Tracking of vitamins, minerals & micro-nutrients'),
                      anim: anim2,
                      isTr: true,
                      otherState: _RowState.dash,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12), // Reduced from 16
 
                    // Row 3: 4 Different Fasting Modes
                    _buildComparisonRow(
                      title: _t('4 Farklı Oruç Modu', '4 Different Fasting Modes'),
                      subtitle: _t('Farklı protokollerle aralıklı oruç takibi', 'Intermittent fasting tracking with different protocols'),
                      anim: anim3,
                      isTr: true,
                      otherState: _RowState.cross,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12), // Reduced from 16
 
                    // Row 4: Personalized Recipes
                    _buildComparisonRow(
                      title: _t('Kişisel Tarif Önerileri', 'Personalized Recipes'),
                      subtitle: _t('Günlük verilerine göre tarif tavsiyeleri', 'Recipe suggestions based on your daily data'),
                      anim: anim4,
                      isTr: true,
                      otherState: _RowState.dash,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12), // Reduced from 16

                    // Row 5: AI Chat Coach
                    _buildComparisonRow(
                      title: _t('Birebir Beslenme Koçu', 'Personal Nutrition Coach'),
                      subtitle: _t('Seni dinleyen, sorularını yanıtlayan ve yol gösteren asistan', 'Assistant that listens to you, answers questions & guides you'),
                      anim: anim5,
                      isTr: true,
                      otherState: _RowState.dash,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12), // Reduced from 16

                    // Row 6: Progress Reports
                    _buildComparisonRow(
                      title: _t('Haftalık Gelişim Raporları', 'Weekly Progress Reports'),
                      subtitle: _t('Kilo, besin ve hücresel sağlık analizleri', 'Weekly weight, nutrition & cellular reports'),
                      anim: anim6,
                      isTr: true,
                      otherState: _RowState.cross,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonRow({
    required String title,
    required String subtitle,
    required Animation<double> anim,
    required bool isTr,
    required _RowState otherState,
    required bool isDark,
  }) {
    return Row(
      children: [
        // Feature description
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _kTextSub,
                ),
              ),
            ],
          ),
        ),

        // LensEat
        Expanded(
          flex: 2,
          child: Center(
            child: ScaleTransition(
              scale: anim,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF0969DA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
          ),
        ),

        // Other
        Expanded(
          flex: 2,
          child: Center(
            child: ScaleTransition(
              scale: anim,
              child: _buildOtherIcon(otherState, isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherIcon(_RowState state, bool isDark) {
    if (state == _RowState.cross) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.close,
          color: isDark ? Colors.white30 : Colors.black26,
          size: 14,
        ),
      );
    } else {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white30 : Colors.black26,
        ),
      );
    }
  }

  Widget _authButton({
    String? icon,
    bool useGoogleIcon = false,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isDark ? _kCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
              )
            else if (useGoogleIcon)
              ShaderMask(
                shaderCallback: (bounds) => const SweepGradient(
                  colors: [
                    Color(0xFFEA4335),
                    Color(0xFFFBBC05),
                    Color(0xFF34A853),
                    Color(0xFF4285F4),
                    Color(0xFFEA4335),
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                ).createShader(bounds),
                child: const Text(
                  'G',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              )
            else if (icon != null)
              Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _tw),
            ),
          ],
        ),
      ),
    );
  }

  // ── S2: App intro ──────────────────────────────────────────────────────────

  Widget _stepAppIntro() {
    final slides = [
      (
        color: Color(0xFF0D0D11),
        image: 'assets/onboarding/onboarding1.webp',
        title: '65+ Mikro Besin Analizi',
        desc: _t('Yemeğini fotoğrafla, yapay zeka 65 farklı mikro besini anında analiz etsin.', 'Photo your food, AI analyzes 65 different micro nutrients instantly.'),
      ),
      (
        color: Color(0xFF0D0D11),
        image: 'assets/onboarding/onboarding2.webp',
        title: _t('Uzun Yaşam Takibi', 'Longevity Tracking'),
        desc: _t('Hücresel sağlığını ve biyolojik yaşını optimize eden özel raporlarla tanış.', 'Meet special reports that optimize your cellular health and biological age.'),
      ),
      (
        color: Color(0xFF0D0D11),
        image: 'assets/onboarding/onboarding3.webp',
        title: _t('Beslenme Koçu', 'Nutrition Coach'),
        desc: _t('Uzun ve sağlıklı bir yaşam için biyolojine özel bilimsel öneriler her zaman yanında.', 'Scientific recommendations tailored to your biology for a long and healthy life are always with you.'),
      ),
    ];
    return Column(
      children: [
        // Auto-scrolling image area – takes all remaining space
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: _introCtrl,
                itemCount: slides.length,
                onPageChanged: (i) {
                  setState(() => _introPage = i);
                  _startIntroTimer();
                },
                itemBuilder: (_, i) {
                  final s = slides[i];
                  return Container(
                    color: s.color,
                    child: Image.asset(
                      s.image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  );
                },
              ),
              // Dot indicator overlaid on at the bottom of the image area
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(slides.length, (i) {
                    final active = i == _introPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? _kGreen : _kGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        // Fixed bottom text block – sits directly below image
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('Tahminleri bırak, verilerle ilerle.', 'Stop guessing, progress with data.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: _tw,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_introPage),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slides[_introPage.clamp(0, slides.length - 1)].title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildRichIntroDesc(slides[_introPage.clamp(0, slides.length - 1)].desc),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRichIntroDesc(String text) {
    final highlights = [
      _t('65 farklı mikro besini', '65 different micro nutrients'),
      _t('özel raporlarla', 'special reports'),
      'uzun',
      _t('sağlıklı bir yaşam', 'a healthy life')
    ];

    List<TextSpan> spans = [];
    String remaining = text;

    while (remaining.isNotEmpty) {
      int earliestMatch = -1;
      String matchText = '';

      for (var h in highlights) {
        int idx = remaining.toLowerCase().indexOf(h.toLowerCase());
        if (idx != -1 && (earliestMatch == -1 || idx < earliestMatch)) {
          earliestMatch = idx;
          matchText = remaining.substring(idx, idx + h.length);
        }
      }

      if (earliestMatch == -1) {
        spans.add(TextSpan(text: remaining));
        break;
      }

      if (earliestMatch > 0) {
        spans.add(TextSpan(text: remaining.substring(0, earliestMatch)));
      }

      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
      ));

      remaining = remaining.substring(earliestMatch + matchText.length);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          color: _kTextSub,
          height: 1.4,
          fontFamily: 'Inter',
        ),
        children: spans,
      ),
    );
  }

  // ── S2: Name (sadece isim) ─────────────────────────────────────────────────

  Widget _stepName() {
    final theme = Theme.of(context);
    return _shell(
      title: _t('Sana nasıl hitap edelim?', 'How should we address you?'),
      subtitle: _t('Sana isminle hitap etmek, bu yolculuğu daha kişisel kılacak.', 'Addressing you by your name will make this journey more personal.'),
      child: _textField(
        label: '',
        controller: _firstNameCtrl,
        hint: _t('Adın', 'Your name'),
        theme: theme,
        capitalization: TextCapitalization.words,
        focusNode: _nameFocusNode,
      ),
    );
  }

  // ── S2: Primary goals ──────────────────────────────────────────────────────

  Widget _stepPrimaryGoals() {
    final options = [
      ('🍽️', _t('65+ mikro besin analizi', '65+ micronutrient analysis')),
      ('🧬', _t('Hücresel gençlik ve Uzun Yaşam', 'Cellular youth and Longevity')),
      ('💪', _t('Daha iyi görünmek', 'Looking better')),
      ('🏥', _t('Genel sağlığımı iyileştirmek', 'Improving my general health')),
      ('⚡', _t('Daha enerjik olmak', 'Being more energetic')),
      ('🛡️', _t('Bağışıklığımı desteklemek', 'Supporting my immunity')),
      ('🧠', _t('Odak ve zihinsel netlik', 'Focus and mental clarity')),
      ('⚖️', _t('Metabolik denge', 'Metabolic balance')),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('Ana hedefin nedir?', 'What is your primary goal?'),
      subtitle: _t('Hedeflerin konusunda sınır tanıma. Sana en önemli olan tüm başlıkları belirle!', 'Do not limit yourself with your goals. Mark all that matter to you!'),
      child: _multiSelectWithOther(
        options: options,
        selected: _data.primaryGoals,
        otherController: _pgOtherCtrl,
        onToggle: (val) => setState(() {
          if (_data.primaryGoals.contains(val)) {
            _data.primaryGoals.remove(val);
          } else {
            _data.primaryGoals.add(val);
          }
        }),
      ),
    );
  }

  // ── S2: Goal confirm (shown as system Overlay, not a PageView page) ─────────

  Widget _stepGoalConfirm() {
    final hasMultipleGoals = _data.primaryGoals.length > 1;
    return GestureDetector(
      onTap: _next,
      behavior: HitTestBehavior.opaque,
      child: _TransitionOverlay(
        key: ValueKey(_goalConfirmVisitCount),
        onComplete: _next,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _kGreen,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  hasMultipleGoals
                      ? _t('Merak etme, bu hedeflerine ulaşman için yanındayız 💪', 'Don\'t worry, we are with you to reach these goals 💪')
                      : _t('Merak etme, bu hedefine ulaşman için yanındayız 💪', 'Don\'t worry, we are with you to reach this goal 💪'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _tw,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── S2: How heard ──────────────────────────────────────────────────────────

  Widget _stepHowHeard() {
    final platform = Platform.isIOS ? 'App Store' : 'Google Play';
    final options = [
      ('📱', _t('Instagram, TikTok, X, YouTube', 'Instagram, TikTok, X, YouTube')),
      ('👥', _t('Arkadaş / Aile Tavsiyesi', 'Friend / Family Recommendation')),
      ('🩺', _t('Doktor veya Diyetisyen Önerisi', 'Doctor or Dietitian Recommendation')),
      ('💬', _t('Topluluklar', 'Communities')),
      ('📲', platform),
      ('🔍', _t('Google Arama / Web Sitesi', 'Google Search / Website')),
      ('📰', _t('Haberler veya Teknoloji Blogları', 'News or Tech Blogs')),
      ('📢', _t('İnternet Reklamları', 'Internet Ads')),
      ('🌟', _t('Influencer Paylaşımları', 'Influencer Posts')),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('Yollarımız nerede kesişti?', 'Where did our paths cross?'),
      subtitle: _t('Büyüyen bir topluluğun parçasısın. Hangi kanaldan geldiğini bilmek, sana daha iyi bir deneyim sunmamıza yardımcı olur.', 'You are part of a growing community. Knowing which channel you came from helps us offer you a better experience.'),
      child: _singleSelectWithOther(
        options: options,
        selected: _data.howHeard,
        otherController: _hdOtherCtrl,
        onSelect: (val) => setState(() => _data.howHeard = val),
      ),
    );
  }

  // ── S3: Age – Gün/Ay/Yıl tamburları ────────────────────────────────────────

  Widget _stepAge() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final maxYear = now.year - 13;
    final minYear = 1926;
    final yearCount = maxYear - minYear + 1;
    final months = [
      _t('Ocak', 'January'), _t('Şubat', 'February'), _t('Mart', 'March'), _t('Nisan', 'April'), _t('Mayıs', 'May'), _t('Haziran', 'June'),
      _t('Temmuz', 'July'), _t('Ağustos', 'August'), _t('Eylül', 'September'), _t('Ekim', 'October'), _t('Kasım', 'November'), _t('Aralık', 'December'),
    ];

    return _shell(
      title: _t('Doğum günün ne zaman?', 'When is your birthday?'),
      subtitle: _t('Sana özel beslenme matematiğini kurabilmemiz için doğum tarihine ihtiyacımız var.', 'We need your date of birth to calculate your personalized nutrition math.'),
      child: Column(
        children: [
          Row(
            children: [
              // Gün
              Expanded(
                child: Column(
                  children: [
                    Text(_t('Gün', 'Day'),
                        style: const TextStyle(fontSize: 12, color: _kTextSub)),
                    const SizedBox(height: 4),
                    _drumPicker(
                      controller: _dayPicker,
                      items: List.generate(
                        31,
                        (i) => Center(
                          child: Text('${i + 1}',
                              style: _pickerTextStyle(theme)),
                        ),
                      ),
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        _selectedDay = i + 1;
                        _updateAgeFromDate(now);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Ay
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(_t('Ay', 'Month'),
                        style: const TextStyle(fontSize: 12, color: _kTextSub)),
                    const SizedBox(height: 4),
                    _drumPicker(
                      controller: _monthPicker,
                      items: List.generate(
                        12,
                        (i) => Center(
                          child: Text(months[i],
                              style: _pickerTextStyle(theme)),
                        ),
                      ),
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        _selectedMonth = i + 1;
                        _updateAgeFromDate(now);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Yıl
              Expanded(
                child: Column(
                  children: [
                    Text(_t('Yıl', 'Year'),
                        style: const TextStyle(fontSize: 12, color: _kTextSub)),
                    const SizedBox(height: 4),
                    _drumPicker(
                      controller: _yearPicker,
                      items: List.generate(
                        yearCount,
                        (i) => Center(
                          child: Text('${i + minYear}',
                              style: _pickerTextStyle(theme)),
                        ),
                      ),
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        _selectedYear = i + minYear;
                        _updateAgeFromDate(now);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t('${_data.age} yaş', '${_data.age} years old'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGreen),
          ),
        ],
      ),
    );
  }

  void _updateAgeFromDate(DateTime now) {
    int age = now.year - _selectedYear;
    if (now.month < _selectedMonth ||
        (now.month == _selectedMonth && now.day < _selectedDay)) {
      age--;
    }
    setState(() => _data.age = age.clamp(0, 120));
    // Schedule annual birthday notification
    NotificationService.scheduleBirthdayNotification(
      day: _selectedDay,
      month: _selectedMonth,
      name: _data.firstName.trim().isNotEmpty ? _data.firstName.trim() : 'Sen',
    );
  }

  // ── S3: Height ─────────────────────────────────────────────────────────────

  Widget _stepHeight() {
    final theme = Theme.of(context);

    String displayHeight() {
      if (_data.useMetricHeight) return '${_data.heightCm.round()} cm';
      final totalIn = (_data.heightCm / 2.54).round();
      return "${totalIn ~/ 12}'${totalIn % 12}\"";
    }

    return _shell(
      title: _t('Boyun kaç?', 'What is your height?'),
      subtitle: _t('Değerlerin yaklaşık olması sorun değil', 'Approximate values are fine'),
      child: Column(
        children: [
          _unitToggle(
            metricLabel: 'cm',
            imperialLabel: 'ft/in',
            isMetric: _data.useMetricHeight,
            onToggle: (v) => setState(() => _data.useMetricHeight = v),
            primary: _kGreen,
            theme: theme,
          ),
          const SizedBox(height: 16),
          if (_data.useMetricHeight)
            _drumPicker(
              controller: _heightCmPicker,
              items: List.generate(
                151,
                (i) => Center(
                  child: Text('${i + 100} cm',
                      style: _pickerTextStyle(theme)),
                ),
              ),
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _data.heightCm = (i + 100).toDouble());
              },
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  child: _drumPicker(
                    controller: _heightFtPicker,
                    items: List.generate(
                      5,
                      (i) => Center(
                        child: Text("${i + 3}'",
                            style: _pickerTextStyle(theme)),
                      ),
                    ),
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      final ft = i + 3;
                      final inch = _heightInPicker.selectedItem % 12;
                      setState(() => _data.heightCm =
                          ((ft * 12 + inch) * 2.54));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: _drumPicker(
                    controller: _heightInPicker,
                    items: List.generate(
                      12,
                      (i) => Center(
                        child: Text('$i"',
                            style: _pickerTextStyle(theme)),
                      ),
                    ),
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      final ft = _heightFtPicker.selectedItem % 5 + 3;
                      setState(
                          () => _data.heightCm = ((ft * 12 + i) * 2.54));
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            displayHeight(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGreen),
          ),
        ],
      ),
    );
  }

  // ── S3: Weight ─────────────────────────────────────────────────────────────

  Widget _stepWeight() {
    final theme = Theme.of(context);

    String displayWeight() {
      if (_data.useMetricWeight) return '${_data.weightKg.round()} kg';
      return '${(_data.weightKg * 2.20462).round()} lb';
    }

    return _shell(
      title: _t('Şu an kaç kilorsun?', 'What is your current weight?'),
      subtitle: _t('Değerlerin yaklaşık olması sorun değil', 'Approximate values are fine'),
      child: Column(
        children: [
          _unitToggle(
            metricLabel: 'kg',
            imperialLabel: 'lb',
            isMetric: _data.useMetricWeight,
            onToggle: (v) {
              final currentKg = _data.weightKg;
              setState(() => _data.useMetricWeight = v);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (v) {
                  // switched to kg
                  final kgIdx = (currentKg.round() - 30).clamp(0, 170);
                  _weightKgPicker.jumpToItem(kgIdx);
                } else {
                  // switched to lb
                  final lbIdx = ((currentKg * 2.20462).round() - 70).clamp(0, 480);
                  _weightLbPicker.jumpToItem(lbIdx);
                }
              });
            },
            primary: _kGreen,
            theme: theme,
          ),
          const SizedBox(height: 16),
          if (_data.useMetricWeight)
            _drumPicker(
              controller: _weightKgPicker,
              items: List.generate(
                171,
                (i) => Center(
                  child: Text('${i + 30} kg',
                      style: _pickerTextStyle(theme)),
                ),
              ),
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _data.weightKg = (i + 30).toDouble());
              },
            )
          else
            _drumPicker(
              controller: _weightLbPicker,
              items: List.generate(
                481,
                (i) => Center(
                  child: Text('${i + 70} lb',
                      style: _pickerTextStyle(theme)),
                ),
              ),
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _data.weightKg = (i + 70) / 2.20462);
              },
            ),
          const SizedBox(height: 12),
          Text(
            displayWeight(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGreen),
          ),
        ],
      ),
    );
  }

  // ── S3: Gender ─────────────────────────────────────────────────────────────

  Widget _stepGender() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return _shell(
      title: _t('Cinsiyetin nedir?', 'What is your gender?'),
      subtitle: _t('Vücut kompozisyonu ve enerji harcama modelleri cinsiyete göre farklılık gösterir. Hedeflerini bu verilere göre optimize edeceğiz.', 'Body composition and energy expenditure models differ by gender. We will optimize your goals based on this data.'),
      child: Column(
        children: [
          Row(
            children: [
              _bigCard(
                emoji: '\u2642',
                label: _t('Erkek', 'Male'),
                selected: _data.gender == Gender.male,
                anySelected: _data.gender != null,
                onTap: () => setState(() => _data.gender =
                    (_data.gender == Gender.male) ? null : Gender.male),
                theme: theme,
                primary: primary,
              ),
              const SizedBox(width: 16),
              _bigCard(
                emoji: '\u2640',
                label: _t('Kadın', 'Female'),
                selected: _data.gender == Gender.female,
                anySelected: _data.gender != null,
                onTap: () => setState(() => _data.gender =
                    (_data.gender == Gender.female) ? null : Gender.female),
                theme: theme,
                primary: primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _choiceRow(
            emoji: '➖',
            title: _t('Belirtmek İstemiyorum', 'Prefer not to say'),
            subtitle: null,
            selected: _data.gender == Gender.other,
            anySelected: _data.gender != null,
            onTap: () => setState(() => _data.gender =
                (_data.gender == Gender.other) ? null : Gender.other),
            theme: theme,
            primary: primary,
          ),
        ],
      ),
    );
  }

  // ── S3: Goal ───────────────────────────────────────────────────────────────

  Widget _stepGoal() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final goals = [
      (Goal.lose, '🔥', _t('Kilo Vermek', 'Lose Weight'), _t('Yağ yakım odaklı', 'Fat burn oriented')),
      (Goal.maintain, '⚖️', _t('Kiloyu Korumak', 'Maintain Weight'), _t('Sağlıklı yaşam odaklı', 'Healthy life oriented')),
      (Goal.gain, '💪', _t('Kilo Almak', 'Gain Weight'), _t('Kas kütlesi artış odaklı', 'Muscle mass gain oriented')),
    ];
    return _shell(
      title: _t('Ana kilo hedein nedir?', 'What is your main weight goal?'),
      subtitle: _t('İdeal kütle hedefini belirlemek, günlük kalori bütçeni ve hedefine ulaşma süreni doğrudan hesaplamamızı sağlar.', 'Setting your ideal mass target allows us to calculate your daily calorie budget and target timeframe directly.'),
      child: Column(
        children: goals.map((g) {
          final selected = _data.weightGoal == g.$1;
          return _choiceRow(
            emoji: g.$2,
            title: g.$3,
            subtitle: g.$4,
            selected: selected,
            anySelected: _data.weightGoal != null,
            onTap: () => setState(() {
              if (selected) {
                _data.weightGoal = null;
              } else {
                _data.weightGoal = g.$1;
                if (g.$1 == Goal.lose) {
                  _data.targetWeightKg =
                      (_data.weightKg - 5).clamp(30.0, 200.0);
                } else if (g.$1 == Goal.gain) {
                  _data.targetWeightKg =
                      (_data.weightKg + 5).clamp(30.0, 200.0);
                }
              }
            }),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S3: Target weight ──────────────────────────────────────────────────────

  Widget _stepTargetWeight() {
    return _shell(
      title: _t('Varış noktanı belirleyelim!', 'Let\'s set your destination!'),
      subtitle: _t('Hızlı değil, kalıcı bir değişim için gerçekçi parametreler kullanmak başarının anahtarıdır. Sana en sağlıklı ve verimli hedef aralığını belirleyelim.', 'Using realistic parameters for permanent rather than rapid change is the key to success. Let\'s set the healthiest and most efficient range for you.'),
      child: _TargetWeightStep(
        initialWeight: _data.weightKg,
        useMetric: _data.useMetricWeight,
        weightGoal: _data.weightGoal ?? Goal.maintain,
        onChanged: (v) => setState(() => _data.targetWeightKg = v),
      ),
    );
  }

  // ── S3: Weekly change ─────────────────────────────────────────────────────

  Widget _stepWeeklyChange() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMetric = _data.useMetricWeight;
    // Metric: 0.25/0.50/0.75/1.00 kg  |  Imperial: 0.5/1.0/1.5/2.0 lb (in kg)
    final values = isMetric
        ? [0.25, 0.50, 0.75, 1.00]
        : [0.5 / 2.20462, 1.0 / 2.20462, 1.5 / 2.20462, 2.0 / 2.20462];

    const colors = [
      Color(0xFF60A5FA), Color(0xFF7EE787),
      Color(0xFFFB923C), Color(0xFFF87171),
    ];

    // Find closest index to current value
    int idx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < values.length; i++) {
      final dist = (_data.weeklyChangeDelta - values[i]).abs();
      if (dist < minDist) { minDist = dist; idx = i; }
    }

    void select(int newIdx) {
      HapticFeedback.selectionClick();
      setState(() => _data.weeklyChangeDelta = values[newIdx]);
    }

    final diff = (_data.targetWeightKg - _data.weightKg).abs();
    final rate = values[idx];
    final weeks = rate > 0 ? (diff / rate).ceil() : 0;

    String rateLabel(double rateKg) {
      if (!isMetric) {
        final lb = rateKg * 2.20462;
        return '${lb.toStringAsFixed(1)} lb';
      }
      return '${rateKg.toStringAsFixed(2)} kg';
    }

    return _shell(
      title: _t('Hedefine ne kadar hızlı ulaşmak istiyorsun?', 'How fast do you want to reach your goal?'),
      subtitle: _t('Sürdürülebilirlik, en kısa değil en kalıcı yolu seçmektir.', 'Sustainability is choosing the most permanent path, not the shortest.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Week countdown ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$weeks',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                    ),
                  ),
                  TextSpan(
                    text: _t(' hafta', ' weeks'),
                    style: TextStyle(fontSize: 18, color: isDark ? Colors.white70 : _kTextSub),
                  ),
                ],
              ),
            ),
          ),
          // ── Slider + 4-dot indicators ──
          LayoutBuilder(builder: (_, constraints) {
            const thumbRadius = 10.0;
            final w = constraints.maxWidth;
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: colors[idx],
                    inactiveTrackColor: _kBorder,
                    thumbColor: colors[idx],
                    overlayColor: colors[idx].withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
                  ),
                  child: Slider(
                    min: values.first,
                    max: values.last,
                    divisions: values.length - 1,
                    value: values[idx],
                    onChanged: (v) {
                      int newIdx = 0;
                      double best = double.infinity;
                      for (int i = 0; i < values.length; i++) {
                        final d = (values[i] - v).abs();
                        if (d < best) { best = d; newIdx = i; }
                      }
                      select(newIdx);
                    },
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Stack(
                    children: values.asMap().entries.map((e) {
                      final i = e.key;
                      final isSel = i == idx;
                      final xPct = i / (values.length - 1);
                      final xPos = xPct * (w - 2 * thumbRadius) + thumbRadius;
                      const labelWidth = 60.0;
                      return Positioned(
                        left: (xPos - labelWidth / 2).clamp(0.0, w - labelWidth),
                        width: labelWidth,
                        top: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: isSel ? 10 : 6,
                              height: isSel ? 10 : 6,
                              decoration: BoxDecoration(
                                color: isSel ? colors[i] : (isDark ? Colors.white38 : const Color(0xFFB0B8C4)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rateLabel(values[i]),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSel ? _tw : Colors.grey,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── S3: Activity level ─────────────────────────────────────────────────────

  Widget _stepActivityLevel() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final levels = [
      (ActivityLevel.sedentary, '🪑', _t('Hareketsiz', 'Sedentary'), _t('Masa başı çalışma, az hareket', 'Desk job, low activity')),
      (ActivityLevel.light, '🚶', _t('Hafif Aktif', 'Lightly Active'), _t('Haftada 1-3 gün egzersiz', 'Exercise 1-3 days/week')),
      (ActivityLevel.moderate, '🏃', _t('Orta Aktif', 'Moderately Active'), _t('Haftada 3-5 gün egzersiz', 'Exercise 3-5 days/week')),
      (ActivityLevel.active, '🏋️', _t('Çok Aktif', 'Very Active'), _t('Haftada 6-7 gün yoğun egzersiz', 'Intense exercise 6-7 days/week')),
      (ActivityLevel.veryActive, '🏆', _t('Ekstra Aktif', 'Extra Active'), _t('Elit düzeyde spor, ağır fiziksel yük', 'Elite sports, heavy physical workload')),
    ];
    return _shell(
      title: _t('Ne kadar aktifsin?', 'How active are you?'),
      subtitle: _t('Statik ve dinamik enerji harcaman arasındaki dengeyi kurmak için yaşam tarzına en yakın modu belirle.', 'Identify the mode closest to your lifestyle to balance your static and dynamic energy expenditure.'),
      child: Column(
        children: levels.map((l) {
          final selected = _data.activityLevel == l.$1;
          return _choiceRow(
            emoji: l.$2,
            title: l.$3,
            subtitle: l.$4,
            selected: selected,
            anySelected: _data.activityLevel != null,
            onTap: () => setState(() => _data.activityLevel = selected ? null : l.$1),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S3: Dietary plan ───────────────────────────────────────────────────────

  Widget _stepDietaryPlan() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final plans = [
      ('🍽️', _t('Standart', 'Standard')),
      ('🥗', _t('Düşük Karb', 'Low Carb')),
      ('🥑', _t('Ketojenik', 'Ketogenic')),
      ('🐟', _t('Pesketeryan', 'Pescatarian')),
      ('💪', _t('Yüksek Protein Düşük Yağ', 'High Protein Low Fat')),
      ('🌱', _t('Vegan', 'Vegan')),
      ('🥦', _t('Vejetaryen', 'Vegetarian')),
      ('🥩', _t('Paleo', 'Paleo')),
      ('⚙️', _t('Özel', 'Custom')),
    ];
    return _shell(
      title: _t('Beslenme tarzın nedir?', 'What is your dietary preference?'),
      subtitle: _t('Beslenme tercihin, sana sunacağımız akıllı tarifler ve içerik analizleri için ana filtreyi oluşturur.', 'Your dietary preference acts as the primary filter for the smart recipes and food analysis we offer.'),
      child: Column(
        children: [
          ...plans.map((p) {
            final sel = _data.dietaryPlan == p.$2;
            final isCustom = p.$2 == _t('Özel', 'Custom');
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: sel ? _kSelBg : (isDark ? _kCard : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? _kGreen : (isDark ? _kBorder : const Color(0xFFD0D7DE)),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _data.dietaryPlan = sel ? null : p.$2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: sel
                                ? _kGreen.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF161B22) : const Color(0xFFF0F0F5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(p.$1, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p.$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                              color: sel ? _kGreen : _tw,
                            ),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: sel ? _kGreen : Colors.transparent,
                            shape: BoxShape.circle,
                            border: sel ? null : Border.all(
                              color: isDark ? _kBorder : const Color(0xFFD0D7DE),
                              width: 1.5,
                            ),
                          ),
                          child: sel
                              ? const Icon(Icons.check, color: Colors.black, size: 13)
                              : null,
                        ),
                      ],
                    ),
                    if (isCustom)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: sel
                            ? _customMacroPanel(theme, primary)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _customMacroPanel(ThemeData theme, Color primary) {
    final protein = int.tryParse(_proteinPctCtrl.text) ?? 0;
    final carb = int.tryParse(_carbPctCtrl.text) ?? 0;
    final fat = int.tryParse(_fatPctCtrl.text) ?? 0;
    final fiber = int.tryParse(_fiberPctCtrl.text) ?? 0;
    final total = carb + fat + protein + fiber;

    final isDarkPanel = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: isDarkPanel ? _kBorder : const Color(0xFFD0D7DE), height: 1),
          const SizedBox(height: 14),
          Text(_t('Özel Makro Dağılımı (%)', 'Custom Macro Distribution (%)'),
              style: TextStyle(fontWeight: FontWeight.w600, color: _tw, fontSize: 13)),
          const SizedBox(height: 12),
          _macroTextField(label: _t('Protein', 'Protein'), controller: _proteinPctCtrl, theme: theme),
          const SizedBox(height: 8),
          _macroTextField(label: _t('Karbonhidrat', 'Carbohydrate'), controller: _carbPctCtrl, theme: theme),
          const SizedBox(height: 8),
          _macroTextField(label: _t('Yağ', 'Fat'), controller: _fatPctCtrl, theme: theme),
          const SizedBox(height: 8),
          _macroTextField(label: _t('Lif', 'Fiber'), controller: _fiberPctCtrl, theme: theme),
          const SizedBox(height: 12),
          if (_macroPctError)
            Text(
              total > 100
                  ? _t('Fazla: %${total - 100}', 'Exceeds: %${total - 100}')
                  : _t('Eksik: %${100 - total}', 'Remaining: %${100 - total}'),
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
            )
          else
            Text(
              _t('Toplam: %$total ✓', 'Total: %$total ✓'),
              style: const TextStyle(color: _kGreen, fontSize: 13, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _macroTextField({
    required String label,
    required TextEditingController controller,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final fieldFill = isDark ? _kCard : Colors.white;
    final borderCol = isDark ? _kBorder : const Color(0xFFD0D7DE);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(color: _tw),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? _kTextSub : const Color(0xFF6E7781)),
        suffixText: '%',
        suffixStyle: TextStyle(color: isDark ? _kTextSub : const Color(0xFF6E7781)),
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderCol),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _kGreen, width: 1.5),
        ),
      ),
    );
  }

  // ── S3: Alcohol ────────────────────────────────────────────────────────────

  Widget _stepAlcohol() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🚫', _t('Hiç kullanmam', 'Never drink')),
      ('🍷', _t('Haftada 1-2', '1-2 times a week')),
      ('🥂', _t('Sosyal ortamlarda', 'Socially')),
      ('🍺', _t('Daha sık', 'More frequent')),
    ];
    return _shell(
      title: _t('Alkol tüketim alışkanlığın nasıl?', 'How are your alcohol consumption habits?'),
      subtitle: _t('Alkol tüketimi, vücudun enerji işleme sürecini ve besin emilimini doğrudan etkiler.', 'Alcohol consumption directly affects how your body processes energy and absorbs nutrients.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.alcoholHabit == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.alcoholHabit != null,
            onTap: () => setState(() => _data.alcoholHabit = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S3: Past weight loss ───────────────────────────────────────────────────

  Widget _stepPastWeightLoss() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return _shell(
      title: _t('Daha önce kilo verme deneyimin oldu mu?', 'Have you had a weight loss experience before?'),
      subtitle: _t('Daha önceki deneyimlerin, bu kez neyi farklı yapmamız gerektiğine dair en büyük ipucumuzdur.', 'Your previous experiences are our biggest clues to what we should do differently this time.'),
      child: Row(
        children: [
          _bigCard(
            emoji: '✅',
            label: _t('Evet', 'Yes'),
            selected: _data.pastWeightLoss == true,
            anySelected: _data.pastWeightLoss != null,
            onTap: () => setState(() => _data.pastWeightLoss = (_data.pastWeightLoss == true) ? null : true),
            theme: theme,
            primary: primary,
          ),
          const SizedBox(width: 16),
          _bigCard(
            emoji: '❌',
            label: _t('Hayır', 'No'),
            selected: _data.pastWeightLoss == false,
            anySelected: _data.pastWeightLoss != null,
            onTap: () => setState(() => _data.pastWeightLoss = (_data.pastWeightLoss == false) ? null : false),
            theme: theme,
            primary: primary,
          ),
        ],
      ),
    );
  }

  // ── S3: Weight loss experience ─────────────────────────────────────────────

  Widget _stepWeightLossExp() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('💧', _t('Su içsem yarıyor', 'Gain weight easily')),
      ('😤', _t('Çok zorlanırım', 'Very difficult for me')),
      ('✨', 'Kolay veririm'),
      ('🔄', _t('Kilom hiç değişmez', 'My weight never changes')),
    ];
    return _shell(
      title: _t('Geçmişteki deneyimin nasıldı?', 'How was your past experience?'),
      subtitle: _t('Geçmişteki kazanımlarını veya zorluklarını temel alarak sana kusursuz bir yol haritası çizelim.', 'Let\'s draw a perfect roadmap for you based on your past gains or difficulties.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.weightLossExp == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.weightLossExp != null,
            onTap: () => setState(() => _data.weightLossExp = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S3: Body type ──────────────────────────────────────────────────────────

  Widget _stepBodyType() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🦴', _t('Zayıf (Ektomorf)', 'Slim (Ectomorph)'), _t('İnce yapılı, zor kilo alır', 'Lean, gains weight slowly')),
      ('🏆', _t('Atletik (Mezomorf)', 'Athletic (Mesomorph)'), _t('Kas gelişimine yatkın', 'Prone to muscle development')),
      ('🐻', _t('Geniş (Endomorf)', 'Broad (Endomorph)'), _t('Kolay kilo alır, zor verir', 'Gains weight easily, loses slowly')),
    ];
    return _shell(
      title: _t('Vücut yapını nasıl tanımlarsın?', 'How do you define your body type?'),
      subtitle: _t('Vücut tipin (Somatotip), besinleri nasıl işlediğin ve antrenmanlara nasıl tepki verdiğin konusunda en temel rehberdir.', 'Your body type (Somatotype) is the primary guide on how you process nutrients and react to training.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.bodyType == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: o.$3,
            selected: sel,
            anySelected: _data.bodyType != null,
            onTap: () => setState(() => _data.bodyType = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S3: Sunlight ───────────────────────────────────────────────────────────

  Widget _stepSunlight() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return _shell(
      title: _t('Güneş ışığından yeterince yararlanıyor musun?', 'Do you get enough sunlight?'),
      subtitle: _t('Gün ışığı, uyku kaliteni ve metabolizma hızını yöneten en temel dış değişkendir.', 'Sunlight is the primary external variable that manages your sleep quality and metabolic rate.'),
      child: Row(
        children: [
          _bigCard(
            emoji: '☀️',
            label: _t('Evet', 'Yes'),
            selected: _data.hasSunlight == true,
            anySelected: _data.hasSunlight != null,
            onTap: () => setState(() => _data.hasSunlight = (_data.hasSunlight == true) ? null : true),
            theme: theme,
            primary: primary,
          ),
          const SizedBox(width: 16),
          _bigCard(
            emoji: '🌥️',
            label: _t('Hayır', 'No'),
            selected: _data.hasSunlight == false,
            anySelected: _data.hasSunlight != null,
            onTap: () => setState(() => _data.hasSunlight = (_data.hasSunlight == false) ? null : false),
            theme: theme,
            primary: primary,
          ),
        ],
      ),
    );
  }

  // ── S3: Sleep hours ────────────────────────────────────────────────────────

  Widget _stepSleepHours() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('😴', "5'ten az saat"),
      ('🌙', '5-7 saat'),
      ('✨', '7-9 saat'),
      ('💤', '9+ saat'),
    ];
    final subtitles = ['Yetersiz uyku', 'Biraz az', _t('İdeal uyku süresi', 'Ideal sleep duration'), 'Fazla uyku'];
    return _shell(
      title: _t('Günde kaç saat uyursun?', 'How many hours do you sleep a day?'),
      subtitle: _t('Uyku, metabolizmanın yeniden kalibre edildiği ve hormonlarının dengelendiği kritik bir süreçtir.', 'Sleep is a critical process where metabolism is recalibrated and hormones are balanced.'),
      child: Column(
        children: List.generate(opts.length, (i) {
          final o = opts[i];
          final sel = _data.sleepHours == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: subtitles[i],
            selected: sel,
            anySelected: _data.sleepHours != null,
            onTap: () => setState(() => _data.sleepHours = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }),
      ),
    );
  }

  // ── S4: Cooking time ───────────────────────────────────────────────────────

  Widget _stepCookingTime() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🥡', _t('Hiç yok, hızlı çözümler isterim', 'None, I want quick solutions'), _t('Dışarıdan veya hazır', 'Takeout or ready-made')),
      ('⏱️', _t('20-30 dk ayırabilirim', 'I can spare 20-30 mins'), _t('Hızlı ve pratik tarifler', 'Quick and practical recipes')),
      ('👨‍🍳', _t('Severim, bol vakit ayırırım', 'I like it, I spare plenty of time'), _t('Detaylı tarifler', 'Detailed recipes')),
    ];
    return _shell(
      title: _t('Yemek yapmak için ne kadar vakit ayırırsın?', 'How much time do you spend cooking?'),
      subtitle: _t('Kısıtlı vakitlerde hızlı çözümler, geniş zamanlarda gurme dokunuşlar... Zaman kısıtlarını analiz ederek sana özel tarifler sunuyoruz!', 'Quick solutions in limited times, gourmet touches in wide times... We analyze time constraints to offer recipes special to you!'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.cookingTime == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: o.$3,
            selected: sel,
            anySelected: _data.cookingTime != null,
            onTap: () => setState(() => _data.cookingTime = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Motivation – çoklu seçim ───────────────────────────────────────────

  Widget _stepMotivation() {
    final options = [
      ('📊', 'Grafikler'),
      ('🔔', _t('Hatırlatıcılar', 'Reminders')),
      ('🏆', _t('Ödüller', 'Rewards')),
      ('✅', 'Onay işaretleri'),
    ];
    return _shell(
      title: _t('Seni en çok ne motive eder?', 'What motivates you the most?'),
      subtitle: _t('Herkesin başarıya giden yolu farklıdır; seni hedefine çeken bütün güçleri işaretle!', 'Everyone\'s way to success is different; check all the forces that pull you to your goal!'),
      child: _multiSelectNoOther(
        options: options,
        selected: _data.motivations,
        onToggle: (val) => setState(() {
          if (_data.motivations.contains(val)) {
            _data.motivations.remove(val);
          } else {
            _data.motivations.add(val);
          }
        }),
      ),
    );
  }

  // ── S4: Hunger time ────────────────────────────────────────────────────────

  Widget _stepHungerTime() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🌅', _t('Sabah', 'Morning')),
      ('☀️', _t('Öğle', 'Afternoon')),
      ('🌤️', _t('İkindi', 'Late Afternoon')),
      ('🌆', _t('Akşam', 'Evening')),
      ('🌙', _t('Gece geç saatler', 'Late night')),
    ];
    return _shell(
      title: _t('En çok ne zaman acıkırsın?', 'When do you feel most hungry?'),
      subtitle: _t('Her metabolizmanın enerji talebi gün içinde farklılık gösterir.', 'Every metabolism\'s energy demand varies during the day.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.hungerTime == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.hungerTime != null,
            onTap: () => setState(() => _data.hungerTime = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Meal count ─────────────────────────────────────────────────────────

  Widget _stepMealCount() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('⏰', _t('2 Öğün', '2 Meals'), _t('Aralıklı oruç dostu', 'Intermittent fasting friendly')),
      ('🍽️', _t('3 Öğün', '3 Meals'), _t('Klasik beslenme düzeni', 'Classic eating pattern')),
      ('🥗', _t('4+ Öğün', '4+ Meals'), _t('Atıştırmalık dahil', 'Snacks included')),
    ];
    return _shell(
      title: _t('Günde kaç öğün yaparsın?', 'How many meals do you have a day?'),
      subtitle: _t('Vücudunun besinleri işleme hızı, öğün sıklığına göre adapte olur.', 'Your body\'s rate of processing nutrients adapts according to meal frequency.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.mealCount == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: o.$3,
            selected: sel,
            anySelected: _data.mealCount != null,
            onTap: () => setState(() => _data.mealCount = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Water habit ────────────────────────────────────────────────────────

  Widget _stepWaterHabit() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('💧', "1L'den az", 'Yetersiz hidrasyon'),
      ('🥤', '1-2L', _t('Ortalama tüketim', 'Average consumption')),
      ('🌊', '2-3L', _t('İyi seviye', 'Good level')),
      ('🏊', "3L'den fazla", _t('Mükemmel hidrasyon', 'Excellent hydration')),
    ];
    return _shell(
      title: _t('Günlük su tüketim alışkanlığın nasıl?', 'How are your daily water intake habits?'),
      subtitle: _t('Hücresel yenilenme ve toksin atımı için su, besinlerden daha önceliklidir.', 'Water is more prioritized than nutrients for cellular renewal and toxin removal.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.waterHabit == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: o.$3,
            selected: sel,
            anySelected: _data.waterHabit != null,
            onTap: () => setState(() => _data.waterHabit = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Eating out ─────────────────────────────────────────────────────────

  Widget _stepEatingOut() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🍔', 'Her gün'),
      ('🍜', _t('Haftada birkaç', 'A few times a week')),
      ('🥗', _t('Sadece hafta sonu', 'Only weekends')),
      ('🏠', _t('Neredeyse hiç', 'Almost never')),
    ];
    return _shell(
      title: _t('Dışarıdan ne sıklıkla yemek yersin?', 'How often do you eat out?'),
      subtitle: _t('Ev dışındaki öğünler, kalori ve makro tahminlerinde yüksek sapma potansiyeli taşır.', 'Meals eaten out have a high potential of deviation in calorie and macro estimations.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.eatingOut == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.eatingOut != null,
            onTap: () => setState(() => _data.eatingOut = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Energy time ────────────────────────────────────────────────────────

  Widget _stepEnergyTime() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🌅', 'Sabah erken'),
      ('☀️', _t('Öğle', 'Afternoon')),
      ('🌆', _t('Akşam üzeri', 'Evening')),
      ('🦉', _t('Gece kuşu', 'Night owl')),
    ];
    return _shell(
      title: _t('Günün hangi saatlerinde enerjik hissediyorsun?', 'At what times of the day do you feel energetic?'),
      subtitle: _t('Beslenme planın senin biyolojik saatine ayak uydurmalı. En güçlü hissettiğin anları seç!', 'Your diet plan should adapt to your biological clock. Choose your strongest moments!'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.energyTime == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.energyTime != null,
            onTap: () => setState(() => _data.energyTime = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Emotional eating ───────────────────────────────────────────────────

  Widget _stepEmotionalEating() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('😰', _t('Evet, streste çok yerim', 'Yes, I eat a lot under stress')),
      ('🤷', 'Pek etkilemez'),
      ('😶', _t('Hayır, iştahım kesilir', 'No, I lose my appetite')),
    ];
    return _shell(
      title: _t('Stres veya üzüntüde yeme eğilimin var mı?', 'Do you tend to eat under stress or sadness?'),
      subtitle: _t('Gerçek bir değişim sadece kalori saymakla değil dürtüleri yönetmekle başlar. Stresin yeme kararlarını nasıl etkilediğini seç!', 'Real change starts with managing impulses, not just counting calories. Select how stress affects your eating decisions!'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.emotionalEating == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.emotionalEating != null,
            onTap: () => setState(() => _data.emotionalEating = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Sleep schedule ─────────────────────────────────────────────────────

  Widget _stepSleepSchedule() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return _shell(
      title: _t('Uyku saatin düzenli mi?', 'Is your sleep schedule regular?'),
      subtitle: _t('Uyku rutinindeki kararlılık, metabolik hızını ve hormonal dengeni doğrudan yönetir.', 'Consistency in sleep routine directly manages your metabolic rate and hormonal balance.'),
      child: Column(
        children: [
          _choiceRow(
            emoji: '✅',
            title: _t('Evet, düzenli', 'Yes, regular'),
            subtitle: _t('Her gün aynı saatte', 'Same time every day'),
            selected: _data.regularSleep == true,
            anySelected: _data.regularSleep != null,
            onTap: () => setState(() => _data.regularSleep = (_data.regularSleep == true) ? null : true),
            theme: theme,
            primary: primary,
          ),
          _choiceRow(
            emoji: '🔀',
            title: _t('Hayır, düzensiz', 'No, irregular'),
            subtitle: _t('Değişken uyku saatlerim', 'Variable sleep hours'),
            selected: _data.regularSleep == false,
            anySelected: _data.regularSleep != null,
            onTap: () => setState(() => _data.regularSleep = (_data.regularSleep == false) ? null : false),
            theme: theme,
            primary: primary,
          ),
        ],
      ),
    );
  }

  // ── S4: Progress indicator ─────────────────────────────────────────────────

  Widget _stepProgressIndicator() {
    final options = [
      ('⚖️', _t('Tartı', 'Scale')),
      ('👕', _t('Kıyafetler', 'Clothes')),
      ('🪞', 'Ayna'),
      ('⚡', 'Enerji seviyesi'),
    ];
    return _shell(
      title: _t('Senin için ideal ilerleme göstergesi nedir?', 'What is the ideal progress indicator for you?'),
      subtitle: _t('Hedefine ulaştığını nasıl anlayacaksın? Kıyafetlerinin duruşu mu, yoksa aynadaki kas belirginliği mi?', 'How will you know you reached your goal? The fit of your clothes, or muscle definition in the mirror?'),
      child: _multiSelectNoOther(
        options: options,
        selected: _data.progressIndicators,
        onToggle: (val) => setState(() {
          if (_data.progressIndicators.contains(val)) {
            _data.progressIndicators.remove(val);
          } else {
            _data.progressIndicators.add(val);
          }
        }),
      ),
    );
  }

  // ── S4: Exercise frequency ─────────────────────────────────────────────────

  Widget _stepExerciseFreq() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final opts = [
      ('🏋️', _t('Düzenli (haftada 3+)', 'Regular (3+ times a week)')),
      ('🚴', 'Bazen'),
      ('🚶', 'Nadiren'),
      ('🛋️', 'Hiç'),
    ];
    return _shell(
      title: _t('Ne sıklıkla egzersiz yapıyorsun?', 'How often do you exercise?'),
      subtitle: _t('Egzersiz sıklığı, vücudunun besinleri enerjiye dönüştürme hızını ve protein sentezi ihtiyacını doğrudan belirler.', 'Exercise frequency directly determines the rate at which your body converts nutrients to energy and protein synthesis needs.'),
      child: Column(
        children: opts.map((o) {
          final sel = _data.exerciseFreq == o.$2;
          return _choiceRow(
            emoji: o.$1,
            title: o.$2,
            subtitle: null,
            selected: sel,
            anySelected: _data.exerciseFreq != null,
            onTap: () => setState(() => _data.exerciseFreq = sel ? null : o.$2),
            theme: theme,
            primary: primary,
          );
        }).toList(),
      ),
    );
  }

  // ── S4: Notifications ──────────────────────────────────────────────────────

  Widget _stepNotifications() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // --- Realistic Phone Mockup ---
                    Container(
                      height: 460,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Phone Outer Frame (Bezel)
                          Container(
                            width: 220,
                            height: 460,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(44),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF1A1F2B),
                                      Colors.black,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(38),
                                ),
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    // Notch / Dynamic Island area
                                    Positioned(
                                      top: 10,
                                      child: Container(
                                        width: 70,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    // Big Time Display
                                    Positioned(
                                      top: 60,
                                      child: Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 72,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white.withValues(alpha: 0.35),
                                          letterSpacing: -2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Notification Stack Effect
                          // Bottom "Peeking" Bubble
                          Positioned(
                            top: 208,
                            child: Transform.scale(
                              scale: 0.94,
                              child: Opacity(
                                opacity: 0.5,
                                child: Container(
                                  width: 320,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: _tw,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Top Primary Bubble
                          Positioned(
                            top: 200,
                            child: _notificationBubble(
                              timeStr,
                              _t('Öğününü kaydetmek için bir saniyen var mı?', 'Do you have a second to log your meal?'),
                              _t('Yediklerini kaydetmek için bir saniyeni ayır - takip ettiğin her öğün seni hedefine bir adım daha yaklaştırır.', 'Take a second to log what you eat - every logged meal gets you closer to your goal.'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // --- Text Content ---
                    Text(
                      _t('Hedefinize daha hızlı ve\nkolay ulaşın 🚀', 'Reach your goal faster and\neasier 🚀'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _tw,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Kalori takibini ',
                              style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: _t('unutmamak için bildirimleri açın. ', 'Turn on notifications to not forget. '),
                              style: TextStyle(color: isDark ? Colors.white70 : _kTextSub),
                            ),
                            TextSpan(
                              text: _t('Sağlıklı alışkanlıklar ', 'The easiest way to create '),
                              style: TextStyle(color: _tw, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: _t('oluşturmanın ve hedeflerinize yaklaşmanın en kolay yolu!', 'healthy habits and get closer to your goals!'),
                              style: TextStyle(color: isDark ? Colors.white70 : _kTextSub),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // --- Action Button ---
                    ElevatedButton(
                      onPressed: () async {
                        final granted = await NotificationService.requestPermissions();
                        if (!mounted) return;
                        if (granted) {
                          NotificationService.saveAndApply(NotificationSettings(
                            waterEnabled: true,
                            breakfastEnabled: true,
                            breakfastTime: const TimeOfDay(hour: 8, minute: 0),
                            lunchEnabled: true,
                            lunchTime: const TimeOfDay(hour: 12, minute: 30),
                            dinnerEnabled: true,
                            dinnerTime: const TimeOfDay(hour: 19, minute: 0),
                            summaryEnabled: true,
                          ));
                        }
                        if (mounted) _next();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _t('Bildirimlere İzin Ver', 'Allow Notifications'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── S4: Health Connect ─────────────────────────────────────────────────────

  Widget _stepHealthConnect() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    const Spacer(),
                    // --- Integration Mockup ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Health App Icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D80),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4D80).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.favorite, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.arrow_forward, color: isDark ? Colors.white38 : _kTextSub, size: 20),
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle, color: _tw, size: 24),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: isDark ? Colors.white38 : _kTextSub, size: 20),
                        const SizedBox(width: 16),
                        // LensEat Icon (App Logo)
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/icon/icon.webp',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.center_focus_strong, color: _tw, size: 40),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // --- Text Content ---
                    Text(
                      _t('Sağlık Uygulamasına\nBağlan', 'Connect to\nHealth App'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _tw,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _t('En kapsamlı veriye sahip olmak için günlük aktivitelerinizi ', 'To have the most comprehensive data, synchronize '),
                              style: TextStyle(color: isDark ? Colors.white70 : _kTextSub),
                            ),
                            const TextSpan(
                              text: 'LensEat ',
                              style: TextStyle(color: _kBlue, fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: _t('ve ', 'and '),
                              style: TextStyle(color: isDark ? Colors.white70 : _kTextSub),
                            ),
                            TextSpan(
                              text: _t('Sağlık uygulaması ', 'your daily activities with Health app '),
                              style: TextStyle(color: Color(0xFFFF5E7D), fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: _t('arasında senkronize edin.', 'internally.'),
                              style: TextStyle(color: isDark ? Colors.white70 : _kTextSub),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // --- Action Buttons ---
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final granted = await HealthService.requestPermissions();
                        if (mounted) _next();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _t('Bağlan', 'Connect'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _next,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white38 : _kTextSub,
                      ),
                      child: Text(
                        _t('Şimdi değil', 'Not now'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── S4: Rate Us ────────────────────────────────────────────────────────────

  Widget _stepRateUs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _shell(
      title: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _tw,
            height: 1.2,
          ),
          children: [
            const TextSpan(text: 'Binlerce insan '),
            TextSpan(
              text: 'LensEat',
              style: TextStyle(color: _kBlue),
            ),
            TextSpan(text: _t('\'e güveniyor', ' trusts')),
          ],
        ),
      ),
      subtitle: null,
      centered: true,
      child: Column(
        children: [
          const SizedBox(height: 10),
          // --- Rating Box ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBlue, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.2,
                    child: const Icon(Icons.military_tech, color: Color(0xFFD4AF37), size: 42),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '5.0',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(5, (index) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 28)),
                  ),
                  const SizedBox(width: 8),
                  Transform.flip(
                    flipX: true,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: const Icon(Icons.military_tech, color: Color(0xFFD4AF37), size: 42),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // --- Avatars ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvatar('assets/profilepic/pp1.webp'),
              _buildAvatar('assets/profilepic/pp2.webp'),
              _buildAvatar('assets/profilepic/pp3.webp'),
            ],
          ),
          const SizedBox(height: 32),
          // --- Testimonials ---
          _testimonialCard(
            name: 'Merve Aydın',
            rating: 5,
            comment: _t('Besin eksikliklerimi LensEat sayesinde fark ettim. Artık çok daha zinde ve enerjik hissediyorum, kesinlikle tavsiye ederim!', 'I noticed my nutrient deficiencies thanks to LensEat. I feel much more fit and energetic now, definitely recommend!'),
            imagePath: 'assets/profilepic/pp3.webp',
          ),
          const SizedBox(height: 16),
          _testimonialCard(
            name: 'Ali Baştürk',
            rating: 5,
            comment: _t('2 ayda 15 kilo verdim. Yapay zeka ile yemekleri taramak hayatımı kolaylaştırdı, her öğünde ne yediğimi tam olarak biliyorum :)', 'I lost 15 kg in 2 months. Scanning food with AI made my life easier, I know exactly what I eat at every meal :)'),
            imagePath: 'assets/profilepic/pp2.webp',
          ),
          const SizedBox(height: 16),
          _testimonialCard(
            name: 'Zeynep Kalkan',
            rating: 5,
            comment: _t('Sadece fotoğraf çekerek kalori ve besin takibi yapmak inanılmaz bir şey. Vaktim kısıtlıyken bile beslenmemi kontrol altında tutabiliyorum.', 'Logging calorie and nutrient tracking by just taking a photo is amazing. Even when my time is limited, I can keep my nutrition under control.'),
            imagePath: 'assets/profilepic/pp1.webp',
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String assetPath) {
    return Container(
      width: 64,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _tw,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(assetPath, fit: BoxFit.cover),
      ),
    );
  }

  Widget _testimonialCard({required String name, required int rating, required String comment, required String imagePath}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _kCard : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(imagePath, width: 40, height: 40, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    Row(
                      children: List.generate(rating, (i) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
              children: comment.split('LensEat').expand((part) => [
                TextSpan(text: part),
                if (comment.contains('LensEat') && part != comment.split('LensEat').last)
                  TextSpan(text: 'LensEat', style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold)),
              ]).where((element) => (element as TextSpan).text!.isNotEmpty || (element as TextSpan).style != null).toList().cast<InlineSpan>(),
            ),
          ),
        ],
      ),
    );
  }

  // ── S6: Diseases ───────────────────────────────────────────────────────────

  Widget _stepDiseases() {
    final options = [
      ('🩸', _t('Tip 1 Diyabet', 'Type 1 Diabetes')),
      ('💉', _t('Tip 2 Diyabet', 'Type 2 Diabetes')),
      ('📈', _t('İnsülin Direnci', 'Insulin Resistance')),
      ('⚡', 'Reaktif Hipoglisemi'),
      ('❤️', 'Hipertansiyon'),
      ('🫀', _t('Yüksek Kolesterol', 'High Cholesterol')),
      ('💔', _t('Kalp Yetmezliği', 'Heart Failure')),
      ('🌾', _t('Çölyak', 'Celiac Disease')),
      ('🫁', _t('IBS (İrritabl Bağırsak Sendromu)', 'IBS (Irritable Bowel Syndrome)')),
      ('🔥', _t('Gastrit / Reflü', 'Gastritis / Reflux')),
      ('🥛', _t('Laktoz İntoleransı', 'Lactose Intolerance')),
      ('🦋', 'Hipotiroidi'),
      ('⚡', 'Hipertiroidi'),
      ('🔴', 'PCOS (Polikistik Over Sendromu)'),
      ('🫘', _t('Kronik Böbrek Yetmezliği', 'Chronic Kidney Failure')),
      ('🫀', _t('Yağlı Karaciğer', 'Fatty Liver')),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('Herhangi bir sağlık durumun var mı?', 'Do you have any health conditions?'),
      subtitle: _t('Hedefine ulaşırken sağlığını riske atma. Kronik durumlarını veya özel hassasiyetlerini belirt!', 'Do not risk your health while reaching your goal. Specify your chronic conditions or sensitivities!'),
      child: _multiSelectWithOther(
        options: options,
        selected: _data.diseases,
        otherController: _diseaseOtherCtrl,
        onToggle: (val) => setState(() {
          if (_data.diseases.contains(val)) {
            _data.diseases.remove(val);
          } else {
            _data.diseases.add(val);
          }
        }),
      ),
    );
  }

  // ── S6: Food sensitivities ─────────────────────────────────────────────────

  Widget _stepFoodSensitivities() {
    final options = [
      ('🌾', _t('Glüten', 'Gluten')),
      ('🥛', _t('Süt', 'Dairy')),
      ('🥚', _t('Yumurta', 'Egg')),
      ('🥜', _t('Yer Fıstığı', 'Peanuts')),
      ('🦐', _t('Deniz Ürünleri', 'Seafood')),
      ('🌱', _t('Soya', 'Soy')),
      ('🧂', 'MSG (Monosodyum Glutamat)'),
      ('🍬', _t('Yapay Tatlandırıcılar', 'Artificial Sweeteners')),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('Hangi gıdalara karşı hassasiyetin var?', 'Which foods are you sensitive to?'),
      subtitle: _t('Vücudunun tolere edemediği besin grupları, sindirim sistemi üzerinde yüksek stres oluşturabilir.', 'Food groups that your body cannot tolerate can build high stress on the digestive system.'),
      child: _multiSelectWithOther(
        options: options,
        selected: _data.foodSensitivities,
        otherController: _foodSensOtherCtrl,
        onToggle: (val) => setState(() {
          if (_data.foodSensitivities.contains(val)) {
            _data.foodSensitivities.remove(val);
          } else {
            _data.foodSensitivities.add(val);
          }
        }),
      ),
    );
  }

  // ── S6: Supplements ────────────────────────────────────────────────────────

  Widget _stepSupplements() {
    final options = [
      ('💊', _t('Multivitamin', 'Multivitamin')),
      ('☀️', _t('D Vitamini', 'Vitamin D')),
      ('🔴', 'B12'),
      ('🪨', _t('Magnezyum', 'Magnesium')),
      ('🔩', _t('Demir', 'Iron')),
      ('🟠', _t('C Vitamini', 'Vitamin C')),
      ('⚙️', _t(_t('Çinko', 'Zinc'), 'Zinc')),
      ('🥤', 'Protein Tozu'),
      ('💪', 'Kreatin'),
      ('🔀', 'BCAA (Branched-Chain Amino Acids)'),
      ('⚡', 'Pre-Workout'),
      ('🐟', 'Omega-3'),
      ('✨', 'Kolajen'),
      ('🦠', 'Probiyotikler'),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('Düzenli kullandığın takviye var mı?', 'Are there any supplements you use regularly?'),
      subtitle: _t('Düzenli kullanılan takviyeler, günlük biyokimyasal dengeni doğrudan etkiler.', 'Regularly used supplements directly affect your daily biochemical balance.'),
      child: _multiSelectWithOther(
        options: options,
        selected: _data.supplements,
        otherController: _suppOtherCtrl,
        onToggle: (val) => setState(() {
          if (_data.supplements.contains(val)) {
            _data.supplements.remove(val);
          } else {
            _data.supplements.add(val);
          }
        }),
      ),
    );
  }

  // ── S6: Main challenge ─────────────────────────────────────────────────────

  Widget _stepMainChallenge() {
    final options = [
      ('😩', 'Kalori takibi yorucu'),
      ('🔄', _t('İstikrarsızlık', 'Inconsistency')),
      ('🍽️', 'Porsiyon bilgisi'),
      ('📚', 'Besin bilgisi'),
      ('🍔', _t('Sağlıksız alışkanlıklar', 'Unhealthy habits')),
      ('👥', _t('Destek eksikliği', 'Lack of support')),
      ('⏰', _t('Yoğun takvim', 'Busy schedule')),
      ('🚫', _t('Fazla kısıtlama', 'Too much restriction')),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('En büyük zorluk sence ne?', 'What do you think is the biggest challenge?'),
      subtitle: _t('Başarıya giden yol, en zayıf halkayı güçlendirmekten geçer.', 'The path to success lies in strengthening the weakest link.'),
      child: _multiSelectWithOther(
        options: options,
        selected: _data.challenges,
        otherController: _challOtherCtrl,
        onToggle: (val) => setState(() {
          if (_data.challenges.contains(val)) {
            _data.challenges.remove(val);
          } else {
            _data.challenges.add(val);
          }
        }),
      ),
    );
  }

  // ── S6: Health goals detailed ──────────────────────────────────────────────

  Widget _stepHealthGoals() {
    final options = [
      ('✨', _t('Uzun ömürlülük (Uzun Yaşam)', 'Longevity (Long Life)')),
      ('🧬', _t('Hücresel sağlık optimizasyonu', 'Cellular health optimization')),
      ('🔄', 'Metabolik esneklik'),
      ('🌿', _t('Bağırsak sağlığı ve mikrobiyota', 'Gut health and microbiota')),
      ('💪', 'Kas kazanmak'),
      ('🔥', _t('Yağ yakmak', 'Burning fat')),
      ('⚖️', 'Hormonal denge'),
      ('🍵', 'Anti-inflamatuar beslenme'),
      ('🏃', 'Atletik performans'),
      ('✏️', _t('Diğer', 'Other')),
    ];
    return _shell(
      title: _t('Uygulamayı kullanmandaki temel amacın?', 'What is your main purpose in using the app?'),
      subtitle: _t('Neyi başarmak istediğin, sistemimizin sana nasıl rehberlik edeceğini belirler.', 'What you want to achieve determines how our system will guide you.'),
      child: _multiSelectWithOther(
        options: options,
        selected: _data.specificGoals,
        otherController: _sgOtherCtrl,
        onToggle: (val) => setState(() {
          if (_data.specificGoals.contains(val)) {
            _data.specificGoals.remove(val);
          } else {
            _data.specificGoals.add(val);
          }
        }),
      ),
    );
  }

  // ── S7: Processing ─────────────────────────────────────────────────────────

  Widget _stepProcessing() {
    return _AnalysisPage(
      onComplete: () {
        if (mounted && _current == _StepId.processing) {
          _navigateTo(_StepId.planReady);
        }
      },
    );
  }

  // ── S7: Plan ready ─────────────────────────────────────────────────────────

  Widget _stepPlanReady() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calorie = _data.calorieTarget.round();
    final protein = _data.proteinG.round();
    final carb = _data.carbG.round();
    final fat = _data.fatG.round();
    final fiber = _data.fiberG.round();
    final startW = _data.weightKg.round();
    final targetW = _data.targetWeightKg.round();

    return _shell(
      title: _t('Planın Hazır!', 'Plan is Ready!'),
      subtitle: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: _kTextSub,
            height: 1.5,
          ),
          children: [
            TextSpan(text: _t('Sana ', 'A plan ')),
            TextSpan(text: _t('özel', 'customized'), style: TextStyle(color: _tw, fontWeight: FontWeight.bold)),
            TextSpan(text: _t(' hazırlandı', ' has been prepared for you')),
          ],
        ),
      ),
      centered: true,
      verticalCenter: true,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBlue, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _planRow('🔥', 'Kalori', '$calorie kcal'),
                const SizedBox(height: 16),
                _planRow('🐟', _t('Protein', 'Protein'), '${protein}g'),
                const SizedBox(height: 16),
                _planRow('🍃', _t('Karbonhidrat', 'Carbohydrate'), '${carb}g'),
                const SizedBox(height: 16),
                _planRow('🥑', _t('Yağ', 'Fat'), '${fat}g'),
                const SizedBox(height: 16),
                _planRow('🥦', _t('Lif', 'Fiber'), '${fiber}g'),
                const SizedBox(height: 16),
                _planRow('💧', 'Su', '${(_data.waterMl / 1000).toStringAsFixed(1)}L'),
                const SizedBox(height: 20),
                Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
                const SizedBox(height: 20),
                _planRow('🎯', 'Hedef kilo',
                  _data.weightGoal == Goal.maintain
                      ? '$startW kg'
                      : '$startW kg → $targetW kg'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ── S7: Sign up ────────────────────────────────────────────────────────────

  Widget _stepSignUp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _shell(
      title: _t('İlerlemen kaybolmasın, hesap aç!', 'Don\'t lose your progress, create an account!'),
      subtitle: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: _kTextSub,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Verilerini '),
            TextSpan(text: _t('güvende tut', 'keep safe'), style: TextStyle(color: _tw, fontWeight: FontWeight.bold)),
            const TextSpan(text: ', '),
            TextSpan(text: _t('her cihazdan eriş', 'access from any device'), style: TextStyle(color: _tw, fontWeight: FontWeight.bold)),
            const TextSpan(text: '.'),
          ],
        ),
      ),
      centered: true,
      verticalCenter: true,
      child: Column(
        children: [
          TextField(
            controller: _signUpEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_signUpLoading,
            style: TextStyle(color: _tw),
            decoration: InputDecoration(
              hintText: 'E-posta',
              hintStyle: const TextStyle(color: _kTextSub),
              filled: true,
              fillColor: isDark ? _kCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _kGreen, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signUpPasswordCtrl,
            obscureText: _signUpObscure,
            textInputAction: TextInputAction.done,
            enabled: !_signUpLoading,
            style: TextStyle(color: _tw),
            onSubmitted: (_) => _handleCreateAccount(),
            decoration: InputDecoration(
              hintText: _t('Şifre (en az 6 karakter)', 'Password (at least 6 characters)'),
              hintStyle: const TextStyle(color: _kTextSub),
              filled: true,
              fillColor: isDark ? _kCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _kGreen, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _signUpObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _kTextSub,
                ),
                onPressed: () => setState(() => _signUpObscure = !_signUpObscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _signUpLoading ? null : _handleCreateAccount,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _tw,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _signUpLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white),
                        )
                        : Text(
                            _t('Hesap Oluştur', 'Create Account'),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.black : Colors.white),
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // --- Google Sign In ---
          _authButton(
            useGoogleIcon: true,
            label: 'Google ile Devam Et',
            onTap: _googleLoading ? null : _handleGoogleSignIn,
            loading: _googleLoading,
          ),
          const SizedBox(height: 24),
          // --- Skip Sign Up ---
          GestureDetector(
            onTap: _finishLoading ? null : _skipSignUp,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _t('Hesap açmadan devam et', 'Continue without creating account'),
                style: TextStyle(
                  color: _kTextSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _skipSignUp() async {
    setState(() => _finishLoading = true);
    try {
      await _saveProfile();
    } catch (e) {
      debugPrint('saveProfile error: $e');
    } finally {
      if (mounted) setState(() => _finishLoading = false);
    }
    if (!mounted) return;
    _navigateTo(_StepId.completion);
  }

  Future<void> _handleCreateAccount() async {
    final email = _signUpEmailCtrl.text.trim();
    final password = _signUpPasswordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('E-posta ve şifre boş bırakılamaz.', 'Email and password cannot be empty.'))),
      );
      return;
    }

    setState(() => _signUpLoading = true);

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      UserCredential userCred;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        // Link anonymous account to email credentials — preserves existing data
        final linked = await DeviceIdService.instance.linkAnonymousToEmail(
          email: email, password: password,
        );
        userCred = linked ?? await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
      } else {
        userCred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
      }

      // Yeni hesabın UID'sini onboardingId olarak kullan
      _data.onboardingId = userCred.user!.uid;

      // Firestore'a onboarding verilerini kaydet
      await _saveOnboardingToFirestore(userCred.user!);

      if (!mounted) return;
      // Profili SQLite'a kaydet (completion sayfası gerçek verileri okusun)
      await _saveProfile();
      if (!mounted) return;
      setState(() => _signUpLoading = false);
      // Hesap oluşturuldu → özet sayfasını göster, oradan HomeScreen'e geç
      _navigateTo(_StepId.completion);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _signUpLoading = false);
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = _t('Bu e-posta zaten kullanımda.', 'This email is already in use.');
          break;
        case 'weak-password':
          msg = _t('Şifre en az 6 karakter olmalı.', 'Password must be at least 6 characters.');
          break;
        case 'invalid-email':
          msg = _t('Geçersiz e-posta adresi.', 'Invalid email address.');
          break;
        case 'too-many-requests':
          msg = _t('Çok fazla deneme. Lütfen bekleyin.', 'Too many attempts. Please wait.');
          break;
        default:
          msg = _t('Hesap oluşturulamadı: ${e.message}', 'Account could not be created: ${e.message}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _signUpLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen hata: $e')),
      );
    }
  }

  Future<void> _saveOnboardingToFirestore(User user) async {
    try {
      final db = FirebaseFirestore.instance;
      final name = _data.firstName.trim();
      await db.collection('users').doc(user.uid).set({
        'profile': {
          'displayName': name.isEmpty ? 'Kullanıcı' : name,
          'email': user.email ?? '',
          'isAnonymous': user.isAnonymous,
          'createdAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
          'appVersion': '2.0',
        },
        'onboarding': {
          'completed': true,
          'completedAt': FieldValue.serverTimestamp(),
          'answers': _data.toJson(),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore hatası onboarding'i engellemez
    }
  }

  // Saves onboarding data for users who skipped account creation —
  // stored under their anonymous Firebase UID so it can be recovered later.
  Future<void> _saveOnboardingAnonymously() async {
    if (Platform.isWindows || Platform.isLinux) return;
    try {
      final uid = await DeviceIdService.instance.ensureFirebaseUser();
      final db = FirebaseFirestore.instance;
      final name = _data.firstName.trim();
      await db.collection('users').doc(uid).set({
        'profile': {
          'displayName': name.isEmpty ? 'Kullanıcı' : name,
          'email': '',
          'isAnonymous': true,
          'createdAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
          'appVersion': '2.0',
        },
        'onboarding': {
          'completed': true,
          'completedAt': FieldValue.serverTimestamp(),
          'answers': _data.toJson(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── S7: Calculated values ──────────────────────────────────────────────────

  Widget _stepCalculatedValues() {
    final bmi = _data.weightKg / ((_data.heightCm / 100) * (_data.heightCm / 100));
    final bmr = _data.bmr.round();
    final tdee = _data.tdee.round();
    final targetWeeks = _data.weeklyChangeDelta > 0
        ? ((_data.weightKg - _data.targetWeightKg).abs() / _data.weeklyChangeDelta).round()
        : 0;
    final isMale = (_data.gender ?? Gender.male) == Gender.male;

    String bmiStatus = 'Normal';
    if (bmi < 18.5) bmiStatus = 'Zayıf';
    else if (bmi >= 25 && bmi < 30) bmiStatus = 'Kilolu';
    else if (bmi >= 30) bmiStatus = 'Obez';

    return _shell(
      title: _t('Hesaplanan değerlerin', 'Your calculated values'),
      subtitle: RichText(
        textAlign: TextAlign.start,
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: _kTextSub, height: 1.5),
          children: [
            TextSpan(text: 'Verdiğin yanıtlara göre '),
            TextSpan(text: _t('kişiselleştirilmiş besin hedeflerin', 'your personalized nutrient goals'), style: TextStyle(color: _tw, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid Section
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _metricCard(
                'BMI', 
                bmi.toStringAsFixed(1), 
                bmiStatus, 
                const Color(0xFFE3F2FD), 
                const Color(0xFF2196F3),
                onTap: () => _showMetricInfo(
                  _t('BMI (Vücut Kitle Endeksi)', 'BMI (Body Mass Index)'), 
                  _t('Kilonuzun boyunuza oranını belirleyen, kilo kategorinizi (zayıf, normal, kilolu) anlamanıza yardımcı olan bir ölçümdür.', 'A measure that determines the ratio of your weight to height, helping you understand your weight category.')
                ),
              ),
              _metricCard(
                'BMR', 
                '$bmr', 
                _t('kcal/gün', 'kcal/day'), 
                const Color(0xFFE8F5E9), 
                const Color(0xFF4CAF50),
                onTap: () => _showMetricInfo(
                  _t('BMR (Bazal Metabolizma Hızı)', 'BMR (Basal Metabolic Rate)'), 
                  _t('Vücudunuzun hiçbir aktivite yapmadan, sadece hayati fonksiyonlarını sürdürmek için (nefes alma, kan dolaşımı vb.) yaktığı enerjidir.', 'The energy your body burns just to maintain vital functions (breathing, blood circulation, etc.) without any activity.')
                ),
              ),
              _metricCard(
                'TDEE', 
                '$tdee', 
                _t('kcal/gün', 'kcal/day'), 
                const Color(0xFFFFF3E0), 
                const Color(0xFFFF9800),
                onTap: () => _showMetricInfo(
                  _t('TDEE (Günlük Enerji Harcaması)', 'TDEE (Total Daily Energy Expenditure)'), 
                  _t('BMR değerinize fiziksel aktivite seviyeniz eklenerek hesaplanan, kilonuzu korumak için her gün yakmanız gereken toplam enerji miktarıdır.', 'The total energy you need to burn daily to maintain weight, calculated by adding your physical activity level to BMR.')
                ),
              ),
              _metricCard(
                _t('HEDEF SÜRE', 'TARGET DURATION'), 
                '$targetWeeks', 
                'hafta', 
                const Color(0xFFF3E5F5), 
                const Color(0xFF9C27B0),
                onTap: () => _showMetricInfo(
                  _t('Hedef Süre', 'Target Duration'), 
                  _t('Belirlediğiniz hedef kiloya, haftalık değişim hızınıza bağlı olarak ne kadar sürede ulaşacağınızın tahmini süresidir.', 'The estimated time to reach your target weight based on your weekly change rate.')
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            _t('Günlük öneriler', 'Daily recommendations'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _tw),
          ),
          const SizedBox(height: 20),
          _macroRow('Kalori', '${_data.calorieTarget.round()} kcal', const Color(0xFFFF9800)),
          _macroRow(_t('Protein', 'Protein'), '${_data.proteinG.round()}g', const Color(0xFFEA4335)),
          _macroRow(_t('Karbonhidrat', 'Carbohydrate'), '${_data.carbG.round()}g', const Color(0xFF4CAF50)),
          _macroRow(_t('Yağ', 'Fat'), '${_data.fatG.round()}g', const Color(0xFFFBBC05)),
          _macroRow(_t('Lif', 'Fiber'), '${_data.fiberG.round()}g', const Color(0xFF8B4513)),
          _macroRow('Su', '${(_data.waterMl / 1000).toStringAsFixed(1)}L', const Color(0xFF4285F4)),

          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Daha fazla besin analizi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _tw,
                  decoration: TextDecoration.underline,
                ),
              ),
              iconColor: _tw,
              collapsedIconColor: _tw,
              children: [
                const SizedBox(height: 12),
                _microHeader('KOLESTEROL', const Color(0xFFFBBC05)),
                _microRow('Kolesterol', '< 300mg'),
                _microRow(_t('Doymuş Yağ', 'Saturated Fat'), '< ${(_data.calorieTarget * 0.1 / 9).round()}g'),
                _microRow(_t('Şeker', 'Sugar'), '< ${(_data.calorieTarget * 0.1 / 4).round()}g'),

                const SizedBox(height: 16),
                _microHeader(_t('MİNERALLER', 'MINERALS'), const Color(0xFF4285F4)),
                _microRow('Kalsiyum', '1000mg'),
                _microRow(_t('Demir', 'Iron'), isMale ? '8mg' : '18mg'),
                _microRow(_t('Magnezyum', 'Magnesium'), isMale ? '420mg' : '320mg'),
                _microRow('Fosfor', '700mg'),
                _microRow('Potasyum', isMale ? '3400mg' : '2600mg'),
                _microRow('Sodyum', '2300mg'),
                _microRow(_t(_t('Çinko', 'Zinc'), 'Zinc'), isMale ? '11mg' : '8mg'),
                _microRow(_t('Bakır', 'Copper'), '900mcg'),
                _microRow('Manganez', isMale ? '2.3mg' : '1.8mg'),
                _microRow('Selenyum', '55mcg'),
                _microRow(_t('İyot', 'Iodine'), '150mcg'),

                const SizedBox(height: 16),
                _microHeader(_t('VİTAMİNLER', 'VITAMINS'), const Color(0xFF34A853)),
                _microRow('A Vitamini', isMale ? '900mcg' : '700mcg'),
                _microRow('B1 (Tiamin)', isMale ? '1.2mg' : '1.1mg'),
                _microRow('B2 (Riboflavin)', isMale ? '1.3mg' : '1.1mg'),
                _microRow('B3 (Niasin)', isMale ? '16mg' : '14mg'),
                _microRow('B5 (Pantotenik Asit)', '5mg'),
                _microRow('B6 (Piridoksin)', '1.3mg'),
                _microRow('B7 (Biotin)', '30mcg'),
                _microRow('B9 (Folat)', '400mcg'),
                _microRow('B12 (Kobalamin)', '2.4mcg'),
                _microRow(_t('C Vitamini', 'Vitamin C'), isMale ? '90mg' : '75mg'),
                _microRow(_t('D Vitamini', 'Vitamin D'), '20mcg'),
                _microRow('E Vitamini', '15mg'),
                _microRow('K Vitamini', isMale ? '120mcg' : '90mcg'),

                const SizedBox(height: 16),
                _microHeader(_t('KAROTENOİDLER', 'CAROTENOIDS'), const Color(0xFFFF5722)),
                _microRow('Beta-Karoten', '6000mcg'),
                _microRow('Alfa-Karoten', isMale ? '2900mcg' : '2400mcg'),
                _microRow('Likopen', isMale ? '15mg' : '11mg'),
                _microRow('Lutein + Zeaksantin', '10000mcg'),

                const SizedBox(height: 16),
                _microHeader(_t('YAĞ ASİTLERİ', 'FATTY ACIDS'), const Color(0xFFFF9800)),
                _microRow('Omega-3', isMale ? '1.6g' : '1.1g'),
                _microRow('Omega-6', isMale ? '17g' : '12g'),
                _microRow('ALA (Alfa-Linolenik)', isMale ? '1.6g' : '1.1g'),
                _microRow('EPA', '0.25g'),
                _microRow('DHA', '0.25g'),

                const SizedBox(height: 16),
                _microHeader(_t('AMİNO ASİTLER', 'AMINO ACIDS'), const Color(0xFFEA4335)),
                _microRow('Triptofan', isMale ? '280mg' : '220mg'),
                _microRow('Treonin', isMale ? '1050mg' : '820mg'),
                _microRow(_t('İzolösin', 'Isoleucine'), isMale ? '1400mg' : '1100mg'),
                _microRow(_t('Lösin', 'Leucine'), isMale ? '2730mg' : '2130mg'),
                _microRow('Lizin', isMale ? '2100mg' : '1650mg'),
                _microRow('Metiyonin', isMale ? '728mg' : '570mg'),
                _microRow('Fenilalanin', isMale ? '1750mg' : '1370mg'),
                _microRow('Valin', isMale ? '1820mg' : '1430mg'),
                _microRow('Histidin', isMale ? '700mg' : '548mg'),

                const SizedBox(height: 16),
                _microHeader(_t('DİĞER BİLEŞENLER', 'OTHER COMPONENTS'), const Color(0xFF9C27B0)),
                _microRow('Kolin', isMale ? '550mg' : '425mg'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kTextSub.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _kTextSub),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('Bu değerler verdiğiniz yanıtlara göre bilimsel formüller kullanılarak tahmin edilmiştir. Kesin sonuçlar için bir uzmana danışmanız önerilir.', 'These values are estimated using scientific formulas based on your answers. Consulting a specialist for exact results is recommended.'),
                    style: TextStyle(fontSize: 12, color: _kTextSub, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showMetricInfo(String title, String content) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 50), // Instant feel
      pageBuilder: (context, anim1, anim2) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Text(title, style: TextStyle(fontSize: 18, color: _tw, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: _kTextSub, height: 1.4)),
        actionsPadding: const EdgeInsets.only(right: 12, bottom: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Anladım', 'I Understand'), style: TextStyle(color: _tw, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _microHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, String sub, Color bg, Color text, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBlue, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text.withValues(alpha: 0.7), letterSpacing: 1.2),
                ),
                const SizedBox(width: 4),
                Icon(Icons.info_outline_rounded, size: 14, color: text.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: text),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF8B949E)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _tw),
          ),
        ],
      ),
    );
  }

  Widget _microRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8B949E)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _tw),
          ),
        ],
      ),
    );
  }

  // ── S7: Paywall ────────────────────────────────────────────────────────────

  Widget _stepPaywall() {
    return PaywallScreen(
      fromOnboarding: true,
      onComplete: () {
        if (mounted && _current == _StepId.paywall) {
          _navigateTo(_StepId.signUp);
        }
      },
    );
  }

  // ── S8: Completion ─────────────────────────────────────────────────────────

  Widget _stepCompletion() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _data.firstName.trim();

    final w = _data.weightKg;
    final h = _data.heightCm;
    final bmi      = (w > 0 && h > 0) ? w / ((h / 100) * (h / 100)) : 0.0;
    final bmr      = _data.bmr.round();
    final tdee     = _data.tdee.round();
    final dailyCal = _data.calorieTarget.round();
    final proteinG = _data.proteinG.round();
    final carbG    = _data.carbG.round();
    final fatG     = _data.fatG.round();
    final fiberG   = _data.fiberG.round();
    final waterL   = _data.waterMl / 1000.0;

    // Daily step recommendation based on activity level
    final stepGoal = {
      ActivityLevel.sedentary:  7500,
      ActivityLevel.light:      8500,
      ActivityLevel.moderate:   10000,
      ActivityLevel.active:     12500,
      ActivityLevel.veryActive: 15000,
    }[_data.activityLevel] ?? 10000;

    String bmiStatus = bmi < 18.5 ? 'Zayıf'
        : bmi < 25 ? 'Normal'
        : bmi < 30 ? 'Kilolu' : 'Obez';

    // Metric card: coloured bg like the calculatedValues page
    Widget metricCard(String label, String value, String sub,
        Color bg, Color accent, {VoidCallback? onTap}) {
      final cardBg = isDark ? accent.withValues(alpha: 0.15) : bg;
      final labelColor = isDark ? accent.withValues(alpha: 0.8) : accent.withValues(alpha: 0.75);
      final valueColor = isDark ? accent : accent;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: isDark ? 0.25 : 0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: labelColor, letterSpacing: 0.8)),
                  if (onTap != null) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.info_outline_rounded, size: 12, color: labelColor),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                  color: valueColor, height: 1.0)),
              const SizedBox(height: 3),
              Text(sub, style: TextStyle(fontSize: 11, color: labelColor)),
            ],
          ),
        ),
      );
    }

    // Nutrient row with coloured dot
    Widget nutriRow(String label, String value, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328)))),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328))),
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 8),
            child: AnimatedBuilder(
              animation: _completionCtrl,
              builder: (_, __) => Opacity(
                opacity: _completionCtrl.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - _completionCtrl.value)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Başlık (8x sayfası stili) ──────────────────
                      Text(
                        name.isNotEmpty
                            ? 'Planın hazır,\n$name!'
                            : 'Kişisel planın\nhazır!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: _tw,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(fontSize: 15, color: _kTextSub, height: 1.6),
                          children: [
                            TextSpan(text: 'LensEat',
                                style: TextStyle(color: _kBlue, fontWeight: FontWeight.w700)),
                            TextSpan(text: ' '),
                            TextSpan(text: _t('sana özel hesaplanan', 'calculated specifically for you'),
                                style: TextStyle(color: _tw, fontWeight: FontWeight.w600)),
                            TextSpan(text: ' bu değerlerle\nhedefine ulaşmana yardımcı olacak.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── 2×2 Metrik Kartlar ─────────────────────────
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.55,
                        children: [
                          metricCard('BMI', bmi.toStringAsFixed(1), bmiStatus,
                              const Color(0xFFE3F2FD), const Color(0xFF2196F3),
                              onTap: () => _showMetricInfo(_t('BMI (Vücut Kitle Endeksi)', 'BMI (Body Mass Index)'),
                                  _t('Kilonuzun boyunuza oranını belirleyen, kilo kategorinizi (zayıf, normal, kilolu) anlamanıza yardımcı olan bir ölçümdür.', 'A measure that determines the ratio of your weight to height, helping you understand your weight category.'))),
                          metricCard('BMR', '$bmr', _t('kcal/gün', 'kcal/day'),
                              const Color(0xFFE8F5E9), const Color(0xFF4CAF50),
                              onTap: () => _showMetricInfo(_t('BMR (Bazal Metabolizma Hızı)', 'BMR (Basal Metabolic Rate)'),
                                  'Vücudunuzun hiçbir aktivite yapmadan, sadece hayati fonksiyonlarını sürdürmek için yaktığı enerji miktarıdır.')),
                          metricCard('TDEE', '$tdee', _t('kcal/gün', 'kcal/day'),
                              const Color(0xFFFFF3E0), const Color(0xFFFF9800),
                              onTap: () => _showMetricInfo(_t('TDEE (Günlük Enerji Harcaması)', 'TDEE (Total Daily Energy Expenditure)'),
                                  _t('BMR değerinize fiziksel aktivite seviyeniz eklenerek hesaplanan, kilonuzu korumak için her gün yakmanız gereken toplam enerji miktarıdır.', 'The total energy you need to burn daily to maintain weight, calculated by adding your physical activity level to BMR.'))),
                          metricCard(_t('GÜNLÜK ADIM', 'DAILY STEPS'), '$stepGoal', _t('adım/gün', 'steps/day'),
                              const Color(0xFFF3E5F5), const Color(0xFF9C27B0)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // ── Günlük Öneriler ────────────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_t('Günlük öneriler', 'Daily recommendations'),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _tw)),
                      ),
                      const SizedBox(height: 4),
                      Divider(color: isDark ? _kBorder : const Color(0xFFD0D7DE), height: 1),
                      const SizedBox(height: 4),
                      nutriRow('Kalori', '$dailyCal kcal', const Color(0xFFFFA726)),
                      nutriRow(_t('Protein', 'Protein'), '${proteinG}g', const Color(0xFF7EE787)),
                      nutriRow(_t('Karbonhidrat', 'Carbohydrate'), '${carbG}g', const Color(0xFF58A6FF)),
                      nutriRow(_t('Yağ', 'Fat'), '${fatG}g', const Color(0xFFFFA726)),
                      nutriRow(_t('Lif', 'Fiber'), '${fiberG}g', const Color(0xFFBC8CF2)),
                      nutriRow('Su', '${waterL.toStringAsFixed(1)}L', const Color(0xFF29B6F6)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Sabit Alt Buton ────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20,
              20 + MediaQuery.of(context).padding.bottom),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _goHome();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF1F2328),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t('Hadi Uygulamaya Başlayalım', 'Let\'s Start the App'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      color: isDark ? Colors.black : Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SHARED UI HELPERS
  // ==========================================================================

  Widget _shell({
    required dynamic title,
    required dynamic subtitle,
    required Widget child,
    bool centered = false,
    bool verticalCenter = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: verticalCenter ? constraints.maxHeight - 80 : 0,
            ),
            child: Column(
              mainAxisAlignment: verticalCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
              crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (!verticalCenter) const SizedBox(height: 52), // Offset for progress bar
                if (title is Widget)
                  title
                else
                  Text(
                    title as String,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _tw,
                      height: 1.2,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  if (subtitle is Widget)
                    subtitle
                  else
                    Text(
                      subtitle as String,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextSub,
                        height: 1.5,
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                child,
                // Minimum tampon boşluk
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Single-choice card row (emoji icon box + title + optional subtitle + right circle)

  Widget _notificationBubble(String timeStr, String title, String body) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Icon
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF0F3),
            ),
            child: Image.asset(
              'assets/icon/icon.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.center_focus_strong,
                color: Color(0xFF1C1C1E),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LensEat',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Text(
                      'şimdi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceRow({
    required String emoji,
    required String title,
    required String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
    required Color primary,
    // anySelected: bir şık seçilmişse true — seçilmeyenler soluklaşır
    bool anySelected = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: (!selected && anySelected) ? 0.55 : 1.0,
      child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _kSelBg : (isDark ? _kCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _kGreen : (isDark ? _kBorder : const Color(0xFFD0D7DE)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? _kGreen.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF161B22) : const Color(0xFFF0F0F5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? _kGreen : _tw,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextSub,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? _kGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(color: _kBorder, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    ),
    );
  }

  /// Large 2-column card (for gender, yes/no)
  Widget _bigCard({
    required String emoji,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
    required Color primary,
    bool anySelected = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: (!selected && anySelected) ? 0.55 : 1.0,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: selected ? _kSelBg : (isDark ? _kCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _kGreen : (isDark ? _kBorder : const Color(0xFFD0D7DE)),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? _kGreen : _tw,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// iOS-native style drum picker using CupertinoPicker with fade edges
  Widget _drumPicker({
    required FixedExtentScrollController controller,
    required List<Widget> items,
    required ValueChanged<int> onChanged,
  }) {
    final count = items.length;
    return SizedBox(
      height: 200,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.transparent,
            Colors.transparent,
            Colors.black,
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstOut,
        child: CupertinoPicker.builder(
          scrollController: controller,
          itemExtent: 44,
          onSelectedItemChanged: (i) {
            HapticFeedback.selectionClick();
            onChanged(i % count);
          },
          childCount: _kPickerMul * 2 * count,
          itemBuilder: (_, i) => Center(child: items[i % count]),
          selectionOverlay: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _pickerTextStyle(ThemeData theme) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: _tw,
    );
  }

  /// Metric/Imperial toggle
  Widget _unitToggle({
    required String metricLabel,
    required String imperialLabel,
    required bool isMetric,
    required ValueChanged<bool> onToggle,
    required Color primary,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _toggleBtn(metricLabel, isMetric, () => onToggle(true), primary,
            theme),
        const SizedBox(width: 8),
        _toggleBtn(imperialLabel, !isMetric, () => onToggle(false),
            primary, theme),
      ],
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap,
      Color primary, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? _kGreen : _kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? Colors.black : _tw,
          ),
        ),
      ),
    );
  }

  /// TextField helper
  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    TextInputAction action = TextInputAction.done,
    TextInputType keyboard = TextInputType.text,
    bool autofocus = false,
    TextCapitalization capitalization = TextCapitalization.none,
    FocusNode? focusNode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kTextSub,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          textInputAction: action,
          keyboardType: keyboard,
          autofocus: autofocus,
          focusNode: focusNode,
          textCapitalization: capitalization,
          style: TextStyle(color: _tw),
          onEditingComplete: () => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kTextSub),
            filled: true,
            fillColor: isDark ? _kCard : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// Multi-select column layout with "Diğer" TextField inline
  Widget _multiSelectWithOther({
    required List<(String, String)> options,
    required Set<String> selected,
    required TextEditingController otherController,
    required ValueChanged<String> onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: options.map((o) {
        final sel = selected.contains(o.$2);
        final isOther = o.$2 == _t('Diğer', 'Other');
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(o.$2);
            if (!isOther || sel) {
              FocusScope.of(context).unfocus();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 10),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: sel ? _kSelBg : (isDark ? _kCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? _kGreen : (isDark ? _kBorder : const Color(0xFFD0D7DE)),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sel
                            ? _kGreen.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF161B22) : const Color(0xFFF0F0F5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(o.$1, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        o.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          color: sel ? _kGreen : _tw,
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: sel ? _kGreen : Colors.transparent,
                        shape: BoxShape.circle,
                        border: sel ? null : Border.all(color: isDark ? _kBorder : const Color(0xFFD0D7DE), width: 1.5),
                      ),
                      child: sel
                          ? const Icon(Icons.check, color: Colors.black, size: 13)
                          : null,
                    ),
                  ],
                ),
                // Inline TextField for "Diğer"
                if (isOther)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: sel
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              children: [
                                TextField(
                                  controller: otherController,
                                  autofocus: true,
                                  textCapitalization: TextCapitalization.sentences,
                                  scrollPadding: const EdgeInsets.only(bottom: 65),
                                  style: TextStyle(color: _tw),
                                  decoration: InputDecoration(
                                    hintText: 'Belirt...',
                                    hintStyle: const TextStyle(color: _kTextSub),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                      borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                      borderSide: BorderSide(color: _kGreen, width: 1.5),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                      borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Multi-select column without "Diğer" (for motivations)
  Widget _multiSelectNoOther({
    required List<(String, String)> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: options.map((o) {
        final sel = selected.contains(o.$2);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(o.$2);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 10),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: sel ? _kSelBg : (isDark ? _kCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? _kGreen : (isDark ? _kBorder : const Color(0xFFD0D7DE)),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sel
                        ? _kGreen.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF161B22) : const Color(0xFFF0F0F5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(o.$1, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    o.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel ? _kGreen : _tw,
                    ),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: sel ? _kGreen : Colors.transparent,
                    shape: BoxShape.circle,
                    border: sel ? null : Border.all(color: _kBorder, width: 1.5),
                  ),
                  child: sel
                      ? const Icon(Icons.check, color: Colors.black, size: 13)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Single-select list with optional "Diğer" text field
  Widget _singleSelectWithOther({
    required List<(String, String)> options,
    required String? selected,
    required TextEditingController otherController,
    required ValueChanged<String> onSelect,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: options.map((o) {
        final sel = selected == o.$2;
        final isOther = o.$2 == _t('Diğer', 'Other');
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: (selected != null && selected.isNotEmpty && !sel) ? 0.4 : 1.0,
          child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(sel ? '' : o.$2);
            if (!isOther || sel) {
              FocusScope.of(context).unfocus();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 10),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: sel ? _kSelBg : (isDark ? _kCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? _kGreen : (isDark ? _kBorder : const Color(0xFFD0D7DE)),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sel
                            ? _kGreen.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF161B22) : const Color(0xFFF0F0F5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(o.$1, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        o.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          color: sel ? _kGreen : _tw,
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: sel ? _kGreen : Colors.transparent,
                        shape: BoxShape.circle,
                        border: sel ? null : Border.all(color: isDark ? _kBorder : const Color(0xFFD0D7DE), width: 1.5),
                      ),
                      child: sel
                          ? const Icon(Icons.check, color: Colors.black, size: 13)
                          : null,
                    ),
                  ],
                ),
                if (isOther)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: sel
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextField(
                              controller: otherController,
                              autofocus: true,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: _tw),
                              decoration: InputDecoration(
                                hintText: 'Belirt...',
                                hintStyle: const TextStyle(color: _kTextSub),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: _kGreen, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                                  borderSide: BorderSide(color: isDark ? _kBorder : const Color(0xFFD0D7DE)),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
        );
      }).toList(),
    );
  }
  String _generateShortId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

// =============================================================================
// TARGET WEIGHT STEP
// =============================================================================

class _TargetWeightStep extends StatefulWidget {
  final double initialWeight;
  final bool useMetric;
  final Goal weightGoal;
  final ValueChanged<double> onChanged;

  const _TargetWeightStep({
    required this.initialWeight,
    required this.useMetric,
    required this.weightGoal,
    required this.onChanged,
  });

  @override
  State<_TargetWeightStep> createState() => _TargetWeightStepState();
}

class _TargetWeightStepState extends State<_TargetWeightStep> {
  late final FixedExtentScrollController _ctrl;
  static const int _multiplier = 500;

  Color get _tw => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1F2328);

  // Display value in the drum's unit (kg or lb)
  late int _currentDisplay;

  bool get _isLb => !widget.useMetric;

  int get _minWeight {
    if (_isLb) {
      final initLb = (widget.initialWeight * 2.20462).round();
      if (widget.weightGoal == Goal.lose) return 66;
      if (widget.weightGoal == Goal.gain) return initLb + 1;
      return 66;
    } else {
      if (widget.weightGoal == Goal.lose) return 30;
      if (widget.weightGoal == Goal.gain) return widget.initialWeight.round() + 1;
      return 30;
    }
  }

  int get _maxWeight {
    if (_isLb) {
      final initLb = (widget.initialWeight * 2.20462).round();
      if (widget.weightGoal == Goal.lose) return (initLb - 1).clamp(67, 1200);
      if (widget.weightGoal == Goal.gain) return 550;
      return 550;
    } else {
      if (widget.weightGoal == Goal.lose) return (widget.initialWeight.round() - 1).clamp(31, 999);
      if (widget.weightGoal == Goal.gain) return 250;
      return 250;
    }
  }

  int get _range => (_maxWeight - _minWeight + 1).clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    final initDisplay = _isLb
        ? (widget.initialWeight * 2.20462).round()
        : widget.initialWeight.round();
    final start = initDisplay.clamp(_minWeight, _maxWeight);
    _currentDisplay = start;
    _ctrl = FixedExtentScrollController(
      initialItem: _multiplier * _range + (start - _minWeight).clamp(0, _range - 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kg = _isLb ? _currentDisplay / 2.20462 : _currentDisplay.toDouble();
      widget.onChanged(kg);
    });
  }

  @override
  void didUpdateWidget(_TargetWeightStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useMetric != widget.useMetric) {
      // Unit changed! Convert existing target weight to new unit
      double oldKg = oldWidget.useMetric
          ? _currentDisplay.toDouble()
          : _currentDisplay / 2.20462;
      _currentDisplay = _isLb ? (oldKg * 2.20462).round() : oldKg.round();
      _currentDisplay = _currentDisplay.clamp(_minWeight, _maxWeight);

      // Reset controller to new position
      _ctrl.jumpToItem(_multiplier * _range +
          (_currentDisplay - _minWeight).clamp(0, _range - 1));
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = _isLb ? 'lb' : 'kg';
    final display = '$_currentDisplay $unit';

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ListWheelScrollView.useDelegate(
                controller: _ctrl,
                itemExtent: 52,
                perspective: 0.003,
                diameterRatio: 1.5,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  HapticFeedback.selectionClick();
                  final val = (i % _range) + _minWeight;
                  final kg = _isLb ? val / 2.20462 : val.toDouble();
                  setState(() => _currentDisplay = val);
                  widget.onChanged(kg);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _multiplier * 2 * _range,
                  builder: (_, i) => Center(
                    child: Text(
                      '${(i % _range) + _minWeight} $unit',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _tw),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hedef: $display',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF58A6FF)),
        ),
      ],
    );
  }
}

class _EmailAuthSheet extends StatefulWidget {
  final void Function(bool onboardingDone) onSuccess;
  final VoidCallback? onUserNotFound;
  const _EmailAuthSheet({required this.onSuccess, this.onUserNotFound});

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Color get _tw => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1F2328);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    FocusManager.instance.primaryFocus?.unfocus();
    super.dispose();
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam', style: TextStyle(color: Color(0xFF58A6FF))),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showDialog('Eksik Bilgi', _t('E-posta ve şifre boş bırakılamaz.', 'Email and password cannot be empty.'));
      return;
    }

    setState(() => _loading = true);

    try {
      final userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);

      if (!mounted) return;

      bool onboardingDone = false;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .get()
            .timeout(const Duration(seconds: 4));
        onboardingDone = (doc.data()?['onboarding']?['completed'] ?? false) as bool;
        if (onboardingDone) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_done', true);
          SyncService.instance.pullUserData();
        }
      } catch (_) {}

      widget.onSuccess(onboardingDone);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e.code == 'user-not-found') {
        _showDialog(_t('Hesap Bulunamadı', 'Account Not Found'), 'Bu e-posta adresiyle kayıtlı bir hesap bulunamadı. Lütfen doğru hesabı giriniz.');
        return;
      }

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          _showDialog(_t('Giriş Başarısız', 'Login Failed'), _t('Şifre veya e-posta hatalı.', 'Incorrect email or password.'));
          break;
        case 'invalid-email':
          _showDialog(_t('Geçersiz E-posta', 'Invalid Email'), _t('Lütfen geçerli bir e-posta adresi giriniz.', 'Please enter a valid email address.'));
          break;
        default:
          _showDialog('Hata', e.message ?? 'Beklenmeyen bir hata oluştu.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showDialog('Hata', 'Beklenmeyen bir hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);
    final handleColor = isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _t('Giriş Yap', 'Log In'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF58A6FF)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: _tw),
            decoration: InputDecoration(
              labelText: 'E-posta',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF58A6FF)),
              filled: true,
              fillColor: fieldFill,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0xFF58A6FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onEditingComplete: _submit,
            style: TextStyle(color: _tw),
            decoration: InputDecoration(
              labelText: 'Şifre',
              labelStyle: const TextStyle(color: Color(0xFF8B949E)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF58A6FF)),
              filled: true,
              fillColor: fieldFill,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0xFF58A6FF), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF8B949E)),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loading ? null : _submit,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(color: _tw, borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        _t('Giriş Yap', 'Log In'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailCtrl.text.trim();
              if (email.isEmpty) {
                _showDialog(_t('E-posta Gerekli', 'Email Required'), _t('Şifre sıfırlama bağlantısı göndermek için önce e-posta adresinizi yazın.', 'Enter your email address first to send a password reset link.'));
                return;
              }

              setState(() => _loading = true);
              final result = await AuthService().sendPasswordReset(email);
              if (!mounted) return;
              setState(() => _loading = false);

              if (result.success) {
                _showDialog(
                  'E-posta Gönderildi',
                  '$email adresine şifre sıfırlama bağlantısı gönderildi. Lütfen gelen kutunuzu (ve gereksiz kutusunu) kontrol edin.',
                );
              } else {
                _showDialog('Hata', result.errorMessage ?? 'Sıfırlama e-postası gönderilemedi.');
              }
            },
            child: Text(_t('Şifremi unuttum', 'Forgot password'), style: const TextStyle(color: Color(0xFF8B949E))),
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// KEEP ALIVE PAGE WRAPPER
// =============================================================================

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// =============================================================================
// TRANSITION OVERLAY
// =============================================================================

class _TransitionOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const _TransitionOverlay({
    super.key,
    required this.child,
    required this.onComplete,
  });

  @override
  State<_TransitionOverlay> createState() => _TransitionOverlayState();
}

class _TransitionOverlayState extends State<_TransitionOverlay> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _visible = true);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 350),
      child: AnimatedScale(
        scale: _visible ? 1.0 : 0.85,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: Material(
          color: bg,
          child: widget.child,
        ),
      ),
    );
  }
}

// =============================================================================
// PAYWALL HELPERS
// =============================================================================

class _F {
  final String label;
  final bool free;
  final bool pro;
  const _F(this.label, {required this.free, required this.pro});
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final bool isPro;
  final String? badge;
  final List<_F> features;
  final bool selected;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.isPro,
    required this.badge,
    required this.features,
    required this.selected,
  });

  static const _green = Color(0xFF7EE787);
  static const _greenBg = Color(0xFF0D2218);
  static const _card = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _textSub = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    final tw = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1F2328);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPro ? _greenBg : _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? _green : (isPro ? _green.withValues(alpha: 0.35) : _border),
          width: selected ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isPro ? _green : tw,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPro ? _green : _textSub,
            ),
          ),
          const SizedBox(height: 10),
          // Features
          ...features.map((f) {
            final has = isPro ? f.pro : f.free;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    has ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: has ? _green : _textSub,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: has ? tw : _textSub,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// ANALYSIS PAGE
// =============================================================================

class _AnalysisPage extends StatefulWidget {
  final VoidCallback onComplete;
  const _AnalysisPage({super.key, required this.onComplete});

  @override
  State<_AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<_AnalysisPage> with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late Animation<double> _progressAnim;

  Color get _tw => Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1F2328);

  List<String> get _labels => [
    _t('BMI hesaplanıyor...', 'Calculating BMI...'),
    _t('BMR (Bazal Metabolizma) hesaplanıyor...', 'Calculating BMR (Basal Metabolism)...'),
    _t('TDEE (Günlük Kalori İhtiyacı) hesaplanıyor...', 'Calculating TDEE (Daily Calorie Need)...'),
    _t('Hedef kalori aralığı belirleniyor...', 'Setting target calorie range...'),
    _t('Metabolizma analiz ediliyor...', 'Analyzing metabolism...'),
    _t('Optimal alım hesaplanıyor...', 'Calculating optimal intake...'),
    _t('Makro besin dağılımı hesaplanıyor...', 'Calculating macro distribution...'),
    _t('Mikrobesin hedefleri ayarlanıyor...', 'Setting micronutrient targets...'),
    _t('Kişiselleştirilmiş plan tamamlanıyor...', 'Finalizing personalized plan...'),
  ];

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: Curves.easeInOut),
    );

    _mainCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete();
      }
    });

    _mainCtrl.forward();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainCtrl,
      builder: (context, child) {
        final progress = _progressAnim.value;
        final linearProgress = _mainCtrl.value; // Lineer ilerleme (etiketler için)
        final percentage = (progress * 100).round();
        
        // Etiket geçişleri lineer ilerlemeye bağlı olsun (yüzde yavaşlasa da etiketler akmaya devam eder)
        final double t = linearProgress * (_labels.length - 1);
        final int currentIndexBase = t.floor();
        final double subProgress = t % 1.0;
        
        // Her adımın son %20'lik kısmında kayma gerçekleşsin
        double slideFactor = 0.0;
        if (subProgress > 0.8) {
          slideFactor = Curves.easeInOutCubic.transform((subProgress - 0.8) / 0.2);
        }
        
        final double indexFraction = currentIndexBase + slideFactor;
        final int currentIndex = indexFraction.round();
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Circular Progress ---
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(_tw.withValues(alpha: 0.08)),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
                    ),
                  ),
                  Center(
                    child: Text(
                      '%$percentage',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: _tw,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              
              // --- Sliding Labels ---
              SizedBox(
                height: 200, // Daha fazla yazı görebilmek için yüksekliği artırdık
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(_labels.length, (i) {
                    final double relativePos = i - indexFraction;
                    
                    // Görünürlük menzilini genişlettik (üstte ve altta daha fazla yazı)
                    if (relativePos.abs() > 2.2) return const SizedBox.shrink();
                    
                    // Opaklık geçişini yumuşattık (bi anda kaybolmuyor)
                    final double opacity = (1.0 - (relativePos.abs() * 0.45)).clamp(0.0, 1.0);
                    final double scale = 0.85 + (opacity * 0.15);
                    final double yOffset = relativePos * 50;

                    return Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _labels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: i == currentIndex ? 20 : 16,
                                fontWeight: i == currentIndex ? FontWeight.w800 : FontWeight.w500,
                                color: i == currentIndex ? _tw : _tw.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// LONGEVITY CHART PAINTER
// =============================================================================

class _LongevityChart extends StatefulWidget {
  final bool active;
  const _LongevityChart({required this.active});

  @override
  State<_LongevityChart> createState() => _LongevityChartState();
}

class _LongevityChartState extends State<_LongevityChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.active) {
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(_LongevityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _ctrl.forward(from: 0.0);
    } else if (!widget.active) {
      _ctrl.value = 0.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _LongevityPainter(_ctrl.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _LongevityPainter extends CustomPainter {
  final double progress;
  _LongevityPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final smoothProgress = Curves.easeInOutCubic.transform(progress);
    final padding = const EdgeInsets.fromLTRB(40, 40, 40, 40);
    final w = size.width - padding.left - padding.right;
    final h = size.height - padding.top - padding.bottom;

    final startX = padding.left;
    final endX = size.width - padding.right;
    final baselineY = size.height - padding.bottom - h * 0.3; // Flat line height

    final paintBase = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final paintBlue = Paint()
      ..color = const Color(0xFF58A6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // 1. Draw Grid Lines (Horizontal Dashed)
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    
    // Bottom X-Axis (Solid)
    canvas.drawLine(Offset(startX, size.height - padding.bottom), Offset(endX, size.height - padding.bottom), gridPaint);
    
    // Two Dashed Horizontal Lines
    void drawDashedLine(double y) {
      const dashWidth = 4;
      const dashSpace = 4;
      double currentX = startX;
      while (currentX < endX) {
        canvas.drawLine(Offset(currentX, y), Offset(currentX + dashWidth, y), gridPaint);
        currentX += dashWidth + dashSpace;
      }
    }
    drawDashedLine(baselineY); // One at the traditional diet level
    drawDashedLine(padding.top + (baselineY - padding.top) * 0.5); // One in the middle

    // 2. Traditional Diet Line (Flat Black/White38)

    final baseLinePath = Path();
    baseLinePath.moveTo(startX, baselineY);
    baseLinePath.lineTo(startX + (w * smoothProgress), baselineY);
    canvas.drawPath(baseLinePath, paintBase);

    // 3. Longevity Line (Rising Blue Curve)

    // Control points for a steep rise without overshooting/dipping at the end
    final cp1 = Offset(startX + w * 0.5, baselineY);
    final cp2 = Offset(endX - 10, padding.top);
    final targetPoint = Offset(endX, padding.top);

    final blueCurvePath = Path();
    blueCurvePath.moveTo(startX, baselineY);
    
    for (double t = 0; t <= smoothProgress; t += 0.01) {
      final x = _cubic(startX, cp1.dx, cp2.dx, targetPoint.dx, t);
      final y = _cubic(baselineY, cp1.dy, cp2.dy, targetPoint.dy, t);
      blueCurvePath.lineTo(x, y);
    }
    canvas.drawPath(blueCurvePath, paintBlue);

    // 4. Shade Area Between Lines
    if (smoothProgress > 0.1) {
      final fillPath = Path();
      fillPath.moveTo(startX, baselineY);
      for (double t = 0; t <= smoothProgress; t += 0.02) {
        final x = _cubic(startX, cp1.dx, cp2.dx, targetPoint.dx, t);
        final y = _cubic(baselineY, cp1.dy, cp2.dy, targetPoint.dy, t);
        fillPath.lineTo(x, y);
      }
      fillPath.lineTo(startX + (w * smoothProgress), baselineY);
      fillPath.close();

      canvas.drawPath(
        fillPath,
        Paint()..color = const Color(0xFF58A6FF).withValues(alpha: 0.15 * smoothProgress),
      );
    }

    // 5. Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // "1. Ay"
    _drawText(canvas, textPainter, "1. Ay", Offset(startX - 10, size.height - padding.bottom + 10), Colors.black);
    // "6. Ay"
    _drawText(canvas, textPainter, "6. Ay", Offset(endX - 20, size.height - padding.bottom + 10), Colors.black);

    // "LensEat" label above the blue line
    if (smoothProgress > 0.85) {
      _drawText(
        canvas, 
        textPainter, 
        "LensEat", 
        Offset(endX - 45, padding.top - 25), 
        const Color(0xFF58A6FF),
        fontSize: 16,
        bold: true
      );
    }

    // "Diğer Uygulamalar" label at the end of the black line
    if (smoothProgress > 0.85) {
      _drawText(
        canvas, 
        textPainter, 
        "Diğer Uygulamalar", 
        Offset(endX - 85, baselineY + 8), 
        Colors.black38,
        fontSize: 11,
        bold: true
      );
    }
  }

  double _cubic(double p0, double p1, double p2, double p3, double t) {
    return (1 - t) * (1 - t) * (1 - t) * p0 +
        3 * (1 - t) * (1 - t) * t * p1 +
        3 * (1 - t) * t * t * p2 +
        t * t * t * p3;
  }

  void _drawText(Canvas canvas, TextPainter tp, String text, Offset offset, Color color, {double fontSize = 12, bool bold = false}) {
    tp.text = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.w900 : FontWeight.w500),
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_LongevityPainter oldDelegate) => oldDelegate.progress != progress;
}

// ── Translation Extension ──────────────────────────────────────────────────
extension TranslationStateExtension on State {
  bool get _isTr => Provider.of<LanguageProvider>(context, listen: false).isTurkish;
  String _t(String tr, String en) => _isTr ? tr : en;
}
