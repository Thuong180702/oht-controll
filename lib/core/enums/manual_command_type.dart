enum ManualCommandType {
  setManualMode('set_manual_mode'),
  travelForward('travel_forward'),
  travelBackward('travel_backward'),
  travelFrontForward('travel_front_forward'),
  travelFrontBackward('travel_front_backward'),
  travelRearForward('travel_rear_forward'),
  travelRearBackward('travel_rear_backward'),
  travelStop('travel_stop'),
  steerFrontLeft('steer_front_left'),
  steerFrontRight('steer_front_right'),
  steerRearLeft('steer_rear_left'),
  steerRearRight('steer_rear_right'),
  steerStop('steer_stop'),
  hoistFrontUp('hoist_front_up'),
  hoistFrontDown('hoist_front_down'),
  hoistRearUp('hoist_rear_up'),
  hoistRearDown('hoist_rear_down'),
  hoistStop('hoist_stop'),
  resetError('reset_error'),
  emergencyStop('emergency_stop');

  const ManualCommandType(this.wireName);

  final String wireName;
}
