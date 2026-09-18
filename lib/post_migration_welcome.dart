import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';

/// What the welcome screen says about the data that came over.
enum WelcomeVariant {
  /// Favorites or user songs came over, possibly with the settings.
  songs,

  /// Only the settings (the font size) came over, no favorites and no user songs.
  settingsOnly,
}

/// Decides whether to show the one-time welcome screen after the migration from the old iOS app
/// (issue #37, docs/PARITY.md section 5.4).
///
/// The decision comes from what the migrations returned in **this** session, never from reading
/// `coreDataMigrationDone`: on the second launch that flag looks exactly the same as on the first,
/// so reading it would bring the screen back on every start.
///
/// All of these must hold:
///
/// - the app runs on iOS;
/// - the Core Data migration ran in this session and finished ([CoreDataMigrationStatus.migrated]):
///   not [CoreDataMigrationStatus.alreadyDone] (a later launch), not
///   [CoreDataMigrationStatus.noDatabase] (a clean install) and not [CoreDataMigrationStatus.failed]
///   (the user sees the error in the settings instead, praising the new look would be out of place);
/// - something was actually carried over: a favorite, a user song or the font size;
/// - the screen was never shown before ([shownKey]).
class PostMigrationWelcome {
  /// Set when the screen is shown, so it never comes back. New key, see the list in CLAUDE.md.
  static const String shownKey = 'postMigrationWelcomeShown';

  final Logger logger;

  PostMigrationWelcome({required this.logger});

  /// Returns the variant to show now and records that the screen was shown, or null when it should
  /// not appear.
  ///
  /// [coreDataResult] is what [CoreDataMigration.runOnStartup] returned in this session (null outside
  /// iOS), [migratedFontSize] what the legacy settings migration returned (null when it moved nothing).
  /// The flag is written before a variant is returned, so a crash while the screen is open does not bring it
  /// back. Never throws: a failure means no welcome screen, not a broken start.
  Future<WelcomeVariant?> decide({
    required CoreDataMigrationResult? coreDataResult,
    required double? migratedFontSize,
    bool? isIOS,
  }) async {
    try {
      if (!(isIOS ?? Platform.isIOS)) {
        return null;
      }
      if (coreDataResult == null || coreDataResult.status != CoreDataMigrationStatus.migrated) {
        return null;
      }
      final WelcomeVariant variant;
      if (coreDataResult.favoritesMarked > 0 || coreDataResult.mySongsAdded > 0) {
        variant = WelcomeVariant.songs;
      } else if (migratedFontSize != null) {
        variant = WelcomeVariant.settingsOnly;
      } else {
        logger.i('Welcome screen: the migration found nothing to carry over, not showing it.');
        return null;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(shownKey) ?? false) {
        logger.i('Welcome screen: already shown, not showing it again.');
        return null;
      }
      await prefs.setBool(shownKey, true);
      logger.i('Welcome screen: showing it once after the migration (${variant.name}).');
      return variant;
    } catch (error, stackTrace) {
      logger.e('Welcome screen: could not decide, not showing it.', error: error, stackTrace: stackTrace);
      return null;
    }
  }
}
