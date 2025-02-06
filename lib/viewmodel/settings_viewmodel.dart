import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsViewModel {
  Future<String> getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<void> launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  Future<void> sendEmail(String version) async {
    try {
      final Uri params = Uri(
        scheme: 'mailto',
        path: 'n.marmucki@icloud.com',
        query: 'subject=Zgłoszenie błędu w aplikacji Śpiewnik ($version)',
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