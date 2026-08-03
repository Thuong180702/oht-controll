import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/motor_state.dart';
import '../../../../core/enums/oht_mode.dart';
import 'motor_status.dart';
import 'sensor_status.dart';

class OhtTelemetry {
  const OhtTelemetry({
    required this.mode,
    required this.connected,
    required this.emergencyStop,
    required this.motors,
    required this.sensors,
    required this.errors,
    required this.timestamp,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.batteryLevel = 100,
    this.isCharging = false,
  });

  final OhtMode mode;
  final bool connected;
  final bool emergencyStop;
  final Map<String, MotorStatus> motors;
  final SensorStatus sensors;
  final List<String> errors;
  final DateTime timestamp;
  final double positionX;
  final double positionY;
  final int batteryLevel;
  final bool isCharging;

  bool get isManualMode => mode == OhtMode.manual;
  bool get hasCriticalError => mode == OhtMode.error || errors.isNotEmpty;
  bool get hasLidarDanger => sensors.hasLidarDanger;

  factory OhtTelemetry.empty() {
    return OhtTelemetry(
      mode: OhtMode.auto,
      connected: false,
      emergencyStop: false,
      motors: {for (final id in MotorIds.all) id: MotorStatus.stopped(id)},
      sensors: SensorStatus.noData(),
      errors: const <String>[],
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      positionX: 0.0,
      positionY: 0.0,
      batteryLevel: 0,
      isCharging: false,
    );
  }

  factory OhtTelemetry.fromJson(Map<String, dynamic> json) {
    final motorPayload = _mapFrom(json['motors']);
    final motors = <String, MotorStatus>{};
    for (final id in MotorIds.all) {
      final wireKey = MotorIds.wireKeys[id]!;
      final motorJson = _mapFrom(motorPayload[wireKey]);
      motors[id] = motorJson.isEmpty
          ? MotorStatus.stopped(id)
          : MotorStatus.fromJson(id, motorJson);
    }

    final rawTimestamp = json['timestamp'];
    final timestamp = rawTimestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
        : DateTime.now();

    return OhtTelemetry(
      mode: OhtModeLabel.fromWire(json['mode'] as String?),
      connected: (json['connected'] as bool?) ?? true,
      emergencyStop: (json['emergencyStop'] as bool?) ?? false,
      motors: motors,
      sensors: SensorStatus.fromJson(_mapFrom(json['sensors'])),
      errors: _stringList(json['errors']),
      timestamp: timestamp,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      batteryLevel: (json['batteryLevel'] as int?) ?? 100,
      isCharging: (json['isCharging'] as bool?) ?? false,
    );
  }

  factory OhtTelemetry.fromFirmwareState(Map<String, dynamic> json) {
    final state = _mapFrom(json['state']);
    final timestamp = _timestampFrom(json['timestamp'] ?? state['timestamp']);

    // Parse errors from error_code field
    final List<String> errors = [];
    final errorCodeStr = _toString(state['error_code']);
    if (errorCodeStr != null &&
        errorCodeStr.isNotEmpty &&
        errorCodeStr != 'E00000') {
      errors.add(errorCodeStr);
    }
    errors.addAll(_stringList(json['errors'] ?? state['errors']));

    // Parse oht_state: 3=error, 4=emergency
    final ohtState = _asInt(state['oht_state']);
    final numericMode = _asInt(state['mode']);
    final ohtEmergency = ohtState == 4;

    final motors = <String, MotorStatus>{
      MotorIds.hoistFront: _firmwareMotor(MotorIds.hoistFront, state, 0),
      MotorIds.hoistRear: _firmwareMotor(MotorIds.hoistRear, state, 1),
      MotorIds.travelFront: _firmwareMotor(MotorIds.travelFront, state, 2),
      MotorIds.travelRear: _firmwareMotor(MotorIds.travelRear, state, 3),
      MotorIds.steerFront: _firmwareMotor(MotorIds.steerFront, state, 4),
      MotorIds.steerRear: _firmwareMotor(MotorIds.steerRear, state, 5),
    };

    // Parse QR position -> positionX (mm -> m)
    final qrPositionMm = _asDouble(state['qr_position_mm']);
    final positionX = qrPositionMm != null ? qrPositionMm / 1000.0 : 0.0;

    return OhtTelemetry(
      mode: _modeFromNumeric(numericMode, ohtState),
      connected: _boolFrom(
        state['online'] ?? json['online'],
        defaultValue: true,
      ),
      emergencyStop: ohtEmergency ||
          _boolFrom(
            state['emergencyStop'] ??
                state['emergency_stop'] ??
                state['estop'] ??
                json['emergencyStop'] ??
                json['emergency_stop'] ??
                json['estop'],
            defaultValue: false,
          ),
      motors: motors,
      sensors: _firmwareSensors(state),
      errors: errors,
      timestamp: timestamp,
      positionX: positionX,
      batteryLevel: _asInt(
        json['batteryLevel'] ?? state['bat_soc'] ?? 100,
      ).clamp(0, 100).toInt(),
      isCharging: _boolFrom(
        json['isCharging'] ?? state['bat_charging'],
        defaultValue: false,
      ),
    );
  }

  OhtTelemetry copyWith({
    OhtMode? mode,
    bool? connected,
    bool? emergencyStop,
    Map<String, MotorStatus>? motors,
    SensorStatus? sensors,
    List<String>? errors,
    DateTime? timestamp,
    double? positionX,
    double? positionY,
    int? batteryLevel,
    bool? isCharging,
  }) {
    return OhtTelemetry(
      mode: mode ?? this.mode,
      connected: connected ?? this.connected,
      emergencyStop: emergencyStop ?? this.emergencyStop,
      motors: motors ?? this.motors,
      sensors: sensors ?? this.sensors,
      errors: errors ?? this.errors,
      timestamp: timestamp ?? this.timestamp,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': 'telemetry',
      'mode': mode.name,
      'connected': connected,
      'emergencyStop': emergencyStop,
      'motors': {
        for (final entry in motors.entries)
          MotorIds.wireKeys[entry.key]!: entry.value.toJson(),
      },
      'sensors': sensors.toJson(),
      'errors': errors,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'positionX': positionX,
      'positionY': positionY,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
    };
  }

  static OhtMode _modeFromNumeric(int numericMode, int ohtState) {
    // numeric: 0=auto, 1=manual
    // oht_state: 0=idle, 1=running, 2=paused, 3=error, 4=emergency
    if (ohtState == 3 || ohtState == 4) {
      return OhtMode.error;
    }
    switch (numericMode) {
      case 0:
        return OhtMode.auto;
      case 1:
        return OhtMode.manual;
      default:
        // Fallback to string-based parsing for backward compat
        return OhtMode.auto;
    }
  }

  static Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  static SensorStatus _firmwareSensors(Map<String, dynamic> state) {
    return SensorStatus(
      steerFrontLeft: _boolOrNull(state['steer_front_left']),
      steerFrontRight: _boolOrNull(state['steer_front_right']),
      steerRearLeft: _boolOrNull(state['steer_rear_left']),
      steerRearRight: _boolOrNull(state['steer_rear_right']),
      hoistFrontUpperLimit: _boolOrNull(state['hoist_front_upper_limit']),
      hoistRearUpperLimit: _boolOrNull(state['hoist_rear_upper_limit']),
      pumperFront: _boolOrNull(state['bumper_front'] ?? state['pumper_front']),
      pumperRear: _boolOrNull(state['bumper_rear'] ?? state['pumper_rear']),
      lidarUpper: _intOrNull(
        state['lidar_upper_level'] ?? state['lidar_upper'],
      ),
      lidarLower: _intOrNull(
        state['lidar_lower_level'] ?? state['lidar_lower'],
      ),
    );
  }

  static MotorStatus _firmwareMotor(
    String id,
    Map<String, dynamic> state,
    int index,
  ) {
    final prefix = 'm$index';
    final connected = _boolFrom(
      state['${prefix}_connected'],
      defaultValue: false,
    );
    final running = _boolFrom(state['${prefix}_running'], defaultValue: false);
    final rawSpeed = _asInt(state['${prefix}_speed']);
    final stateLabel = connected && running
        ? MotorState.running
        : MotorState.stopped;

    return MotorStatus(
      id: id,
      state: stateLabel,
      direction: _directionForSpeed(id, rawSpeed, running),
      speed: rawSpeed.abs(),  // RPM value from firmware
      warning: connected ? null : 'disconnected',
    );
  }

  static String _directionForSpeed(String id, int speed, bool running) {
    if (!running || speed == 0) {
      return 'none';
    }
    if (id == MotorIds.travelFront || id == MotorIds.travelRear) {
      return speed > 0 ? 'forward' : 'backward';
    }
    return 'moving';
  }

  static DateTime _timestampFrom(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    return DateTime.now();
  }

  static bool _boolFrom(Object? value, {required bool defaultValue}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
        case 'on':
          return true;
        case 'false':
        case '0':
        case 'no':
        case 'off':
          return false;
      }
    }
    return defaultValue;
  }

  static bool? _boolOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    return _boolFrom(value, defaultValue: false);
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static int? _intOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static String? _toString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }
}
