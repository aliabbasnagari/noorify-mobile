import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/library_recents.dart';

/// Records, once, that the library item named by [libraryKey] was opened (so
/// Your Library can sort it to the top of "Recents"), then shows [child].
class RecordsOpen extends StatefulWidget {
  const RecordsOpen({super.key, required this.libraryKey, required this.child});

  /// For example `album:al1`, `playlist:42` or `favorites`.
  final String libraryKey;
  final Widget child;

  @override
  State<RecordsOpen> createState() => _RecordsOpenState();
}

class _RecordsOpenState extends State<RecordsOpen> {
  @override
  void initState() {
    super.initState();
    context.read<LibraryRecents>().touch(widget.libraryKey);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
