class AppConstants {
  const AppConstants._();

  static const appName = 'OHT Manual Control & Monitoring App';
  static const unitId = '1807-T';
  static const currentVersion = '1.0.1';
  static const currentBuildNumber = 2;
  static const githubRepo = 'Thuong180702/oht-controll';

  static const defaultWebSocketUrl = 'ws://10.14.64.7:80/ws';
  static const mockEndpoint = 'mock://local-oht';
  static const telemetryTimeout = Duration(seconds: 2);
  static const maxEventLogItems = 120;
}
