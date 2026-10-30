import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/state/star_controller.dart';
import 'package:noorify/subsonic/subsonic_client.dart';

void main() {
  const config = ServerConfig(
    url: 'https://music.example.com',
    username: 'alice',
    password: 'sesame',
  );

  late List<Uri> requests;

  StarController controllerReplying(Map<String, dynamic> body) {
    requests = [];
    final client = SubsonicClient(
      config,
      httpClient: MockClient((req) async {
        requests.add(req.url);
        return http.Response(jsonEncode({'subsonic-response': body}), 200);
      }),
    );
    return StarController()..attach(client);
  }

  test('starring calls the star endpoint and flips the state', () async {
    final stars = controllerReplying({'status': 'ok'});
    const song = Song(id: 's1', title: 'One');
    expect(stars.isStarred(song), isFalse);

    await stars.toggle(song);

    expect(stars.isStarred(song), isTrue);
    expect(requests.single.path, endsWith('/rest/star.view'));
    expect(requests.single.queryParameters['id'], 's1');
  });

  test('toggling an already starred song unstars it', () async {
    final stars = controllerReplying({'status': 'ok'});
    const song = Song(id: 's1', title: 'One', starred: true);
    expect(stars.isStarred(song), isTrue);

    await stars.toggle(song);

    expect(stars.isStarred(song), isFalse);
    expect(requests.single.path, endsWith('/rest/unstar.view'));
  });

  test('a failed call puts the state back and rethrows', () async {
    final stars = controllerReplying({
      'status': 'failed',
      'error': {'code': 0, 'message': 'nope'},
    });
    const song = Song(id: 's1', title: 'One');

    await expectLater(stars.toggle(song), throwsA(isA<SubsonicException>()));

    expect(stars.isStarred(song), isFalse);
  });

  test('the state is notified immediately, before the server answers', () async {
    final stars = controllerReplying({'status': 'ok'});
    const song = Song(id: 's1', title: 'One');
    var notified = 0;
    stars.addListener(() => notified++);

    final pending = stars.toggle(song);
    expect(notified, 1);
    expect(stars.isStarred(song), isTrue);
    await pending;
  });

  test('attaching a different client forgets session overrides', () async {
    final stars = controllerReplying({'status': 'ok'});
    const song = Song(id: 's1', title: 'One');
    await stars.toggle(song);
    expect(stars.isStarred(song), isTrue);

    stars.attach(null);

    expect(stars.isStarred(song), isFalse);
  });
}
