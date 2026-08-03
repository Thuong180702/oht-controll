import '../../../../core/enums/event_severity.dart';

class AlarmEvent {
  const AlarmEvent({
    required this.id,
    required this.severity,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final EventSeverity severity;
  final String message;
  final DateTime timestamp;

  factory AlarmEvent.now({
    required EventSeverity severity,
    required String message,
  }) {
    final now = DateTime.now();
    return AlarmEvent(
      id: 'evt_${now.microsecondsSinceEpoch}',
      severity: severity,
      message: message,
      timestamp: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'severity': severity.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AlarmEvent.fromJson(Map<String, dynamic> json) {
    return AlarmEvent(
      id: json['id'] as String? ?? 'evt_${DateTime.now().microsecondsSinceEpoch}',
      severity: EventSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => EventSeverity.info,
      ),
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
