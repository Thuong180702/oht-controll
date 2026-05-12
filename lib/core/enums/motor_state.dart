enum MotorState { running, stopped, error }

extension MotorStateLabel on MotorState {
  String get label {
    switch (this) {
      case MotorState.running:
        return 'Running';
      case MotorState.stopped:
        return 'Stopped';
      case MotorState.error:
        return 'Error';
    }
  }

  static MotorState fromWire(String? value) {
    switch (value) {
      case 'running':
        return MotorState.running;
      case 'error':
        return MotorState.error;
      case 'stopped':
      default:
        return MotorState.stopped;
    }
  }
}
