import 'package:flutter/foundation.dart';

/// A counter that changes whenever the user's server playlists change from
/// somewhere other than the Library screen (the Create menu, "add to a new
/// playlist"). The Library list listens and reloads, so it never shows a
/// stale list after the user comes back to it.
class PlaylistsRevision extends ChangeNotifier {
  int _value = 0;

  int get value => _value;

  void bump() {
    _value++;
    notifyListeners();
  }
}
