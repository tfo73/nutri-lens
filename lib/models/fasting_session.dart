enum FastingMode { twelvetwelve, sixteen8, eighteen6, custom }

extension FastingModeX on FastingMode {
  String get label {
    switch (this) {
      case FastingMode.twelvetwelve: return '12:12';
      case FastingMode.sixteen8:    return '16:8';
      case FastingMode.eighteen6:   return '18:6';
      case FastingMode.custom:      return 'Serbest';
    }
  }

  String get title {
    switch (this) {
      case FastingMode.twelvetwelve: return 'Başlangıç';
      case FastingMode.sixteen8:    return 'Standart';
      case FastingMode.eighteen6:   return 'İleri Seviye';
      case FastingMode.custom:      return 'Serbest';
    }
  }

  String get description {
    switch (this) {
      case FastingMode.twelvetwelve:
        return 'Sirkadiyen ritme uyum sağlar, uyku ile doğal oruç penceresi oluşturur.';
      case FastingMode.sixteen8:
        return 'En popüler ve sürdürülebilir mod. Yağ yakımı ve metabolik faydalar için idealdir.';
      case FastingMode.eighteen6:
        return 'Daha derin otofaji ve ketoz için. Deneyimlilere önerilir.';
      case FastingMode.custom:
        return 'Kendi oruç sürenizi belirleyin. Tam özgürlük sizin elinizde.';
    }
  }

  int get defaultFastingHours {
    switch (this) {
      case FastingMode.twelvetwelve: return 12;
      case FastingMode.sixteen8:    return 16;
      case FastingMode.eighteen6:   return 18;
      case FastingMode.custom:      return 16;
    }
  }

  String get name => toString().split('.').last;
}

class FastingPhase {
  final String name;
  final String description;
  final String emoji;
  final int minHours;
  final int? maxHours;

  const FastingPhase({
    required this.name,
    required this.description,
    required this.emoji,
    required this.minHours,
    this.maxHours,
  });

  static FastingPhase forElapsed(Duration elapsed, {double? weightKg, int? age, String? gender}) {
    final h = elapsed.inMinutes / 60.0;

    double factor = 1.0;
    if (weightKg != null && weightKg > 90) factor = 0.9;
    if (age != null && age > 50) factor *= 0.95;
    if (gender == 'female') factor *= 1.05;

    final adjustedH = h / factor;

    if (adjustedH < 4)  return _phases[0];
    if (adjustedH < 8)  return _phases[1];
    if (adjustedH < 12) return _phases[2];
    if (adjustedH < 16) return _phases[3];
    if (adjustedH < 20) return _phases[4];
    if (adjustedH < 24) return _phases[5];
    return _phases[6];
  }

  static const List<FastingPhase> _phases = [
    FastingPhase(
      name: 'Sindirim Fazı',
      description: 'Vücudunuz son öğününü sindiriyor. İnsülin yüksek, enerji depolanıyor.',
      emoji: '🍽️',
      minHours: 0,
      maxHours: 4,
    ),
    FastingPhase(
      name: 'Geçiş Fazı',
      description: 'Glikojen depoları azalıyor. Vücut alternatif enerji kaynakları arıyor.',
      emoji: '⚡',
      minHours: 4,
      maxHours: 8,
    ),
    FastingPhase(
      name: 'Yağ Yakma Başlangıcı',
      description: 'Vücudunuz depolanmış yağa başvuruyor. Metabolik esneklik artıyor.',
      emoji: '🔥',
      minHours: 8,
      maxHours: 12,
    ),
    FastingPhase(
      name: 'Yağ Yakma Fazı',
      description: 'Glikojen depoları tükendi. Vücut birincil olarak depolanmış yağdan enerji alıyor. Metabolik esneklik artıyor.',
      emoji: '💧',
      minHours: 12,
      maxHours: 16,
    ),
    FastingPhase(
      name: 'Derin Ketoz',
      description: 'Keton seviyeleri yükseliyor. Beyin keton cisimciklerinden temiz enerji alıyor.',
      emoji: '🚀',
      minHours: 16,
      maxHours: 20,
    ),
    FastingPhase(
      name: 'Otofaji Başlangıcı',
      description: 'Hücre temizliği başladı. Hasarlı proteinler ve organeller yeniden işleniyor.',
      emoji: '✨',
      minHours: 20,
      maxHours: 24,
    ),
    FastingPhase(
      name: 'Derin Otofaji',
      description: 'Maksimum hücre yenilenmesi. Güçlü anti-inflamatuar ve uzun ömür etkileri.',
      emoji: '🌟',
      minHours: 24,
      maxHours: null,
    ),
  ];
}

class FastingSession {
  final String id;
  final FastingMode mode;
  final DateTime startTime;
  final DateTime? endTime;
  final int fastingHours;
  final bool wasCancelled;

  const FastingSession({
    required this.id,
    required this.mode,
    required this.startTime,
    this.endTime,
    required this.fastingHours,
    this.wasCancelled = false,
  });

  bool get isActive => endTime == null;

  bool get wasCompleted =>
      endTime != null && !wasCancelled && elapsed >= goalDuration;

  Duration get goalDuration => Duration(hours: fastingHours);

  Duration get elapsed {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double get progress {
    final e = elapsed.inSeconds;
    final g = goalDuration.inSeconds;
    if (g == 0) return 0;
    return (e / g).clamp(0.0, 1.0);
  }

  FastingSession copyWith({DateTime? endTime, bool? wasCancelled}) => FastingSession(
        id: id,
        mode: mode,
        startTime: startTime,
        endTime: endTime ?? this.endTime,
        fastingHours: fastingHours,
        wasCancelled: wasCancelled ?? this.wasCancelled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'fastingHours': fastingHours,
        'wasCancelled': wasCancelled,
      };

  factory FastingSession.fromJson(Map<String, dynamic> j) => FastingSession(
        id: j['id'] as String,
        mode: FastingMode.values.firstWhere(
          (m) => m.name == j['mode'],
          orElse: () => FastingMode.sixteen8,
        ),
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: j['endTime'] != null ? DateTime.parse(j['endTime'] as String) : null,
        fastingHours: (j['fastingHours'] as num).toInt(),
        wasCancelled: (j['wasCancelled'] as bool?) ?? false,
      );
}
