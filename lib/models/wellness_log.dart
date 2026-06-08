enum MoodType { enerjik, sakin, yorgun, gergin, huzursuz }

extension MoodTypeX on MoodType {
  String get label {
    switch (this) {
      case MoodType.enerjik:   return 'Enerjik';
      case MoodType.sakin:     return 'Sakin';
      case MoodType.yorgun:    return 'Yorgun';
      case MoodType.gergin:    return 'Gergin';
      case MoodType.huzursuz:  return 'Huzursuz';
    }
  }

  String get emoji {
    switch (this) {
      case MoodType.enerjik:   return '😀';
      case MoodType.sakin:     return '😌';
      case MoodType.yorgun:    return '😴';
      case MoodType.gergin:    return '😤';
      case MoodType.huzursuz:  return '😟';
    }
  }

  static MoodType fromString(String s) =>
      MoodType.values.firstWhere((e) => e.name == s, orElse: () => MoodType.sakin);
}

class MoodEntry {
  final String timeSlot; // 'sabah' | 'öğle' | 'akşam' | 'gece'
  final MoodType mood;

  const MoodEntry({required this.timeSlot, required this.mood});

  factory MoodEntry.fromJson(Map<String, dynamic> j) => MoodEntry(
        timeSlot: j['timeSlot'] as String,
        mood: MoodTypeX.fromString(j['mood'] as String),
      );

  Map<String, dynamic> toJson() => {'timeSlot': timeSlot, 'mood': mood.name};
}

class WcEntry {
  final DateTime time;
  final int stoolType; // -3 to 3

  const WcEntry({required this.time, required this.stoolType});

  factory WcEntry.fromJson(Map<String, dynamic> j) => WcEntry(
        time: DateTime.parse(j['time'] as String),
        stoolType: (j['stoolType'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'stoolType': stoolType,
      };
}

class WellnessLog {
  final DateTime date;
  final int? sleepScore;        // 1–5
  final List<MoodEntry> moods;
  final List<WcEntry> wcEntries;
  final List<String> symptoms;

  const WellnessLog({
    required this.date,
    this.sleepScore,
    this.moods = const [],
    this.wcEntries = const [],
    this.symptoms = const [],
  });

  int get wcCount => wcEntries.length;

  WellnessLog copyWith({
    int? sleepScore,
    List<MoodEntry>? moods,
    List<WcEntry>? wcEntries,
    List<String>? symptoms,
  }) =>
      WellnessLog(
        date: date,
        sleepScore: sleepScore ?? this.sleepScore,
        moods: moods ?? this.moods,
        wcEntries: wcEntries ?? this.wcEntries,
        symptoms: symptoms ?? this.symptoms,
      );

  factory WellnessLog.fromJson(Map<String, dynamic> j) => WellnessLog(
        date: DateTime.parse(j['date'] as String),
        sleepScore: (j['sleepScore'] as num?)?.toInt(),
        moods: (j['moods'] as List? ?? [])
            .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        wcEntries: (j['wcEntries'] as List? ?? [])
            .map((e) => WcEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        symptoms: (j['symptoms'] as List? ?? []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        if (sleepScore != null) 'sleepScore': sleepScore,
        'moods': moods.map((e) => e.toJson()).toList(),
        'wcEntries': wcEntries.map((e) => e.toJson()).toList(),
        'symptoms': symptoms,
      };

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get dateKey => _dateKey(date);

  MoodType? moodFor(String slot) {
    try {
      return moods.firstWhere((m) => m.timeSlot == slot).mood;
    } catch (_) {
      return null;
    }
  }
}
