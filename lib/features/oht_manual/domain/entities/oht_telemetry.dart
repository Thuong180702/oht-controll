import '../../../../core/constants/oht_ids.dart';
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

  static Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }
}
