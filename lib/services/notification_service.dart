import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _waterChannelId = 'water_reminder';
  static const String _mealChannelId = 'meal_reminder';
  static const String _summaryChannelId = 'daily_summary';
  static const String _goalChannelId = 'goal_reached';
  static const String _birthdayChannelId = 'birthday';
  static const String _weightChannelId = 'weight_reminder';

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await impl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  static Future<void> scheduleWaterReminder({
    required bool enabled,
    required bool breakfastEnabled,
    required TimeOfDay breakfastTime,
    required bool lunchEnabled,
    required TimeOfDay lunchTime,
    required bool dinnerEnabled,
    required TimeOfDay dinnerTime,
  }) async {
    try {
      for (var i = 100; i < 110; i++) {
        await _plugin.cancel(i);
      }
      if (!enabled) return;

      int id = 100;
      if (breakfastEnabled) {
        final targetHour = (breakfastTime.hour + 1) % 24;
        await _scheduleDailyNotification(
          id: id++,
          channelId: _waterChannelId,
          channelName: 'Su Hatırlatıcısı',
          title: '💧 Su İçme Zamanı!',
          body: 'Günde en az 8 bardak su içmeyi unutma!',
          hour: targetHour,
          minute: breakfastTime.minute,
        );
      }
      if (lunchEnabled) {
        final targetHour = (lunchTime.hour + 1) % 24;
        await _scheduleDailyNotification(
          id: id++,
          channelId: _waterChannelId,
          channelName: 'Su Hatırlatıcısı',
          title: '💧 Su İçme Zamanı!',
          body: 'Günde en az 8 bardak su içmeyi unutma!',
          hour: targetHour,
          minute: lunchTime.minute,
        );
      }
      if (dinnerEnabled) {
        final targetHour = (dinnerTime.hour + 1) % 24;
        await _scheduleDailyNotification(
          id: id++,
          channelId: _waterChannelId,
          channelName: 'Su Hatırlatıcısı',
          title: '💧 Su İçme Zamanı!',
          body: 'Günde en az 8 bardak su içmeyi unutma!',
          hour: targetHour,
          minute: dinnerTime.minute,
        );
      }
    } catch (e) {
      debugPrint('scheduleWaterReminder error: $e');
    }
  }

  static Future<void> scheduleMealReminder({
    required bool breakfast,
    required TimeOfDay breakfastTime,
    required bool lunch,
    required TimeOfDay lunchTime,
    required bool dinner,
    required TimeOfDay dinnerTime,
  }) async {
    try {
      await _plugin.cancel(200);
      await _plugin.cancel(201);
      await _plugin.cancel(202);

      if (breakfast) {
        await _scheduleDailyNotification(
          id: 200,
          channelId: _mealChannelId,
          channelName: 'Öğün Hatırlatıcısı',
          title: '🍳 Kahvaltı Zamanı!',
          body: 'Güne sağlıklı bir kahvaltı ile başla.',
          hour: breakfastTime.hour,
          minute: breakfastTime.minute,
        );
      }
      if (lunch) {
        await _scheduleDailyNotification(
          id: 201,
          channelId: _mealChannelId,
          channelName: 'Öğün Hatırlatıcısı',
          title: '🥗 Öğle Yemeği Zamanı!',
          body: 'Öğle yemeğini takip etmeyi unutma.',
          hour: lunchTime.hour,
          minute: lunchTime.minute,
        );
      }
      if (dinner) {
        await _scheduleDailyNotification(
          id: 202,
          channelId: _mealChannelId,
          channelName: 'Öğün Hatırlatıcısı',
          title: '🍽️ Akşam Yemeği Zamanı!',
          body: 'Akşam yemeğini kaydetmeyi unutma.',
          hour: dinnerTime.hour,
          minute: dinnerTime.minute,
        );
      }
    } catch (e) {
      debugPrint('scheduleMealReminder error: $e');
    }
  }

  static Future<void> scheduleDailySummary(bool enabled) async {
    try {
      await _plugin.cancel(300);
      if (!enabled) return;

      await _scheduleDailyNotification(
        id: 300,
        channelId: _summaryChannelId,
        channelName: 'Günlük Özet',
        title: '📊 Günlük Beslenme Özeti',
        body: 'Bugünkü beslenme durumunu kontrol et!',
        hour: 21,
        minute: 0,
      );
    } catch (e) {
      debugPrint('scheduleDailySummary error: $e');
    }
  }

  static Future<void> showCalorieGoalReached() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _goalChannelId,
        'Hedef Bildirimleri',
        channelDescription: 'Kalori hedefi bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      400,
      '🎉 Tebrikler!',
      'Günlük kalori hedefinize ulaştınız!',
      details,
    );
  }

  static Future<void> showAchievementNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _goalChannelId,
        'Hedef Bildirimleri',
        channelDescription: 'Rozet ve hedef bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      500 + DateTime.now().millisecondsSinceEpoch % 100,
      title,
      body,
      details,
    );
  }

  static Future<void> showFastingCompleteNotification({required int fastingHours}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _goalChannelId,
        'Hedef Bildirimleri',
        channelDescription: 'Oruç tamamlanma bildirimi',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      600,
      '🏆 Oruç Tamamlandı!',
      '$fastingHours saatlik orucunuzu başarıyla tamamladınız!',
      details,
    );
  }

  /// Schedule a weekly Monday morning reminder to log weight.
  static Future<void> scheduleWeeklyWeightReminder(bool enabled) async {
    try { await _plugin.cancel(700); } catch (_) {}
    if (!enabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _weightChannelId,
        'Haftalık Kilo Hatırlatıcısı',
        channelDescription: 'Her Pazartesi sabahı kilo girişi için hatırlatıcı',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final now = tz.TZDateTime.now(tz.local);
    // Find next Monday at 09:00
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    while (next.weekday != DateTime.monday || next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        700,
        '⚖️ Haftalık Kilo Takibi',
        'Bu haftanın kilonu girmeyi unutma!',
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('Kilo hatırlatıcısı planlama hatası: $e');
    }
  }

  static Future<void> scheduleBirthdayNotification({
    required int day,
    required int month,
    required String name,
  }) async {
    try {
      await _plugin.cancel(600);

      final now = tz.TZDateTime.now(tz.local);
      var nextBirthday = tz.TZDateTime(tz.local, now.year, month, day, 9, 0);
      if (nextBirthday.isBefore(now)) {
        nextBirthday = tz.TZDateTime(tz.local, now.year + 1, month, day, 9, 0);
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _birthdayChannelId,
          'Doğum Günü',
          channelDescription: 'Yıllık doğum günü kutlama bildirimi',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        600,
        '🎂 Mutlu Yıllar, $name!',
        'Bu özel günde seni kutluyoruz! Kendine iyi bak 🎉',
        nextBirthday,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } catch (e) {
      debugPrint('Doğum günü bildirimi planlama hatası: $e');
    }
  }

  static Future<void> scheduleSupplementDoseNotification({
    required int id,
    required String supplementName,
    required int hour,
    required int minute,
  }) async {
    await _scheduleDailyNotification(
      id: id,
      channelId: 'supplement_reminders',
      channelName: 'Takviye Hatırlatıcıları',
      title: 'Takviye Zamanı! 💊',
      body: '$supplementName takviyenizi alma vaktiniz geldi.',
      hour: hour,
      minute: minute,
    );
  }

  static Future<void> cancelSupplementNotifications(String supplementId) async {
    try {
      final baseId = supplementId.hashCode.abs() % 100000;
      for (int i = 0; i < 8; i++) {
        await _plugin.cancel(900000 + baseId + i);
      }
    } catch (e) {
      debugPrint('Takviye bildirim iptal hatası: $e');
    }
  }

  static Future<void> _scheduleDailyNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOf(hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Bildirim planlama hatası: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<NotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      waterEnabled: prefs.getBool('notif_water') ?? false,
      breakfastEnabled: prefs.getBool('notif_breakfast') ?? false,
      breakfastTime: TimeOfDay(
        hour: prefs.getInt('notif_breakfast_hour') ?? 8,
        minute: prefs.getInt('notif_breakfast_minute') ?? 0,
      ),
      lunchEnabled: prefs.getBool('notif_lunch') ?? false,
      lunchTime: TimeOfDay(
        hour: prefs.getInt('notif_lunch_hour') ?? 12,
        minute: prefs.getInt('notif_lunch_minute') ?? 0,
      ),
      dinnerEnabled: prefs.getBool('notif_dinner') ?? false,
      dinnerTime: TimeOfDay(
        hour: prefs.getInt('notif_dinner_hour') ?? 19,
        minute: prefs.getInt('notif_dinner_minute') ?? 0,
      ),
      summaryEnabled: prefs.getBool('notif_summary') ?? false,
    );
  }

  static Future<void> saveAndApply(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_water', settings.waterEnabled);
    await prefs.setBool('notif_breakfast', settings.breakfastEnabled);
    await prefs.setInt('notif_breakfast_hour', settings.breakfastTime.hour);
    await prefs.setInt('notif_breakfast_minute', settings.breakfastTime.minute);
    await prefs.setBool('notif_lunch', settings.lunchEnabled);
    await prefs.setInt('notif_lunch_hour', settings.lunchTime.hour);
    await prefs.setInt('notif_lunch_minute', settings.lunchTime.minute);
    await prefs.setBool('notif_dinner', settings.dinnerEnabled);
    await prefs.setInt('notif_dinner_hour', settings.dinnerTime.hour);
    await prefs.setInt('notif_dinner_minute', settings.dinnerTime.minute);
    await prefs.setBool('notif_summary', settings.summaryEnabled);

    await scheduleWaterReminder(
      enabled: settings.waterEnabled,
      breakfastEnabled: settings.breakfastEnabled,
      breakfastTime: settings.breakfastTime,
      lunchEnabled: settings.lunchEnabled,
      lunchTime: settings.lunchTime,
      dinnerEnabled: settings.dinnerEnabled,
      dinnerTime: settings.dinnerTime,
    );
    await scheduleMealReminder(
      breakfast: settings.breakfastEnabled,
      breakfastTime: settings.breakfastTime,
      lunch: settings.lunchEnabled,
      lunchTime: settings.lunchTime,
      dinner: settings.dinnerEnabled,
      dinnerTime: settings.dinnerTime,
    );
    await scheduleDailySummary(settings.summaryEnabled);
  }
}

class NotificationSettings {
  bool waterEnabled;
  bool breakfastEnabled;
  TimeOfDay breakfastTime;
  bool lunchEnabled;
  TimeOfDay lunchTime;
  bool dinnerEnabled;
  TimeOfDay dinnerTime;
  bool summaryEnabled;

  NotificationSettings({
    required this.waterEnabled,
    required this.breakfastEnabled,
    required this.breakfastTime,
    required this.lunchEnabled,
    required this.lunchTime,
    required this.dinnerEnabled,
    required this.dinnerTime,
    required this.summaryEnabled,
  });
}
