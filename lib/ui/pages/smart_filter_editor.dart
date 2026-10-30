import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../smart/smart_filter.dart';
import '../../state/download_controller.dart';
import '../../state/smart_playlist_store.dart';
import '../../state/sync_controller.dart';

/// One editable rule row. Values live in a controller so typing is cheap.
class _RuleDraft {
  _RuleDraft(this.field, this.operator, String value)
      : value = TextEditingController(text: value);

  SmartField field;
  SmartOperator operator;
  final TextEditingController value;

  SmartRule toRule() => SmartRule(field, operator, value.text.trim());
}

class SmartFilterEditor extends StatefulWidget {
  const SmartFilterEditor({super.key, this.existing});

  final SmartPlaylist? existing;

  @override
  State<SmartFilterEditor> createState() => _SmartFilterEditorState();
}

class _SmartFilterEditorState extends State<SmartFilterEditor> {
  late final TextEditingController _title;
  late final TextEditingController _limit;
  late MergeRule _merge;
  late String? _sortField;
  late bool _ascending;
  final List<_RuleDraft> _rules = [];

  /// Nested groups can't be edited here but are kept when saving.
  final List<SmartNode> _groups = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final filter = e?.filter ?? const SmartFilter();
    _title = TextEditingController(text: e?.title ?? '');
    _limit = TextEditingController(text: filter.limit > 0 ? '${filter.limit}' : '');
    _merge = filter.merge;
    final firstSort = filter.sort.isEmpty ? null : filter.sort.first;
    _sortField = firstSort?.field;
    _ascending = firstSort?.ascending ?? true;
    for (final node in filter.rules) {
      switch (node) {
        case SmartRule r:
          _rules.add(_RuleDraft(r.field, r.operator, r.value));
        case SmartGroup g:
          _groups.add(g);
      }
    }
    if (e == null) {
      _rules.add(_RuleDraft(SmartField.genre, SmartOperator.contains, ''));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _limit.dispose();
    for (final r in _rules) {
      r.value.dispose();
    }
    super.dispose();
  }

  SmartFilter _buildFilter() => SmartFilter(
        merge: _merge,
        rules: [for (final r in _rules) r.toRule(), ..._groups],
        sort: _sortField == null ? const [] : [SmartSort(_sortField!, ascending: _ascending)],
        limit: int.tryParse(_limit.text.trim()) ?? 0,
      );

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give the playlist a name')));
      return;
    }
    final store = context.read<SmartPlaylistStore>();
    final router = GoRouter.of(context);
    final filter = _buildFilter();
    final existing = widget.existing;
    await store.upsert(
      existing == null
          ? SmartPlaylist.create(title, filter)
          : existing.copyWith(title: title, filter: filter),
    );
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final downloads = context.read<DownloadController>();
    final matches = sync.songs.isEmpty
        ? null
        : _buildFilter().apply(
            sync.songs,
            SmartContext(isDownloaded: downloads.isDownloaded),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New smart playlist' : 'Edit smart playlist'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Match'),
              const SizedBox(width: 12),
              SegmentedButton<MergeRule>(
                segments: const [
                  ButtonSegment(value: MergeRule.all, label: Text('all rules')),
                  ButtonSegment(value: MergeRule.any, label: Text('any rule')),
                ],
                selected: {_merge},
                onSelectionChanged: (s) => setState(() => _merge = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _rules.length; i++) _ruleCard(i),
          if (_groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${_groups.length} nested rule group(s) are kept but can\'t be edited here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _rules.add(_RuleDraft(SmartField.title, SmartOperator.contains, '')),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add rule'),
            ),
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _sortField,
                  decoration: const InputDecoration(labelText: 'Sort by', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Default order')),
                    for (final f in SmartField.values)
                      if (f.type != FieldType.flag)
                        DropdownMenuItem(value: f.name, child: Text(f.label)),
                    const DropdownMenuItem(value: SmartSort.random, child: Text('Random')),
                  ],
                  onChanged: (v) => setState(() => _sortField = v),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: _ascending ? 'Ascending' : 'Descending',
                onPressed: (_sortField == null || _sortField == SmartSort.random)
                    ? null
                    : () => setState(() => _ascending = !_ascending),
                icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limit,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Limit (songs)',
              helperText: 'Leave empty for no limit',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.preview),
              title: Text(
                matches == null ? 'Sync your library to preview' : '${matches.length} matching songs',
              ),
              subtitle: matches == null || matches.isEmpty
                  ? null
                  : Text(
                      matches.take(3).map((s) => s.title).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(int i) {
    final rule = _rules[i];
    final operators = operatorsFor(rule.field.type);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SmartField>(
                    // Keyed on the draft so removing a rule above doesn't leak
                    // its selection into the next one.
                    key: ObjectKey(rule),
                    initialValue: rule.field,
                    decoration: const InputDecoration(labelText: 'Field'),
                    items: [
                      for (final f in SmartField.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (f) {
                      if (f == null) return;
                      setState(() {
                        // Operators differ per field type; reset when the
                        // new field can't use the current one.
                        if (!operatorsFor(f.type).contains(rule.operator)) {
                          rule.operator = operatorsFor(f.type).first;
                          rule.value.clear();
                        }
                        rule.field = f;
                      });
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Remove rule',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _rules.removeAt(i).value.dispose()),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SmartOperator>(
                    // initialValue is read once, so re-key when the field (and
                    // therefore the operator list) changes.
                    key: ValueKey((rule, rule.field)),
                    initialValue: operators.contains(rule.operator) ? rule.operator : operators.first,
                    decoration: const InputDecoration(labelText: 'Condition'),
                    items: [
                      for (final o in operators) DropdownMenuItem(value: o, child: Text(o.label)),
                    ],
                    onChanged: (o) => setState(() => rule.operator = o ?? rule.operator),
                  ),
                ),
                if (rule.operator.needsValue) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rule.value,
                      keyboardType: rule.field.type == FieldType.text
                          ? TextInputType.text
                          : TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Value'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
