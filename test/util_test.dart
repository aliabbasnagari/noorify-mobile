import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/subsonic/subsonic_client.dart';
import 'package:noorify/ui/util.dart';

void main() {
  group('isConnectivityError', () {
    test('true for the "could not reach server" shape', () {
      expect(
        isConnectivityError(
            SubsonicException('Could not reach server: SocketException')),
        isTrue,
      );
    });

    test('false for a real server error with a code', () {
      expect(
        isConnectivityError(
            SubsonicException('Wrong username or password', code: 40)),
        isFalse,
      );
    });

    test('false for a non-SubsonicException', () {
      expect(isConnectivityError(Exception('boom')), isFalse);
    });
  });
}
