import '../core/constants/oht_ids.dart';
import '../core/enums/motor_state.dart';
import '../core/enums/oht_mode.dart';
import '../features/oht_manual/domain/entities/motor_status.dart';
import '../features/oht_manual/domain/entities/oht_telemetry.dart';
import '../features/oht_manual/domain/entities/sensor_status.dart';

class MockOhtData {
  const MockOhtData._();

  static OhtTelemetry initialTelemetry() {
    return OhtTelemetry(
      mode: OhtMode.manual,
      connected: false,
      emergencyStop: false,
      motors: {for (final id in MotorIds.all) id: MotorStatus.stopped(id)},
      sensors: const SensorStatus(
        steerFrontLeft: true,   // Default at full left
        steerFrontRight: false,
        steerRearLeft: true,    // Default at full left
        steerRearRight: false,
        hoistFrontUpperLimit: true,  // Default at top
        hoistRearUpperLimit: true,   // Default at top
        pumperFront: false,
        pumperRear: false,
        lidarUpper: 0,
        lidarLower: 1,
      ),
      errors: const <String>[],
      timestamp: DateTime.now(),
    );
  }

  static MotorStatus stoppedMotor(String id) {
    return MotorStatus(
      id: id,
      state: MotorState.stopped,
      direction: 'none',
      speed: 0,
      velocityMps: 0,
      positionM: 0,
    );
  }
}
