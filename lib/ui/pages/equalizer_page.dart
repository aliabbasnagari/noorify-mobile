import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../audio/equalizer_presets.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  late final Future<AndroidEqualizerParameters?> _params;

  /// Gains shown while dragging; committed to settings on release.
  List<double>? _draft;

  @override
  void initState() {
    super.initState();
    _params = context.read<PlayerController>().equalizerParameters();
  }

  static String _freq(double hz) =>
      hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k' : hz.round().toString();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final player = context.read<PlayerController>();
    final p = settings.playback;

    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer')),
      body: FutureBuilder<AndroidEqualizerParameters?>(
        future: _params,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final params = snap.data;
          if (params == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'The equalizer is available on Android once something is '
                  'playing. Start a song, then come back.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final n = params.bands.length;
          final gains = _draft ?? projectGains(p.eqGains, n);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Enable equalizer'),
                value: p.eqEnabled,
                onChanged: (v) => settings.updatePlayback((c) => c.copyWith(
                      eqEnabled: v,
                      eqGains: c.eqGains.isEmpty ? List.filled(n, 0.0) : c.eqGains,
                    )),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final preset in eqPresets)
                    ActionChip(
                      label: Text(preset.name),
                      onPressed: () {
                        // Devices differ in range (the emulator only allows ±2 dB),
                        // so store what will actually be applied.
                        final g = [
                          for (final v in projectGains(preset.gains, n))
                            v.clamp(params.minDecibels, params.maxDecibels).toDouble(),
                        ];
                        setState(() => _draft = null);
                        settings.updatePlayback(
                          (c) => c.copyWith(eqEnabled: true, eqGains: g),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
                child: Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              gains[i].toStringAsFixed(0),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  min: params.minDecibels,
                                  max: params.maxDecibels,
                                  value: gains[i].clamp(params.minDecibels, params.maxDecibels),
                                  onChanged: p.eqEnabled
                                      ? (v) {
                                          final next = [...gains]..[i] = v;
                                          setState(() => _draft = next);
                                          player.previewEqualizer(next);
                                        }
                                      : null,
                                  onChangeEnd: (_) {
                                    final committed = _draft;
                                    if (committed == null) return;
                                    settings.updatePlayback((c) => c.copyWith(eqGains: committed));
                                    setState(() => _draft = null);
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _freq(params.bands[i].centerFrequency),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${params.minDecibels.round()} to ${params.maxDecibels.round()} dB, Hz',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
