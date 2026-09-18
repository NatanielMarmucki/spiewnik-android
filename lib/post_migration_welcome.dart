import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';

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

  /// Returns true when the screen should be shown now and records that it was.
  ///
  /// [coreDataResult] is what [CoreDataMigration.runOnStartup] returned in this session (null outside
  /// iOS), [migratedFontSize] what the legacy settings migration returned (null when it moved nothing).
  /// The flag is written before returning true, so a crash while the screen is open does not bring it
  /// back. Never throws: a failure means no welcome screen, not a broken start.
  Future<bool> shouldShow({
    required CoreDataMigrationResult? coreDataResult,
    required double? migratedFontSize,
    bool? isIOS,
  }) async {
    try {
      if (!(isIOS ?? Platform.isIOS)) {
        return false;
      }
      if (coreDataResult == null || coreDataResult.status != CoreDataMigrationStatus.migrated) {
        return false;
      }
      final carriedOver =
          coreDataResult.favoritesMarked > 0 || coreDataResult.mySongsAdded > 0 || migratedFontSize != null;
      if (!carriedOver) {
        logger.i('Welcome screen: the migration found nothing to carry over, not showing it.');
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(shownKey) ?? false) {
        logger.i('Welcome screen: already shown, not showing it again.');
        return false;
      }
      await prefs.setBool(shownKey, true);
      logger.i('Welcome screen: showing it once after the migration.');
      return true;
    } catch (error, stackTrace) {
      logger.e('Welcome screen: could not decide, not showing it.', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
