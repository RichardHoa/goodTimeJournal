class JournalEntry {
  final String id;
  final String activity;
  final double engagement;
  final double goodness;
  final DateTime timestamp;
  final bool isFlow;

  JournalEntry({
    required this.id,
    required this.activity,
    required this.engagement,
    required this.goodness,
    required this.timestamp,
    this.isFlow = false,
  });

  // Unique day key for grouping (e.g., 2026-07-19)
  String get dateKey {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activity': activity,
      'engagement': engagement,
      'goodness': goodness,
      'timestamp': timestamp.toIso8601String(),
      'isFlow': isFlow,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      activity: json['activity'] as String,
      engagement: (json['engagement'] as num).toDouble(),
      goodness: (json['goodness'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFlow: (json['isFlow'] as bool?) ?? false,
    );
  }

  JournalEntry copyWith({
    String? id,
    String? activity,
    double? engagement,
    double? goodness,
    DateTime? timestamp,
    bool? isFlow,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      activity: activity ?? this.activity,
      engagement: engagement ?? this.engagement,
      goodness: goodness ?? this.goodness,
      timestamp: timestamp ?? this.timestamp,
      isFlow: isFlow ?? this.isFlow,
    );
  }
}
