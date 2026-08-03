// Platform-agnostic WebSocket service.
// Uses conditional imports to pick the correct implementation at compile time:
// - dart:io  → websocket_io.dart   (Windows, Android, iOS, Linux, macOS)
// - dart:html → websocket_web.dart  (Web/browser)

import '../../domain/repositories/oht_communication_service.dart';

import 'websocket_stub.dart'
    if (dart.library.io) 'websocket_io.dart'
    if (dart.library.html) 'websocket_web.dart' as platform;

class WebSocketOhtCommunicationService {
  WebSocketOhtCommunicationService._();

  /// Creates the platform-appropriate WebSocket communication service.
  static OhtCommunicationService create() => platform.createWebSocketService();
}
