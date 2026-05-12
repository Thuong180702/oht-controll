class MotorIds {
  const MotorIds._();

  static const steerFront = 'steer_front';
  static const steerRear = 'steer_rear';
  static const travelFront = 'travel_front';
  static const travelRear = 'travel_rear';
  static const hoistFront = 'hoist_front';
  static const hoistRear = 'hoist_rear';

  static const all = <String>[
    steerFront,
    steerRear,
    travelFront,
    travelRear,
    hoistFront,
    hoistRear,
  ];

  static const labels = <String, String>{
    steerFront: 'Steer Front',
    steerRear: 'Steer Rear',
    travelFront: 'Travel Front',
    travelRear: 'Travel Rear',
    hoistFront: 'Hoist Front',
    hoistRear: 'Hoist Rear',
  };

  static const wireKeys = <String, String>{
    steerFront: 'steerFront',
    steerRear: 'steerRear',
    travelFront: 'travelFront',
    travelRear: 'travelRear',
    hoistFront: 'hoistFront',
    hoistRear: 'hoistRear',
  };
}

class SensorIds {
  const SensorIds._();

  static const steerFrontLeft = 'steer_front_left';
  static const steerFrontRight = 'steer_front_right';
  static const steerRearLeft = 'steer_rear_left';
  static const steerRearRight = 'steer_rear_right';
  static const hoistFrontUpperLimit = 'hoist_front_upper_limit';
  static const hoistRearUpperLimit = 'hoist_rear_upper_limit';
  static const pumperFront = 'pumper_front';
  static const pumperRear = 'pumper_rear';
  static const lidarUpper = 'lidar_upper';
  static const lidarLower = 'lidar_lower';

  static const boolSensorLabels = <String, String>{
    steerFrontLeft: 'Steer Front Left',
    steerFrontRight: 'Steer Front Right',
    steerRearLeft: 'Steer Rear Left',
    steerRearRight: 'Steer Rear Right',
    hoistFrontUpperLimit: 'Hoist Front Upper Limit',
    hoistRearUpperLimit: 'Hoist Rear Upper Limit',
    pumperFront: 'Pumper Front',
    pumperRear: 'Pumper Rear',
  };

  static const lidarSensorLabels = <String, String>{
    lidarUpper: 'Lidar Upper',
    lidarLower: 'Lidar Lower',
  };
}
