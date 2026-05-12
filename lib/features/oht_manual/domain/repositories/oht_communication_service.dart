import '../entities/alarm_event.dart';
import '../entities/connection_status.dart';
import '../entities/manual_command.dart';
import '../entities/oht_telemetry.dart';

abstract class OhtCommunicationService {
  Stream<OhtTelemetry> get telemetryStream;
  Stream<ConnectionStatus> get connectionStatusStream;
  Stream<AlarmEvent> get eventStream;
  ConnectionStatus get status;

  Future<void> connect({required String endpoint});
  Future<void> disconnect();
  Future<void> sendCommand(ManualCommand command);
  void dispose();
}
