import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../features/oht_manual/domain/entities/alarm_event.dart';
import 'session_storage.dart';

class EventLogStorage {
  EventLogStorage._();

  static const String _storageKey = 'oht_event_logs_persistent';
  static const int _maxStoredLogs = 2000;

  /// Load persisted events from storage synchronously or asynchronously.
  static List<AlarmEvent> loadEvents() {
    try {
      final rawJson = SessionStorage.getItem(_storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return <AlarmEvent>[];
      }

      final List<dynamic> decodedList = jsonDecode(rawJson) as List<dynamic>;
      return decodedList
          .map((item) => AlarmEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[EventLogStorage] Error loading events: $e');
      return <AlarmEvent>[];
    }
  }

  /// Persist event list to storage (retains max 2000 items).
  static Future<void> saveEvents(List<AlarmEvent> events) async {
    try {
      final logsToSave = events.take(_maxStoredLogs).map((e) => e.toJson()).toList();
      final jsonStr = jsonEncode(logsToSave);
      await SessionStorage.setItem(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[EventLogStorage] Error saving events: $e');
    }
  }

  /// Clear all stored events from storage.
  static Future<void> clearEvents() async {
    try {
      await SessionStorage.removeItem(_storageKey);
    } catch (e) {
      debugPrint('[EventLogStorage] Error clearing events: $e');
    }
  }
}
