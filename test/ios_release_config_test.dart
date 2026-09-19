import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS settings that App Store Connect requires when a build is uploaded.
void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final privacyManifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  /// The boolean value of a key in an XML plist, or null when the key is missing.
  bool? plistBool(String plist, String key) {
    final match = RegExp('<key>$key</key>\\s*<(true|false)/>').firstMatch(plist);
    return match == null ? null : match.group(1) == 'true';
  }

  test('Info.plist declares no non-exempt encryption', () {
    expect(plistBool(infoPlist, 'ITSAppUsesNonExemptEncryption'), isFalse);
  });

  group('Runner target privacy manifest', () {
    test('does not track the user and collects no data', () {
      expect(plistBool(privacyManifest, 'NSPrivacyTracking'), isFalse);
      expect(privacyManifest, matches(RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>')));
      expect(privacyManifest, matches(RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array/>')));
    });

    /// A required-reason API category and its only declared reason.
    Matcher declares(String category, String reason) => matches(RegExp(
          '<string>NSPrivacyAccessedAPICategory$category</string>\\s*'
          '<key>NSPrivacyAccessedAPITypeReasons</key>\\s*<array>\\s*<string>${RegExp.escape(reason)}</string>\\s*</array>',
        ));

    test('declares reason CA92.1 for UserDefaults, which AppDelegate reads', () {
      expect(privacyManifest, declares('UserDefaults', 'CA92.1'));
    });

    test('declares reason C617.1 for file timestamps read by package_info_plus and ObjectBox', () {
      expect(privacyManifest, declares('FileTimestamp', 'C617.1'));
    });

    test('declares reason E174.1 for free disk space checked by ObjectBox', () {
      expect(privacyManifest, declares('DiskSpace', 'E174.1'));
    });

    test('is added to the bundle by the Resources phase of the Runner target', () {
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
