import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsViewModel {
  /// Adres, pod który idą zgłoszenia błędów i kontakt. **Jedyne miejsce w kodzie z adresem** —
  /// podmiana aliasu przed wydaniem dotyczy tej stałej i niczego więcej.
  static const String contactEmail = 'n.marmucki@icloud.com';

  final Logger logger;

  /// Otwieranie linków wstrzykiwane, żeby test mógł udać, że system nie ma czym ich otworzyć.
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

  /// Otwiera stronę. Zwraca false, gdy się nie udało — widok pokazuje wtedy komunikat,
  /// zamiast zostawiać użytkownika z niczym.
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
  /// Zwraca false, gdy nie udało się otworzyć poczty.
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
