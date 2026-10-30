/// Retries a flaky [action] with exponential backoff (delay doubles each
/// attempt), for transient failures like a dropped mobile connection.
///
/// Gives up and rethrows once [maxAttempts] have failed.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } on Object {
      if (attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(initialDelay * (1 << (attempt - 1)));
    }
  }
}
