import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../subsonic/subsonic_client.dart';

/// Owns the server login and exposes the active [SubsonicClient].
class SessionController extends ChangeNotifier {
  SessionController({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kUrl = 'server_url';
  static const _kUser = 'server_user';
  static const _kPass = 'server_pass';

  final FlutterSecureStorage _storage;

  SubsonicClient? _client;
  bool _restoring = true;

  SubsonicClient? get client => _client;
  bool get isRestoring => _restoring;
  bool get isLoggedIn => _client != null;

  /// Tries to sign in with the credentials saved by a previous session.
  Future<void> restore() async {
    try {
      final url = await _storage.read(key: _kUrl);
      final user = await _storage.read(key: _kUser);
      final pass = await _storage.read(key: _kPass);
      if (url != null && user != null && pass != null) {
        final client = SubsonicClient(
          ServerConfig(url: url, username: user, password: pass),
        );
        await client.ping();
        _client = client;
      }
    } on Object {
      // Offline or bad stored credentials: fall back to the login screen.
      _client = null;
    }
    _restoring = false;
    notifyListeners();
  }

  /// Validates the credentials against the server, then persists them.
  /// Throws [SubsonicException] on failure.
  Future<void> login(String url, String username, String password) async {
    final client = SubsonicClient(
      ServerConfig(
        url: normalizeUrl(url),
        username: username.trim(),
        password: password,
      ),
    );
    await client.ping();
    await _storage.write(key: _kUrl, value: client.config.url);
    await _storage.write(key: _kUser, value: client.config.username);
    await _storage.write(key: _kPass, value: client.config.password);
    _client = client;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: _kUrl);
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kPass);
    _client = null;
    notifyListeners();
  }

  @visibleForTesting
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (!url.contains('://')) url = 'https://$url';
    return url.replaceAll(RegExp(r'/+$'), '');
  }
}
