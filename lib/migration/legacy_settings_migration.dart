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
class LegacySettingsMigration {
  static const MethodChannel channel = MethodChannel('com.natanielmarmucki.spiewnik/legacy_user_defaults');
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
    final Object? value = await channel.invokeMethod<Object?>('readNumber', {'key': legacyFontSizeKey});
    // A missing key is normal: the old app saved it only after the user moved the slider.
    if (value is! num || value.isNaN || value.isInfinite) {
      logger.i('Legacy settings migration: no font size from the old app.');
      return null;
    }
    // The old iPad version used 24-44; values outside the current range are clamped, not dropped.
    final fontSize = value.toDouble().clamp(minFontSize, maxFontSize);
    await prefs.setDouble(fontSizeKey, fontSize);
    logger.i('Legacy settings migration: font size $value saved as $fontSize.');
    return fontSize;
  }
}
