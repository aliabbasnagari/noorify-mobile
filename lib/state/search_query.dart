import 'package:flutter/foundation.dart';

/// The text being searched for, shared between the search field and the
/// results. On phones the Search tab owns the field; on desktop the top bar
/// does, and the Search tab just shows the results of whatever is typed.
class SearchQuery extends ChangeNotifier {
  String _text = '';

  String get text => _text;

  void set(String value) {
    if (value == _text) return;
    _text = value;
    notifyListeners();
  }

  void clear() => set('');
}
