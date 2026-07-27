import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/daily_log.dart';
import '../models/wellness_log.dart';
import '../providers/profile_provider.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data_65.dart';

class ReportGeneratorService {
  static Future<String> generateAndUploadReport({
    required UserProfile profile,
    required Map<String, DailyLog> dailyLogs,
    required Map<String, WellnessLog> wellnessLogs,
    required List<String> supplements,
  }) async {
    // 1. Generate HTML string
    final htmlContent = _buildHtml(profile, dailyLogs, wellnessLogs, supplements);

    // 2. Upload to Pagedrop
    return await uploadToPagedrop(htmlContent);
  }

  static Future<String> uploadToPagedrop(String htmlContent) async {
    final url = Uri.parse('https://pagedrop.io/api/upload');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'html': htmlContent,
        'ttl': '1d', // Expiry in 1 day
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final shareUrl = data['data']?['url'] as String?;
      if (shareUrl != null && shareUrl.isNotEmpty) {
        return shareUrl;
      } else {
        throw Exception('Invalid response format from PageDrop: ${response.body}');
      }
    } else {
      throw Exception('PageDrop upload failed with status ${response.statusCode}: ${response.body}');
    }
  }

  static String _buildHtml(
    UserProfile profile,
    Map<String, DailyLog> dailyLogs,
    Map<String, WellnessLog> wellnessLogs,
    List<String> supplements,
  ) {
    final now = DateTime.now();
    final dateList = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
    
    // Calculate averages and summaries
    double totalCalories = 0;
    int caloriesLoggedDays = 0;
    double totalWater = 0;
    int waterLoggedDays = 0;
    int totalSteps = 0;
    int stepsLoggedDays = 0;
    double totalSleep = 0;
    int sleepLoggedDays = 0;

    int totalWcEntries = 0;
    final allSymptoms = <String>{};

    final dailyRowsHtml = StringBuffer();
    final calorieChartHtml = StringBuffer();
    final stepsChartHtml = StringBuffer();

    // 30 days log in reverse order (newest to oldest)
    final tableDates = dateList.reversed.toList();

    for (final date in dateList) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dailyLog = dailyLogs[dateKey];
      final wellnessLog = wellnessLogs[dateKey];

      final cal = dailyLog?.totalNutrition.calories ?? 0;
      final water = dailyLog?.waterIntakeMl ?? 0;
      final steps = dailyLog?.stepsCount ?? 0;
      final sleep = wellnessLog?.sleepScore ?? 0;

      if (cal > 0) {
        totalCalories += cal;
        caloriesLoggedDays++;
      }
      if (water > 0) {
        totalWater += water;
        waterLoggedDays++;
      }
      if (steps > 0) {
        totalSteps += steps;
        stepsLoggedDays++;
      }
      if (sleep > 0) {
        totalSleep += sleep;
        sleepLoggedDays++;
      }

      if (wellnessLog != null) {
        totalWcEntries += wellnessLog.wcEntries.length;
        allSymptoms.addAll(wellnessLog.symptoms);
      }
    }

    // Build table rows in reverse chronological order (newest to oldest)
    for (final date in tableDates) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dailyLog = dailyLogs[dateKey];
      final wellnessLog = wellnessLogs[dateKey];

      final cal = dailyLog?.totalNutrition.calories ?? 0;
      final dateStr = DateFormat('d MMM yyyy', 'tr').format(date);
      final dayName = DateFormat('EEEE', 'tr').format(date);
      final sleep = wellnessLog?.sleepScore ?? 0;

      // Burned calories includes baseline BMR + active calories from exercises
      final burned = profile.bmr + (dailyLog?.exercises.fold<double>(0.0, (sum, e) => sum + e.burnedCalories) ?? 0.0);
      final wcCount = wellnessLog?.wcEntries.length ?? 0;
      final wcText = wcCount > 0 ? '$wcCount kez' : '-';
      final symptomsText = (wellnessLog?.symptoms != null && wellnessLog!.symptoms.isNotEmpty) 
          ? wellnessLog.symptoms.join(', ') 
          : '-';

      dailyRowsHtml.write('''
        <tr class="log-row">
          <td>
            <div class="date-main">$dateStr</div>
            <div class="date-sub">$dayName</div>
          </td>
          <td>${cal > 0 ? '${cal.toStringAsFixed(0)} kcal' : '<span class="empty-val">-</span>'}</td>
          <td>${burned > 0 ? '${burned.toStringAsFixed(0)} kcal' : '<span class="empty-val">-</span>'}</td>
          <td>${wcText != '-' ? wcText : '<span class="empty-val">-</span>'}</td>
          <td style="max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="$symptomsText">
            ${symptomsText != '-' ? symptomsText : '<span class="empty-val">-</span>'}
          </td>
          <td>${sleep > 0 ? '⭐️ $sleep/5' : '<span class="empty-val">-</span>'}</td>
        </tr>
      ''');
    }

    final avgCal = caloriesLoggedDays > 0 ? totalCalories / caloriesLoggedDays : 0;
    final avgWater = waterLoggedDays > 0 ? totalWater / waterLoggedDays : 0;
    final avgSteps = stepsLoggedDays > 0 ? totalSteps / stepsLoggedDays : 0;
    final avgSleep = sleepLoggedDays > 0 ? totalSleep / sleepLoggedDays : 0;

    // Generate recent 7 days chart elements
    final recent7Days = dateList.sublist(23); // Last 7 days
    double maxCalIn7Days = 2000;
    int maxStepsIn7Days = 10000;

    for (final date in recent7Days) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final log = dailyLogs[dateKey];
      final cal = log?.totalNutrition.calories ?? 0;
      final steps = log?.stepsCount ?? 0;
      if (cal > maxCalIn7Days) maxCalIn7Days = cal;
      if (steps > maxStepsIn7Days) maxStepsIn7Days = steps;
    }

    for (final date in recent7Days) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final log = dailyLogs[dateKey];
      final cal = log?.totalNutrition.calories ?? 0;
      final steps = log?.stepsCount ?? 0;
      final dayName = DateFormat('E', 'tr').format(date);

      final calPct = (cal / maxCalIn7Days * 100).clamp(5.0, 100.0);
      final stepsPct = (steps / maxStepsIn7Days * 100).clamp(5.0, 100.0);

      calorieChartHtml.write('''
        <div class="chart-bar-container">
          <div class="chart-bar-wrapper">
            <div class="chart-bar-fill" style="height: $calPct%;" data-value="${cal.toStringAsFixed(0)} kcal"></div>
          </div>
          <div class="chart-bar-label">$dayName</div>
        </div>
      ''');

      stepsChartHtml.write('''
        <div class="chart-bar-container">
          <div class="chart-bar-wrapper">
            <div class="chart-bar-fill steps-bar" style="height: $stepsPct%;" data-value="${NumberFormat('#,###', 'tr').format(steps)}"></div>
          </div>
          <div class="chart-bar-label">$dayName</div>
        </div>
      ''');
    }

    // Advanced Info calculations
    final bmi = profile.bmi;
    String bmiStatus = 'Normal';
    String bmiColor = '#34C759';
    if (bmi < 18.5) {
      bmiStatus = 'Zayıf';
      bmiColor = '#5856D6';
    } else if (bmi >= 25 && bmi < 30) {
      bmiStatus = 'Fazla Kilolu';
      bmiColor = '#FF9500';
    } else if (bmi >= 30) {
      bmiStatus = 'Obez';
      bmiColor = '#FF3B30';
    }

    // Dietary preferences HTML
    final dietaryHtml = StringBuffer();
    if (profile.dietaryPreferences.isNotEmpty) {
      dietaryHtml.write('''
      <div class="card">
        <div class="card-title">🥗 Gıda Hassasiyetleri & Beslenme Tercihleri</div>
        <div class="pill-list">
      ''');
      for (final pref in profile.dietaryPreferences) {
        dietaryHtml.write('<span class="pill">$pref</span>');
      }
      dietaryHtml.write('''
        </div>
      </div>
      ''');
    }

    // Health conditions HTML
    final healthHtml = StringBuffer();
    if (profile.healthConditions.isNotEmpty) {
      healthHtml.write('''
      <div class="card">
        <div class="card-title">⚠️ Hastalıklar & Sağlık Koşulları</div>
        <div class="pill-list">
      ''');
      for (final cond in profile.healthConditions) {
        healthHtml.write('<span class="pill red">$cond</span>');
      }
      healthHtml.write('''
        </div>
      </div>
      ''');
    }

    // Supplements HTML
    final supplementsHtml = StringBuffer();
    if (supplements.isNotEmpty) {
      supplementsHtml.write('''
      <div class="card">
        <div class="card-title">💊 Düzenli Kullanılan Takviyeler</div>
        <div class="pill-list">
      ''');
      for (final supp in supplements) {
        supplementsHtml.write('<span class="pill purple">$supp</span>');
      }
      supplementsHtml.write('''
        </div>
      </div>
      ''');
    }

    final genderLabel = profile.gender == Gender.male ? 'Erkek' : profile.gender == Gender.female ? 'Kadın' : 'Diğer';

    // 30 days food entries day by day with nested accordion (Day -> Meal -> Food)
    final nutritionDaysHtml = StringBuffer();
    for (final date in tableDates) {
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final log = dailyLogs[dateKey];
      if (log == null || log.entries.isEmpty) continue;

      final dateStr = DateFormat('d MMM yyyy', 'tr').format(date);
      final dayName = DateFormat('EEEE', 'tr').format(date);
      final totalDayCal = log.totalNutrition.calories;

      nutritionDaysHtml.write('''
      <div class="day-nutrition-card card" style="padding: 0; overflow: hidden; border-radius: 20px;">
        <div class="day-accordion-header" onclick="toggleDay('day-$dateKey')" style="display: flex; justify-content: space-between; align-items: center; padding: 18px 24px; cursor: pointer; user-select: none; background: var(--card-bg);">
          <div>
            <div style="font-size: 16px; font-weight: 700; color: var(--text-main);">$dateStr</div>
            <div style="font-size: 11px; color: var(--text-sub); margin-top: 2px;">$dayName</div>
          </div>
          <div style="display: flex; align-items: center; gap: 12px;">
            <div style="font-size: 16px; font-weight: 700; color: var(--primary);">
              ${totalDayCal.toStringAsFixed(0)} kcal
            </div>
            <span class="expand-icon" id="icon-day-$dateKey" style="font-size: 10px; color: var(--text-sub); transition: transform 0.2s ease;">▼</span>
          </div>
        </div>
        <div class="day-accordion-content" id="day-$dateKey" style="display: none; padding: 16px 24px; border-top: 1px solid var(--divider); background: rgba(0,0,0,0.005);">
      ''');

      // 4 meals:
      final breakfastEntries = log.entries.where((e) {
        final m = e.mealType.toLowerCase();
        return m == 'kahvaltı' || m == 'breakfast';
      }).toList();

      final lunchEntries = log.entries.where((e) {
        final m = e.mealType.toLowerCase();
        return m == 'öğle' || m == 'lunch' || m == 'öğle yemeği';
      }).toList();

      final dinnerEntries = log.entries.where((e) {
        final m = e.mealType.toLowerCase();
        return m == 'akşam' || m == 'dinner' || m == 'akşam yemeği';
      }).toList();

      final snackEntries = log.entries.where((e) {
        final m = e.mealType.toLowerCase();
        return m == 'ara öğün' || m == 'ara' || m == 'snack' || m == 'atıştırmalık';
      }).toList();

      void writeMealSection(String mealId, String mealLabel, List<FoodEntry> entries) {
        nutritionDaysHtml.write('''
          <div class="meal-section" style="margin-bottom: 12px; border: 1px solid var(--card-border); border-radius: 14px; overflow: hidden; background: var(--card-bg);">
            <div class="meal-accordion-header" onclick="toggleMeal('meal-$dateKey-$mealId')" style="display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; cursor: pointer; user-select: none;">
              <span class="meal-title" style="font-size: 13px; font-weight: 700; color: var(--text-sub); text-transform: uppercase;">$mealLabel</span>
              <span class="expand-icon" id="icon-meal-$dateKey-$mealId" style="font-size: 9px; color: var(--text-sub); transition: transform 0.2s ease;">▼</span>
            </div>
            <div class="meal-accordion-content" id="meal-$dateKey-$mealId" style="display: none; padding: 12px 16px; border-top: 1px solid var(--divider); background: rgba(0,0,0,0.003);">
        ''');

        if (entries.isEmpty) {
          nutritionDaysHtml.write('''
            <div class="empty-meal" style="font-size: 12px; color: var(--text-sub); opacity: 0.6; padding: 4px 0;">Bu öğün için giriş yapılmadı</div>
          ''');
        } else {
          for (final entry in entries) {
            final scaled = entry.nutritionData.scaleBy(entry.portionSize / 100);
            final scaled65 = (entry.nutrition65per100g ?? entry.nutritionData.to65()).scaleBy(entry.portionSize / 100);

            final Map<String, String> allEntries = {};
            
            void addIfValid(String label, double? value, String unit) {
              if (value != null && value > 0.001) {
                String formattedVal = value.toStringAsFixed(value < 0.1 ? 3 : (value < 1 ? 2 : 1));
                if (formattedVal.endsWith('.0')) {
                  formattedVal = formattedVal.substring(0, formattedVal.length - 2);
                }
                allEntries[label] = '$formattedVal $unit';
              }
            }

            // Yağlar & Kolesterol
            addIfValid('Tekli Doymamış Yağ', scaled.monoFat ?? scaled65.monoFat, 'g');
            addIfValid('Çoklu Doymamış Yağ', scaled.polyFat ?? scaled65.polyFat, 'g');
            addIfValid('Trans Yağ', scaled.transFat ?? scaled65.transFat, 'g');
            addIfValid('Kolesterol', scaled.cholesterol ?? scaled65.cholesterol, 'mg');

            // Mineraller
            addIfValid('Selenyum', scaled.selenium ?? scaled65.selenium, 'µg');
            addIfValid('Magnezyum', scaled.magnesium ?? scaled65.magnesium, 'mg');
            addIfValid('Demir', scaled.iron ?? scaled65.iron, 'mg');
            addIfValid('Çinko', scaled.zinc ?? scaled65.zinc, 'mg');
            addIfValid('Kalsiyum', scaled.calcium ?? scaled65.calcium, 'mg');
            addIfValid('Potasyum', scaled.potassium ?? scaled65.potassium, 'mg');
            addIfValid('Fosfor', scaled.phosphorus ?? scaled65.phosphorus, 'mg');
            addIfValid('Bakır', scaled.copper ?? scaled65.copper, 'mg');
            addIfValid('Manganez', scaled.manganese ?? scaled65.manganese, 'mg');
            addIfValid('İyot', scaled65.iodine, 'µg');
            addIfValid('Krom', scaled65.chromium, 'µg');
            addIfValid('Molibden', scaled65.molybdenum, 'µg');
            addIfValid('Florür', scaled65.fluoride, 'µg');

            // Vitaminler
            addIfValid('A Vitamini', scaled.vitaminA ?? scaled65.vitA_RAE, 'µg RAE');
            addIfValid('C Vitamini', scaled.vitaminC ?? scaled65.vitC, 'mg');
            addIfValid('D Vitamini', scaled.vitaminD ?? scaled65.vitD_mcg, 'µg');
            addIfValid('E Vitamini', scaled.vitaminE ?? scaled65.vitE, 'mg');
            addIfValid('K Vitamini', scaled.vitaminK ?? scaled65.vitK, 'µg');
            addIfValid('B12 Vitamini', scaled.vitaminB12 ?? scaled65.vitB12, 'µg');
            addIfValid('B1 Vitamini (Tiamin)', scaled.thiamine ?? scaled65.thiamine, 'mg');
            addIfValid('B2 Vitamini (Riboflavin)', scaled.riboflavin ?? scaled65.riboflavin, 'mg');
            addIfValid('B3 Vitamini (Niasin)', scaled.niacin ?? scaled65.niacin, 'mg');
            addIfValid('B5 Vitamini (Pantotenik)', scaled.pantothenic ?? scaled65.pantothenic, 'mg');
            addIfValid('B6 Vitamini', scaled.vitaminB6 ?? scaled65.vitB6, 'mg');
            addIfValid('Folat', scaled.folate ?? scaled65.folate, 'µg');
            addIfValid('Kolin', scaled.choline ?? scaled65.choline, 'mg');
            addIfValid('Biyotin', scaled.biotin ?? scaled65.biotin, 'µg');

            // Yağ Asitleri
            addIfValid('Omega-3', scaled.omega3 ?? scaled65.omega3, 'g');
            addIfValid('Omega-6', scaled.omega6 ?? scaled65.omega6, 'g');
            addIfValid('ALA', scaled.ala ?? scaled65.ala, 'g');
            addIfValid('EPA', scaled.epa ?? scaled65.epa, 'g');
            addIfValid('DHA', scaled.dha ?? scaled65.dha, 'g');

            // Amino Asitler
            addIfValid('Triptofan', scaled.tryptophan ?? scaled65.tryptophan, 'g');
            addIfValid('Treonin', scaled.threonine ?? scaled65.threonine, 'g');
            addIfValid('İzolösin', scaled.isoleucine ?? scaled65.isoleucine, 'g');
            addIfValid('Lösin', scaled.leucine ?? scaled65.leucine, 'g');
            addIfValid('Lisin', scaled.lysine ?? scaled65.lysine, 'g');
            addIfValid('Metiyonin', scaled.methionine ?? scaled65.methionine, 'g');
            addIfValid('Fenilalanin', scaled.phenylalanine ?? scaled65.phenylalanine, 'g');
            addIfValid('Valin', scaled.valine ?? scaled65.valine, 'g');
            addIfValid('Histidin', scaled.histidine ?? scaled65.histidine, 'g');

            // Karotenoidler
            addIfValid('Beta-Karoten', scaled.betaCarotene ?? scaled65.betaCarot, 'µg');
            addIfValid('Likopen', scaled.lycopene ?? scaled65.lycopene, 'µg');
            addIfValid('Lutein & Zeaksantin', scaled.luteinZeaxanthin ?? scaled65.luteinZea, 'µg');
            addIfValid('Alfa-Karoten', scaled.alphaCarotene ?? scaled65.alphaCarot, 'µg');

            final microHtml = StringBuffer();
            microHtml.write('<div class="nutr-chip macro"><strong>Karbonhidrat:</strong> ${scaled.carbohydrates.toStringAsFixed(1)} g</div>');
            microHtml.write('<div class="nutr-chip macro"><strong>Protein:</strong> ${scaled.protein.toStringAsFixed(1)} g</div>');
            microHtml.write('<div class="nutr-chip macro"><strong>Yağ:</strong> ${scaled.fat.toStringAsFixed(1)} g</div>');
            microHtml.write('<div class="nutr-chip fiber"><strong>Lif:</strong> ${scaled.fiber.toStringAsFixed(1)} g</div>');
            microHtml.write('<div class="nutr-chip"><strong>Şeker:</strong> ${scaled.sugar.toStringAsFixed(1)} g</div>');
            microHtml.write('<div class="nutr-chip"><strong>Sodyum:</strong> ${scaled.sodium != null ? "${scaled.sodium!.toStringAsFixed(0)} mg" : "-"}</div>');

            allEntries.forEach((label, valStr) {
              if (label != 'Karbonhidrat' && label != 'Protein' && label != 'Yağ' && label != 'Lif' && label != 'Şeker' && label != 'Sodyum') {
                microHtml.write('<div class="nutr-chip"><strong>$label:</strong> $valStr</div>');
              }
            });

            nutritionDaysHtml.write('''
            <div class="food-item">
              <div class="food-summary" onclick="toggleFoodDetails('food-${entry.id}')">
                <div class="food-info-left">
                  <span class="food-name">${entry.name}</span>
                  <span class="food-portion">${entry.portionSize.toStringAsFixed(0)} ${entry.portionUnit}</span>
                </div>
                <div class="food-info-right">
                  <span class="food-cal">${scaled.calories.toStringAsFixed(0)} kcal</span>
                  <span class="expand-icon" id="icon-food-${entry.id}">▼</span>
                </div>
              </div>
              <div class="food-details" id="food-${entry.id}" style="display: none;">
                <div class="nutrients-scroll-container">
                  $microHtml
                </div>
              </div>
            </div>
            ''');
          }
        }
        nutritionDaysHtml.write('</div></div>');
      }

      writeMealSection('breakfast', 'Kahvaltı', breakfastEntries);
      writeMealSection('lunch', 'Öğle Yemeği', lunchEntries);
      writeMealSection('dinner', 'Akşam Yemeği', dinnerEntries);
      writeMealSection('snack', 'Ara Öğün / Atıştırmalık', snackEntries);

      nutritionDaysHtml.write('</div></div>');
    }

    final hasOnlineAvatar = profile.imagePath != null && profile.imagePath!.startsWith('http');
    final avatarHtml = hasOnlineAvatar 
        ? '<img class="profile-avatar-img" src="${profile.imagePath}" alt="Avatar" />'
        : '';

    return '''<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LensEat Sağlık Raporu - ${profile.name}</title>
  <style>
    :root {
      --bg-color: #F6F8FA;
      --card-bg: rgba(255, 255, 255, 0.85);
      --card-border: rgba(0, 0, 0, 0.08);
      --text-main: #1D1D1F;
      --text-sub: #86868B;
      --primary: #007AFF;
      --primary-light: rgba(0, 122, 255, 0.1);
      --green: #34C759;
      --green-light: rgba(52, 199, 89, 0.1);
      --orange: #FF9500;
      --red: #FF3B30;
      --divider: rgba(0, 0, 0, 0.05);
      --font-stack: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Icons", "Helvetica Neue", Helvetica, Arial, sans-serif;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg-color: #0D1117;
        --card-bg: rgba(22, 27, 34, 0.85);
        --card-border: rgba(255, 255, 255, 0.08);
        --text-main: #E6EDF3;
        --text-sub: #8B949E;
        --divider: rgba(255, 255, 255, 0.08);
        --primary-light: rgba(88, 166, 255, 0.15);
      }
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: var(--font-stack);
      background-color: var(--bg-color);
      color: var(--text-main);
      -webkit-font-smoothing: antialiased;
      padding-bottom: 60px;
      line-height: 1.4;
    }

    /* Wave Background styling */
    .wave-bg {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      z-index: -1;
      pointer-events: none;
      overflow: hidden;
    }

    .wave-bg svg {
      position: absolute;
      left: 0;
      width: 100%;
      height: 320px;
    }

    /* Hide PageDrop watermark / badge / expiration timer */
    [class*="pagedrop"], [id*="pagedrop"],
    [class*="pd-"], [id*="pd-"],
    .pagedrop-badge, .pagedrop-logo, .pagedrop-watermark,
    .pd-badge, .pd-watermark, .pd-expiration {
      display: none !important;
      opacity: 0 !important;
      visibility: hidden !important;
      pointer-events: none !important;
      height: 0 !important;
      width: 0 !important;
    }

    .container {
      max-width: 900px;
      margin: 0 auto;
      padding: 20px;
    }

    /* Cupertino Navigation Bar */
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 20px 0;
      margin-bottom: 24px;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .brand-title {
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -0.5px;
    }

    .print-btn {
      background-color: var(--primary-light);
      color: var(--primary);
      border: none;
      padding: 10px 18px;
      border-radius: 20px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s ease;
    }

    .print-btn:hover {
      opacity: 0.8;
      transform: scale(0.98);
    }

    /* User Profile Card */
    .profile-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border-radius: 24px;
      padding: 24px;
      display: flex;
      gap: 24px;
      align-items: center;
      margin-bottom: 28px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.04);
    }

    .profile-avatar-img {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      object-fit: cover;
      border: 2px solid var(--primary);
    }

    .profile-info {
      flex: 1;
    }

    .profile-name {
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.5px;
      margin-bottom: 4px;
    }

    .profile-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px 16px;
      color: var(--text-sub);
      font-size: 14px;
    }

    .profile-badge {
      background-color: var(--divider);
      color: var(--text-main);
      padding: 4px 10px;
      border-radius: 12px;
      font-weight: 500;
      font-size: 12px;
    }

    /* Segmented Control (Tabs) */
    .segmented-control {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      padding: 4px;
      border-radius: 16px;
      display: flex;
      margin-bottom: 28px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.02);
    }

    .tab-btn {
      flex: 1;
      border: none;
      background: none;
      padding: 10px;
      border-radius: 12px;
      font-size: 14px;
      font-weight: 600;
      color: var(--text-sub);
      cursor: pointer;
      transition: all 0.25s ease;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }

    .tab-btn.active {
      background: #FFFFFF;
      color: #000000;
      box-shadow: 0 3px 8px rgba(0, 0, 0, 0.08);
    }

    @media (prefers-color-scheme: dark) {
      .tab-btn.active {
        background: rgba(255, 255, 255, 0.15);
        color: #FFFFFF;
        box-shadow: none;
      }
    }

    /* Tab Content panels */
    .tab-content {
      display: none;
      animation: fadeIn 0.4s ease;
    }

    .tab-content.active {
      display: block;
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(6px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* Metrics Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 16px;
      margin-bottom: 28px;
    }

    @media (min-width: 600px) {
      .metrics-grid {
        grid-template-columns: repeat(4, 1fr);
      }
    }

    .metric-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 20px;
      text-align: center;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.02);
    }

    .metric-icon {
      font-size: 24px;
      margin-bottom: 8px;
    }

    .metric-value {
      font-size: 20px;
      font-weight: 700;
      margin-bottom: 4px;
    }

    .metric-label {
      font-size: 12px;
      color: var(--text-sub);
      font-weight: 500;
    }

    /* Cards */
    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 24px;
      padding: 24px;
      margin-bottom: 24px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.03);
    }

    .card-title {
      font-size: 18px;
      font-weight: 700;
      letter-spacing: -0.3px;
      margin-bottom: 18px;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    /* Detail Grid Layout */
    .detail-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: 20px;
    }

    @media (min-width: 700px) {
      .detail-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }

    .info-row {
      display: flex;
      justify-content: space-between;
      padding: 12px 0;
      border-bottom: 1px solid var(--divider);
    }

    .info-row:last-child {
      border-bottom: none;
    }

    .info-label {
      color: var(--text-sub);
      font-weight: 500;
      font-size: 14px;
    }

    .info-value {
      font-weight: 600;
      font-size: 14px;
    }

    /* Charts (Apple Bar style with lines and Y-axis limits) */
    .chart-wrapper {
      display: flex;
      align-items: stretch;
      height: 180px;
      margin-top: 15px;
      position: relative;
    }

    .chart-y-axis {
      width: 60px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      align-items: flex-end;
      padding-right: 8px;
      font-size: 10px;
      color: var(--text-sub);
      font-weight: 550;
      height: 150px;
      margin-top: 5px;
    }

    .chart-container-outer {
      flex: 1;
      position: relative;
      height: 100%;
    }

    .chart-grid-lines {
      position: absolute;
      top: 5px;
      left: 0;
      width: 100%;
      height: 150px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      pointer-events: none;
      z-index: 1;
    }

    .grid-line {
      width: 100%;
      border-bottom: 1px dashed var(--divider);
      height: 0;
    }

    .chart-container {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      height: 175px;
      position: relative;
      z-index: 2;
    }

    .chart-bar-container {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      height: 100%;
      position: relative;
    }

    .chart-bar-wrapper {
      flex: 1;
      width: 100%;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      height: calc(100% - 25px);
    }

    .chart-bar-fill {
      width: 14px;
      background-color: var(--primary);
      border-radius: 7px 7px 0 0;
      cursor: pointer;
      position: relative;
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .chart-bar-fill.steps-bar {
      background-color: var(--green);
    }

    .chart-bar-fill:hover {
      opacity: 0.85;
    }

    .chart-bar-fill::after {
      content: attr(data-value);
      position: absolute;
      top: -30px;
      left: 50%;
      transform: translateX(-50%) scale(0.9);
      background: rgba(0,0,0,0.8);
      color: white;
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 10px;
      white-space: nowrap;
      opacity: 0;
      pointer-events: none;
      transition: all 0.2s ease;
    }

    @media (prefers-color-scheme: dark) {
      .chart-bar-fill::after {
        background: rgba(255,255,255,0.95);
        color: black;
      }
    }

    .chart-bar-fill:hover::after {
      opacity: 1;
      transform: translateX(-50%) scale(1);
    }

    .chart-bar-label {
      font-size: 11px;
      color: var(--text-sub);
      margin-top: 8px;
      font-weight: 500;
    }

    /* Logs Table */
    .table-container {
      overflow-x: auto;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }

    th {
      padding: 12px 16px;
      color: var(--text-sub);
      font-weight: 600;
      font-size: 13px;
      border-bottom: 1px solid var(--divider);
    }

    td {
      padding: 16px;
      font-size: 14px;
      border-bottom: 1px solid var(--divider);
    }

    .log-row:hover {
      background-color: var(--divider);
    }

    .date-main {
      font-weight: 600;
    }

    .date-sub {
      font-size: 11px;
      color: var(--text-sub);
      margin-top: 2px;
    }

    .empty-val {
      color: var(--text-sub);
      opacity: 0.4;
    }

    /* Lists of Preferences & Conditions */
    .pill-list {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 8px;
    }

    .pill {
      background-color: var(--primary-light);
      color: var(--primary);
      padding: 6px 12px;
      border-radius: 14px;
      font-size: 13px;
      font-weight: 550;
    }

    .pill.red {
      background-color: rgba(255, 59, 48, 0.1);
      color: var(--red);
    }

    .pill.purple {
      background-color: rgba(175, 82, 222, 0.1);
      color: #AF52DE;
    }

    /* BMI Meter */
    .bmi-container {
      margin-top: 14px;
    }

    .bmi-bar-wrapper {
      height: 6px;
      background: linear-gradient(to right, #5856D6, #34C759, #FF9500, #FF3B30);
      border-radius: 3px;
      position: relative;
      margin: 16px 0 8px 0;
    }

    .bmi-indicator {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background-color: var(--text-main);
      border: 2px solid var(--card-bg);
      position: absolute;
      top: -3px;
      transform: translateX(-50%);
      transition: left 0.5s ease;
    }

    /* Food accordion styles */
    .food-item {
      background: var(--bg-color);
      border-radius: 12px;
      margin-bottom: 8px;
      border: 1px solid var(--card-border);
      overflow: hidden;
    }

    .food-summary {
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      cursor: pointer;
      user-select: none;
    }

    .food-summary:hover {
      background-color: var(--divider);
    }

    .food-info-left {
      display: flex;
      flex-direction: column;
    }

    .food-name {
      font-weight: 600;
      font-size: 14px;
    }

    .food-portion {
      font-size: 11px;
      color: var(--text-sub);
      margin-top: 2px;
    }

    .food-info-right {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .food-cal {
      font-weight: 600;
      font-size: 14px;
    }

    .expand-icon {
      font-size: 10px;
      color: var(--text-sub);
      transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      display: inline-block;
    }

    .food-details {
      padding: 12px 16px;
      border-top: 1px solid var(--divider);
      background: rgba(0,0,0,0.01);
    }

    @media (prefers-color-scheme: dark) {
      .food-details {
        background: rgba(255,255,255,0.01);
      }
    }

    .nutrients-scroll-container {
      display: flex;
      overflow-x: auto;
      gap: 8px;
      padding-bottom: 8px;
      scrollbar-width: thin;
      -webkit-overflow-scrolling: touch;
    }

    .nutrients-scroll-container::-webkit-scrollbar {
      height: 4px;
    }

    .nutrients-scroll-container::-webkit-scrollbar-track {
      background: transparent;
    }

    .nutrients-scroll-container::-webkit-scrollbar-thumb {
      background: var(--divider);
      border-radius: 2px;
    }

    .nutr-chip {
      flex: 0 0 auto;
      background: var(--bg-color);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 6px 12px;
      font-size: 11px;
      font-weight: 550;
      color: var(--text-main);
      display: flex;
      align-items: center;
      gap: 4px;
    }

    .nutr-chip.macro {
      border-color: var(--primary-light);
      background: var(--primary-light);
      color: var(--primary);
    }

    .nutr-chip.fiber {
      border-color: var(--primary-light);
      background: var(--primary-light);
      color: var(--primary);
      font-weight: 700;
    }

    @media (prefers-color-scheme: dark) {
      .nutr-chip.macro, .nutr-chip.fiber {
        color: #58A6FF;
      }
    }

    @media print {
      body {
        background-color: white;
        color: black;
      }
      .print-btn, .segmented-control, .wave-bg {
        display: none !important;
      }
      .tab-content {
        display: block !important;
        margin-bottom: 40px;
        page-break-inside: avoid;
      }
      .profile-card, .card, .metric-card {
        background: white !important;
        border: 1px solid #ddd !important;
        box-shadow: none !important;
      }
    }
  </style>
</head>
<body>

  <div class="wave-bg">
    <svg viewBox="0 0 1440 320" preserveAspectRatio="none">
      <path fill="rgba(88, 166, 255, 0.04)" d="M0,96L48,112C96,128,192,160,288,186.7C384,213,480,235,576,218.7C672,203,768,149,864,138.7C960,128,1056,160,1152,165.3C1248,171,1344,149,1392,138.7L1440,128L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"></path>
    </svg>
    <svg viewBox="0 0 1440 320" preserveAspectRatio="none" style="top: 250px;">
      <path fill="rgba(126, 231, 135, 0.03)" d="M0,192L48,197.3C96,203,192,213,288,202.7C384,192,480,160,576,149.3C672,139,768,149,864,165.3C960,181,1056,203,1152,192C1248,181,1344,139,1392,117.3L1440,96L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"></path>
    </svg>
    <svg viewBox="0 0 1440 320" preserveAspectRatio="none" style="top: 550px;">
      <path fill="rgba(88, 166, 255, 0.03)" d="M0,64L48,80C96,96,192,128,288,122.7C384,117,480,75,576,85.3C672,96,768,160,864,186.7C960,213,1056,203,1152,176C1248,149,1344,107,1392,85.3L1440,64L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z"></path>
    </svg>
  </div>

  <div class="container">
    <header>
      <div class="brand">
        <div class="brand-title">LensEat</div>
      </div>
    </header>

    <!-- User Profile Header -->
    <div class="profile-card">
      $avatarHtml
      <div class="profile-info">
        <div class="profile-name">${profile.name}</div>
        <div class="profile-meta">
          <span>Yaş: <strong>${profile.age}</strong></span>
          <span>Boy: <strong>${profile.height.toStringAsFixed(0)} cm</strong></span>
          <span>Kilo: <strong>${profile.weight.toStringAsFixed(1)} kg</strong></span>
          <span class="profile-badge">$genderLabel</span>
        </div>
      </div>
    </div>

    <!-- Segmented Tab Bar -->
    <div class="segmented-control">
      <button class="tab-btn active" onclick="showTab('tab-dashboard')">📊 Özet</button>
      <button class="tab-btn" onclick="showTab('tab-nutrition')">🥗 Beslenme</button>
      <button class="tab-btn" onclick="showTab('tab-wellness')">🛌 Sağlık</button>
      <button class="tab-btn" onclick="showTab('tab-profile')">👤 Profil</button>
    </div>

    <!-- Tab 1: Dashboard -->
    <div id="tab-dashboard" class="tab-content active">
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-icon">🔥</div>
          <div class="metric-value">${avgCal.toStringAsFixed(0)}</div>
          <div class="metric-label">Ort. Alınan Kalori (kcal)</div>
        </div>
        <div class="metric-card">
          <div class="metric-icon">💧</div>
          <div class="metric-value">${avgWater.toStringAsFixed(0)}</div>
          <div class="metric-label">Ort. Su (ml)</div>
        </div>
        <div class="metric-card">
          <div class="metric-icon">🏃</div>
          <div class="metric-value">${NumberFormat('#,###', 'tr').format(avgSteps)}</div>
          <div class="metric-label">Ort. Adım</div>
        </div>
        <div class="metric-card">
          <div class="metric-icon">⭐️</div>
          <div class="metric-value">${avgSleep > 0 ? '${avgSleep.toStringAsFixed(1)}/5' : '-'}</div>
          <div class="metric-label">Ort. Uyku Puanı</div>
        </div>
      </div>

      <div class="detail-grid">
        <div class="card">
          <div class="card-title">🔥 Kalori Tüketimi (Son 7 Gün)</div>
          <div class="chart-wrapper">
            <div class="chart-y-axis">
              <span>${maxCalIn7Days.toStringAsFixed(0)}</span>
              <span>${(maxCalIn7Days / 2).toStringAsFixed(0)}</span>
              <span>0</span>
            </div>
            <div class="chart-container-outer">
              <div class="chart-grid-lines">
                <div class="grid-line"></div>
                <div class="grid-line"></div>
                <div class="grid-line"></div>
              </div>
              <div class="chart-container">
                $calorieChartHtml
              </div>
            </div>
          </div>
        </div>
        <div class="card">
          <div class="card-title">👟 Adım Geçmişi (Son 7 Gün)</div>
          <div class="chart-wrapper">
            <div class="chart-y-axis">
              <span>${NumberFormat('#,###', 'tr').format(maxStepsIn7Days)}</span>
              <span>${NumberFormat('#,###', 'tr').format(maxStepsIn7Days ~/ 2)}</span>
              <span>0</span>
            </div>
            <div class="chart-container-outer">
              <div class="chart-grid-lines">
                <div class="grid-line"></div>
                <div class="grid-line"></div>
                <div class="grid-line"></div>
              </div>
              <div class="chart-container">
                $stepsChartHtml
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-title">🗓️ Son 30 Günlük Sağlık Günlüğü</div>
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Tarih</th>
                <th>Alınan Kalori</th>
                <th>Yakılan Kalori</th>
                <th>Tuvalet</th>
                <th>Semptomlar</th>
                <th>Uyku Puanı</th>
              </tr>
            </thead>
            <tbody>
              $dailyRowsHtml
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Tab 2: Nutrition -->
    <div id="tab-nutrition" class="tab-content">
      <div class="card">
        <div class="card-title">🥗 Beslenme Hedefleri ve Ortalamalar</div>
        <div class="detail-grid">
          <div>
            <div class="info-row">
              <span class="info-label">Günlük Kalori Hedefi</span>
              <span class="info-value">${profile.calorieGoal.toStringAsFixed(0)} kcal</span>
            </div>
            <div class="info-row">
              <span class="info-label">Ortalama Alınan Kalori</span>
              <span class="info-value">${avgCal.toStringAsFixed(0)} kcal</span>
            </div>
          </div>
          <div>
            <div class="info-row">
              <span class="info-label">Protein Hedefi</span>
              <span class="info-value">${profile.proteinGoal.toStringAsFixed(1)} g</span>
            </div>
            <div class="info-row">
              <span class="info-label">Yağ Hedefi</span>
              <span class="info-value">${profile.fatGoal.toStringAsFixed(1)} g</span>
            </div>
            <div class="info-row">
              <span class="info-label">Karbonhidrat Hedefi</span>
              <span class="info-value">${profile.carbGoal.toStringAsFixed(1)} g</span>
            </div>
            <div class="info-row">
              <span class="info-label">Lif Hedefi</span>
              <span class="info-value">${profile.fiberGoal.toStringAsFixed(1)} g</span>
            </div>
          </div>
        </div>
      </div>
      
      $nutritionDaysHtml
    </div>

    <!-- Tab 3: Wellness -->
    <div id="tab-wellness" class="tab-content">
      <div class="card">
        <div class="card-title">🛌 Sağlık & Yaşam Özeti</div>
        <div class="detail-grid">
          <div>
            <div class="info-row">
              <span class="info-label">Ortalama Uyku Kalitesi</span>
              <span class="info-value">${avgSleep > 0 ? '${avgSleep.toStringAsFixed(1)} / 5' : 'Veri Yok'}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Toplam Tuvalet Girdisi</span>
              <span class="info-value">$totalWcEntries kayıt</span>
            </div>
          </div>
          <div>
            <div class="info-row">
              <span class="info-label">Kaydedilen Semptomlar</span>
              <span class="info-value">${allSymptoms.isNotEmpty ? allSymptoms.join(', ') : 'Hiç semptom bildirilmedi'}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Tab 4: Profile Details -->
    <div id="tab-profile" class="tab-content">
      <div class="card">
        <div class="card-title">👤 Profil Detayları ve Hedefler</div>
        <div class="detail-grid">
          <div>
            <div class="info-row">
              <span class="info-label">Yaş / Cinsiyet</span>
              <span class="info-value">${profile.age} yaş / $genderLabel</span>
            </div>
            <div class="info-row">
              <span class="info-label">Boy / Kilo</span>
              <span class="info-value">${profile.height.toStringAsFixed(0)} cm / ${profile.weight.toStringAsFixed(1)} kg</span>
            </div>
            <div class="info-row">
              <span class="info-label">BMR (Bazal Metabolizma)</span>
              <span class="info-value">${profile.bmr.toStringAsFixed(0)} kcal</span>
            </div>
            <div class="info-row">
              <span class="info-label">TDEE (Günlük Enerji)</span>
              <span class="info-value">${profile.tdee.toStringAsFixed(0)} kcal</span>
            </div>
          </div>
          <div>
            <div class="info-row">
              <span class="info-label">Ana Hedef</span>
              <span class="info-value">${profile.goalLabel}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Aktivite Seviyesi</span>
              <span class="info-value">${profile.activityLabel}</span>
            </div>
            <div class="info-row">
              <span class="info-label">Başlangıç Kilosu</span>
              <span class="info-value">${profile.startingWeight.toStringAsFixed(1)} kg</span>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-title">⚖️ Vücut Kitle Endeksi (VKE / BMI)</div>
        <div class="bmi-container">
          <div class="info-row">
            <span class="info-label">BMI Değeri</span>
            <span class="info-value" style="color: $bmiColor; font-size: 18px; font-weight: 700;">${bmi.toStringAsFixed(1)} ($bmiStatus)</span>
          </div>
          <div class="bmi-bar-wrapper">
            <div class="bmi-indicator" style="left: ${((bmi - 15) / 20 * 100).clamp(5.0, 95.0)}%;"></div>
          </div>
        </div>
      </div>

      $healthHtml

      $dietaryHtml

      $supplementsHtml
    </div>

  </div>

  <script>
    function showTab(tabId) {
      document.querySelectorAll('.tab-content').forEach(el => {
        el.classList.remove('active');
      });
      document.querySelectorAll('.tab-btn').forEach(el => {
        el.classList.remove('active');
      });
      document.getElementById(tabId).classList.add('active');
      
      const buttons = document.querySelectorAll('.tab-btn');
      buttons.forEach(btn => {
        if (btn.getAttribute('onclick').includes(tabId)) {
          btn.classList.add('active');
        }
      });
    }

    function toggleDay(id) {
      const content = document.getElementById(id);
      const icon = document.getElementById('icon-' + id);
      if (content.style.display === 'none') {
        content.style.display = 'block';
        icon.style.transform = 'rotate(180deg)';
      } else {
        content.style.display = 'none';
        icon.style.transform = 'rotate(0deg)';
      }
    }

    function toggleMeal(id) {
      const content = document.getElementById(id);
      const icon = document.getElementById('icon-' + id);
      if (content.style.display === 'none') {
        content.style.display = 'block';
        icon.style.transform = 'rotate(180deg)';
      } else {
        content.style.display = 'none';
        icon.style.transform = 'rotate(0deg)';
      }
    }

    function toggleFoodDetails(id) {
      const details = document.getElementById(id);
      const icon = document.getElementById('icon-' + id);
      if (details.style.display === 'none') {
        details.style.display = 'block';
        icon.style.transform = 'rotate(180deg)';
      } else {
        details.style.display = 'none';
        icon.style.transform = 'rotate(0deg)';
      }
    }
  </script>
</body>
</html>
''';
  }
}
