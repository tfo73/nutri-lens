import 'package:flutter_test/flutter_test.dart';
import 'package:lens_eat/models/daily_log.dart';
import 'package:lens_eat/models/nutrition_data.dart';

void main() {
  group('Firestore Sync Repair and Unscaling Tests', () {
    test('Should unscale old formatted entry safely', () {
      // Simulate Firestore log document data in the old format
      // Portion size = 314.3g (factor = 3.143)
      // Stored calories in old format: 225 kcal (scaled once)
      final oldEntryMap = {
        'id': 'test_entry',
        'name': 'Test Plate',
        'portionSize': 314.3,
        'portionUnit': 'g',
        'mealType': 'akşam',
        'timestamp': DateTime.now().toIso8601String(),
        'nutritionData': {
          'calories': 225.0, // Scaled once: original (71.59) * 3.143
          'protein': 10.0,
          'carbohydrates': 20.0,
          'fat': 5.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'saturatedFat': 0.0,
        }
      };

      final data = {
        'id': '2026-07-30',
        'date': '2026-07-30T00:00:00.000Z',
        'entries': [oldEntryMap],
      };

      // Run our preprocessing logic
      if (data['entries'] != null) {
        final entriesList = List<dynamic>.from(data['entries'] as List);
        for (var i = 0; i < entriesList.length; i++) {
          final entryMap = Map<String, dynamic>.from(entriesList[i] as Map);
          final portionSize = (entryMap['portionSize'] as num?)?.toDouble() ?? 100.0;
          final factor = portionSize / 100.0;

          if (factor > 0 && factor != 1.0) {
            if (!entryMap.containsKey('nutritionDataScaled')) {
              final nutritionJson = entryMap['nutritionData'] as Map<String, dynamic>?;
              if (nutritionJson != null) {
                var currentND = NutritionData.fromJson(nutritionJson);
                currentND = currentND.scaleBy(1.0 / factor);
                while ((currentND.calories * factor) > 1000.0) {
                  currentND = currentND.scaleBy(1.0 / factor);
                }
                entryMap['nutritionData'] = currentND.toStructuredJson();
              }
            }
          }
          entriesList[i] = entryMap;
        }
        data['entries'] = entriesList;
      }

      // Parse with DailyLog
      final cloudLog = DailyLog.fromJson(data);
      expect(cloudLog.entries.length, 1);
      
      final repairedEntry = cloudLog.entries.first;
      // Per 100g calories should be unscaled to ~71.59
      expect(repairedEntry.nutritionData.calories, closeTo(71.59, 0.1));
      
      // Portioned total calories should be ~225
      expect(cloudLog.totalNutrition.calories, closeTo(225.0, 0.1));
    });

    test('Should repair multiple-scaled (corrupted) entry safely', () {
      // Simulate Firestore log document data that got corrupted (scaled 4 times)
      // Portion size = 314.3g (factor = 3.143)
      // Stored calories: 6984.8 kcal (representing a 21973 kcal portion displayed)
      final corruptedEntryMap = {
        'id': 'corrupted_entry',
        'name': 'Corrupted Plate',
        'portionSize': 314.3,
        'portionUnit': 'g',
        'mealType': 'akşam',
        'timestamp': DateTime.now().toIso8601String(),
        'nutritionData': {
          'calories': 6984.8, // Corrupted: original (71.59) * 3.143^4
          'protein': 310.0,
          'carbohydrates': 620.0,
          'fat': 155.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'saturatedFat': 0.0,
        }
      };

      final data = {
        'id': '2026-07-30',
        'date': '2026-07-30T00:00:00.000Z',
        'entries': [corruptedEntryMap],
      };

      // Run our preprocessing logic
      if (data['entries'] != null) {
        final entriesList = List<dynamic>.from(data['entries'] as List);
        for (var i = 0; i < entriesList.length; i++) {
          final entryMap = Map<String, dynamic>.from(entriesList[i] as Map);
          final portionSize = (entryMap['portionSize'] as num?)?.toDouble() ?? 100.0;
          final factor = portionSize / 100.0;

          if (factor > 0 && factor != 1.0) {
            if (!entryMap.containsKey('nutritionDataScaled')) {
              final nutritionJson = entryMap['nutritionData'] as Map<String, dynamic>?;
              if (nutritionJson != null) {
                var currentND = NutritionData.fromJson(nutritionJson);
                currentND = currentND.scaleBy(1.0 / factor);
                while ((currentND.calories * factor) > 1000.0) {
                  currentND = currentND.scaleBy(1.0 / factor);
                }
                entryMap['nutritionData'] = currentND.toStructuredJson();
              }
            }
          }
          entriesList[i] = entryMap;
        }
        data['entries'] = entriesList;
      }

      // Parse with DailyLog
      final cloudLog = DailyLog.fromJson(data);
      expect(cloudLog.entries.length, 1);
      
      final repairedEntry = cloudLog.entries.first;
      // Should be successfully unscaled back to a realistic per-100g calorie density (~224.96 kcal)
      expect(repairedEntry.nutritionData.calories, closeTo(224.96, 0.1));
      
      // Portioned total calories should be restored to ~707 kcal
      expect(cloudLog.totalNutrition.calories, closeTo(707.0, 1.0));
    });
  });
}
