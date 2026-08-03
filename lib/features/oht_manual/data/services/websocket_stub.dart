// Stub – imported when neither dart:io nor dart:html is available.
// This file is only used during compilation as a fallback.

import '../../domain/repositories/oht_communication_service.dart';

OhtCommunicationService createWebSocketService() =>
    throw UnsupportedError('WebSocket is not supported on this platform');
