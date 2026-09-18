import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsViewModel {
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

  Future<void> launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  /// Opens an email to report a bug. [details] are added to the message body when given.
  Future<void> sendEmail(String version, {String? details}) async {
    try {
      final subject = 'subject=Zgłoszenie błędu w aplikacji Śpiewnik ($version)';
      final Uri params = Uri(
        scheme: 'mailto',
        path: 'n.marmucki@icloud.com',
        query: details == null ? subject : '$subject&body=${Uri.encodeComponent(details)}',
      );
      var url = params.toString();
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        print('Could not send email');
      }
    } catch (e) {
      print('Error sending email: $e');
    }
  }
}
