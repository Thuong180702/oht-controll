import '../../../../core/enums/lidar_zone.dart';

class SensorStatus {
  const SensorStatus({
    required this.steerFrontLeft,
    required this.steerFrontRight,
    required this.steerRearLeft,
    required this.steerRearRight,
    required this.hoistFrontUpperLimit,
    required this.hoistRearUpperLimit,
    required this.pumperFront,
    required this.pumperRear,
    required this.lidarUpper,
    required this.lidarLower,
  });

  final bool? steerFrontLeft;
  final bool? steerFrontRight;
  final bool? steerRearLeft;
  final bool? steerRearRight;
  final bool? hoistFrontUpperLimit;
  final bool? hoistRearUpperLimit;
  final bool? pumperFront;
  final bool? pumperRear;
  final int? lidarUpper;
  final int? lidarLower;

  LidarZone get lidarUpperZone => LidarZone.fromValue(lidarUpper);
  LidarZone get lidarLowerZone => LidarZone.fromValue(lidarLower);
  bool get hasLidarDanger =>
      lidarUpperZone == LidarZone.danger || lidarLowerZone == LidarZone.danger;

  bool get hasLidarWarning =>
      lidarUpperZone == LidarZone.warning ||
      lidarLowerZone == LidarZone.warning;

  factory SensorStatus.noData() {
    return const SensorStatus(
      steerFrontLeft: null,
      steerFrontRight: null,
      steerRearLeft: null,
      steerRearRight: null,
      hoistFrontUpperLimit: null,
      hoistRearUpperLimit: null,
      pumperFront: null,
      pumperRear: null,
      lidarUpper: null,
      lidarLower: null,
    );
  }

  factory SensorStatus.fromJson(Map<String, dynamic> json) {
    return SensorStatus(
      steerFrontLeft: _asBool(json['steerFrontLeft']),
      steerFrontRight: _asBool(json['steerFrontRight']),
      steerRearLeft: _asBool(json['steerRearLeft']),
      steerRearRight: _asBool(json['steerRearRight']),
      hoistFrontUpperLimit: _asBool(json['hoistFrontUpperLimit']),
      hoistRearUpperLimit: _asBool(json['hoistRearUpperLimit']),
      pumperFront: _asBool(json['pumperFront']),
      pumperRear: _asBool(json['pumperRear']),
      lidarUpper: _asIntOrNull(json['lidarUpper']),
      lidarLower: _asIntOrNull(json['lidarLower']),
    );
  }

  SensorStatus copyWith({
    bool? steerFrontLeft,
    bool? steerFrontRight,
    bool? steerRearLeft,
    bool? steerRearRight,
    bool? hoistFrontUpperLimit,
    bool? hoistRearUpperLimit,
    bool? pumperFront,
    bool? pumperRear,
    int? lidarUpper,
    int? lidarLower,
  }) {
    return SensorStatus(
      steerFrontLeft: steerFrontLeft ?? this.steerFrontLeft,
      steerFrontRight: steerFrontRight ?? this.steerFrontRight,
      steerRearLeft: steerRearLeft ?? this.steerRearLeft,
      steerRearRight: steerRearRight ?? this.steerRearRight,
      hoistFrontUpperLimit: hoistFrontUpperLimit ?? this.hoistFrontUpperLimit,
      hoistRearUpperLimit: hoistRearUpperLimit ?? this.hoistRearUpperLimit,
      pumperFront: pumperFront ?? this.pumperFront,
      pumperRear: pumperRear ?? this.pumperRear,
      lidarUpper: lidarUpper ?? this.lidarUpper,
      lidarLower: lidarLower ?? this.lidarLower,
    );
  }

  bool? boolValue(String id) {
    switch (id) {
      case 'steer_front_left':
        return steerFrontLeft;
      case 'steer_front_right':
        return steerFrontRight;
      case 'steer_rear_left':
        return steerRearLeft;
      case 'steer_rear_right':
        return steerRearRight;
      case 'hoist_front_upper_limit':
        return hoistFrontUpperLimit;
      case 'hoist_rear_upper_limit':
        return hoistRearUpperLimit;
      case 'pumper_front':
        return pumperFront;
      case 'pumper_rear':
        return pumperRear;
      default:
        return null;
    }
  }

  LidarZone lidarValue(String id) {
    switch (id) {
      case 'lidar_upper':
        return lidarUpperZone;
      case 'lidar_lower':
        return lidarLowerZone;
      default:
        return LidarZone.noData;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'steerFrontLeft': steerFrontLeft,
      'steerFrontRight': steerFrontRight,
      'steerRearLeft': steerRearLeft,
      'steerRearRight': steerRearRight,
      'hoistFrontUpperLimit': hoistFrontUpperLimit,
      'hoistRearUpperLimit': hoistRearUpperLimit,
      'pumperFront': pumperFront,
      'pumperRear': pumperRear,
      'lidarUpper': lidarUpper,
      'lidarLower': lidarLower,
    };
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }

  static int? _asIntOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }
}
