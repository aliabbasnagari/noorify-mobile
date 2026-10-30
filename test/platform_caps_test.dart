import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/ui/adaptive/platform_caps.dart';

void main() {
  PlatformCaps caps(TargetPlatform platform, {bool web = false}) =>
      PlatformCaps(isWeb: web, platform: platform);

  test('Android has the equalizer, skip silence, downloads and system volume',
      () {
    final c = caps(TargetPlatform.android);

    expect(c.isAndroid, isTrue);
    expect(c.supportsEqualizer, isTrue);
    expect(c.supportsSkipSilence, isTrue);
    expect(c.supportsDownloads, isTrue);
    expect(c.hasSystemVolume, isTrue);
  });

  test('iOS has downloads and system volume but no Android audio effects', () {
    final c = caps(TargetPlatform.iOS);

    expect(c.supportsEqualizer, isFalse);
    expect(c.supportsSkipSilence, isFalse);
    expect(c.supportsDownloads, isTrue);
    expect(c.hasSystemVolume, isTrue);
  });

  test('desktop platforms download but need the in-app volume', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ]) {
      final c = caps(platform);

      expect(c.supportsEqualizer, isFalse, reason: '$platform');
      expect(c.supportsSkipSilence, isFalse, reason: '$platform');
      expect(c.supportsDownloads, isTrue, reason: '$platform');
      expect(c.hasSystemVolume, isFalse, reason: '$platform');
    }
  });

  test('a browser can do none of the device things, whatever the OS', () {
    for (final platform in TargetPlatform.values) {
      final c = caps(platform, web: true);

      expect(c.isAndroid, isFalse, reason: '$platform');
      expect(c.supportsEqualizer, isFalse, reason: '$platform');
      expect(c.supportsSkipSilence, isFalse, reason: '$platform');
      expect(c.supportsDownloads, isFalse, reason: '$platform');
      expect(c.hasSystemVolume, isFalse, reason: '$platform');
    }
  });

  test('current() reads the platform the tests run as', () {
    final c = PlatformCaps.current();

    expect(c.isWeb, isFalse);
    expect(c.platform, defaultTargetPlatform);
  });
}
