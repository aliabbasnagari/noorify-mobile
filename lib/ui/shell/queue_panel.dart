import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/cover_art.dart';

/// The wide layout's right-hand queue: what is playing now, then what comes
/// next with the source it came from. Upcoming songs can be dragged to
/// reorder, removed, or jumped to. Empty, it explains how to add songs.
class QueuePanel extends StatelessWidget {
  const QueuePanel({super.key, required this.onFindSomething});

  /// Called by the empty state's "Find something to play" button.
  final VoidCallback onFindSomething;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final queue = player.queueSongs;
    final current = player.currentIndex;
    final hasCurrent =
        current != null && current >= 0 && current < queue.length;
    final firstUpcoming = hasCurrent ? current + 1 : 0;
    final upcoming = queue.sublist(firstUpcoming.clamp(0, queue.length));
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(child: Text('Queue', style: textTheme.titleSmall)),
              IconButton(
                tooltip: 'Close queue',
                icon: const Icon(Icons.close),
                onPressed: () => context
                    .read<SettingsController>()
                    .updateShell((s) => s.copyWith(queuePanelOpen: false)),
              ),
            ],
          ),
        ),
        Expanded(
          child: queue.isEmpty
              ? _EmptyQueue(onFindSomething: onFindSomething)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasCurrent) ...[
                        const _Heading('Now playing'),
                        _QueueRow(
                          song: queue[current],
                          isCurrent: true,
                          onTap: null,
                        ),
                      ],
                      if (upcoming.isNotEmpty)
                        _Heading(player.queueSource == null
                            ? 'Next in queue'
                            : 'Next from: ${player.queueSource}'),
                    ],
                  ),
                  itemCount: upcoming.length,
                  onReorderItem: (from, to) =>
                      player.move(firstUpcoming + from, firstUpcoming + to),
                  itemBuilder: (context, i) {
                    final index = firstUpcoming + i;
                    return _QueueRow(
                      key: ValueKey('${upcoming[i].id}#$index'),
                      song: upcoming[i],
                      isCurrent: false,
                      onTap: () => player.skipTo(index),
                      onRemove: () => player.removeAt(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.onRemove,
  });

  final Song song;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: CoverArt(
          coverArt: song.coverArt, size: 40, requestSize: 80, radius: 4),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? TextStyle(color: scheme.primary) : null,
      ),
      subtitle: Text(
        song.artist ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove from queue',
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: onRemove,
            ),
      onTap: onTap,
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.onFindSomething});

  final VoidCallback onFindSomething;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Add to your queue', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Choose "Add to queue" from a track\'s menu to see it here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onFindSomething,
              child: const Text('Find something to play'),
            ),
          ],
        ),
      ),
    );
  }
}
