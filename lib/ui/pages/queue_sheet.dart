import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../util.dart';
import '../widgets/cover_art.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // HomeShell gives each tab its own Navigator so pushed pages don't cover
    // the mini player; always anchoring to the root one here keeps this
    // sheet (and anything it in turn opens) in a single, consistent
    // Navigator/Overlay hierarchy regardless of which tab it's opened from.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _QueueList(scrollController: scroll),
    ),
  );
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final queue = player.queueSongs;
    final scheme = Theme.of(context).colorScheme;

    if (queue.isEmpty) return const Center(child: Text('Queue is empty'));

    return ReorderableListView.builder(
      scrollController: scrollController,
      itemCount: queue.length,
      // `to` is already adjusted for the removed item.
      onReorderItem: player.move,
      itemBuilder: (context, i) {
        final song = queue[i];
        final isCurrent = i == player.currentIndex;
        return Dismissible(
          key: ObjectKey('${song.id}#$i#${queue.length}'),
          direction: DismissDirection.endToStart,
          background: ColoredBox(
            color: scheme.errorContainer,
            child: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.delete_outline),
              ),
            ),
          ),
          onDismissed: (_) => player.removeAt(i),
          child: ListTile(
            leading: CoverArt(
                coverArt: song.coverArt, size: 44, requestSize: 100, radius: 6),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatDuration(song.duration)),
                // Dragging to the very top/bottom of a long queue fights the
                // sheet's own drag-to-resize gesture near its edges, so give
                // reaching the ends a reliable non-drag path too.
                PopupMenuButton<VoidCallback>(
                  tooltip: 'Move',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    if (i > 0)
                      PopupMenuItem(
                        value: () => player.move(i, 0),
                        child: const Text('Move to top'),
                      ),
                    if (i < queue.length - 1)
                      PopupMenuItem(
                        value: () => player.move(i, queue.length - 1),
                        child: const Text('Move to bottom'),
                      ),
                  ],
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
            onTap: () => player.skipTo(i),
          ),
        );
      },
    );
  }
}
