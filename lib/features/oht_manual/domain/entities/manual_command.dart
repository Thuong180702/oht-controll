import '../../../../core/enums/manual_command_type.dart';

class ManualCommand {
  const ManualCommand({
    required this.type,
    required this.target,
    required this.speed,
    required this.requestId,
    required this.timestamp,
  });

  final ManualCommandType type;
  final String target;
  final int speed;
  final String requestId;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'type': 'manual_cmd',
      'request_id': requestId,
      'action': _firmwareAction,
    };

    final firmwareTarget = _firmwareTarget;
    if (firmwareTarget != null) {
      payload['target'] = firmwareTarget;
    }

    final firmwareUnit = _firmwareUnit;
    if (firmwareUnit != null) {
      payload['unit'] = firmwareUnit;
    }

    final firmwareValue = _firmwareValue;
    if (firmwareValue != null) {
      payload['value'] = firmwareValue;
    }

    if (_requiresDeadman) {
      payload['deadman'] = true;
    }

    return payload;
  }

  String get _firmwareAction {
    switch (type) {
      case ManualCommandType.setManualMode:
        return 'mode_manual';
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
        return 'travel_set';
      case ManualCommandType.travelStop:
        return 'travel_stop';
      case ManualCommandType.steerLeft:
        return 'steer_left';
      case ManualCommandType.steerRight:
        return 'steer_right';
      case ManualCommandType.steerStop:
        return 'steer_stop';
      case ManualCommandType.hoistUp:
      case ManualCommandType.hoistDown:
        return 'hoist_move';
      case ManualCommandType.hoistStop:
        return 'hoist_stop';
      case ManualCommandType.stopAll:
        return 'stop_all';
      case ManualCommandType.resetError:
        return 'reset_all_faults';
      case ManualCommandType.emergencyStop:
        return 'estop';
      case ManualCommandType.heartbeat:
        return 'heartbeat';
    }
  }

  String? get _firmwareTarget {
    switch (type) {
      case ManualCommandType.setManualMode:
      case ManualCommandType.heartbeat:
        return null;
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
      case ManualCommandType.travelStop:
        return 'travel';
      case ManualCommandType.steerLeft:
      case ManualCommandType.steerRight:
      case ManualCommandType.steerStop:
        return 'steering';
      case ManualCommandType.hoistUp:
      case ManualCommandType.hoistDown:
      case ManualCommandType.hoistStop:
        return 'hoist';
      case ManualCommandType.stopAll:
        return 'all';
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
        return 'all';
    }
  }

  String? get _firmwareUnit {
    switch (type) {
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
        return 'mps';
      case ManualCommandType.hoistUp:
      case ManualCommandType.hoistDown:
        return 'rpm';
      case ManualCommandType.setManualMode:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerLeft:
      case ManualCommandType.steerRight:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
      case ManualCommandType.stopAll:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
      case ManualCommandType.heartbeat:
        return null;
    }
  }

  double? get _firmwareValue {
    switch (type) {
      case ManualCommandType.travelForward:
        return _speedPercentToMps();
      case ManualCommandType.travelBackward:
        return -_speedPercentToMps();
      case ManualCommandType.hoistUp:
        return _speedPercentToRpm();
      case ManualCommandType.hoistDown:
        return -_speedPercentToRpm();
      case ManualCommandType.setManualMode:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerLeft:
      case ManualCommandType.steerRight:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
      case ManualCommandType.stopAll:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
      case ManualCommandType.heartbeat:
        return null;
    }
  }

  bool get _requiresDeadman {
    switch (type) {
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
      case ManualCommandType.steerLeft:
      case ManualCommandType.steerRight:
      case ManualCommandType.hoistUp:
      case ManualCommandType.hoistDown:
        return true;
      case ManualCommandType.setManualMode:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
      case ManualCommandType.stopAll:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
      case ManualCommandType.heartbeat:
        return false;
    }
  }

  /// Map 0..100% → 0.0..0.5 m/s
  double _speedPercentToMps() {
    return speed.clamp(0, 100).toDouble() / 100.0 * 0.5;
  }

  /// Map 0..100% → 0..1200 RPM
  double _speedPercentToRpm() {
    return speed.clamp(0, 100).toDouble() * 12.0;
  }
}
