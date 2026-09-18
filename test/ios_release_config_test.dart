import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ustawienia iOS, których App Store Connect wymaga przy wysyłce builda.
void main() {
  final privacyManifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  /// Wartość logiczna klucza z pliku plist w formacie XML albo null, gdy klucza nie ma.
  bool? plistBool(String plist, String key) {
    final match = RegExp('<key>$key</key>\\s*<(true|false)/>').firstMatch(plist);
    return match == null ? null : match.group(1) == 'true';
  }

  group('manifest prywatności targetu Runner', () {
    test('nie śledzi użytkownika i nie zbiera danych', () {
      expect(plistBool(privacyManifest, 'NSPrivacyTracking'), isFalse);
      expect(privacyManifest, matches(RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>')));
      expect(privacyManifest, matches(RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array/>')));
    });

    /// Kategoria API z wymaganym powodem i jej jedyny zadeklarowany powód.
    Matcher declares(String category, String reason) => matches(RegExp(
          '<string>NSPrivacyAccessedAPICategory$category</string>\\s*'
          '<key>NSPrivacyAccessedAPITypeReasons</key>\\s*<array>\\s*<string>${RegExp.escape(reason)}</string>\\s*</array>',
        ));

    test('podaje powód CA92.1 dla UserDefaults, z których czyta AppDelegate', () {
      expect(privacyManifest, declares('UserDefaults', 'CA92.1'));
    });

    test('podaje powód C617.1 dla dat plików czytanych przez package_info_plus i ObjectBox', () {
      expect(privacyManifest, declares('FileTimestamp', 'C617.1'));
    });

    test('podaje powód E174.1 dla wolnego miejsca sprawdzanego przez ObjectBox', () {
      expect(privacyManifest, declares('DiskSpace', 'E174.1'));
    });

    test('trafia do bundla przez fazę Resources targetu Runner', () {
      final buildFile = RegExp(r'(\w{24}) /\* PrivacyInfo\.xcprivacy in Resources \*/ = \{isa = PBXBuildFile;')
          .firstMatch(project);
      expect(buildFile, isNotNull);

      // 97C146EC1CF9000F007C117D is the Resources phase of the Runner target in the Flutter template.
      final runnerResources = RegExp(r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{.*?\};', dotAll: true)
          .firstMatch(project)!
          .group(0)!;
      expect(runnerResources, contains('${buildFile!.group(1)} /* PrivacyInfo.xcprivacy in Resources */'));
    });
  });
}
