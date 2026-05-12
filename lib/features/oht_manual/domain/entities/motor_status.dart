import '../../../../core/enums/motor_state.dart';

class MotorStatus {
  const MotorStatus({
    required this.id,
    required this.state,
    required this.direction,
    required this.speed,
    this.warning,
  });

  final String id;
  final MotorState state;
  final String direction;
  final int speed;
  final String? warning;

  bool get hasWarning => warning != null && warning!.trim().isNotEmpty;

  factory MotorStatus.stopped(String id) {
    return MotorStatus(
      id: id,
      state: MotorState.stopped,
      direction: 'none',
      speed: 0,
    );
  }

  factory MotorStatus.fromJson(String id, Map<String, dynamic> json) {
    return MotorStatus(
      id: id,
      state: MotorStateLabel.fromWire(json['state'] as String?),
      direction: (json['direction'] as String?) ?? 'none',
      speed: _clampSpeed(_asInt(json['speed'])),
      warning: json['warning'] as String?,
    );
  }

  MotorStatus copyWith({
    MotorState? state,
    String? direction,
    int? speed,
    String? warning,
  }) {
    return MotorStatus(
      id: id,
      state: state ?? this.state,
      direction: direction ?? this.direction,
      speed: _clampSpeed(speed ?? this.speed),
      warning: warning,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'state': state.name,
      'direction': direction,
      'speed': speed,
      if (warning != null) 'warning': warning,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return 0;
  }

  static int _clampSpeed(int value) {
    return value.clamp(0, 100).toInt();
  }
}
