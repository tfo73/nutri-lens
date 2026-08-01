import 'dart:convert';
import 'dart:math' as math;

class SupplementItem {
  final String id;
  final String name;
  final int timesPerDay;
  final String? reminderTime;
  final List<String>? doseTimes;
  final String? microNutrientKey;
  final double? microAmount;
  final String microUnit;
  final String? imagePath;

  SupplementItem({
    required this.id,
    required this.name,
    this.timesPerDay = 1,
    this.reminderTime,
    this.doseTimes,
    this.microNutrientKey,
    this.microAmount,
    this.microUnit = 'mg',
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'timesPerDay': timesPerDay,
        'reminderTime': reminderTime,
        'doseTimes': doseTimes,
        'microNutrientKey': microNutrientKey,
        'microAmount': microAmount,
        'microUnit': microUnit,
        'imagePath': imagePath,
      };

  factory SupplementItem.fromJson(Map<String, dynamic> json) => SupplementItem(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Takviye',
        timesPerDay: (json['timesPerDay'] as num?)?.toInt() ?? 1,
        reminderTime: json['reminderTime'] as String?,
        doseTimes: (json['doseTimes'] as List?)?.cast<String>(),
        microNutrientKey: json['microNutrientKey'] as String?,
        microAmount: (json['microAmount'] as num?)?.toDouble(),
        microUnit: json['microUnit'] as String? ?? 'mg',
        imagePath: json['imagePath'] as String?,
      );

  List<String> getCalculatedDoseTimes() {
    if (doseTimes != null && doseTimes!.length >= timesPerDay) {
      return doseTimes!.sublist(0, timesPerDay);
    }
    if (timesPerDay == 2) {
      return ['08:00', '20:00'];
    } else if (timesPerDay == 3) {
      return ['08:00', '14:00', '20:00'];
    } else if (timesPerDay == 4) {
      return ['08:00', '12:00', '16:00', '20:00'];
    }
    return ['08:00'];
  }

  static String encodeList(List<SupplementItem> items) =>
      json.encode(items.map((i) => i.toJson()).toList());

  static List<SupplementItem> decodeList(String str) {
    if (str.isEmpty) return [];
    try {
      final List decoded = json.decode(str);
      return decoded.map((i) => SupplementItem.fromJson(i as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
