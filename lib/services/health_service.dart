import 'dart:io';
import 'package:flutter/services.dart';

class HealthService {
  static const MethodChannel _channel = MethodChannel('nutrilens/health');

  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('requestPermissions');
        return result ?? false;
      } else if (Platform.isIOS) {
        final result = await _channel.invokeMethod<bool>('requestPermissions');
        return result ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<int> getTodaySteps() async {
    try {
      final result = await _channel.invokeMethod<int>('getTodaySteps');
      return result ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static double calculateCaloriesFromSteps(int steps, double weightKg) {
    return steps * 0.04 * (weightKg > 0 ? weightKg : 70);
  }
}
