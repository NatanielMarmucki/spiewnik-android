import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time migration of the font size set in the old native iOS app.
///
/// The old app stored `isSize` in UserDefaults without the `flutter.` prefix that shared_preferences
/// uses, so it is read through a platform channel (ios/Runner/AppDelegate.swift) and saved as
/// `fontSize`. `isLineSpacing` is not migrated: the old app stored points (0-10), the new one a line
/// height multiplier (1.0-3.0), which cannot be converted. Never throws.
///
/// Two outcomes used to look the same — both quiet, both with the flag written:
///
/// - **the old app never saved a size**: normal, most users never moved the slider. The flag is
///   written, the migration is over and does not run again.
/// - **the channel did not answer**: our own bug, not the user's data. Since the UIScene migration
///   the channel is registered when the implicit engine is initialised, so a registration that
///   arrives too late would look exactly like "no size to migrate" and quietly cost the user their
///   setting, for good. In that case the flag is **not** written, so the next launch tries again.
class LegacySettingsMigration {
  static const String legacyUserDefaultsChannel = 'com.natanielmarmucki.spiewnik/legacy_user_defaults';
  static const MethodChannel channel = MethodChannel(legacyUserDefaultsChannel);
  static const String doneKey = 'legacySettingsMigrationDone';
  static const String legacyFontSizeKey = 'isSize';
  static const String fontSizeKey = 'fontSize';
  static const double minFontSize = 10.0;
  static const double maxFontSize = 30.0;

  final Logger logger;

  LegacySettingsMigration({required this.logger});

  /// Does nothing outside iOS. Returns the saved font size, or null when nothing was migrated.
  Future<double?> run({bool? isIOS}) async {
    if (!(isIOS ?? Platform.isIOS)) {
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(doneKey) ?? false) {
        return null;
      }
      final migrated = await _migrateFontSize(prefs);
      await prefs.setBool(doneKey, true);
      return migrated;
    } on MissingPluginException catch (error, stackTrace) {
      // The flag stays unwritten on purpose: this is our wiring, and the next launch should retry
      // instead of leaving the user with the default size and no way back.
      logger.e(
        'Legacy settings migration: the $legacyUserDefaultsChannel channel did not answer. '
        'Nothing migrated, the migration will be retried on the next launch.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      logger.e('Legacy settings migration failed.', error: error, stackTrace: stackTrace);
      try {
        // Not retried: a later retry could overwrite a font size the user has chosen since.
        await (await SharedPreferences.getInstance()).setBool(doneKey, true);
      } catch (_) {}
      return null;
    }
  }

  Future<double?> _migrateFontSize(SharedPreferences prefs) async {
    if (prefs.containsKey(fontSizeKey)) {
      logger.i('Legacy settings migration: font size already set in the new app, keeping it.');
      return null;
    }
    // A MissingPluginException is not caught here: run() tells it apart from a missing key.
    final Object? value = await channel.invokeMethod<Object?>('readNumber', {'key': legacyFontSizeKey});
    // A missing key is normal: the old app saved it only after the user moved the slider.
    if (value is! num || value.isNaN || value.isInfinite) {
      logger.i(
        'Legacy settings migration: the channel answered, the old app has no font size saved. '
        'Nothing to migrate, marking the migration as done.',
      );
      return null;
    }
    // The old iPad version used 24-44; values outside the current range are clamped, not dropped.
    final fontSize = value.toDouble().clamp(minFontSize, maxFontSize);
    await prefs.setDouble(fontSizeKey, fontSize);
    logger.i(
      'Legacy settings migration: the channel answered with $value, saved as fontSize $fontSize.',
    );
    return fontSize;
  }
}
