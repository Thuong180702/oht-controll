import 'dart:async';

import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../domain/entities/alarm_event.dart';
import '../../domain/entities/connection_status.dart';
import '../../domain/entities/manual_command.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/repositories/oht_communication_service.dart';

class MqttOhtCommunicationService implements OhtCommunicationService {
  final _telemetryController = StreamController<OhtTelemetry>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<AlarmEvent>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected();

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
    _status = ConnectionStatus(
      phase: ConnectionPhase.error,
      endpoint: endpoint,
      message: 'MQTT is a placeholder. Add an MQTT package and topics later.',
      changedAt: DateTime.now(),
    );
    _statusController.add(_status);
    _eventController.add(
      AlarmEvent.now(
        severity: EventSeverity.warning,
        message: 'MQTT service is not implemented yet',
      ),
    );
    throw UnsupportedError('MQTT service is not implemented yet');
  }

  @override
  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnected(endpoint: _status.endpoint);
    _statusController.add(_status);
  }

  @override
  Future<void> sendCommand(ManualCommand command) async {
    throw UnsupportedError('MQTT service is not implemented yet');
  }

  @override
  void dispose() {
    _telemetryController.close();
    _statusController.close();
    _eventController.close();
  }
}
