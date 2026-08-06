abstract class SessionStoragePlatform {
  Future<void> init();
  String? getItem(String key);
  Future<void> setItem(String key, String value);
  Future<void> removeItem(String key);
}

SessionStoragePlatform createSessionStorage() =>
    throw UnsupportedError('SessionStorage not supported on this platform');
