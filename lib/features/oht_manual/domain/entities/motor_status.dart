import '../../../../core/enums/motor_state.dart';

class MotorStatus {
  const MotorStatus({
    required this.id,
    required this.state,
    required this.direction,
    required this.speed,
    this.velocityMps,
    this.positionM,
    this.warning,
  });

  final String id;
  final MotorState state;
  final String direction;

  /// Motor speed in RPM (raw value from firmware feedback).
  /// This is the actual servo RPM, not a percentage.
  final int speed;

  /// Device velocity in m/s (only meaningful for travel overall speed).
  /// Per-motor velocity is shown as RPM, not m/s.
  final double? velocityMps;
  final double? positionM;
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
      speed: (_asInt(json['speed'])).abs(),  // RPM value
      velocityMps: _asOptionalDouble(
        json['velocityMps'] ??
            json['velocity'] ??
            json['speedMps'] ??
            json['actualVelocity'] ??
            json['actualSpeed'],
      ),
      positionM: _asOptionalDouble(
        json['positionM'] ??
            json['position'] ??
            json['heightM'] ??
            json['height'],
      ),
      warning: json['warning'] as String?,
    );
  }

  MotorStatus copyWith({
    MotorState? state,
    String? direction,
    int? speed,
    double? velocityMps,
    double? positionM,
    String? warning,
  }) {
    return MotorStatus(
      id: id,
      state: state ?? this.state,
      direction: direction ?? this.direction,
      speed: speed ?? this.speed,
      velocityMps: velocityMps ?? this.velocityMps,
      positionM: positionM ?? this.positionM,
      warning: warning,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'state': state.name,
      'direction': direction,
      'speed': speed,
      if (velocityMps != null) 'velocityMps': velocityMps,
      if (positionM != null) 'positionM': positionM,
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

  static double? _asOptionalDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
