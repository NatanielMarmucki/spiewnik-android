import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsViewModel {
  /// Address that bug reports and contact messages go to. **The only place in the code with the address** —
  /// swapping the alias before release means changing this constant and nothing else.
  static const String contactEmail = 'n.marmucki@icloud.com';

  final Logger logger;

  /// Link opening is injected, so a test can pretend the system has nothing to open them with.
  final Future<bool> Function(Uri url) openUrl;

  SettingsViewModel({Logger? logger, Future<bool> Function(Uri url)? openUrl})
    : logger = logger ?? Logger(),
      openUrl = openUrl ?? _launch;

  static Future<bool> _launch(Uri url) async {
    if (!await canLaunchUrl(url)) {
      return false;
    }
    return launchUrl(url);
  }

  Future<String> getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Error saved by the failed migration from the old iOS app, or null when it did not fail.
  Future<String?> getDataMigrationError() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(CoreDataMigration.failedKey) ?? false)) {
      return null;
    }
    return prefs.getString(CoreDataMigration.errorKey) ?? 'Brak szczegółów błędu.';
  }

  /// Opens a web page. Returns false when that failed — the view then shows a message
  /// instead of leaving the user with nothing.
  Future<bool> launchURL(String url) async {
    try {
      final opened = await openUrl(Uri.parse(url));
      if (!opened) {
        logger.w('Could not launch $url');
      }
      return opened;
    } catch (error, stackTrace) {
      logger.e('Could not launch $url', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Opens an email to report a bug. [details] are added to the message body when given.
  /// Returns false when the mail app could not be opened.
  Future<bool> sendEmail(String version, {String? details}) async {
    final subject = 'subject=Zgłoszenie błędu w aplikacji Śpiewnik ($version)';
    final Uri params = Uri(
      scheme: 'mailto',
      path: contactEmail,
      query: details == null ? subject : '$subject&body=${Uri.encodeComponent(details)}',
    );
    try {
      final opened = await openUrl(params);
      if (!opened) {
        logger.w('Could not send email to $contactEmail');
      }
      return opened;
    } catch (error, stackTrace) {
      logger.e('Error sending email', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
