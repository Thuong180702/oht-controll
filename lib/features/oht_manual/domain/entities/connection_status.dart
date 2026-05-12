import '../../../../core/enums/connection_phase.dart';

class ConnectionStatus {
  const ConnectionStatus({
    required this.phase,
    required this.endpoint,
    required this.message,
    required this.changedAt,
  });

  final ConnectionPhase phase;
  final String endpoint;
  final String message;
  final DateTime changedAt;

  bool get isConnected => phase == ConnectionPhase.connected;
  bool get isConnecting => phase == ConnectionPhase.connecting;

  factory ConnectionStatus.disconnected({String endpoint = ''}) {
    return ConnectionStatus(
      phase: ConnectionPhase.disconnected,
      endpoint: endpoint,
      message: 'Disconnected',
      changedAt: DateTime.now(),
    );
  }

  ConnectionStatus copyWith({
    ConnectionPhase? phase,
    String? endpoint,
    String? message,
    DateTime? changedAt,
  }) {
    return ConnectionStatus(
      phase: phase ?? this.phase,
      endpoint: endpoint ?? this.endpoint,
      message: message ?? this.message,
      changedAt: changedAt ?? this.changedAt,
    );
  }
}
