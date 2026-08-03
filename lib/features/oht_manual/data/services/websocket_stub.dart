// Stub – imported when neither dart:io nor dart:html is available.
// This file is only used during compilation as a fallback.

import 'dart:async';
import 'dart:convert';

import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../domain/entities/alarm_event.dart';
import '../../domain/entities/connection_status.dart';
import '../../domain/entities/manual_command.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../../domain/repositories/oht_communication_service.dart';
import '../models/oht_message_type.dart';

OhtCommunicationService createWebSocketService() =>
    throw UnsupportedError('WebSocket is not supported on this platform');
