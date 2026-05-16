import '../../../../core/constants/oht_ids.dart';
import '../../domain/entities/motor_status.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/entities/sensor_status.dart';

const double _fallbackMaxSpeedMps = 1.0;

double speedPercentToMps(int speed) {
  return speed.clamp(0, 100).toDouble() / 100.0 * _fallbackMaxSpeedMps;
}

String formatCommandSpeedMps(int speed) {
  return '${speedPercentToMps(speed).toStringAsFixed(2)} m/s';
}

String formatMotorVelocityMps(MotorStatus? motor) {
  return '${motorVelocityMps(motor).toStringAsFixed(2)} m/s';
}

String formatTravelVelocityMps(OhtTelemetry telemetry) {
  final front = telemetry.motors[MotorIds.travelFront];
  final rear = telemetry.motors[MotorIds.travelRear];
  final active = <MotorStatus?>[?front, ?rear];
  if (active.isEmpty) return '0.00 m/s';

  final total = active.fold<double>(
    0,
    (sum, motor) => sum + motorVelocityMps(motor),
  );
  return '${(total / active.length).toStringAsFixed(2)} m/s';
}

double motorVelocityMps(MotorStatus? motor) {
  if (motor == null) return 0;
  return motor.velocityMps ?? speedPercentToMps(motor.speed);
}

String formatMotorDetails(String id, MotorStatus? motor, SensorStatus sensors) {
  final velocity = formatMotorVelocityMps(motor);
  if (id == MotorIds.steerFront || id == MotorIds.steerRear) {
    return '$velocity  |  VT: ${_steerPosition(id, motor, sensors)}';
  }
  if (id == MotorIds.hoistFront || id == MotorIds.hoistRear) {
    return '$velocity  |  H: ${_hoistPosition(id, motor, sensors)}';
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

String _hoistPosition(String id, MotorStatus? motor, SensorStatus sensors) {
  final upperLimit = id == MotorIds.hoistFront
      ? sensors.hoistFrontUpperLimit
      : sensors.hoistRearUpperLimit;
  final position = motor?.positionM ?? (upperLimit == true ? 0.01 : 0.0);
  return '${position.toStringAsFixed(2)} m';
}
