/// User-facing settings. Shapes follow the configuration models REA observed
/// in Symfonium (PlaybackReplayGainSettings, RendererTransitionsSettings,
/// EqualizationProfile, SkipSilenceProfile, HomeRowConfiguration).
library;

enum ReplayGainMode { off, track, album }

/// User's theme preference. Noorify's Spotify-exact theme only ships a Dark
/// and a Light scheme (no Solarized), but `system` still means "follow the
/// OS" rather than always defaulting to Dark.
enum AppThemeMode { system, light, dark }

class PlaybackSettings {
  const PlaybackSettings({
    this.replayGain = ReplayGainMode.off,
    this.preAmpDb = 0,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.crossfadeMs = 0,
    this.skipSilence = false,
    this.eqEnabled = false,
    this.eqGains = const [],
    this.volume = 1,
    this.muted = false,
  });

  final ReplayGainMode replayGain;
  final double preAmpDb;
  final int fadeInMs;
  final int fadeOutMs;

  /// Overlap between consecutive tracks, in ms. 0 disables crossfade, in
  /// which case [fadeOutMs] (if set) still applies as an edge-only fade.
  /// Only used for sequential (non-shuffled) playback.
  final int crossfadeMs;
  final bool skipSilence;
  final bool eqEnabled;

  /// Per-band gain in dB for the device's equalizer bands.
  final List<double> eqGains;

  /// The listener's own volume, 0..1, applied on top of ReplayGain and fades.
  /// Phones leave this at 1 and use the hardware keys; desktop and web, which
  /// have no per-app hardware control, expose it as a slider.
  final double volume;

  /// Silences playback without losing [volume], so unmuting restores it.
  final bool muted;

  PlaybackSettings copyWith({
    ReplayGainMode? replayGain,
    double? preAmpDb,
    int? fadeInMs,
    int? fadeOutMs,
    int? crossfadeMs,
    bool? skipSilence,
    bool? eqEnabled,
    List<double>? eqGains,
    double? volume,
    bool? muted,
  }) =>
      PlaybackSettings(
        replayGain: replayGain ?? this.replayGain,
        preAmpDb: preAmpDb ?? this.preAmpDb,
        fadeInMs: fadeInMs ?? this.fadeInMs,
        fadeOutMs: fadeOutMs ?? this.fadeOutMs,
        crossfadeMs: crossfadeMs ?? this.crossfadeMs,
        skipSilence: skipSilence ?? this.skipSilence,
        eqEnabled: eqEnabled ?? this.eqEnabled,
        eqGains: eqGains ?? this.eqGains,
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
      );

  Map<String, dynamic> toJson() => {
        'replayGain': replayGain.name,
        'preAmpDb': preAmpDb,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'crossfadeMs': crossfadeMs,
        'skipSilence': skipSilence,
        'eqEnabled': eqEnabled,
        'eqGains': eqGains,
        'volume': volume,
        'muted': muted,
      };

  factory PlaybackSettings.fromJson(Map<String, dynamic> j) => PlaybackSettings(
        replayGain: ReplayGainMode.values.firstWhere(
          (m) => m.name == j['replayGain'],
          orElse: () => ReplayGainMode.off,
        ),
        preAmpDb: (j['preAmpDb'] as num?)?.toDouble() ?? 0,
        fadeInMs: (j['fadeInMs'] as num?)?.toInt() ?? 0,
        fadeOutMs: (j['fadeOutMs'] as num?)?.toInt() ?? 0,
        crossfadeMs: (j['crossfadeMs'] as num?)?.toInt() ?? 0,
        skipSilence: j['skipSilence'] as bool? ?? false,
        eqEnabled: j['eqEnabled'] as bool? ?? false,
        eqGains: [
          for (final g in (j['eqGains'] as List? ?? const []))
            (g as num).toDouble(),
        ],
        volume: ((j['volume'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0),
        muted: j['muted'] as bool? ?? false,
      );
}

/// One configurable shelf on the home screen.
class HomeRowConfig {
  const HomeRowConfig({required this.id, this.visible = true, this.count = 20});

  /// One of [homeRowTitles]' keys.
  final String id;
  final bool visible;

  /// Number of items in the row (cf. `dataItemCount`).
  final int count;

  HomeRowConfig copyWith({bool? visible, int? count}) => HomeRowConfig(
      id: id, visible: visible ?? this.visible, count: count ?? this.count);

  Map<String, dynamic> toJson() =>
      {'id': id, 'visible': visible, 'count': count};

  factory HomeRowConfig.fromJson(Map<String, dynamic> j) => HomeRowConfig(
        id: j['id'] as String,
        visible: j['visible'] as bool? ?? true,
        count: (j['count'] as num?)?.toInt() ?? 20,
      );
}

const homeRowTitles = <String, String>{
  'recent': 'Recently played',
  'newest': 'Newly added',
  'frequent': 'Most played',
  'random': 'Discover',
  'starred': 'Favorites',
};

class HomeLayout {
  const HomeLayout(this.rows);

  final List<HomeRowConfig> rows;

  static const defaults = HomeLayout([
    HomeRowConfig(id: 'recent'),
    HomeRowConfig(id: 'newest'),
    HomeRowConfig(id: 'frequent'),
    HomeRowConfig(id: 'random'),
    HomeRowConfig(id: 'starred', visible: false),
  ]);

  Map<String, dynamic> toJson() => {
        'rows': [for (final r in rows) r.toJson()]
      };

  /// Unknown rows are dropped and rows missing from storage are appended, so
  /// a stored layout survives app updates that add or remove shelves.
  factory HomeLayout.fromJson(Map<String, dynamic> j) {
    final stored = [
      for (final r in (j['rows'] as List? ?? const []))
        HomeRowConfig.fromJson(r as Map<String, dynamic>),
    ].where((r) => homeRowTitles.containsKey(r.id)).toList();
    final known = stored.map((r) => r.id).toSet();
    return HomeLayout([
      ...stored,
      for (final d in defaults.rows)
        if (!known.contains(d.id)) d,
    ]);
  }
}
