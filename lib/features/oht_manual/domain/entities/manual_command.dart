import '../../../../core/enums/manual_command_type.dart';

class ManualCommand {
  const ManualCommand({
    required this.type,
    required this.target,
    required this.speed,
    required this.requestId,
    required this.timestamp,
  });

  final ManualCommandType type;
  final String target;
  final int speed;
  final String requestId;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': 'command',
      'command': type.wireName,
      'target': target,
      'speed': speed,
      'requestId': requestId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
