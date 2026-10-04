import 'package:shared_preferences/shared_preferences.dart';

/// Where Journey keeps its small JSON blobs (progress, settings).
/// The main app can later supply its own implementation through JourneyHost.
abstract class JourneyStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryStorage implements JourneyStorage {
  MemoryStorage([Map<String, String>? initial]) : data = {...?initial};
  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

class SharedPrefsStorage implements JourneyStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
  @override
  Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}
