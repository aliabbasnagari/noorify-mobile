import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';

class _TogglePlayIntent extends Intent {
  const _TogglePlayIntent();
}

class _NextTrackIntent extends Intent {
  const _NextTrackIntent();
}

class _PreviousTrackIntent extends Intent {
  const _PreviousTrackIntent();
}

/// Desktop keyboard control of playback: Space toggles play/pause, and
/// Ctrl+Right / Ctrl+Left (Cmd on macOS) skip to the next / previous track.
///
/// Every shortcut stands down while the user is typing in a text field, or
/// when nothing is queued, so the key then does what it normally would
/// (insert a space, move the caret, activate a focused button).
class PlaybackShortcuts extends StatelessWidget {
  const PlaybackShortcuts({super.key, required this.child});

  final Widget child;

  static const _bindings = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.space): _TogglePlayIntent(),
    SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
        _NextTrackIntent(),
    SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
        _NextTrackIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
        _PreviousTrackIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
        _PreviousTrackIntent(),
  };

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Shortcuts(
      shortcuts: _bindings,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePlayIntent:
              _PlayerAction<_TogglePlayIntent>(player, (p) => p.togglePlay()),
          _NextTrackIntent:
              _PlayerAction<_NextTrackIntent>(player, (p) => p.next()),
          _PreviousTrackIntent:
              _PlayerAction<_PreviousTrackIntent>(player, (p) => p.previous()),
        },
        // Gives the shortcuts a focus node to hang off when nothing else on
        // the page has taken focus yet.
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}

class _PlayerAction<T extends Intent> extends Action<T> {
  _PlayerAction(this._player, this._run);

  final PlayerController _player;
  final Future<void> Function(PlayerController player) _run;

  @override
  bool isEnabled(T intent) => _player.hasQueue && !_isTyping();

  @override
  Object? invoke(T intent) {
    _run(_player);
    return null;
  }

  static bool _isTyping() {
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null);
  }
}
