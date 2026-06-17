import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/nutrition_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/achievement_provider.dart';
import 'providers/wellness_provider.dart';
import 'providers/fasting_provider.dart';
import 'providers/coach_provider.dart';
import 'screens/splash_screen.dart';
import 'services/config_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

// ─── Global Palette ───────────────────────────────────────────────────────────
// Dark  (primary)
const _deepVoid   = Color(0xFF0D1117); // Ana arka plan
const _nebulaGray = Color(0xFF161B22); // Kart / panel
const _iceCobalt  = Color(0xFF58A6FF); // Aktif buton / grafik
const _bioMint    = Color(0xFF7EE787); // Başarı / onay
const _solarFlare = Color(0xFFF85149); // Uyarı / kritik
const _starlight  = Color(0xFFE6EDF3); // Ana metin
const _secondText = Color(0xFF8B949E); // İkincil metin
const _border     = Color(0xFF30363D); // Kenarlık / ayraç
const _panelHigh  = Color(0xFF21262D); // Biraz daha açık panel
// Light (adapted)
const _lBg        = Color(0xFFF6F8FA);
const _lCard      = Color(0xFFFFFFFF);
const _lPrimary   = Color(0xFF0969DA);
const _lSuccess   = Color(0xFF1F883D);
const _lError     = Color(0xFFCF222E);
const _lText      = Color(0xFF1F2328);
const _lSubText   = Color(0xFF656D76);
const _lBorder    = Color(0xFFD0D7DE);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await initializeDateFormatting('tr_TR', null);

  if (!Platform.isWindows) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );

    await ConfigService.initialize();
  }

  // Increase image cache to reduce decode overhead on re-visits
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20; // 150 MB

  try {
    await NotificationService.initialize();
    await NotificationService.scheduleWeeklyWeightReminder(true);
    SyncService.instance.init();
  } catch (_) {}

  final profileProvider = ProfileProvider();
  await profileProvider.loadProfiles();

  runApp(NutriLensApp(profileProvider: profileProvider));
}

class NutriLensApp extends StatelessWidget {
  final ProfileProvider profileProvider;

  const NutriLensApp({super.key, required this.profileProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileProvider),
        ChangeNotifierProvider<WellnessProvider>(
          create: (_) => WellnessProvider()..load(),
        ),
        ChangeNotifierProvider<FastingProvider>(
          create: (_) => FastingProvider()..load(),
        ),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProxyProvider<ProfileProvider, NutritionProvider>(
          create: (_) => NutritionProvider(),
          update: (_, profileProv, nutritionProvider) {
            final profileId = profileProv.activeProfileId;
            if (profileId.isNotEmpty) {
              nutritionProvider?.switchProfile(profileId);
            }
            return nutritionProvider!;
          },
        ),
        ChangeNotifierProxyProvider2<
          ProfileProvider,
          NutritionProvider,
          AchievementProvider
        >(
          create: (_) => AchievementProvider(),
          update: (_, profile, nutrition, achievement) {
            if (profile.isProfileComplete) {
              achievement?.onNutritionUpdated(
                calorieGoal: profile.calorieGoal,
                proteinGoal: profile.proteinGoal,
                carbGoal: profile.carbGoal,
                fatGoal: profile.fatGoal,
                fiberGoal: profile.fiberGoal,
                waterGoalMl: profile.waterGoalMl.toDouble(),
                totalCalories: nutrition.totalNutrition.calories,
                totalProtein: nutrition.totalNutrition.protein,
                totalCarbs: nutrition.totalNutrition.carbohydrates,
                totalFat: nutrition.totalNutrition.fat,
                totalFiber: nutrition.totalNutrition.fiber,
                waterIntakeMl: nutrition.todayLog.waterIntakeMl,
                mealCount: nutrition.todayLog.entries.length,
              );
            }
            return achievement!;
          },
        ),
        ChangeNotifierProxyProvider<ProfileProvider, CoachProvider>(
          create: (_) => CoachProvider(''),
          update: (_, profile, coach) {
            final id = profile.activeProfileId;
            if (id.isNotEmpty && id != coach?.profileId) {
              return CoachProvider(id);
            }
            return coach!;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'LensEat',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // ── Light Theme ───────────────────────────────────────────────────
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: _lPrimary,
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFDCEBFF),
              onPrimaryContainer: _lPrimary,
              secondary: _lSuccess,
              onSecondary: Colors.white,
              secondaryContainer: Color(0xFFCEF3D8),
              onSecondaryContainer: _lSuccess,
              error: _lError,
              onError: Colors.white,
              surface: _lCard,
              onSurface: _lText,
              surfaceContainerHighest: Color(0xFFEFF1F3),
              outline: _lBorder,
              outlineVariant: Color(0xFFE7ECF0),
              onSurfaceVariant: _lSubText,
              tertiary: _lPrimary,
              onTertiary: Colors.white,
            ),
            scaffoldBackgroundColor: _lBg,
            cardColor: _lCard,
            dividerColor: _lBorder,
            textTheme: const TextTheme(
              displayLarge: TextStyle(color: _lText, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              headlineLarge: TextStyle(color: _lText, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              headlineMedium: TextStyle(color: _lText, fontWeight: FontWeight.w600),
              titleLarge: TextStyle(color: _lText, fontWeight: FontWeight.w600, fontSize: 17),
              titleMedium: TextStyle(color: _lText, fontWeight: FontWeight.w500, fontSize: 15),
              bodyLarge: TextStyle(color: _lText, fontSize: 17),
              bodyMedium: TextStyle(color: _lSubText, fontSize: 15),
              bodySmall: TextStyle(color: _lSubText, fontSize: 13),
              labelSmall: TextStyle(color: _lSubText, fontSize: 11, letterSpacing: 0.5),
            ),
          ),

          // ── Dark Theme (Ana Tema) ─────────────────────────────────────────
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: const ColorScheme(
              brightness: Brightness.dark,
              primary: _iceCobalt,
              onPrimary: _deepVoid,
              primaryContainer: Color(0xFF1A2744),
              onPrimaryContainer: _iceCobalt,
              secondary: _bioMint,
              onSecondary: _deepVoid,
              secondaryContainer: Color(0xFF0D2218),
              onSecondaryContainer: _bioMint,
              error: _solarFlare,
              onError: _starlight,
              surface: _nebulaGray,
              onSurface: _starlight,
              surfaceContainerHighest: _panelHigh,
              outline: _border,
              outlineVariant: _panelHigh,
              onSurfaceVariant: _secondText,
              tertiary: _bioMint,
              onTertiary: _deepVoid,
            ),
            scaffoldBackgroundColor: _deepVoid,
            cardColor: _nebulaGray,
            dividerColor: _border,
            textTheme: const TextTheme(
              displayLarge: TextStyle(color: _starlight, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              headlineLarge: TextStyle(color: _starlight, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              headlineMedium: TextStyle(color: _starlight, fontWeight: FontWeight.w600),
              titleLarge: TextStyle(color: _starlight, fontWeight: FontWeight.w600, fontSize: 17),
              titleMedium: TextStyle(color: _starlight, fontWeight: FontWeight.w500, fontSize: 15),
              bodyLarge: TextStyle(color: _starlight, fontSize: 17),
              bodyMedium: TextStyle(color: _secondText, fontSize: 15),
              bodySmall: TextStyle(color: _secondText, fontSize: 13),
              labelSmall: TextStyle(color: _secondText, fontSize: 11, letterSpacing: 0.5),
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
