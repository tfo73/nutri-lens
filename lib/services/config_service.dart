import 'dart:io' show Platform;
import 'package:firebase_remote_config/firebase_remote_config.dart';

class ConfigService {
  static final _rc = FirebaseRemoteConfig.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || Platform.isWindows) return;
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _rc.setDefaults({
        'ANTHROPIC_API_KEY': '',
        'USDA_API_KEY': '',
        'EDAMAM_NUTRITION_KEY': '',
        'EDAMAM_RECIPE_KEY': '',
        'PIXABAY_API_KEY': '',
      });
      await _rc.fetchAndActivate();
      _initialized = true;
    } catch (_) {}
  }

  static String get anthropicKey {
    if (Platform.isWindows) {
      return const String.fromEnvironment('ANTHROPIC_API_KEY');
    }
    return _rc.getString('ANTHROPIC_API_KEY');
  }

  static String get usdaKey {
    if (Platform.isWindows) {
      return const String.fromEnvironment('USDA_API_KEY');
    }
    return _rc.getString('USDA_API_KEY');
  }

  static String get edamamNutritionKey {
    if (Platform.isWindows) {
      return const String.fromEnvironment('EDAMAM_NUTRITION_KEY');
    }
    return _rc.getString('EDAMAM_NUTRITION_KEY');
  }

  static String get edamamRecipeKey {
    if (Platform.isWindows) {
      return const String.fromEnvironment('EDAMAM_RECIPE_KEY');
    }
    return _rc.getString('EDAMAM_RECIPE_KEY');
  }

  static String get pixabayKey {
    if (Platform.isWindows) {
      return const String.fromEnvironment('PIXABAY_API_KEY');
    }
    return _rc.getString('PIXABAY_API_KEY');
  }
}
