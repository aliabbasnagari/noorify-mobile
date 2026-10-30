import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/settings_models.dart';
import '../../state/settings_controller.dart';

/// Reorder, hide and size the home screen shelves.
class HomeLayoutPage extends StatelessWidget {
  const HomeLayoutPage({super.key});

  static const _counts = [10, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final rows = settings.home.rows;

    void save(List<HomeRowConfig> next) => settings.setHome(HomeLayout(next));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home layout'),
        actions: [
          TextButton(
            onPressed: () => settings.setHome(HomeLayout.defaults),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: rows.length,
        onReorderItem: (from, to) {
          final next = [...rows];
          next.insert(to, next.removeAt(from));
          save(next);
        },
        itemBuilder: (context, i) {
          final row = rows[i];
          return ListTile(
            key: ValueKey(row.id),
            leading: Switch(
              value: row.visible,
              onChanged: (v) => save([...rows]..[i] = row.copyWith(visible: v)),
            ),
            title: Text(homeRowTitles[row.id] ?? row.id),
            subtitle: Text('${row.count} items'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<int>(
                  tooltip: 'Items',
                  icon: const Icon(Icons.format_list_numbered),
                  initialValue: row.count,
                  onSelected: (c) =>
                      save([...rows]..[i] = row.copyWith(count: c)),
                  itemBuilder: (_) => [
                    for (final c in _counts)
                      PopupMenuItem(value: c, child: Text('$c items')),
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
          );
        },
      ),
    );
  }
}
