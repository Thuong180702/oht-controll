class AppConstants {
  const AppConstants._();

  static const appName = 'OHT Manual Control & Monitoring App';
  static const defaultWebSocketUrl = 'ws://192.168.1.100:8080/ws';
  static const mockEndpoint = 'mock://local-oht';
  static const telemetryTimeout = Duration(seconds: 2);
  static const maxEventLogItems = 120;
}
