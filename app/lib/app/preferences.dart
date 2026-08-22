import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppPreferences {
  bool? getBool(String key);

  String? getString(String key);

  Future<bool> setBool(String key, bool value);

  Future<bool> setString(String key, String value);
}

class SharedPreferencesStore implements AppPreferences {
  const SharedPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  bool? getBool(String key) => _preferences.getBool(key);

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  Future<bool> setBool(String key, bool value) =>
      _preferences.setBool(key, value);

  @override
  Future<bool> setString(String key, String value) =>
      _preferences.setString(key, value);
}

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  throw StateError('AppPreferences must be supplied at bootstrap.');
});
