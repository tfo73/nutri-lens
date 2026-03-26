class ExerciseEntry {
  final String id;
  final String name;
  final int durationMinutes;
  final double burnedCalories;
  final DateTime timestamp;

  const ExerciseEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.burnedCalories,
    required this.timestamp,
  });

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: json['durationMinutes'] as int,
      burnedCalories: (json['burnedCalories'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'burnedCalories': burnedCalories,
        'timestamp': timestamp.toIso8601String(),
      };
}
