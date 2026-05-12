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
  int _hoistFrontUpTicks = 0;
  int _hoistRearUpTicks = 0;
  int _steerFrontLeftTicks = 0;
  int _steerFrontRightTicks = 0;
  int _steerRearLeftTicks = 0;
  int _steerRearRightTicks = 0;

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

    final frontHoist = motors[MotorIds.hoistFront];
    if (frontHoist?.state == MotorState.running &&
        frontHoist?.direction == 'up') {
      _hoistFrontUpTicks++;
      if (_hoistFrontUpTicks >= 8) {
        motors[MotorIds.hoistFront] = MockOhtData.stoppedMotor(
          MotorIds.hoistFront,
        );
        sensors = sensors.copyWith(hoistFrontUpperLimit: true);
      }
    } else if (frontHoist?.state == MotorState.running && frontHoist?.direction == 'down') {
      _hoistFrontUpTicks = 0;
      sensors = sensors.copyWith(hoistFrontUpperLimit: false);
    }

    final frontSteer = motors[MotorIds.steerFront];
    if (frontSteer?.state == MotorState.running && frontSteer?.direction == 'left') {
      _steerFrontRightTicks = 0;
      sensors = sensors.copyWith(steerFrontRight: false);
      _steerFrontLeftTicks++;
      if (_steerFrontLeftTicks >= 8) {
        motors[MotorIds.steerFront] = MockOhtData.stoppedMotor(MotorIds.steerFront);
        sensors = sensors.copyWith(steerFrontLeft: true);
      }
    } else if (frontSteer?.state == MotorState.running && frontSteer?.direction == 'right') {
      _steerFrontLeftTicks = 0;
      sensors = sensors.copyWith(steerFrontLeft: false);
      _steerFrontRightTicks++;
      if (_steerFrontRightTicks >= 8) {
        motors[MotorIds.steerFront] = MockOhtData.stoppedMotor(MotorIds.steerFront);
        sensors = sensors.copyWith(steerFrontRight: true);
      }
    }

    final rearHoist = motors[MotorIds.hoistRear];
    if (rearHoist?.state == MotorState.running &&
        rearHoist?.direction == 'up') {
      _hoistRearUpTicks++;
      if (_hoistRearUpTicks >= 8) {
        motors[MotorIds.hoistRear] = MockOhtData.stoppedMotor(
          MotorIds.hoistRear,
        );
        sensors = sensors.copyWith(hoistRearUpperLimit: true);
      }
    } else if (rearHoist?.state == MotorState.running && rearHoist?.direction == 'down') {
      _hoistRearUpTicks = 0;
      sensors = sensors.copyWith(hoistRearUpperLimit: false);
    }

    final rearSteer = motors[MotorIds.steerRear];
    if (rearSteer?.state == MotorState.running && rearSteer?.direction == 'left') {
      _steerRearRightTicks = 0;
      sensors = sensors.copyWith(steerRearRight: false);
      _steerRearLeftTicks++;
      if (_steerRearLeftTicks >= 8) {
        motors[MotorIds.steerRear] = MockOhtData.stoppedMotor(MotorIds.steerRear);
        sensors = sensors.copyWith(steerRearLeft: true);
      }
    } else if (rearSteer?.state == MotorState.running && rearSteer?.direction == 'right') {
      _steerRearLeftTicks = 0;
      sensors = sensors.copyWith(steerRearLeft: false);
      _steerRearRightTicks++;
      if (_steerRearRightTicks >= 8) {
        motors[MotorIds.steerRear] = MockOhtData.stoppedMotor(MotorIds.steerRear);
        sensors = sensors.copyWith(steerRearRight: true);
      }
    }

    double px = _telemetry.positionX;
    final travelFront = motors[MotorIds.travelFront];
    if (travelFront?.state == MotorState.running) {
      px += (travelFront!.direction == 'forward' ? 1 : -1) * (travelFront.speed / 100.0) * 0.1;
    }
    final travelRear = motors[MotorIds.travelRear];
    if (travelRear?.state == MotorState.running) {
      px += (travelRear!.direction == 'forward' ? 1 : -1) * (travelRear.speed / 100.0) * 0.1;
    }

    int battery = _telemetry.batteryLevel;
    bool charging = _telemetry.isCharging;
    if (_tick % 10 == 0) {
      if (charging) {
        battery += 1;
        if (battery >= 100) { battery = 100; charging = false; }
      } else {
        battery -= 1;
        if (battery <= 20) { charging = true; }
      }
    }

    List<String> currentErrors = List.from(_telemetry.errors);
    bool emg = _telemetry.emergencyStop;

    if (_tick % 1000 == 800) {
      final errorType = (_tick ~/ 1000) % 5;
      switch (errorType) {
        case 0:
          if (!currentErrors.contains('Mất kết nối động cơ Nâng Trước')) currentErrors.add('Mất kết nối động cơ Nâng Trước');
          emg = true;
          break;
        case 1:
          if (!currentErrors.contains('Lỗi đồng bộ: Nâng không đều')) currentErrors.add('Lỗi đồng bộ: Nâng không đều');
          emg = true;
          break;
        case 2:
          if (!currentErrors.contains('Lỗi đồng bộ: Rẽ hướng không đều')) currentErrors.add('Lỗi đồng bộ: Rẽ hướng không đều');
          emg = true;
          break;
        case 3:
          if (!currentErrors.contains('Mất mạng cục bộ (Network timeout)')) currentErrors.add('Mất mạng cục bộ (Network timeout)');
          emg = true;
          break;
        case 4:
          if (!currentErrors.contains('Lỗi driver động cơ Di Chuyển')) currentErrors.add('Lỗi driver động cơ Di Chuyển');
          emg = true;
          break;
      }
    }

    if (sensors.pumperFront == true) {
      if (!currentErrors.contains('Lỗi va chạm Pumper trước')) currentErrors.add('Lỗi va chạm Pumper trước');
      emg = true;
    }
    if (sensors.pumperRear == true) {
      if (!currentErrors.contains('Lỗi va chạm Pumper sau')) currentErrors.add('Lỗi va chạm Pumper sau');
      emg = true;
    }
    if (sensors.lidarUpperZone == LidarZone.danger) {
      if (!currentErrors.contains('Lidar Upper Zone báo lỗi nguy hiểm')) currentErrors.add('Lidar Upper Zone báo lỗi nguy hiểm');
      emg = true;
    }
    if (sensors.lidarLowerZone == LidarZone.danger) {
      if (!currentErrors.contains('Lidar Lower Zone báo lỗi nguy hiểm')) currentErrors.add('Lidar Lower Zone báo lỗi nguy hiểm');
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
          motors[id] = MockOhtData.stoppedMotor(id);
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
      case ManualCommandType.travelFrontForward:
        motors[MotorIds.travelFront] = _runningMotor(
          MotorIds.travelFront,
          'forward',
          command.speed,
        );
      case ManualCommandType.travelFrontBackward:
        motors[MotorIds.travelFront] = _runningMotor(
          MotorIds.travelFront,
          'backward',
          command.speed,
        );
      case ManualCommandType.travelRearForward:
        motors[MotorIds.travelRear] = _runningMotor(
          MotorIds.travelRear,
          'forward',
          command.speed,
        );
      case ManualCommandType.travelRearBackward:
        motors[MotorIds.travelRear] = _runningMotor(
          MotorIds.travelRear,
          'backward',
          command.speed,
        );
      case ManualCommandType.travelStop:
        motors[MotorIds.travelFront] = MockOhtData.stoppedMotor(
          MotorIds.travelFront,
        );
        motors[MotorIds.travelRear] = MockOhtData.stoppedMotor(
          MotorIds.travelRear,
        );
      case ManualCommandType.steerFrontLeft:
        _steerFrontLeftTicks = 0; _steerFrontRightTicks = 0;
        sensors = sensors.copyWith(steerFrontRight: false);
        motors[MotorIds.steerFront] = _runningMotor(
          MotorIds.steerFront,
          'left',
          command.speed,
        );
      case ManualCommandType.steerFrontRight:
        _steerFrontLeftTicks = 0; _steerFrontRightTicks = 0;
        sensors = sensors.copyWith(steerFrontLeft: false);
        motors[MotorIds.steerFront] = _runningMotor(
          MotorIds.steerFront,
          'right',
          command.speed,
        );
      case ManualCommandType.steerRearLeft:
        _steerRearLeftTicks = 0; _steerRearRightTicks = 0;
        sensors = sensors.copyWith(steerRearRight: false);
        motors[MotorIds.steerRear] = _runningMotor(
          MotorIds.steerRear,
          'left',
          command.speed,
        );
      case ManualCommandType.steerRearRight:
        _steerRearLeftTicks = 0; _steerRearRightTicks = 0;
        sensors = sensors.copyWith(steerRearLeft: false);
        motors[MotorIds.steerRear] = _runningMotor(
          MotorIds.steerRear,
          'right',
          command.speed,
        );
      case ManualCommandType.steerStop:
        motors[MotorIds.steerFront] = MockOhtData.stoppedMotor(
          MotorIds.steerFront,
        );
        motors[MotorIds.steerRear] = MockOhtData.stoppedMotor(
          MotorIds.steerRear,
        );
      case ManualCommandType.hoistFrontUp:
        _hoistFrontUpTicks = 0;
        sensors = sensors.copyWith(hoistFrontUpperLimit: false);
        motors[MotorIds.hoistFront] = _runningMotor(
          MotorIds.hoistFront,
          'up',
          command.speed,
        );
      case ManualCommandType.hoistFrontDown:
        _hoistFrontUpTicks = 0;
        sensors = sensors.copyWith(hoistFrontUpperLimit: false);
        motors[MotorIds.hoistFront] = _runningMotor(
          MotorIds.hoistFront,
          'down',
          command.speed,
        );
      case ManualCommandType.hoistRearUp:
        _hoistRearUpTicks = 0;
        sensors = sensors.copyWith(hoistRearUpperLimit: false);
        motors[MotorIds.hoistRear] = _runningMotor(
          MotorIds.hoistRear,
          'up',
          command.speed,
        );
      case ManualCommandType.hoistRearDown:
        _hoistRearUpTicks = 0;
        sensors = sensors.copyWith(hoistRearUpperLimit: false);
        motors[MotorIds.hoistRear] = _runningMotor(
          MotorIds.hoistRear,
          'down',
          command.speed,
        );
      case ManualCommandType.hoistStop:
        motors[MotorIds.hoistFront] = MockOhtData.stoppedMotor(
          MotorIds.hoistFront,
        );
        motors[MotorIds.hoistRear] = MockOhtData.stoppedMotor(
          MotorIds.hoistRear,
        );
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

  MotorStatus _runningMotor(String id, String direction, int speed) {
    return MotorStatus(
      id: id,
      state: MotorState.running,
      direction: direction,
      speed: speed.clamp(0, 100).toInt(),
    );
  }

  void _emitTelemetry() {
    _telemetryController.add(_telemetry);
  }

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
