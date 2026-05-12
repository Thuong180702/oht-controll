enum LidarZone {
  noData(-1, 'No Data'),
  clear(0, 'Clear'),
  warning(1, 'Warning'),
  danger(2, 'Danger');

  const LidarZone(this.value, this.label);

  final int value;
  final String label;

  static LidarZone fromValue(int? value) {
    switch (value) {
      case 0:
        return LidarZone.clear;
      case 1:
        return LidarZone.warning;
      case 2:
        return LidarZone.danger;
      default:
        return LidarZone.noData;
    }
  }
}
