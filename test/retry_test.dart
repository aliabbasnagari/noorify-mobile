import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/util/retry.dart';

void main() {
  const noDelay = Duration.zero;

  test('returns the result on the first successful attempt', () async {
    var calls = 0;
    final result = await withRetry(() async {
      calls++;
      return 42;
    }, initialDelay: noDelay);
    expect(result, 42);
    expect(calls, 1);
  });

  test('retries after a failure and returns once it succeeds', () async {
    var calls = 0;
    final result = await withRetry(() async {
      calls++;
      if (calls < 3) throw Exception('transient');
      return 'ok';
    }, maxAttempts: 5, initialDelay: noDelay);
    expect(result, 'ok');
    expect(calls, 3);
  });

  test('gives up and rethrows after maxAttempts failures', () async {
    var calls = 0;
    await expectLater(
      withRetry(() async {
        calls++;
        throw Exception('always fails');
      }, maxAttempts: 3, initialDelay: noDelay),
      throwsException,
    );
    expect(calls, 3);
  });
}
