import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../subsonic/subsonic_client.dart';

/// Owns the server login and exposes the active [SubsonicClient].
class SessionController extends ChangeNotifier {
  SessionController({
    FlutterSecureStorage? storage,
    SubsonicClient Function(ServerConfig config)? clientFactory,
  })  : _storage = storage ??
            // The data-protection keychain needs a keychain-access-groups
            // entitlement, which unsigned/ad-hoc macOS builds don't have.
            const FlutterSecureStorage(
              mOptions: MacOsOptions(useDataProtectionKeyChain: false),
            ),
        _clientFactory = clientFactory ?? SubsonicClient.new;

  static const _kUrl = 'server_url';
  static const _kUser = 'server_user';
  static const _kPass = 'server_pass';

  /// Subsonic error codes that mean the saved credentials are no longer
  /// usable: 40 wrong username/password, 41 token auth unsupported for this
  /// user, 44 invalid API key.
  static const _credentialErrorCodes = {40, 41, 44};

  final FlutterSecureStorage _storage;
  final SubsonicClient Function(ServerConfig config) _clientFactory;

  SubsonicClient? _client;
  bool _restoring = true;

  SubsonicClient? get client => _client;
  bool get isRestoring => _restoring;
  bool get isLoggedIn => _client != null;

  /// Signs in with the credentials saved by a previous session.
  ///
  /// The session is restored from storage without waiting on the network, so
  /// the app still opens (and downloaded songs still play) while offline. The
  /// server is checked in the background and the session is dropped only if it
  /// explicitly rejects the saved credentials.
  Future<void> restore() async {
    try {
      final url = await _storage.read(key: _kUrl);
      final user = await _storage.read(key: _kUser);
      final pass = await _storage.read(key: _kPass);
      if (url != null && user != null && pass != null) {
        _client = _clientFactory(
          ServerConfig(url: url, username: user, password: pass),
        );
      }
    } on Object {
      // Unreadable secure storage: fall back to the login screen.
      _client = null;
    }
    _restoring = false;
    notifyListeners();
    final restored = _client;
    if (restored != null) unawaited(_verify(restored));
  }

  Future<void> _verify(SubsonicClient client) async {
    try {
      await client.ping();
    } on SubsonicException catch (e) {
      if (!_credentialErrorCodes.contains(e.code)) return;
      if (identical(client, _client)) await logout();
    } on Object {
      // Offline or server down: keep the session.
    }
  }

  /// Validates the credentials against the server, then persists them.
  /// Throws [SubsonicException] on failure.
  Future<void> login(String url, String username, String password) async {
    final client = _clientFactory(
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
