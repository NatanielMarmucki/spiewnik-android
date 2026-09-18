import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while at least one song detail screen is open.
///
/// Screens call [acquire] in initState and [release] in dispose. A plain enable/disable pair is not
/// enough: pushReplacement (going to a song by number, swiping to the next one) builds the new screen
/// before the old one is disposed, so the old screen's disable would arrive last and turn the screen
/// off while a song is open. Counting open screens enables the wakelock only when the first one opens
/// and disables it only when the last one closes.
class ScreenWakeLock {
  static int _holders = 0;
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
    _holders++;
    if (_holders == 1) {
      _apply();
    }
  }

  static void release() {
    if (_holders == 0) {
      return;
    }
    _holders--;
    if (_holders == 0) {
      _apply();
    }
  }

  static void _apply() {
    if (_enabled && _holders > 0) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @visibleForTesting
  static int get holders => _holders;

  @visibleForTesting
  static bool get isEnabled => _enabled;

  /// Brings the setting back to its default, so one test does not leak it into the next.
  @visibleForTesting
  static void resetEnabledForTesting() => _enabled = true;
}
