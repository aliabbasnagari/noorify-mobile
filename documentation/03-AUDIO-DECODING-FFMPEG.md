# Noorify - Audio Playback & Decoding

## 1. Overview

Noorify does not bundle a decoder of its own. Playback runs on **`just_audio`**
(queue/transport/effects API) with **`audio_service`** providing the OS media
session (`PlayerController` is itself the `audio_service` `AudioHandler` — see
[05-AUDIO-HARDWARE-INTEGRATION.md](05-AUDIO-HARDWARE-INTEGRATION.md)). Both are
pure-Dart/plugin packages declared in `pubspec.yaml`:

```yaml
just_audio: ^0.9.40
audio_service: ^0.18.19
```

`just_audio` is a thin Dart wrapper around each platform's native media
framework — there is no custom native codec, no JNI bridge, and no bundled
FFmpeg in this codebase. Decoding is delegated entirely to the OS:

| Platform | Decoding backend (via just_audio) |
|----------|-----------------------------------|
| Android | ExoPlayer (Media3) |
| iOS / macOS | AVFoundation (`AVPlayer`) |
| Windows / Linux | platform plugins backing `just_audio` (`just_audio_windows`, `just_audio_mpv`/community plugins) |
| Web | HTML5 `<audio>` / MediaSource, where supported |

Supported container/codec coverage (MP3, AAC, FLAC, OGG/Vorbis/Opus, WAV) is
therefore whatever each OS's native player supports — Noorify does not extend
or restrict it. There is no DSD support and no bit-perfect/USB-specific output
path; those were part of Symfonium's native FFmpeg/JNI stack (see
`ui-mobile/docs/symfonium-findings.md`) and were not carried over.

## 2. Where Playback Lives

All transport state is owned by `lib/state/player_controller.dart`
(`PlayerController`, a `ChangeNotifier` registered with `provider`). It wraps a
single `AudioPlayer`:

```dart
_player = AudioPlayer(
  audioPipeline: _isAndroid
      ? AudioPipeline(androidAudioEffects: [_equalizer, _loudness])
      : null,
);
```

`AudioPipeline`/`AndroidEqualizer`/`AndroidLoudnessEnhancer` only attach on
Android, since both wrap Android's native `AudioEffect` framework — there is
no equivalent effect chain on other platforms today.

## 3. Queue & Source Resolution

The queue is a `ConcatenatingAudioSource` built from the app's `Song` models.
Each song is resolved to a local file (if downloaded) or a streamed URL from
the active Subsonic/OpenSubsonic server — never a raw path handed to a native
decoder:

```dart
MediaItem _toMediaItem(Song s) => MediaItem(
      id: s.id,
      title: s.title,
      album: s.album,
      artist: s.artist,
      duration: s.duration > 0 ? Duration(seconds: s.duration) : null,
      artUri: coverUri(s.coverArt),
    );

AudioSource _toSource(Song s) {
  final client = _client;
  if (client == null) throw StateError('No active server session');
  final tag = _toMediaItem(s);
  // Prefer the offline copy when we have one.
  final local = _downloads?.localPath(s.id);
  if (local != null && File(local).existsSync()) {
    return AudioSource.file(local, tag: tag);
  }
  return AudioSource.uri(client.streamUrl(s.id), tag: tag);
}
```

The `MediaItem` tag on each source is also what `PlayerController` pushes
through `audio_service`'s `mediaItem`/`queue` streams to surface the OS media
session / notification / lock screen (see
[05-AUDIO-HARDWARE-INTEGRATION.md](05-AUDIO-HARDWARE-INTEGRATION.md)).

`playSongs()` replaces the queue, loads the `ConcatenatingAudioSource`, and
re-applies the sound-shaping settings below once a source exists (effects only
exist on Android after a source is loaded):

```dart
await _player.setAudioSource(_source, initialIndex: index);
await _player.setShuffleModeEnabled(shuffle);
if (shuffle) await _player.shuffle();
unawaited(_applySettings());
unawaited(_player.play());
```

## 4. ReplayGain

ReplayGain is **not** a native DSP effect — it's a plain Dart volume
calculation in `lib/audio/replay_gain.dart`, run against the OpenSubsonic
`replayGain` block already attached to each `Song`:

```dart
double replayGainDb(ReplayGainInfo? info, ReplayGainMode mode, double preAmpDb) {
  if (mode == ReplayGainMode.off) return 0;
  if (info == null) return preAmpDb;

  final preferTrack = mode == ReplayGainMode.track;
  final gain = preferTrack
      ? (info.trackGain ?? info.albumGain)
      : (info.albumGain ?? info.trackGain);
  final peak = preferTrack
      ? (info.trackPeak ?? info.albumPeak)
      : (info.albumPeak ?? info.trackPeak);

  var db = (gain ?? info.fallbackGain ?? 0) + preAmpDb;
  if (peak != null && peak > 0) {
    // Largest gain that keeps the peak at or below full scale.
    db = math.min(db, -20 * math.log(peak) / math.ln10);
  }
  return db;
}

double dbToVolume(double db) =>
    math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
```

Negative gain (attenuation) is applied directly as player volume. Positive
gain can't be expressed that way — `AudioPlayer.volume` tops out at `1.0` — so
on Android it's realized through `AndroidLoudnessEnhancer.setTargetGain()`
instead. On platforms without that effect, positive ReplayGain is simply not
boosted (no clipping, no silent failure — see `_applyVolume()` in
`player_controller.dart`).

Modes: **Off / Track / Album**, plus a user pre-amp in dB
(`PlaybackSettings.preAmpDb`, see `lib/settings/settings_models.dart`).

## 5. Fade In / Fade Out, and Crossfade

The edge fade is a software volume ramp computed every ~50–100 ms from the
player's position stream and folded into the same volume calculation as
ReplayGain:

```dart
void _updateFade(Duration position) {
  final p = _playback;
  var f = 1.0;
  if (p.fadeInMs > 0 || p.fadeOutMs > 0) {
    final posMs = position.inMilliseconds;
    if (p.fadeInMs > 0 && posMs < p.fadeInMs) f = posMs / p.fadeInMs;
    final durMs = _player.duration?.inMilliseconds ?? ...;
    if (p.fadeOutMs > 0 && durMs != null) {
      final remaining = durMs - posMs;
      if (remaining < p.fadeOutMs) {
        f = f < remaining / p.fadeOutMs ? f : remaining / p.fadeOutMs;
      }
    }
    f = f.clamp(0.0, 1.0);
  }
  ...
}

// volume = ReplayGain(dB → linear) × fade factor
final volume = (dbToVolume(db) * _fade).clamp(0.0, 1.0);
```

### 5.1 Crossfade

When `PlaybackSettings.crossfadeMs > 0` (Settings → Playback → Crossfade,
0–12s, off by default), the same `_updateFade` tick drives a real overlapping
crossfade for **sequential** (non-shuffled) playback instead of a plain
fade-out, using a second, lazily-created `AudioPlayer`:

1. Within the final `crossfadeMs` of the current track, `_peekNextSequential()`
   determines what plays next without shuffle (`_queue[i+1]`, or `_queue[0]`
   under `LoopMode.all` at the end of the queue; `null` under shuffle or
   `LoopMode.one`, which skip crossfade entirely).
2. `_startCrossfade()` loads that song onto the overlap player at volume 0 and
   starts it playing, while the main player continues the current track.
3. Each subsequent tick (`_tickCrossfade()`) computes progress `t` purely from
   the main player's position (not a separate timer), ramping the main
   player's volume down via the existing `_fade`/ReplayGain volume formula and
   the overlap player's volume up toward the *next* song's own
   ReplayGain-adjusted target — so loudness doesn't jump at the handoff.
4. The main player's own `ConcatenatingAudioSource` still auto-advances
   gaplessly to the next track on its own (nothing about its sequencing is
   disabled). When that happens, `_onIndexChanged` detects the index changed
   while crossfading and calls `_finishCrossfade()`, which seeks the main
   player to the overlap player's current position — a one-time handoff so
   there is only ever one audible copy — then stops (not disposes) the
   overlap player for reuse next time.

A `_finishingCrossfade` flag covers the gap `_crossfading` itself can't: that
flag flips to `false` synchronously the instant the handoff starts, but the
seek in step 4 is async, and the position-stream tick driving `_updateFade`
keeps firing every 50-100ms regardless. Without a separate flag, that next
tick would see "not crossfading" and run the normal (non-crossfade) fade-in
path, which forces the main player back to full volume while it's still
sitting at position 0 pre-seek — audible as the new track briefly
"restarting" before snapping to the right spot once the seek lands. Both
`_onIndexChanged` and `_updateFade` check `_finishingCrossfade` and defer to
`_finishCrossfade()` (which clears it once the seek + overlap-stop actually
complete) instead of touching `_fade`/volume themselves during that window.

Known limitations (by design, not bugs): the overlap player has no
`AudioPipeline`/effects of its own, so EQ and the loudness enhancer only
apply once a track has handed off to the main player — the incoming track
plays briefly unprocessed during the overlap window. If the user skips
manually mid-crossfade, `_finishCrossfade()` detects the index doesn't match
the expected next song, skips the seek, and just stops the overlap player.

## 6. Skip Silence

`AudioPlayer.setSkipSilenceEnabled(bool)` is a thin call into ExoPlayer's
native skip-silence feature — Android only, no custom detection logic:

```dart
await _player.setSkipSilenceEnabled(p.skipSilence);
```

## 7. Equalizer

The EQ is Android-only (`AndroidEqualizer`, from `just_audio`'s audio
pipeline) and band-agnostic: `lib/audio/equalizer_presets.dart` defines
presets as a 5-point gain curve and linearly interpolates it onto however many
bands the device's native equalizer actually exposes:

```dart
const eqPresets = <EqPreset>[
  EqPreset('Flat', [0, 0, 0, 0, 0]),
  EqPreset('Bass boost', [6, 4, 0, 0, 0]),
  EqPreset('Treble boost', [0, 0, 0, 3, 6]),
  EqPreset('Vocal', [-2, 0, 3, 3, 0]),
  EqPreset('Rock', [4, 2, -2, 2, 4]),
  EqPreset('Classical', [3, 2, -1, 2, 3]),
];

double gainForBand(List<double> gains, int index, int bandCount) { ... }
```

`PlayerController` reads the device's real band count/range from
`AndroidEqualizer.parameters` (only available once a source is loaded) and
writes clamped gains per band:

```dart
Future<void> _writeBands(AndroidEqualizerParameters params, List<double> gains) async {
  final n = params.bands.length;
  for (var i = 0; i < n; i++) {
    final g = gainForBand(gains, i, n).clamp(params.minDecibels, params.maxDecibels);
    await params.bands[i].setGain(g);
  }
}
```

There is no parametric EQ (shelf filters, Q-factor, limiter) — Symfonium
exposed a 10-band PEQ natively; Noorify deliberately ships the simpler
preset + device-equalizer model instead (see
`ui-mobile/docs/symfonium-findings.md` for that design call), and it does not
exist on non-Android platforms.

## 8. What's Intentionally Not Here

So nobody goes looking for native hooks that don't exist in this codebase:

- No bundled FFmpeg, no `.so` codec libraries, no JNI/NDK code.
- No custom demuxer/decoder/resampler pipeline — the OS player does all of it.
- No DSD (DSF/DFF), no bit-perfect/USB-audio-specific output path.
- No parametric EQ, shelf filters, limiter, or hardware DSP beyond what
  `AndroidEqualizer`/`AndroidLoudnessEnhancer` expose — in particular,
  `just_audio` has no `AndroidBassBoost`/`AndroidVirtualizer` classes to wrap,
  so bass boost/virtualizer aren't implemented (would need a bespoke native
  Android platform channel around `android.media.audiofx`, not a `just_audio`
  feature gap that can be closed in Dart).

Anything in this list is a legitimate place to extend the app — just do it by
reaching for the right Flutter/Dart package or platform channel, not by
porting native Kotlin/JNI code wholesale.
