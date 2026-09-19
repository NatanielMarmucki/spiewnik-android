import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a song screen (a songbook song or a user song) is open.
///
/// Screens call [acquire] in initState and [release] in dispose. This is a plain on/off pair because
/// only one song screen is open at a time: moving between songs turns pages inside [SongDetailView]'s
/// PageView and never builds a second song screen.
///
/// **Why it used to be a counter, and when it must be again.** Before the PageView, moving to another
/// song replaced the whole screen with pushReplacement, which builds the new screen before disposing
/// the old one. The old screen's release then came last and turned the screen off while a song was
/// open (fixed in #16 by counting open screens). If navigation ever puts two song screens on the stack
/// at once again (pushReplacement between songs, a song pushed over a song), bring the counter back.
class ScreenWakeLock {
  static bool _held = false;
  static bool _enabled = true;

  /// Reflects the "Nie gaś ekranu przy pieśni" setting. Turning it off releases the wakelock right
  /// away, even with a song open, because the settings screen is reachable from the song itself.
  static set enabled(bool value) {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    _apply();
  }

  static void acquire() {
    if (_held) {
      return;
    }
    _held = true;
    _apply();
  }

  static void release() {
    if (!_held) {
      return;
    }
    _held = false;
    _apply();
  }

  static void _apply() {
    if (_enabled && _held) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @visibleForTesting
  static bool get isHeld => _held;

  @visibleForTesting
  static bool get isEnabled => _enabled;

  /// Brings the setting back to its default, so one test does not leak it into the next.
  @visibleForTesting
  static void resetEnabledForTesting() => _enabled = true;
}
