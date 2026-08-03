import 'dart:async';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/enums/manual_command_type.dart';
import '../../../../core/enums/motor_state.dart';
import '../../../../core/enums/oht_mode.dart';
import '../../../../mock/mock_oht_data.dart';
import '../../domain/entities/alarm_event.dart';
import '../../domain/entities/connection_status.dart';
import '../../domain/entities/manual_command.dart';
import '../../domain/entities/motor_status.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/repositories/oht_communication_service.dart';

class MockOhtCommunicationService implements OhtCommunicationService {
  final _telemetryController = StreamController<OhtTelemetry>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<AlarmEvent>.broadcast();

  Timer? _timer;
  OhtTelemetry _telemetry = MockOhtData.initialTelemetry();
  ConnectionStatus _status = ConnectionStatus.disconnected(
    endpoint: AppConstants.mockEndpoint,
  );
  int _tick = 0;
  int _hoistDownTicks = 0;
  double _travelFrontPositionM = 0;
  double _travelRearPositionM = 0;
  double _steerFrontPositionM = -1.0; // Default at full left
  double _steerRearPositionM = -1.0; // Default at full left
  double _hoistFrontPositionM = 0.0; // Default at top (fully raised)
  double _hoistRearPositionM = 0.0; // Default at top (fully raised)

  @override
  Stream<OhtTelemetry> get telemetryStream => _telemetryController.stream;

  @override
  Stream<ConnectionStatus> get connectionStatusStream =>
      _statusController.stream;

  @override
  Stream<AlarmEvent> get eventStream => _eventController.stream;

  @override
  ConnectionStatus get status => _status;

  @override
  Future<void> connect({required String endpoint}) async {
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.connecting,
        endpoint: AppConstants.mockEndpoint,
        message: 'Starting local mock telemetry',
        changedAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.connected,
        endpoint: AppConstants.mockEndpoint,
        message: 'Mock OHT connected',
        changedAt: DateTime.now(),
      ),
    );
    _telemetry = _telemetry.copyWith(
      connected: true,
      mode: OhtMode.manual,
      timestamp: DateTime.now(),
    );
    _emitTelemetry();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _stepTelemetry();
    });
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _telemetry = _telemetry.copyWith(
      connected: false,
      timestamp: DateTime.now(),
    );
    _emitTelemetry();
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.disconnected,
        endpoint: AppConstants.mockEndpoint,
        message: 'Mock OHT disconnected',
        changedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> sendCommand(ManualCommand command) async {
    if (!_status.isConnected) {
      throw StateError('Mock OHT is not connected');
    }

    _applyCommand(command);
    _eventController.add(
      AlarmEvent.now(
        severity: EventSeverity.ack,
        message: 'ACK ${command.type.wireName} (${command.requestId})',
      ),
    );
    _emitTelemetry();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _telemetryController.close();
    _statusController.close();
    _eventController.close();
  }

  void _stepTelemetry() {
    _tick++;

    final phase = _tick % 1000;
    final lidarUpper = phase == 100 || phase == 101 ? 2 : 0;
    final lidarLower = phase >= 200 && phase <= 205 ? 1 : 0;

    final motors = Map<String, MotorStatus>.from(_telemetry.motors);
    var sensors = _telemetry.sensors.copyWith(
      lidarUpper: lidarUpper,
      lidarLower: lidarLower,
      pumperFront: phase >= 300 && phase <= 302,
      pumperRear: phase >= 400 && phase <= 402,
    );

    // Unified hoist simulation
    // Hoist starts at top (position=0, upper_limit=true).
    // Down increases lowered distance, Up returns toward 0 (top limit).
    final frontHoist = motors[MotorIds.hoistFront];
    final rearHoist = motors[MotorIds.hoistRear];
    if (frontHoist?.state == MotorState.running &&
        rearHoist?.state == MotorState.running) {
      if (frontHoist?.direction == 'down') {
        _updateHoistPosition(motors, MotorIds.hoistFront, frontHoist!);
        _updateHoistPosition(motors, MotorIds.hoistRear, rearHoist!);
        _hoistDownTicks++;
        sensors = sensors.copyWith(
          hoistFrontUpperLimit: false,
          hoistRearUpperLimit: false,
        );
        if (_hoistDownTicks >= 12) {
          motors[MotorIds.hoistFront] = _stoppedMotor(MotorIds.hoistFront);
          motors[MotorIds.hoistRear] = _stoppedMotor(MotorIds.hoistRear);
        }
      } else if (frontHoist?.direction == 'up') {
        _updateHoistPosition(motors, MotorIds.hoistFront, frontHoist!);
        _updateHoistPosition(motors, MotorIds.hoistRear, rearHoist!);
        if (_hoistFrontPositionM <= 0.0 || _hoistRearPositionM <= 0.0) {
          motors[MotorIds.hoistFront] = _stoppedMotor(MotorIds.hoistFront);
          motors[MotorIds.hoistRear] = _stoppedMotor(MotorIds.hoistRear);
          sensors = sensors.copyWith(
            hoistFrontUpperLimit: true,
            hoistRearUpperLimit: true,
          );
        }
      }
    }

    // Unified steer simulation
    // Steer starts at full left (position=-1.0, steer_left sensors=true).
    // With the 500 ms mock tick, full left to full right takes about 2 seconds.
    final frontSteer = motors[MotorIds.steerFront];
    final rearSteer = motors[MotorIds.steerRear];
    if (frontSteer?.state == MotorState.running &&
        rearSteer?.state == MotorState.running) {
      if (frontSteer?.direction == 'right') {
        _updateSteerPosition(motors, MotorIds.steerFront, frontSteer!);
        _updateSteerPosition(motors, MotorIds.steerRear, rearSteer!);
        sensors = sensors.copyWith(steerFrontLeft: false, steerRearLeft: false);
        if (_steerFrontPositionM >= 1.0 || _steerRearPositionM >= 1.0) {
          motors[MotorIds.steerFront] = _stoppedMotor(MotorIds.steerFront);
          motors[MotorIds.steerRear] = _stoppedMotor(MotorIds.steerRear);
          sensors = sensors.copyWith(
            steerFrontRight: true,
            steerRearRight: true,
          );
        }
      } else if (frontSteer?.direction == 'left') {
        _updateSteerPosition(motors, MotorIds.steerFront, frontSteer!);
        _updateSteerPosition(motors, MotorIds.steerRear, rearSteer!);
        sensors = sensors.copyWith(
          steerFrontRight: false,
          steerRearRight: false,
        );
        if (_steerFrontPositionM <= -1.0 || _steerRearPositionM <= -1.0) {
          motors[MotorIds.steerFront] = _stoppedMotor(MotorIds.steerFront);
          motors[MotorIds.steerRear] = _stoppedMotor(MotorIds.steerRear);
          sensors = sensors.copyWith(steerFrontLeft: true, steerRearLeft: true);
        }
      }
    }

    double px = _telemetry.positionX;
    final travelFront = motors[MotorIds.travelFront];
    if (travelFront?.state == MotorState.running) {
      _updateTravelPosition(motors, MotorIds.travelFront, travelFront!);
      px +=
          (travelFront.direction == 'forward' ? 1 : -1) *
          (travelFront.speed / 100.0) *
          0.1;
    }
    final travelRear = motors[MotorIds.travelRear];
    if (travelRear?.state == MotorState.running) {
      _updateTravelPosition(motors, MotorIds.travelRear, travelRear!);
      px +=
          (travelRear.direction == 'forward' ? 1 : -1) *
          (travelRear.speed / 100.0) *
          0.1;
    }

    int battery = _telemetry.batteryLevel;
    bool charging = _telemetry.isCharging;
    if (_tick % 10 == 0) {
      if (charging) {
        battery += 1;
        if (battery >= 100) {
          battery = 100;
          charging = false;
        }
      } else {
        battery -= 1;
        if (battery <= 20) {
          charging = true;
        }
      }
    }

    List<String> currentErrors = List.from(_telemetry.errors);
    bool emg = _telemetry.emergencyStop;

    if (_tick % 1000 == 800) {
      final errorType = (_tick ~/ 1000) % 5;
      switch (errorType) {
        case 0:
          if (!currentErrors.contains('Mất kết nối động cơ Nâng Trước')) {
            currentErrors.add('Mất kết nối động cơ Nâng Trước');
          }
          emg = true;
          break;
        case 1:
          if (!currentErrors.contains('Lỗi đồng bộ: Nâng không đều')) {
            currentErrors.add('Lỗi đồng bộ: Nâng không đều');
          }
          emg = true;
          break;
        case 2:
          if (!currentErrors.contains('Lỗi đồng bộ: Rẽ hướng không đều')) {
            currentErrors.add('Lỗi đồng bộ: Rẽ hướng không đều');
          }
          emg = true;
          break;
        case 3:
          if (!currentErrors.contains('Mất mạng cục bộ (Network timeout)')) {
            currentErrors.add('Mất mạng cục bộ (Network timeout)');
          }
          emg = true;
          break;
        case 4:
          if (!currentErrors.contains('Lỗi driver động cơ Di Chuyển')) {
            currentErrors.add('Lỗi driver động cơ Di Chuyển');
          }
          emg = true;
          break;
      }
    }

    if (sensors.pumperFront == true) {
      if (!currentErrors.contains('Lỗi va chạm Pumper trước')) {
        currentErrors.add('Lỗi va chạm Pumper trước');
      }
      emg = true;
    }
    if (sensors.pumperRear == true) {
      if (!currentErrors.contains('Lỗi va chạm Pumper sau')) {
        currentErrors.add('Lỗi va chạm Pumper sau');
      }
      emg = true;
    }
    if (sensors.lidarUpperZone == LidarZone.danger) {
      if (!currentErrors.contains('Lidar Upper Zone báo lỗi nguy hiểm')) {
        currentErrors.add('Lidar Upper Zone báo lỗi nguy hiểm');
      }
      emg = true;
    }
    if (sensors.lidarLowerZone == LidarZone.danger) {
      if (!currentErrors.contains('Lidar Lower Zone báo lỗi nguy hiểm')) {
        currentErrors.add('Lidar Lower Zone báo lỗi nguy hiểm');
      }
      emg = true;
    }

    _telemetry = _telemetry.copyWith(
      motors: motors,
      sensors: sensors,
      errors: currentErrors,
      emergencyStop: emg,
      timestamp: DateTime.now(),
      positionX: px,
      batteryLevel: battery,
      isCharging: charging,
    );
    _emitTelemetry();
  }

  void _applyCommand(ManualCommand command) {
    final motors = Map<String, MotorStatus>.from(_telemetry.motors);
    var sensors = _telemetry.sensors;
    var mode = _telemetry.mode;
    var emergencyStop = _telemetry.emergencyStop;
    var errors = _telemetry.errors;

    switch (command.type) {
      case ManualCommandType.setManualMode:
        mode = OhtMode.manual;
      case ManualCommandType.resetError:
        emergencyStop = false;
        errors = <String>[];
        sensors = sensors.copyWith(pumperFront: false, pumperRear: false);
      case ManualCommandType.emergencyStop:
        emergencyStop = true;
        for (final id in MotorIds.all) {
          motors[id] = _stoppedMotor(id);
        }
      case ManualCommandType.travelForward:
        _setMotorPair(
          motors,
          MotorIds.travelFront,
          MotorIds.travelRear,
          'forward',
          command.speed,
        );
      case ManualCommandType.travelBackward:
        _setMotorPair(
          motors,
          MotorIds.travelFront,
          MotorIds.travelRear,
          'backward',
          command.speed,
        );
      case ManualCommandType.travelStop:
        motors[MotorIds.travelFront] = _stoppedMotor(MotorIds.travelFront);
        motors[MotorIds.travelRear] = _stoppedMotor(MotorIds.travelRear);
      case ManualCommandType.steerLeft:
        // If already at left limit, keep limit active
        if (_steerFrontPositionM <= -1.0 || _steerRearPositionM <= -1.0) {
          sensors = sensors.copyWith(
            steerFrontLeft: true,
            steerRearLeft: true,
            steerFrontRight: false,
            steerRearRight: false,
          );
        } else {
          sensors = sensors.copyWith(
            steerFrontRight: false,
            steerRearRight: false,
          );
          motors[MotorIds.steerFront] = _runningMotor(
            MotorIds.steerFront,
            'left',
            command.speed,
          );
          motors[MotorIds.steerRear] = _runningMotor(
            MotorIds.steerRear,
            'left',
            command.speed,
          );
        }
      case ManualCommandType.steerRight:
        sensors = sensors.copyWith(steerFrontLeft: false, steerRearLeft: false);
        motors[MotorIds.steerFront] = _runningMotor(
          MotorIds.steerFront,
          'right',
          command.speed,
        );
        motors[MotorIds.steerRear] = _runningMotor(
          MotorIds.steerRear,
          'right',
          command.speed,
        );
      case ManualCommandType.steerStop:
        motors[MotorIds.steerFront] = _stoppedMotor(MotorIds.steerFront);
        motors[MotorIds.steerRear] = _stoppedMotor(MotorIds.steerRear);
      case ManualCommandType.hoistUp:
        // If already at top, keep upper limit active
        if (_hoistFrontPositionM <= 0.0 || _hoistRearPositionM <= 0.0) {
          sensors = sensors.copyWith(
            hoistFrontUpperLimit: true,
            hoistRearUpperLimit: true,
          );
        } else {
          sensors = sensors.copyWith(
            hoistFrontUpperLimit: false,
            hoistRearUpperLimit: false,
          );
          motors[MotorIds.hoistFront] = _runningMotor(
            MotorIds.hoistFront,
            'up',
            command.speed,
          );
          motors[MotorIds.hoistRear] = _runningMotor(
            MotorIds.hoistRear,
            'up',
            command.speed,
          );
        }
      case ManualCommandType.hoistDown:
        _hoistDownTicks = 0;
        sensors = sensors.copyWith(
          hoistFrontUpperLimit: false,
          hoistRearUpperLimit: false,
        );
        motors[MotorIds.hoistFront] = _runningMotor(
          MotorIds.hoistFront,
          'down',
          command.speed,
        );
        motors[MotorIds.hoistRear] = _runningMotor(
          MotorIds.hoistRear,
          'down',
          command.speed,
        );
      case ManualCommandType.hoistStop:
        motors[MotorIds.hoistFront] = _stoppedMotor(MotorIds.hoistFront);
        motors[MotorIds.hoistRear] = _stoppedMotor(MotorIds.hoistRear);
      case ManualCommandType.stopAll:
        for (final id in MotorIds.all) {
          motors[id] = _stoppedMotor(id);
        }
      case ManualCommandType.heartbeat:
        break;
    }

    _telemetry = _telemetry.copyWith(
      mode: mode,
      emergencyStop: emergencyStop,
      motors: motors,
      sensors: sensors,
      errors: errors,
      timestamp: DateTime.now(),
    );
  }

  void _setMotorPair(
    Map<String, MotorStatus> motors,
    String first,
    String second,
    String direction,
    int speed,
  ) {
    motors[first] = _runningMotor(first, direction, speed);
    motors[second] = _runningMotor(second, direction, speed);
  }

  void _updateHoistPosition(
    Map<String, MotorStatus> motors,
    String id,
    MotorStatus motor,
  ) {
    final pct = (motor.speed / 30.0).clamp(0.0, 100.0); // RPM → 0-100
    final delta = pct / 100.0 * 0.01;
    final sign = motor.direction == 'up' ? -1.0 : 1.0;
    final next = (_positionForMotor(id) + sign * delta)
        .clamp(0.0, 1.0)
        .toDouble();
    if (id == MotorIds.hoistFront) {
      _hoistFrontPositionM = next;
    } else if (id == MotorIds.hoistRear) {
      _hoistRearPositionM = next;
    }
    motors[id] = motor.copyWith(velocityMps: pct / 100.0, positionM: next);
  }

  void _updateTravelPosition(
    Map<String, MotorStatus> motors,
    String id,
    MotorStatus motor,
  ) {
    final pct = (motor.speed / 30.0).clamp(0.0, 100.0); // RPM → 0-100
    final delta = pct / 100.0 * 0.05;
    final sign = motor.direction == 'forward' ? 1.0 : -1.0;
    final next = (_positionForMotor(id) + sign * delta).toDouble();
    if (id == MotorIds.travelFront) {
      _travelFrontPositionM = next;
    } else if (id == MotorIds.travelRear) {
      _travelRearPositionM = next;
    }
    motors[id] = motor.copyWith(velocityMps: pct / 100.0, positionM: next);
  }

  void _updateSteerPosition(
    Map<String, MotorStatus> motors,
    String id,
    MotorStatus motor,
  ) {
    final pct = (motor.speed / 30.0).clamp(0.0, 100.0); // RPM → 0-100
    const delta = 0.5;
    final sign = motor.direction == 'left' ? -1.0 : 1.0;
    final next = (_positionForMotor(id) + sign * delta)
        .clamp(-1.0, 1.0)
        .toDouble();
    if (id == MotorIds.steerFront) {
      _steerFrontPositionM = next;
    } else if (id == MotorIds.steerRear) {
      _steerRearPositionM = next;
    }
    motors[id] = motor.copyWith(velocityMps: pct / 100.0, positionM: next);
  }

  MotorStatus _runningMotor(String id, String direction, int speed) {
    final clampedSpeed = speed.clamp(0, 100).toInt();
    final rpm = clampedSpeed * 30; // Simulate 0-3000 RPM from command %
    return MotorStatus(
      id: id,
      state: MotorState.running,
      direction: direction,
      speed: rpm,
      velocityMps: clampedSpeed / 100.0, // Keep m/s for physics
      positionM: _positionForMotor(id),
    );
  }

  MotorStatus _stoppedMotor(String id) {
    return MotorStatus(
      id: id,
      state: MotorState.stopped,
      direction: 'none',
      speed: 0,
      velocityMps: 0,
      positionM: _positionForMotor(id),
    );
  }

  double _positionForMotor(String id) {
    if (id == MotorIds.travelFront) return _travelFrontPositionM;
    if (id == MotorIds.travelRear) return _travelRearPositionM;
    if (id == MotorIds.steerFront) return _steerFrontPositionM;
    if (id == MotorIds.steerRear) return _steerRearPositionM;
    if (id == MotorIds.hoistFront) return _hoistFrontPositionM;
    if (id == MotorIds.hoistRear) return _hoistRearPositionM;
    return 0;
  }

  void _emitTelemetry() {
    _telemetryController.add(_telemetry);
  }

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
