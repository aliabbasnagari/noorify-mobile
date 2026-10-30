import 'package:flutter/foundation.dart';

/// What the platform the app is running on can actually do, so screens offer
/// only the things that will work instead of showing a switch that does
/// nothing (an equalizer on iOS, downloads in a browser).
///
/// Provided app-wide (`Provider<PlatformCaps>`); tests pass their own.
class PlatformCaps {
  const PlatformCaps({required this.isWeb, required this.platform});

  /// The platform the app is running on right now.
  factory PlatformCaps.current() =>
      PlatformCaps(isWeb: kIsWeb, platform: defaultTargetPlatform);

  final bool isWeb;
  final TargetPlatform platform;

  bool get isAndroid => !isWeb && platform == TargetPlatform.android;

  /// The system equalizer and loudness enhancer exist only on Android.
  bool get supportsEqualizer => isAndroid;

  /// Skipping silence is an ExoPlayer (Android) feature.
  bool get supportsSkipSilence => isAndroid;

  /// Downloads are files on disk, which a browser tab does not have.
  bool get supportsDownloads => !isWeb;

  /// Whether the device has its own volume keys and system volume, which the
  /// in-app volume slider on desktop and web stands in for.
  bool get hasSystemVolume =>
      !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
}
