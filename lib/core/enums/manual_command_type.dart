enum ManualCommandType {
  setManualMode('mode_manual'),
  travelForward('travel_forward'),
  travelBackward('travel_backward'),
  travelStop('travel_stop'),
  steerLeft('steer_left'),
  steerRight('steer_right'),
  steerStop('steer_stop'),
  hoistUp('hoist_up'),
  hoistDown('hoist_down'),
  hoistStop('hoist_stop'),
  stopAll('stop_all'),
  resetError('reset_error'),
  emergencyStop('emergency_stop'),
  heartbeat('heartbeat');

  const ManualCommandType(this.wireName);

  final String wireName;
}
