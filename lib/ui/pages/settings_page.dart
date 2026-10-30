import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../settings/settings_models.dart';
import '../../state/download_controller.dart';
import '../../state/session_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/sync_controller.dart';
import '../routing/app_routes.dart';
import '../routing/navigation.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final p = settings.playback;
    final sync = context.watch<SyncController>();
    final downloads = context.watch<DownloadController>();

    void update(PlaybackSettings Function(PlaybackSettings) change) =>
        settings.updatePlayback(change);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Section('Appearance'),
          const ListTile(title: Text('Theme')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                    value: AppThemeMode.system, label: Text('System')),
                ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          const _Section('Playback'),
          const ListTile(
            title: Text('ReplayGain'),
            subtitle: Text(
              'Evens out loudness using gain tags provided by your server '
              '(OpenSubsonic). Tracks without tags play unchanged.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ReplayGainMode>(
              segments: const [
                ButtonSegment(value: ReplayGainMode.off, label: Text('Off')),
                ButtonSegment(
                    value: ReplayGainMode.track, label: Text('Track')),
                ButtonSegment(
                    value: ReplayGainMode.album, label: Text('Album')),
              ],
              selected: {p.replayGain},
              onSelectionChanged: (s) =>
                  update((c) => c.copyWith(replayGain: s.first)),
            ),
          ),
          _SliderTile(
            label: 'Pre-amp',
            valueText: '${p.preAmpDb.toStringAsFixed(1)} dB',
            value: p.preAmpDb,
            min: -12,
            max: 12,
            divisions: 48,
            enabled: p.replayGain != ReplayGainMode.off,
            onChanged: (v) => update((c) => c.copyWith(preAmpDb: v)),
          ),
          _SliderTile(
            label: 'Fade in',
            valueText: p.fadeInMs == 0
                ? 'Off'
                : '${(p.fadeInMs / 1000).toStringAsFixed(1)} s',
            value: p.fadeInMs / 1000,
            min: 0,
            max: 10,
            divisions: 40,
            onChanged: (v) =>
                update((c) => c.copyWith(fadeInMs: (v * 1000).round())),
          ),
          _SliderTile(
            label: 'Fade out',
            valueText: p.fadeOutMs == 0
                ? 'Off'
                : '${(p.fadeOutMs / 1000).toStringAsFixed(1)} s',
            value: p.fadeOutMs / 1000,
            min: 0,
            max: 10,
            divisions: 40,
            onChanged: (v) =>
                update((c) => c.copyWith(fadeOutMs: (v * 1000).round())),
          ),
          const ListTile(
            title: Text('Crossfade'),
            subtitle: Text(
              'Overlaps the end of a track with the start of the next. '
              'Sequential playback only; takes over from Fade out for the '
              'last stretch of each track.',
            ),
          ),
          _SliderTile(
            label: 'Crossfade',
            valueText: p.crossfadeMs == 0
                ? 'Off'
                : '${(p.crossfadeMs / 1000).toStringAsFixed(1)} s',
            value: p.crossfadeMs / 1000,
            min: 0,
            max: 12,
            divisions: 48,
            onChanged: (v) =>
                update((c) => c.copyWith(crossfadeMs: (v * 1000).round())),
          ),
          SwitchListTile(
            title: const Text('Skip silence'),
            subtitle: const Text('Android only'),
            value: p.skipSilence,
            onChanged: (v) => update((c) => c.copyWith(skipSilence: v)),
          ),
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Equalizer'),
            subtitle: Text(p.eqEnabled ? 'On' : 'Off'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.openEqualizer(),
          ),
          const _Section('Library'),
          ListTile(
            leading: sync.isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            title: const Text('Sync library'),
            subtitle: Text(_syncSummary(sync)),
            onTap: sync.isSyncing ? null : sync.sync,
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Downloads'),
            subtitle: Text(
              '${downloads.downloaded.length} songs • ${_formatBytes(downloads.usedBytes)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.openDownloads(),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Home layout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.openHomeLayout(),
          ),
          const _Section('Account'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle: const Text(
                'Removes downloads and the synced library from this device'),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  /// Signing out wipes this account's local data: downloaded files and the
  /// synced song cache. Playback stops when the session ends.
  static Future<void> _confirmSignOut(BuildContext context) async {
    final router = GoRouter.of(context);
    final session = context.read<SessionController>();
    final downloads = context.read<DownloadController>();
    final sync = context.read<SyncController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Downloaded songs and the synced library will be removed from this '
          'device.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    // Wipe while the account's client is still attached, then end the session.
    await downloads.clearAll();
    await sync.clear();
    await session.logout();
    // Signing out re-runs the router's redirect, which would otherwise send
    // the next sign-in back to this settings page.
    router.go(AppRoutes.login);
  }

  static String _syncSummary(SyncController sync) {
    if (sync.isSyncing) return 'Syncing… ${sync.songs.length} songs';
    if (sync.error != null) return 'Failed: ${sync.error}';
    final last = sync.lastSync;
    if (last == null) return 'Not synced. Needed for smart playlists.';
    return '${sync.songs.length} songs • last synced ${_ago(last)}';
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(valueText)],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

/// Human-readable size, shared with the downloads screen.
String formatBytes(int bytes) => _formatBytes(bytes);
