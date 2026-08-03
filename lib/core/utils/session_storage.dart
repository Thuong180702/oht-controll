import 'session_storage_stub.dart'
    if (dart.library.io) 'session_storage_io.dart'
    if (dart.library.html) 'session_storage_web.dart' as platform;

class SessionStorage {
  SessionStorage._();

  static final _impl = platform.createSessionStorage();

  static String? getItem(String key) => _impl.getItem(key);
  static Future<void> setItem(String key, String value) => _impl.setItem(key, value);
  static Future<void> removeItem(String key) => _impl.removeItem(key);
}
