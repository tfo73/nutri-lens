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
              seedColor: const Color(0xFF4CAF50),
              brightness: Brightness.light,
            ).copyWith(
              surface: const Color(0xFFF5F5F5),
            ),
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4CAF50),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF1E1E1E),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
