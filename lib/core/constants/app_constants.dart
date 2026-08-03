class AppConstants {
  const AppConstants._();

  static const appName = 'OHT Manual Control & Monitoring App';
  static const defaultWebSocketUrl = 'ws://10.14.64.7:80/ws';
  static const mockEndpoint = 'mock://local-oht';
  static const telemetryTimeout = Duration(seconds: 2);
  static const maxEventLogItems = 120;
}
