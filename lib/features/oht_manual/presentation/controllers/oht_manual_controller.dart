import 'dart:async';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/communication_protocol.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/enums/manual_command_type.dart';
import '../../../../mock/mock_oht_data.dart';
import '../../data/services/mock_oht_communication_service.dart';
import '../../data/services/mqtt_oht_communication_service.dart';
import '../../data/services/websocket_oht_communication_service.dart';
import '../../domain/entities/alarm_event.dart';
import '../../domain/entities/connection_status.dart';
import '../../domain/entities/manual_command.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/repositories/oht_communication_service.dart';

/// Controller for OHT manual mode.
///
/// **Important:** This class does NOT extend ChangeNotifier and does NOT call
/// notifyListeners.  Instead the UI polls [revision] via a periodic Timer.
/// This completely eliminates the "!_debugDoingThisLayout" assertion because
/// no rebuild is ever triggered from inside a stream callback or during
/// Flutter's layout/paint phase.
class OhtManualController {
  OhtManualController() {
    _service = MockOhtCommunicationService();
    _connectionStatus = ConnectionStatus.disconnected(
      endpoint: AppConstants.mockEndpoint,
    );
    _bindService();
    _watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkTelemetryTimeout();
    });
    _addEvent(
      AlarmEvent.now(
        severity: EventSeverity.info,
        message: 'Mock mode is enabled by default',
      ),
    );
  }

  late OhtCommunicationService _service;
  StreamSubscription<OhtTelemetry>? _telemetrySubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<AlarmEvent>? _eventSubscription;
  Timer? _watchdog;

  OhtTelemetry _telemetry = MockOhtData.initialTelemetry();
  late ConnectionStatus _connectionStatus;
  final List<AlarmEvent> _events = <AlarmEvent>[];

  CommunicationProtocol _protocol = CommunicationProtocol.mock;
  String _webSocketUrl = AppConstants.defaultWebSocketUrl;
  int _travelSpeed = 30;
  int _hoistSpeed = 30;
  int _steerSpeed = 30;
  int _requestCounter = 0;
  DateTime? _lastTelemetryAt;
  bool _emergencyLatched = false;
  bool _disposed = false;

  /// Monotonically increasing revision number.  The UI compares this to its
  /// own cached value to decide whether to [setState].  This is the ONLY
  /// mechanism for UI updates — no ChangeNotifier, no addListener, no
  /// notifyListeners.
  int _revision = 0;
  int get revision => _revision;

  void _bump() => _revision++;

  OhtTelemetry get telemetry => _telemetry;
  ConnectionStatus get connectionStatus => _connectionStatus;
  List<AlarmEvent> get events => List.unmodifiable(_events);
  CommunicationProtocol get protocol => _protocol;
  String get webSocketUrl => _webSocketUrl;
  int get travelSpeed => _travelSpeed;
  int get hoistSpeed => _hoistSpeed;
  int get steerSpeed => _steerSpeed;
  bool get isMockMode => _protocol == CommunicationProtocol.mock;
  bool get isConnected => _connectionStatus.phase == ConnectionPhase.connected;
  bool get isConnecting =>
      _connectionStatus.phase == ConnectionPhase.connecting;
  bool get emergencyStopActive => _emergencyLatched || _telemetry.emergencyStop;
  bool get hasCriticalError => _telemetry.hasCriticalError;

  String get activeEndpoint {
    switch (_protocol) {
      case CommunicationProtocol.mock:
        return AppConstants.mockEndpoint;
      case CommunicationProtocol.websocket:
      case CommunicationProtocol.mqtt:
        return _webSocketUrl;
    }
  }

  bool get manualControlsEnabled {
    return isConnected &&
        _telemetry.isManualMode &&
        !emergencyStopActive &&
        !hasCriticalError;
  }

  void setTravelSpeed(double value) {
    _travelSpeed = value.round().clamp(0, 100).toInt();
    _bump();
  }

  void setHoistSpeed(double value) {
    _hoistSpeed = value.round().clamp(0, 100).toInt();
    _bump();
  }

  void setSteerSpeed(double value) {
    _steerSpeed = value.round().clamp(0, 100).toInt();
    _bump();
  }

  Future<void> connect() async {
    if (isConnecting || isConnected) return;
    try {
      await _service.connect(endpoint: activeEndpoint);
    } catch (error) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'Connect failed: $error',
        ),
      );
    }
  }

  Future<bool> waitForFirstTelemetry(Duration timeout) async {
    if (_protocol == CommunicationProtocol.mock) return true;
    if (_lastTelemetryAt != null) return true;
    if (_connectionStatus.phase == ConnectionPhase.error ||
        _connectionStatus.phase == ConnectionPhase.disconnected) {
      return false;
    }

    final deadline = DateTime.now().add(timeout);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      if (_lastTelemetryAt != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (_disposed) return false;
    if (_connectionStatus.phase == ConnectionPhase.connected ||
        _connectionStatus.phase == ConnectionPhase.connecting) {
      _connectionStatus = _connectionStatus.copyWith(
        phase: ConnectionPhase.timeout,
        message: 'Khong ket noi duoc (khong co du lieu trong 3 giay)',
        changedAt: DateTime.now(),
      );
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'Khong nhan du lieu trong 3 giay. Ket noi that bai.',
        ),
      );
      _bump();
    }
    return false;
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    _lastTelemetryAt = null;
  }

  Future<void> updateConnectionSettings({
    required CommunicationProtocol protocol,
    required String webSocketUrl,
  }) async {
    final normalizedUrl = webSocketUrl.trim().isEmpty
        ? AppConstants.defaultWebSocketUrl
        : webSocketUrl.trim();
    final protocolChanged = protocol != _protocol;
    final endpointChanged = normalizedUrl != _webSocketUrl;

    if (!protocolChanged && !endpointChanged) return;

    if (_connectionStatus.isConnected || _connectionStatus.isConnecting) {
      await disconnect();
    }

    _protocol = protocol;
    _webSocketUrl = normalizedUrl;
    if (protocolChanged) {
      _replaceService(_createService(protocol));
    } else {
      _connectionStatus = ConnectionStatus.disconnected(
        endpoint: activeEndpoint,
      );
    }

    _addEvent(
      AlarmEvent.now(
        severity: EventSeverity.info,
        message:
            'Connection configured for ${protocol.label} at $activeEndpoint',
      ),
    );
    _bump();
  }

  Future<void> sendManualCommand(ManualCommandType type) async {
    final blockReason = blockReasonFor(type);
    if (blockReason != null) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.warning,
          message: 'Blocked ${type.wireName}: $blockReason',
        ),
      );
      return;
    }

    final command = ManualCommand(
      type: type,
      target: _targetFor(type),
      speed: _speedFor(type),
      requestId: _nextRequestId(),
      timestamp: DateTime.now(),
    );

    if (type == ManualCommandType.emergencyStop) {
      _emergencyLatched = true;
      _bump();
    }
    if (type == ManualCommandType.resetError) {
      _emergencyLatched = false;
      _bump();
    }

    _addEvent(
      AlarmEvent.now(
        severity: EventSeverity.command,
        message:
            'Sent ${command.type.wireName} target=${command.target} speed=${command.speed}% requestId=${command.requestId}',
      ),
    );

    try {
      await _service.sendCommand(command);
    } catch (error) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'Command failed ${command.type.wireName}: $error',
        ),
      );
    }
  }

  bool canSendCommand(ManualCommandType type) => blockReasonFor(type) == null;

  /// Send both front and rear steer commands at once (unified mode).
  Future<void> sendUnifiedSteer({required bool left}) async {
    final frontType = left
        ? ManualCommandType.steerFrontLeft
        : ManualCommandType.steerFrontRight;
    final rearType = left
        ? ManualCommandType.steerRearLeft
        : ManualCommandType.steerRearRight;
    await sendManualCommand(frontType);
    await sendManualCommand(rearType);
  }

  /// Send both front and rear hoist commands at once (unified mode).
  Future<void> sendUnifiedHoist({required bool up}) async {
    final frontType = up
        ? ManualCommandType.hoistFrontUp
        : ManualCommandType.hoistFrontDown;
    final rearType = up
        ? ManualCommandType.hoistRearUp
        : ManualCommandType.hoistRearDown;
    await sendManualCommand(frontType);
    await sendManualCommand(rearType);
  }

  /// Block reason for unified steer (checks BOTH front & rear limits).
  String? blockReasonForUnifiedSteer({required bool left}) {
    if (!isConnected) return 'OHT is not connected';
    if (emergencyStopActive) return 'Emergency stop is active';
    if (!_telemetry.isManualMode) return 'OHT is not in manual mode';
    if (hasCriticalError) return 'Critical OHT error is active';
    if (left) {
      if (_telemetry.sensors.steerFrontLeft == true &&
          _telemetry.sensors.steerRearLeft == true) {
        return 'Both steer left limits active';
      }
    } else {
      if (_telemetry.sensors.steerFrontRight == true &&
          _telemetry.sensors.steerRearRight == true) {
        return 'Both steer right limits active';
      }
    }
    return null;
  }

  /// Block reason for unified hoist (checks BOTH front & rear limits).
  String? blockReasonForUnifiedHoist({required bool up}) {
    if (!isConnected) return 'OHT is not connected';
    if (emergencyStopActive) return 'Emergency stop is active';
    if (!_telemetry.isManualMode) return 'OHT is not in manual mode';
    if (hasCriticalError) return 'Critical OHT error is active';
    if (up) {
      if (_telemetry.sensors.hoistFrontUpperLimit == true &&
          _telemetry.sensors.hoistRearUpperLimit == true) {
        return 'Both hoist upper limits active';
      }
    }
    return null;
  }

  /// Clear all events.
  void clearEvents() {
    _events.clear();
    _bump();
  }

  String? blockReasonFor(ManualCommandType type) {
    if (!isConnected) return 'OHT is not connected';
    if (type == ManualCommandType.emergencyStop) return null;
    if (type == ManualCommandType.resetError) return null;
    if (emergencyStopActive) return 'Emergency stop is active';
    if (type == ManualCommandType.setManualMode) return null;
    if (!_telemetry.isManualMode) return 'OHT is not in manual mode';
    if (hasCriticalError) return 'Critical OHT error is active';
    if (type == ManualCommandType.travelForward &&
        _telemetry.sensors.hasLidarDanger) {
      return 'Lidar danger zone blocks travel_forward';
    }
    // Hoist upper limit blocking
    if (type == ManualCommandType.hoistFrontUp &&
        _telemetry.sensors.hoistFrontUpperLimit == true) {
      return 'Front hoist upper limit is active';
    }
    if (type == ManualCommandType.hoistRearUp &&
        _telemetry.sensors.hoistRearUpperLimit == true) {
      return 'Rear hoist upper limit is active';
    }
    // Steering limit sensor blocking
    if (type == ManualCommandType.steerFrontLeft &&
        _telemetry.sensors.steerFrontLeft == true) {
      return 'Steer front left limit is active';
    }
    if (type == ManualCommandType.steerFrontRight &&
        _telemetry.sensors.steerFrontRight == true) {
      return 'Steer front right limit is active';
    }
    if (type == ManualCommandType.steerRearLeft &&
        _telemetry.sensors.steerRearLeft == true) {
      return 'Steer rear left limit is active';
    }
    if (type == ManualCommandType.steerRearRight &&
        _telemetry.sensors.steerRearRight == true) {
      return 'Steer rear right limit is active';
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    _telemetrySubscription?.cancel();
    _statusSubscription?.cancel();
    _eventSubscription?.cancel();
    _service.dispose();
  }

  // ─── Private ──────────────────────────────────────────────────────────

  OhtCommunicationService _createService(CommunicationProtocol protocol) {
    switch (protocol) {
      case CommunicationProtocol.mock:
        return MockOhtCommunicationService();
      case CommunicationProtocol.websocket:
        return WebSocketOhtCommunicationService();
      case CommunicationProtocol.mqtt:
        return MqttOhtCommunicationService();
    }
  }

  void _replaceService(OhtCommunicationService nextService) {
    _telemetrySubscription?.cancel();
    _statusSubscription?.cancel();
    _eventSubscription?.cancel();
    _service.dispose();
    _service = nextService;
    _connectionStatus = ConnectionStatus.disconnected(endpoint: activeEndpoint);
    _lastTelemetryAt = null;
    _bindService();
  }

  void _bindService() {
    _telemetrySubscription = _service.telemetryStream.listen((telemetry) {
      if (_disposed) return;
      final previous = _telemetry;
      _lastTelemetryAt = DateTime.now();
      _telemetry = telemetry;
      _emergencyLatched = telemetry.emergencyStop;
      if (_connectionStatus.phase == ConnectionPhase.timeout &&
          _service.status.isConnected) {
        _connectionStatus = _service.status.copyWith(
          message: 'Telemetry restored',
          changedAt: DateTime.now(),
        );
        _addEvent(
          AlarmEvent.now(
            severity: EventSeverity.info,
            message: 'Telemetry restored',
          ),
        );
      }
      _inspectTelemetry(previous, telemetry);
      _bump();
    });

    _statusSubscription = _service.connectionStatusStream.listen((status) {
      if (_disposed) return;
      _connectionStatus = status;
      if (status.phase != ConnectionPhase.connected) {
        _lastTelemetryAt = null;
      }
      if (status.phase == ConnectionPhase.error ||
          status.phase == ConnectionPhase.disconnected) {
        _addEvent(
          AlarmEvent.now(
            severity: status.phase == ConnectionPhase.error
                ? EventSeverity.critical
                : EventSeverity.info,
            message: status.message,
          ),
        );
      }
      _bump();
    });

    _eventSubscription = _service.eventStream.listen((event) {
      if (_disposed) return;
      _addEvent(event);
    });
  }

  void _checkTelemetryTimeout() {
    if (_disposed || _connectionStatus.phase != ConnectionPhase.connected) {
      return;
    }
    final lastTelemetryAt = _lastTelemetryAt;
    if (lastTelemetryAt == null) return;
    final age = DateTime.now().difference(lastTelemetryAt);
    if (age <= AppConstants.telemetryTimeout) return;

    _connectionStatus = _connectionStatus.copyWith(
      phase: ConnectionPhase.timeout,
      message: 'Telemetry timeout > 2 seconds',
      changedAt: DateTime.now(),
    );
    _addEvent(
      AlarmEvent.now(
        severity: EventSeverity.critical,
        message: 'Telemetry timeout > 2 seconds. Manual commands disabled.',
      ),
    );
    _bump();
  }

  void _inspectTelemetry(OhtTelemetry previous, OhtTelemetry current) {
    _inspectLidar(
      label: 'Lidar Upper',
      previous: previous.sensors.lidarUpperZone,
      current: current.sensors.lidarUpperZone,
    );
    _inspectLidar(
      label: 'Lidar Lower',
      previous: previous.sensors.lidarLowerZone,
      current: current.sensors.lidarLowerZone,
    );
    _inspectUpperLimit(
      label: 'Front hoist upper limit',
      previous: previous.sensors.hoistFrontUpperLimit,
      current: current.sensors.hoistFrontUpperLimit,
    );
    _inspectUpperLimit(
      label: 'Rear hoist upper limit',
      previous: previous.sensors.hoistRearUpperLimit,
      current: current.sensors.hoistRearUpperLimit,
    );

    if (previous.batteryLevel > 20 &&
        current.batteryLevel <= 20 &&
        !current.isCharging) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.warning,
          message: 'Cảnh báo: Pin yếu (${current.batteryLevel}%)',
        ),
      );
    }
    if (previous.sensors.pumperFront != true &&
        current.sensors.pumperFront == true) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'LỖI: Va chạm Pumper trước!',
        ),
      );
    }
    if (previous.sensors.pumperRear != true &&
        current.sensors.pumperRear == true) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'LỖI: Va chạm Pumper sau!',
        ),
      );
    }

    if (!previous.emergencyStop && current.emergencyStop) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message: 'Emergency stop is active',
        ),
      );
    }

    for (final error in current.errors) {
      if (!previous.errors.contains(error)) {
        _addEvent(
          AlarmEvent.now(
            severity: EventSeverity.critical,
            message: 'OHT error: $error',
          ),
        );
      }
    }
  }

  void _inspectLidar({
    required String label,
    required LidarZone previous,
    required LidarZone current,
  }) {
    if (previous == current) return;
    if (current == LidarZone.danger) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.critical,
          message:
              '$label danger zone. travel_forward is blocked; stop advised.',
        ),
      );
    } else if (current == LidarZone.warning) {
      _addEvent(
        AlarmEvent.now(
          severity: EventSeverity.warning,
          message: '$label warning zone',
        ),
      );
    }
  }

  void _inspectUpperLimit({
    required String label,
    required bool? previous,
    required bool? current,
  }) {
    if (previous == true || current != true) return;
    _addEvent(
      AlarmEvent.now(
        severity: EventSeverity.warning,
        message: '$label active. Up command is blocked.',
      ),
    );
  }

  void _addEvent(AlarmEvent event) {
    _events.insert(0, event);
    if (_events.length > AppConstants.maxEventLogItems) {
      _events.removeRange(AppConstants.maxEventLogItems, _events.length);
    }
    _bump();
  }

  String _nextRequestId() {
    _requestCounter++;
    return 'cmd_${_requestCounter.toString().padLeft(4, '0')}';
  }

  int _speedFor(ManualCommandType type) {
    switch (type) {
      case ManualCommandType.travelStop:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
      case ManualCommandType.setManualMode:
        return 0;
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelFrontBackward:
      case ManualCommandType.travelRearForward:
      case ManualCommandType.travelRearBackward:
        return _travelSpeed;
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.steerRearLeft:
      case ManualCommandType.steerRearRight:
        return _steerSpeed;
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.hoistRearUp:
      case ManualCommandType.hoistRearDown:
        return _hoistSpeed;
    }
  }

  String _targetFor(ManualCommandType type) {
    switch (type) {
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelFrontBackward:
        return 'front';
      case ManualCommandType.steerRearLeft:
      case ManualCommandType.steerRearRight:
      case ManualCommandType.hoistRearUp:
      case ManualCommandType.hoistRearDown:
      case ManualCommandType.travelRearForward:
      case ManualCommandType.travelRearBackward:
        return 'rear';
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
        return 'both';
      case ManualCommandType.setManualMode:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
        return 'system';
    }
  }
}
