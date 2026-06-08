import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/constants/oht_ids.dart';
import 'package:flutter_application_1/core/enums/connection_phase.dart';
import 'package:flutter_application_1/core/enums/lidar_zone.dart';
import 'package:flutter_application_1/core/enums/manual_command_type.dart';
import 'package:flutter_application_1/core/enums/motor_state.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/alarm_event.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/connection_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/manual_command.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/oht_telemetry.dart';
import 'package:flutter_application_1/features/oht_manual/domain/repositories/oht_communication_service.dart';
import 'package:flutter_application_1/features/oht_manual/presentation/controllers/oht_manual_controller.dart';

void main() {
  ManualCommand command(ManualCommandType type, {int speed = 30}) {
    return ManualCommand(
      type: type,
      target: 'both',
      speed: speed,
      requestId: 'cmd_0001',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1710000000000),
    );
  }

  test('travel commands serialize to firmware manual_cmd using mps', () {
    final forward = command(ManualCommandType.travelForward).toJson();

    expect(forward['type'], 'manual_cmd');
    expect(forward['request_id'], 'cmd_0001');
    expect(forward['action'], 'travel_set');
    expect(forward['target'], 'travel');
    expect(forward['unit'], 'mps');
    expect(forward['value'], closeTo(0.30, 0.0001));
    expect(forward['deadman'], isTrue);

    final backward = command(ManualCommandType.travelBackward).toJson();
    expect(backward['action'], 'travel_set');
    expect(backward['unit'], 'mps');
    expect(backward['value'], closeTo(-0.30, 0.0001));
  });

  test('hoist commands serialize to firmware manual_cmd using mm', () {
    final up = command(ManualCommandType.hoistFrontUp, speed: 75).toJson();
    expect(up['action'], 'hoist_move');
    expect(up['target'], 'hoist');
    expect(up['unit'], 'mm');
    expect(up['value'], closeTo(0.0, 0.0001));

    final down = command(ManualCommandType.hoistRearDown, speed: 75).toJson();
    expect(down['action'], 'hoist_move');
    expect(down['target'], 'hoist');
    expect(down['unit'], 'mm');
    expect(down['value'], closeTo(75.0, 0.0001));
  });

  test('system commands serialize to firmware action names', () {
    expect(
      command(ManualCommandType.emergencyStop).toJson()['action'],
      'estop',
    );
    expect(
      command(ManualCommandType.resetError).toJson()['action'],
      'reset_all_faults',
    );
    expect(
      command(ManualCommandType.setManualMode).toJson()['action'],
      'mode_manual',
    );
  });

  test('deadman heartbeat serializes to firmware action name', () {
    final heartbeat = command(ManualCommandType.heartbeat).toJson();

    expect(heartbeat['type'], 'manual_cmd');
    expect(heartbeat['request_id'], 'cmd_0001');
    expect(heartbeat['action'], 'heartbeat');
    expect(heartbeat.containsKey('target'), isFalse);
    expect(heartbeat.containsKey('unit'), isFalse);
    expect(heartbeat.containsKey('value'), isFalse);
  });

  test(
    'controller sends deadman heartbeat while motion command is held',
    () async {
      final service = _RecordingOhtService();
      final controller = OhtManualController(service: service);
      addTearDown(controller.dispose);

      await controller.sendManualCommand(
        ManualCommandType.travelForward,
        speedOverride: 30,
      );
      await Future<void>.delayed(const Duration(milliseconds: 320));
      await controller.sendManualCommand(ManualCommandType.travelStop);

      final actions = service.commands
          .map((command) => command.toJson()['action'])
          .toList(growable: false);
      expect(actions.first, 'travel_set');
      expect(actions, contains('heartbeat'));
      expect(actions.last, 'travel_stop');

      final commandCountAfterStop = service.commands.length;
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(service.commands.length, commandCountAfterStop);
    },
  );

  test('firmware state message maps six motors into telemetry', () {
    final telemetry = OhtTelemetry.fromFirmwareState({
      'type': 'state',
      'state': {
        'online': true,
        'm0_connected': true,
        'm0_running': false,
        'm0_speed': 0,
        'm0_pos': 10,
        'm1_connected': true,
        'm1_running': true,
        'm1_speed': 12,
        'm1_pos': 20,
        'm2_connected': true,
        'm2_running': true,
        'm2_speed': 34,
        'm2_pos': 30,
        'm3_connected': true,
        'm3_running': false,
        'm3_speed': 0,
        'm3_pos': 40,
        'm4_connected': true,
        'm4_running': true,
        'm4_speed': 5,
        'm4_pos': 50,
        'm5_connected': false,
        'm5_running': false,
        'm5_speed': 0,
        'm5_pos': 60,
        'lidar_upper_level': 2,
        'lidar_lower_level': 1,
        'bumper_front': true,
        'bumper_rear': false,
        'steer_front_left': true,
        'steer_front_right': false,
        'steer_rear_left': false,
        'steer_rear_right': true,
        'hoist_front_upper_limit': true,
        'hoist_rear_upper_limit': false,
        'qr_ready': false,
        'qr_valid': false,
      },
    });

    expect(telemetry.connected, isTrue);
    expect(telemetry.motors[MotorIds.hoistFront]!.state, MotorState.stopped);
    expect(telemetry.motors[MotorIds.hoistRear]!.state, MotorState.running);
    expect(telemetry.motors[MotorIds.travelFront]!.state, MotorState.running);
    expect(telemetry.motors[MotorIds.travelRear]!.state, MotorState.stopped);
    expect(telemetry.motors[MotorIds.steerFront]!.state, MotorState.running);
    expect(telemetry.motors[MotorIds.steerRear]!.warning, 'disconnected');
    expect(telemetry.sensors.lidarUpperZone, LidarZone.danger);
    expect(telemetry.sensors.lidarLowerZone, LidarZone.warning);
    expect(telemetry.sensors.pumperFront, isTrue);
    expect(telemetry.sensors.pumperRear, isFalse);
    expect(telemetry.sensors.steerFrontLeft, isTrue);
    expect(telemetry.sensors.steerRearRight, isTrue);
    expect(telemetry.sensors.hoistFrontUpperLimit, isTrue);
    expect(telemetry.sensors.hoistRearUpperLimit, isFalse);
  });
}

class _RecordingOhtService implements OhtCommunicationService {
  final _telemetryController = StreamController<OhtTelemetry>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<AlarmEvent>.broadcast();
  final List<ManualCommand> commands = <ManualCommand>[];

  ConnectionStatus _status = ConnectionStatus(
    phase: ConnectionPhase.connected,
    endpoint: AppConstants.defaultWebSocketUrl,
    message: 'Connected',
    changedAt: DateTime.now(),
  );

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
    _status = _status.copyWith(endpoint: endpoint, changedAt: DateTime.now());
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = _status.copyWith(
      phase: ConnectionPhase.disconnected,
      changedAt: DateTime.now(),
    );
    _statusController.add(_status);
  }

  @override
  Future<void> sendCommand(ManualCommand command) async {
    commands.add(command);
  }

  @override
  void dispose() {
    _telemetryController.close();
    _statusController.close();
    _eventController.close();
  }
}
