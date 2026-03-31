import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/achievement_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();

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
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()),
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
        ChangeNotifierProxyProvider2<ProfileProvider, NutritionProvider,
            AchievementProvider>(
          create: (_) => AchievementProvider(),
          update: (_, profile, nutrition, achievement) {
            if (profile.isProfileComplete) {
              achievement?.onNutritionUpdated(
                calorieGoal: profile.calorieGoal,
                proteinGoal: profile.proteinGoal,
                waterGoalMl: 2000,
                totalCalories: nutrition.totalNutrition.calories,
                totalProtein: nutrition.totalNutrition.protein,
                waterIntakeMl: nutrition.todayLog.waterIntakeMl,
                mealCount: nutrition.todayLog.entries.length,
              );
            }
            return achievement!;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'NutriLens',
          debugShowCheckedModeBanner: false,
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B4332),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFF40916C),
              secondary: const Color(0xFF74C69D),
              surface: const Color(0xFFF8FFF8),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FFF8),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B4332),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF4ADE80),
              secondary: const Color(0xFF74C69D),
              surface: const Color(0xFF122018),
              surfaceContainerHighest: const Color(0xFF0F1C13),
              outline: const Color(0xFF1A3020),
              onPrimary: const Color(0xFF0C1610),
              onSurface: const Color(0xFFE8F5EC),
              onSurfaceVariant: const Color(0xFFB8D4C0),
            ),
            scaffoldBackgroundColor: const Color(0xFF0C1610),
            cardColor: const Color(0xFF122018),
            dividerColor: const Color(0xFF1A3020),
            useMaterial3: true,
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                  color: Color(0xFFE8F5EC),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5),
              displayMedium: TextStyle(
                  color: Color(0xFFE8F5EC),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0),
              headlineLarge: TextStyle(
                  color: Color(0xFFE8F5EC),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5),
              headlineMedium: TextStyle(
                  color: Color(0xFFE8F5EC),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5),
              titleLarge: TextStyle(
                  color: Color(0xFFE8F5EC), fontWeight: FontWeight.w600),
              titleMedium: TextStyle(
                  color: Color(0xFFE8F5EC), fontWeight: FontWeight.w500),
              bodyLarge: TextStyle(color: Color(0xFFE8F5EC)),
              bodyMedium: TextStyle(color: Color(0xFFB8D4C0)),
              bodySmall: TextStyle(color: Color(0xFF4A7060)),
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
