// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'session_storage_stub.dart';

SessionStoragePlatform createSessionStorage() => WebSessionStorage();

class WebSessionStorage implements SessionStoragePlatform {
  @override
  Future<void> init() async {}
  @override
  String? getItem(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setItem(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    } catch (e) {
      // Failed to write to localStorage
    }
  }

  @override
  Future<void> removeItem(String key) async {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {}
  }
}
