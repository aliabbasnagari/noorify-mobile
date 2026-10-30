import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/state/session_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

void main() {
  const saved = {
    'server_url': 'https://music.example.com',
    'server_user': 'alice',
    'server_pass': 'sesame',
  };

  SessionController controllerWith(
    http.Client httpClient, {
    Map<String, String> stored = saved,
  }) {
    FlutterSecureStorage.setMockInitialValues({...stored});
    return SessionController(
      storage: const FlutterSecureStorage(),
      clientFactory: (config) => SubsonicClient(config, httpClient: httpClient),
    );
  }

  http.Response subsonic(Map<String, dynamic> body) =>
      http.Response(jsonEncode({'subsonic-response': body}), 200);

  test('restores the saved session even when the server is unreachable',
      () async {
    final session = controllerWith(
      MockClient((_) async => throw http.ClientException('no network')),
    );

    await session.restore();
    await Future<void>.delayed(Duration.zero);

    expect(session.isRestoring, isFalse);
    expect(session.isLoggedIn, isTrue);
  });

  test('keeps the session when the background check succeeds', () async {
    final session = controllerWith(
      MockClient((_) async => subsonic({'status': 'ok'})),
    );

    await session.restore();
    await Future<void>.delayed(Duration.zero);

    expect(session.isLoggedIn, isTrue);
  });

  test('drops the session when the server rejects the saved credentials',
      () async {
    final session = controllerWith(
      MockClient(
        (_) async => subsonic({
          'status': 'failed',
          'error': {'code': 40, 'message': 'Wrong username or password'},
        }),
      ),
    );

    await session.restore();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(session.isLoggedIn, isFalse);
    expect(await const FlutterSecureStorage().read(key: 'server_pass'), isNull);
  });

  test('keeps the session on a non-credential server error', () async {
    final session = controllerWith(
      MockClient(
        (_) async => subsonic({
          'status': 'failed',
          'error': {'code': 0, 'message': 'Generic error'},
        }),
      ),
    );

    await session.restore();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(session.isLoggedIn, isTrue);
  });

  test('stays signed out when nothing is saved', () async {
    final session = controllerWith(
      MockClient((_) async => subsonic({'status': 'ok'})),
      stored: const {},
    );

    await session.restore();

    expect(session.isRestoring, isFalse);
    expect(session.isLoggedIn, isFalse);
  });
}
