// dart:html WebSocket implementation for web platform.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../domain/entities/alarm_event.dart';
import '../../domain/entities/connection_status.dart';
import '../../domain/entities/manual_command.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/repositories/oht_communication_service.dart';
import '../models/oht_message_type.dart';

OhtCommunicationService createWebSocketService() =>
    WebWebSocketOhtCommunicationService();

class WebWebSocketOhtCommunicationService implements OhtCommunicationService {
  final _telemetryController = StreamController<OhtTelemetry>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _eventController = StreamController<AlarmEvent>.broadcast();

  html.WebSocket? _socket;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  ConnectionStatus _status = ConnectionStatus.disconnected();
  bool _manualClose = false;

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
    await disconnect();
    _manualClose = false;
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.connecting,
        endpoint: endpoint,
        message: 'Connecting to OHT WebSocket',
        changedAt: DateTime.now(),
      ),
    );

    try {
      final socket = html.WebSocket(endpoint);
      _socket = socket;

      final openCompleter = Completer<void>();

      _subscriptions.add(
        socket.onOpen.listen((_) {
          if (!openCompleter.isCompleted) openCompleter.complete();
          _emitStatus(
            ConnectionStatus(
              phase: ConnectionPhase.connected,
              endpoint: endpoint,
              message: 'Connected to OHT WebSocket',
              changedAt: DateTime.now(),
            ),
          );
          // Request initial state immediately after connecting
          socket.send('{"type":"get_state"}');
        }),
      );

      _subscriptions.add(
        socket.onMessage.listen((event) {
          _handleMessage(event.data);
        }),
      );

      _subscriptions.add(
        socket.onError.listen((_) {
          if (!openCompleter.isCompleted) {
            openCompleter.completeError(
              StateError('WebSocket connect failed'),
            );
          }
          _handleSocketError('WebSocket error');
        }),
      );

      _subscriptions.add(
        socket.onClose.listen((_) {
          if (!openCompleter.isCompleted) {
            openCompleter.completeError(
              StateError('WebSocket closed before open'),
            );
          }
          _handleSocketDone();
        }),
      );

      await openCompleter.future.timeout(const Duration(seconds: 5));
    } catch (error) {
      _emitStatus(
        ConnectionStatus(
          phase: ConnectionPhase.error,
          endpoint: endpoint,
          message: 'WebSocket connect failed: $error',
          changedAt: DateTime.now(),
        ),
      );
      _eventController.add(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'WebSocket connect failed: $error',
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _manualClose = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _socket?.close();
    _socket = null;
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.disconnected,
        endpoint: _status.endpoint,
        message: 'Disconnected',
        changedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> sendCommand(ManualCommand command) async {
    final socket = _socket;
    if (socket == null || socket.readyState != html.WebSocket.OPEN) {
      throw StateError('WebSocket is not connected');
    }
    socket.send(jsonEncode(command.toJson()));
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _socket?.close();
    _telemetryController.close();
    _statusController.close();
    _eventController.close();
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Message is not a JSON object');
      }

      switch (OhtMessageType.fromWire(decoded['type'] as String?)) {
        case OhtMessageType.state:
          _telemetryController.add(OhtTelemetry.fromFirmwareState(decoded));
        case OhtMessageType.telemetry:
          _telemetryController.add(OhtTelemetry.fromJson(decoded));
        case OhtMessageType.manualAck:
          _handleManualAck(decoded);
        case OhtMessageType.ack:
          _eventController.add(
            AlarmEvent.now(
              severity: EventSeverity.ack,
              message:
                  'ACK ${decoded['command'] ?? ''} ${decoded['requestId'] ?? ''}',
            ),
          );
        case OhtMessageType.nack:
          _eventController.add(
            AlarmEvent.now(
              severity: EventSeverity.nack,
              message:
                  'NACK ${decoded['command'] ?? ''} ${decoded['reason'] ?? ''}',
            ),
          );
        case OhtMessageType.event:
          _eventController.add(
            AlarmEvent.now(
              severity: EventSeverity.info,
              message: decoded['message']?.toString() ?? 'OHT event',
            ),
          );
        case OhtMessageType.unknown:
          _eventController.add(
            AlarmEvent.now(
              severity: EventSeverity.warning,
              message: 'Ignored unknown WebSocket message type',
            ),
          );
      }
    } catch (error) {
      _eventController.add(
        AlarmEvent.now(
          severity: EventSeverity.warning,
          message: 'Invalid WebSocket payload: $error',
        ),
      );
    }
  }

  void _handleManualAck(Map<String, dynamic> decoded) {
    final status = decoded['status']?.toString() ?? '';
    final action = decoded['action']?.toString() ?? '';
    final requestId = decoded['request_id']?.toString() ?? '';
    final reason = decoded['reason']?.toString() ?? '';
    final message = decoded['message']?.toString() ?? '';
    final accepted = status == 'queued' || status == 'executed';
    final details = <String>[
      accepted ? 'ACK' : 'NACK',
      if (action.isNotEmpty) action,
      if (requestId.isNotEmpty) requestId,
      if (reason.isNotEmpty) reason,
      if (message.isNotEmpty && message != reason) message,
    ].join(' ');

    _eventController.add(
      AlarmEvent.now(
        severity: accepted ? EventSeverity.ack : EventSeverity.nack,
        message: details.isEmpty ? 'Manual command acknowledgement' : details,
      ),
    );
  }

  void _handleSocketError(Object error) {
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.error,
        endpoint: _status.endpoint,
        message: 'WebSocket error: $error',
        changedAt: DateTime.now(),
      ),
    );
    _eventController.add(
      AlarmEvent.now(
        severity: EventSeverity.critical,
        message: 'WebSocket error: $error',
      ),
    );
  }

  void _handleSocketDone() {
    if (_manualClose) {
      return;
    }
    _emitStatus(
      ConnectionStatus(
        phase: ConnectionPhase.disconnected,
        endpoint: _status.endpoint,
        message: 'WebSocket closed by remote OHT',
        changedAt: DateTime.now(),
      ),
    );
    _eventController.add(
      AlarmEvent.now(
        severity: EventSeverity.warning,
        message: 'WebSocket closed by remote OHT',
      ),
    );
  }

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}
