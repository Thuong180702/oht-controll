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
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelFrontBackward:
      case ManualCommandType.travelRearForward:
      case ManualCommandType.travelRearBackward:
        return 'travel_set';
      case ManualCommandType.travelStop:
        return 'travel_stop';
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerRearLeft:
        return 'steer_left';
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.steerRearRight:
        return 'steer_right';
      case ManualCommandType.steerStop:
        return 'steer_stop';
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.hoistRearUp:
      case ManualCommandType.hoistRearDown:
        return 'hoist_move';
      case ManualCommandType.hoistStop:
        return 'hoist_stop';
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
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelFrontBackward:
      case ManualCommandType.travelRearForward:
      case ManualCommandType.travelRearBackward:
      case ManualCommandType.travelStop:
        return 'travel';
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.steerRearLeft:
      case ManualCommandType.steerRearRight:
      case ManualCommandType.steerStop:
        return 'steering';
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.hoistRearUp:
      case ManualCommandType.hoistRearDown:
      case ManualCommandType.hoistStop:
        return 'hoist';
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
        return 'all';
    }
  }

  String? get _firmwareUnit {
    switch (type) {
      case ManualCommandType.travelForward:
      case ManualCommandType.travelBackward:
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelFrontBackward:
      case ManualCommandType.travelRearForward:
      case ManualCommandType.travelRearBackward:
        return 'mps';
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.hoistRearUp:
      case ManualCommandType.hoistRearDown:
        return 'mm';
      case ManualCommandType.setManualMode:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.steerRearLeft:
      case ManualCommandType.steerRearRight:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
      case ManualCommandType.heartbeat:
        return null;
    }
  }

  double? get _firmwareValue {
    switch (type) {
      case ManualCommandType.travelForward:
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelRearForward:
        return _speedPercentToMps();
      case ManualCommandType.travelBackward:
      case ManualCommandType.travelFrontBackward:
      case ManualCommandType.travelRearBackward:
        return -_speedPercentToMps();
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistRearUp:
        return 0.0;
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.hoistRearDown:
        return speed.clamp(0, 100).toDouble();
      case ManualCommandType.setManualMode:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.steerRearLeft:
      case ManualCommandType.steerRearRight:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
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
      case ManualCommandType.travelFrontForward:
      case ManualCommandType.travelFrontBackward:
      case ManualCommandType.travelRearForward:
      case ManualCommandType.travelRearBackward:
      case ManualCommandType.steerFrontLeft:
      case ManualCommandType.steerFrontRight:
      case ManualCommandType.steerRearLeft:
      case ManualCommandType.steerRearRight:
      case ManualCommandType.hoistFrontUp:
      case ManualCommandType.hoistFrontDown:
      case ManualCommandType.hoistRearUp:
      case ManualCommandType.hoistRearDown:
        return true;
      case ManualCommandType.setManualMode:
      case ManualCommandType.travelStop:
      case ManualCommandType.steerStop:
      case ManualCommandType.hoistStop:
      case ManualCommandType.resetError:
      case ManualCommandType.emergencyStop:
      case ManualCommandType.heartbeat:
        return false;
    }
  }

  double _speedPercentToMps() {
    return speed.clamp(0, 100).toDouble() / 100.0;
  }
}
