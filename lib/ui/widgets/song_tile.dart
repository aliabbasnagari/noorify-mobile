import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';
import '../../state/playlists_revision.dart';
import '../../state/session_controller.dart';
import '../../state/star_controller.dart';
import '../util.dart';
import 'cover_art.dart';
import 'playing_bars.dart';

enum _SongAction {
  playNext,
  addToQueue,
  addToPlaylist,
  toggleStar,
  download,
  removeDownload
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.showCover = true,
    this.showTrackNumber = false,
    this.extraActions = const [],
  });

  final Song song;
  final VoidCallback onTap;
  final bool showCover;
  final bool showTrackNumber;

  /// Additional menu entries (e.g. "Remove from playlist").
  final List<PopupMenuEntry<VoidCallback>> extraActions;

  @override
  Widget build(BuildContext context) {
    final current =
        context.select<PlayerController, String?>((p) => p.current?.id);
    final dl =
        context.select<DownloadController, ({bool done, double? progress})>(
      (d) => (done: d.isDownloaded(song.id), progress: d.progress(song.id)),
    );
    final starred =
        context.select<StarController, bool>((s) => s.isStarred(song));
    final isCurrent = current == song.id;
    final isPlaying =
        isCurrent && context.select<PlayerController, bool>((p) => p.isPlaying);
    final scheme = Theme.of(context).colorScheme;

    Widget? leading;
    if (showTrackNumber) {
      leading = SizedBox(
        width: 32,
        child: Center(
          child: isCurrent
              ? PlayingBars(playing: isPlaying)
              : Text('${song.track ?? ''}'),
        ),
      );
    } else if (showCover) {
      leading = CoverArt(
          coverArt: song.coverArt, size: 48, requestSize: 100, radius: 6);
    }

    Widget? status;
    if (dl.progress != null) {
      status = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          // Negative means "size unknown": show an indeterminate spinner.
          value: dl.progress! >= 0 ? dl.progress : null,
        ),
      );
    } else if (dl.done) {
      status = Icon(Icons.download_done, size: 16, color: scheme.primary);
    }

    return ListTile(
      leading: leading,
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? TextStyle(color: scheme.primary) : null,
      ),
      subtitle: Text(
        [song.artist, if (!showTrackNumber) song.album]
            .whereType<String>()
            .join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (starred) ...[
            Icon(Icons.favorite, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
          ],
          if (status != null) ...[status, const SizedBox(width: 8)],
          Text(formatDuration(song.duration)),
          PopupMenuButton<Object>(
            onSelected: (v) {
              if (v is VoidCallback) {
                v();
              } else if (v is _SongAction) {
                _handle(context, v);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: _SongAction.playNext, child: Text('Play next')),
              const PopupMenuItem(
                  value: _SongAction.addToQueue, child: Text('Add to queue')),
              const PopupMenuItem(
                value: _SongAction.addToPlaylist,
                child: Text('Add to playlist…'),
              ),
              PopupMenuItem(
                value: _SongAction.toggleStar,
                child: Text(
                    starred ? 'Remove from favorites' : 'Add to favorites'),
              ),
              if (dl.done)
                const PopupMenuItem(
                  value: _SongAction.removeDownload,
                  child: Text('Remove download'),
                )
              else
                const PopupMenuItem(
                    value: _SongAction.download, child: Text('Download')),
              ...extraActions,
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _handle(BuildContext context, _SongAction action) async {
    final player = context.read<PlayerController>();
    final downloads = context.read<DownloadController>();
    switch (action) {
      case _SongAction.playNext:
        await player.playNext(song);
      case _SongAction.addToQueue:
        await player.addToQueue(song);
      case _SongAction.addToPlaylist:
        await showAddToPlaylistSheet(context, [song]);
      case _SongAction.toggleStar:
        final messenger = ScaffoldMessenger.of(context);
        try {
          await context.read<StarController>().toggle(song);
        } on Object catch (e) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$e')));
        }
      case _SongAction.download:
        await downloads.downloadSongs([song]);
      case _SongAction.removeDownload:
        await downloads.removeSong(song.id);
    }
  }
}

/// Lets the user pick (or create) a playlist and adds [songs] to it.
Future<void> showAddToPlaylistSheet(
    BuildContext context, List<Song> songs) async {
  final client = context.read<SessionController>().client!;
  final messenger = ScaffoldMessenger.of(context);
  final revision = context.read<PlaylistsRevision>();

  Future<void> run(Future<void> Function() op, String ok) async {
    try {
      await op();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  final ids = songs.map((s) => s.id).toList();

  await showModalBottomSheet<void>(
    context: context,
    // See the comment on showQueueSheet's useRootNavigator: this sheet opens
    // a showDialog (the "New playlist" prompt below) while still open, and
    // mixing a tab-local Navigator for the sheet with the dialog's default
    // root Navigator is exactly the kind of cross-hierarchy combination that
    // can corrupt focus/Overlay state — keep both on the root.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: FutureBuilder<List<Playlist>>(
        future: client.getPlaylists(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final playlists = snap.data!;
          return ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New playlist'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final name =
                      await promptForText(context, 'New playlist', 'Name');
                  if (name != null) {
                    await run(
                      () async {
                        await client.createPlaylist(name, songIds: ids);
                        revision.bump();
                      },
                      'Created "$name"',
                    );
                  }
                },
              ),
              for (final p in playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(p.name),
                  subtitle: Text('${p.songCount} songs'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await run(
                      () => client.addToPlaylist(p.id, ids),
                      'Added to "${p.name}"',
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// Simple single-field text prompt. Returns null if cancelled or empty.
Future<String?> promptForText(
    BuildContext context, String title, String label) async {
  final controller = TextEditingController();
  // Closing the dialog's route while its autofocused TextField still has
  // the on-screen keyboard mid-transition can hit a Flutter framework
  // assertion ("_dependents.isEmpty": is not true). Unfocusing first isn't
  // enough on its own — the IME's teardown is an async platform-channel
  // round trip, so popping synchronously right after can still race it.
  // Deferring the pop to the next frame gives that teardown time to settle.
  void close(BuildContext dialogContext, [String? value]) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialogContext.mounted) Navigator.pop(dialogContext, value);
    });
  }

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => close(dialogContext, v),
      ),
      actions: [
        TextButton(
          onPressed: () => close(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => close(dialogContext, controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
