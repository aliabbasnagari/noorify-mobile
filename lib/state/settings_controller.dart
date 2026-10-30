import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings_models.dart';

/// Persists [PlaybackSettings], [HomeLayout], [ShellLayoutSettings] and the
/// theme preference as
/// JSON/plain values in SharedPreferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    playback =
        _read(_kPlayback, PlaybackSettings.fromJson, const PlaybackSettings());
    home = _read(_kHome, HomeLayout.fromJson, HomeLayout.defaults);
    shell = _read(
        _kShell, ShellLayoutSettings.fromJson, const ShellLayoutSettings());
    themeMode = AppThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_kThemeMode),
      // Dark is the default theme (matches the Spotify-exact design target).
      orElse: () => AppThemeMode.dark,
    );
  }

  static const _kPlayback = 'settings.playback';
  static const _kHome = 'settings.home';
  static const _kThemeMode = 'settings.themeMode';
  static const _kShell = 'settings.shell';

  final SharedPreferences _prefs;

  late PlaybackSettings playback;
  late HomeLayout home;
  late AppThemeMode themeMode;
  late ShellLayoutSettings shell;

  T _read<T>(String key, T Function(Map<String, dynamic>) parse, T fallback) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return fallback;
      return parse(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Corrupt or outdated settings must never block startup.
      return fallback;
    }
  }

  Future<void> updatePlayback(
      PlaybackSettings Function(PlaybackSettings) change) async {
    playback = change(playback);
    notifyListeners();
    await _prefs.setString(_kPlayback, jsonEncode(playback.toJson()));
  }

  Future<void> setHome(HomeLayout layout) async {
    home = layout;
    notifyListeners();
    await _prefs.setString(_kHome, jsonEncode(layout.toJson()));
  }

  Future<void> updateShell(
      ShellLayoutSettings Function(ShellLayoutSettings) change) async {
    shell = change(shell);
    notifyListeners();
    await _prefs.setString(_kShell, jsonEncode(shell.toJson()));
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kThemeMode, mode.name);
  }
}
