import 'package:flutter/material.dart';

import '../routing/navigation.dart';
import '../widgets/create_sheet.dart';
import '../widgets/library_browser.dart';

/// "Your Library" on phones and tablets: everything in the library as one
/// browsable list (see [LibraryBrowser]), with the Create menu in the header.
/// The desktop layout shows the same list as its sidebar instead.
class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  /// The library is the third tab.
  static const _branchIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            tooltip: 'Create',
            icon: const Icon(Icons.add),
            onPressed: () =>
                showCreateSheet(context, branchIndex: _branchIndex),
          ),
        ],
      ),
      body: LibraryBrowser(onOpen: context.openLibraryEntry),
    );
  }
}
