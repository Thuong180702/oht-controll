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
}
