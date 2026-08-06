import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/constants/oht_ids.dart';
import 'package:flutter_application_1/core/enums/connection_phase.dart';
import 'package:flutter_application_1/core/enums/event_severity.dart';
import 'package:flutter_application_1/core/utils/app_update_service.dart';
import 'package:flutter_application_1/core/enums/lidar_zone.dart';
import 'package:flutter_application_1/core/enums/manual_command_type.dart';
import 'package:flutter_application_1/core/enums/motor_state.dart';
import 'package:flutter_application_1/core/enums/oht_mode.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/alarm_event.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/connection_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/manual_command.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/motor_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/oht_telemetry.dart';
import 'package:flutter_application_1/features/oht_manual/domain/entities/sensor_status.dart';
import 'package:flutter_application_1/features/oht_manual/domain/repositories/oht_communication_service.dart';
import 'package:flutter_application_1/features/oht_manual/presentation/controllers/oht_manual_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  ManualCommand command(ManualCommandType type, {int speed = 30}) {
    return ManualCommand(
      type: type,
      target: 'system',
      speed: speed,
      requestId: 'cmd_0001',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1710000000000),
    );
  }

  test('travel forward 30% serializes to 0.15 mps', () {
    final forward = command(ManualCommandType.travelForward).toJson();

    expect(forward['type'], 'manual_cmd');
    expect(forward['request_id'], 'cmd_0001');
    expect(forward['action'], 'travel_set');
    expect(forward['target'], 'travel');
    expect(forward['unit'], 'mps');
    expect(forward['value'], closeTo(0.15, 0.0001));
    expect(forward['deadman'], isTrue);
  });

  test('travel backward 30% serializes to -0.15 mps', () {
    final backward = command(ManualCommandType.travelBackward).toJson();

    expect(backward['action'], 'travel_set');
    expect(backward['target'], 'travel');
    expect(backward['unit'], 'mps');
    expect(backward['value'], closeTo(-0.15, 0.0001));
    expect(backward['deadman'], isTrue);
  });

  test('hoist up 75% serializes to +900 rpm', () {
    final up = command(ManualCommandType.hoistUp, speed: 75).toJson();

    expect(up['action'], 'hoist_move');
    expect(up['target'], 'hoist');
    expect(up['unit'], 'rpm');
    expect(up['value'], closeTo(900.0, 0.0001));
    expect(up['deadman'], isTrue);
  });

  test('hoist down 75% serializes to -900 rpm', () {
    final down = command(ManualCommandType.hoistDown, speed: 75).toJson();

    expect(down['action'], 'hoist_move');
    expect(down['target'], 'hoist');
    expect(down['unit'], 'rpm');
    expect(down['value'], closeTo(-900.0, 0.0001));
    expect(down['deadman'], isTrue);
  });

  test('steer left does not send unit/value', () {
    final left = command(ManualCommandType.steerLeft).toJson();

    expect(left['action'], 'steer_left');
    expect(left['target'], 'steering');
    expect(left.containsKey('unit'), isFalse);
    expect(left.containsKey('value'), isFalse);
    expect(left['deadman'], isTrue);
  });

  test('steer right does not send unit/value', () {
    final right = command(ManualCommandType.steerRight).toJson();

    expect(right['action'], 'steer_right');
    expect(right['target'], 'steering');
    expect(right.containsKey('unit'), isFalse);
    expect(right.containsKey('value'), isFalse);
    expect(right['deadman'], isTrue);
  });

  test('steer stop does not send unit/value or deadman', () {
    final stop = command(ManualCommandType.steerStop).toJson();

    expect(stop['action'], 'steer_stop');
    expect(stop['target'], 'steering');
    expect(stop.containsKey('unit'), isFalse);
    expect(stop.containsKey('value'), isFalse);
    expect(stop.containsKey('deadman'), isFalse);
  });

  test('AlarmEvent operator field serializes and deserializes correctly', () {
    final event = AlarmEvent.now(
      severity: EventSeverity.command,
      message: 'Test command',
      operator: 'Thaco_Op1',
    );

    final json = event.toJson();
    expect(json['operator'], 'Thaco_Op1');

    final restored = AlarmEvent.fromJson(json);
    expect(restored.operator, 'Thaco_Op1');
  });

  test('AlarmEvent operator defaults to System when omitted in json', () {
    final json = {
      'id': 'evt_123',
      'severity': 'info',
      'message': 'System event',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final event = AlarmEvent.fromJson(json);
    expect(event.operator, 'System');
  });

  test('AppVersionInfo isUpdateAvailable is false when app is on latest version', () {
    const infoSame = AppVersionInfo(
      latestVersion: '1.0.1',
      buildNumber: 2,
      releaseNotes: 'Test',
      downloadUrls: {},
    );
    expect(infoSame.isUpdateAvailable, isFalse);

    const infoOlder = AppVersionInfo(
      latestVersion: '1.0.0',
      buildNumber: 1,
      releaseNotes: 'Test',
      downloadUrls: {},
    );
    expect(infoOlder.isUpdateAvailable, isFalse);

    const infoNewer = AppVersionInfo(
      latestVersion: '1.0.9',
      buildNumber: 10,
      releaseNotes: 'Test',
      downloadUrls: {},
    );
    expect(infoNewer.isUpdateAvailable, isTrue);
  });

  test('stopAll serializes correctly', () {
    final stopAll = command(ManualCommandType.stopAll).toJson();

    expect(stopAll['action'], 'stop_all');
    expect(stopAll['target'], 'all');
    expect(stopAll.containsKey('unit'), isFalse);
    expect(stopAll.containsKey('value'), isFalse);
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

  test('deadman heartbeat serializes correctly', () {
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
        'mode': 1,
        'oht_state': 1,
        'error_code': 'E00000',
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
        'bat_soc': 85,
        'bat_charging': true,
        'qr_position_mm': 1250,
      },
    });

    expect(telemetry.connected, isTrue);
    expect(telemetry.mode.name, 'manual');
    expect(telemetry.isManualMode, isTrue);
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
    expect(telemetry.batteryLevel, 85);
    expect(telemetry.isCharging, isTrue);
    expect(telemetry.positionX, closeTo(1.250, 0.001));
    expect(telemetry.errors, isEmpty);
  });

  test('firmware state with error_code and oht_state=3 sets error mode', () {
    final telemetry = OhtTelemetry.fromFirmwareState({
      'type': 'state',
      'state': {
        'online': true,
        'mode': 1,
        'oht_state': 3,
        'error_code': 'E01234',
        'm0_connected': true,
        'm0_running': false,
        'm0_speed': 0,
        'm0_pos': 0,
        'm1_connected': true,
        'm1_running': false,
        'm1_speed': 0,
        'm1_pos': 0,
        'm2_connected': true,
        'm2_running': false,
        'm2_speed': 0,
        'm2_pos': 0,
        'm3_connected': true,
        'm3_running': false,
        'm3_speed': 0,
        'm3_pos': 0,
        'm4_connected': true,
        'm4_running': false,
        'm4_speed': 0,
        'm4_pos': 0,
        'm5_connected': true,
        'm5_running': false,
        'm5_speed': 0,
        'm5_pos': 0,
        'lidar_upper_level': 0,
        'lidar_lower_level': 0,
        'bat_soc': 50,
        'bat_charging': false,
      },
    });

    expect(telemetry.hasCriticalError, isTrue);
    expect(telemetry.errors, contains('E01234'));
    expect(telemetry.emergencyStop, isFalse);
  });

  test('firmware state with oht_state=4 sets emergency stop', () {
    final telemetry = OhtTelemetry.fromFirmwareState({
      'type': 'state',
      'state': {
        'online': true,
        'mode': 1,
        'oht_state': 4,
        'error_code': 'E00000',
        'm0_connected': true,
        'm0_running': false,
        'm0_speed': 0,
        'm0_pos': 0,
        'm1_connected': true,
        'm1_running': false,
        'm1_speed': 0,
        'm1_pos': 0,
        'm2_connected': true,
        'm2_running': false,
        'm2_speed': 0,
        'm2_pos': 0,
        'm3_connected': true,
        'm3_running': false,
        'm3_speed': 0,
        'm3_pos': 0,
        'm4_connected': true,
        'm4_running': false,
        'm4_speed': 0,
        'm4_pos': 0,
        'm5_connected': true,
        'm5_running': false,
        'm5_speed': 0,
        'm5_pos': 0,
        'lidar_upper_level': 0,
        'lidar_lower_level': 0,
        'bat_soc': 50,
        'bat_charging': false,
      },
    });

    expect(telemetry.emergencyStop, isTrue);
    expect(telemetry.hasCriticalError, isTrue);
  });

  test('unified steer controller sends single steer command', () async {
    final service = _RecordingOhtService();
    final controller = OhtManualController(service: service);
    addTearDown(controller.dispose);
    service.emitReadyTelemetry();
    await Future<void>.delayed(Duration.zero);

    await controller.sendUnifiedSteer(left: true);

    expect(service.commands.length, 1);
    expect(service.commands.first.type, ManualCommandType.steerLeft);

    service.commands.clear();
    await controller.sendUnifiedSteer(left: false);

    expect(service.commands.length, 1);
    expect(service.commands.first.type, ManualCommandType.steerRight);
  });

  test('unified hoist controller sends single hoist command', () async {
    final service = _RecordingOhtService();
    final controller = OhtManualController(service: service);
    addTearDown(controller.dispose);
    service.emitReadyTelemetry();
    await Future<void>.delayed(Duration.zero);

    await controller.sendUnifiedHoist(up: true);

    expect(service.commands.length, 1);
    expect(service.commands.first.type, ManualCommandType.hoistUp);

    service.commands.clear();
    await controller.sendUnifiedHoist(up: false);

    expect(service.commands.length, 1);
    expect(service.commands.first.type, ManualCommandType.hoistDown);
  });

  test('no front/rear commands are referenced in the codebase', () {
    // Verify that old front/rear enum values no longer exist
    expect(
      ManualCommandType.values.any((t) => t.wireName.contains('front')),
      isFalse,
    );
    expect(
      ManualCommandType.values.any((t) => t.wireName.contains('rear')),
      isFalse,
    );
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

  void emitReadyTelemetry() {
    _telemetryController.add(
      OhtTelemetry(
        mode: OhtMode.manual,
        connected: true,
        emergencyStop: false,
        motors: {for (final id in MotorIds.all) id: MotorStatus.stopped(id)},
        sensors: SensorStatus.noData(),
        errors: const [],
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> connect({required String endpoint}) async {
    _status = _status.copyWith(endpoint: endpoint, changedAt: DateTime.now());
    _statusController.add(_status);
    // Emit initial telemetry with manual mode, no limits so commands pass
    emitReadyTelemetry();
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
