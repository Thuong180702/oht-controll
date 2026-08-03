import '../../../../core/constants/oht_ids.dart';
import '../../domain/entities/motor_status.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/entities/sensor_status.dart';

// Approximate conversion: travel motor max RPM (~3000 for Kinco) → 0.5 m/s
const double _travelRpmToMps = 0.5 / 3000.0;

/// Per-motor velocity display: RPM.
String formatMotorVelocityRpm(MotorStatus? motor) {
  final rpm = motorVelocityRpm(motor);
  return '${rpm.toInt()} RPM';
}

/// Per-motor velocity as RPM (from motor.speed).
double motorVelocityRpm(MotorStatus? motor) {
  return (motor?.speed ?? 0).toDouble();
}

/// Device travel velocity in m/s (averaged from travel motors).
String formatTravelVelocityMps(OhtTelemetry telemetry) {
  final front = telemetry.motors[MotorIds.travelFront];
  final rear = telemetry.motors[MotorIds.travelRear];
  final avgRpm = (motorVelocityRpm(front) + motorVelocityRpm(rear)) / 2.0;
  final mps = avgRpm * _travelRpmToMps;
  return '${mps.toStringAsFixed(2)} m/s';
}

/// Command speed preview in m/s (0..100% → 0.0..0.5 m/s).
String formatCommandSpeedMps(int speed) {
  final mps = speed.clamp(0, 100).toDouble() / 100.0 * 0.5;
  return '${mps.toStringAsFixed(2)} m/s';
}

String formatMotorDetails(String id, MotorStatus? motor, SensorStatus sensors) {
  final velocity = formatMotorVelocityRpm(motor);
  if (id == MotorIds.steerFront || id == MotorIds.steerRear) {
    return '$velocity  |  VT: ${_steerPosition(id, motor, sensors)}';
  }
  if (id == MotorIds.hoistFront || id == MotorIds.hoistRear) {
    return '$velocity  |  H: ${_hoistPosition(motor)}';
  }
  return velocity;
}

String _steerPosition(String id, MotorStatus? motor, SensorStatus sensors) {
  final isFront = id == MotorIds.steerFront;
  final left = isFront ? sensors.steerFrontLeft : sensors.steerRearLeft;
  final right = isFront ? sensors.steerFrontRight : sensors.steerRearRight;
  if (left == true && right == true) return 'Loi VT';
  if (left == true) return 'Trai';
  if (right == true) return 'Phai';

  final direction = motor?.direction.toLowerCase();
  if (direction == 'left') return 'Dang Trai';
  if (direction == 'right') return 'Dang Phai';
  return '-';
}

String _hoistPosition(MotorStatus? motor) {
  final position = motor?.positionM ?? 0.0;
  return '${position.toStringAsFixed(2)} m';
}
