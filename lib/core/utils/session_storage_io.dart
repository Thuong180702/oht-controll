import 'package:shared_preferences/shared_preferences.dart';
import 'session_storage_stub.dart';

SessionStoragePlatform createSessionStorage() => IoSessionStorage();

class IoSessionStorage implements SessionStoragePlatform {
  SharedPreferences? _prefs;
  final Map<String, String> _cache = {};

  @override
  Future<void> init() async {
    await _getPrefs();
  }

  Future<SharedPreferences> _getPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (_prefs != p) {
      _prefs = p;
      _cache.clear();
      for (final key in p.getKeys()) {
        final val = p.getString(key);
        if (val != null) _cache[key] = val;
      }
    }
    return p;
  }

  @override
  String? getItem(String key) {
    if (_cache.containsKey(key)) return _cache[key];
    if (_prefs != null) return _prefs!.getString(key);
    // Asynchronously preload
    _getPrefs();
    return null;
  }

  @override
  Future<void> setItem(String key, String value) async {
    _cache[key] = value;
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  @override
  Future<void> removeItem(String key) async {
    _cache.remove(key);
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }
}
