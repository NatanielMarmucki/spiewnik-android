import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/migration/core_data_migration.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

import 'support/platform_fakes.dart';

void main() {
  const notice = 'Nie udało się przenieść ulubionych i własnych pieśni z poprzedniej wersji aplikacji.';
  const migrationError = 'CoreDataReadException: Could not read database (file is not a database)';
  late FakeUrlLauncher urlLauncher;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Śpiewnik',
      packageName: 'com.nm.spiewnik',
      version: '1.2.1',
      buildNumber: '5',
      buildSignature: '',
    );
    urlLauncher = FakeUrlLauncher()..install();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDown(() {
    urlLauncher.uninstall();
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FontSizeModel()),
          ChangeNotifierProvider(create: (_) => AppSettingsModel()),
          Provider(create: (_) => SettingsViewModel()),
        ],
        child: MaterialApp(theme: lightTheme, home: const SettingsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('settings notice', () {
    testWidgets('is hidden when the migration did not fail', (tester) async {
      SharedPreferences.setMockInitialValues({CoreDataMigration.doneKey: true});

      await pumpSettings(tester);

      expect(find.text(notice), findsNothing);
      expect(find.text('Wyślij szczegóły błędu'), findsNothing);
    });

    testWidgets('is shown at the bottom when the migration failed', (tester) async {
      SharedPreferences.setMockInitialValues({
        CoreDataMigration.doneKey: true,
        CoreDataMigration.failedKey: true,
        CoreDataMigration.errorKey: migrationError,
      });

      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Wyślij szczegóły błędu'), 200);

      expect(find.text(notice), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(notice)).dy,
        greaterThan(tester.getTopLeft(find.text('Zgłoś błąd')).dy),
      );
    });

    testWidgets('sends the error details through the bug report email', (tester) async {
      SharedPreferences.setMockInitialValues({
        CoreDataMigration.doneKey: true,
        CoreDataMigration.failedKey: true,
        CoreDataMigration.errorKey: migrationError,
      });
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('Wyślij szczegóły błędu'), 200);
      await tester.ensureVisible(find.text('Wyślij szczegóły błędu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wyślij szczegóły błędu'));
      await tester.pumpAndSettle();

      final email = Uri.parse(urlLauncher.launchedUrls.single);
      expect(email.scheme, 'mailto');
      expect(email.path, 'n.marmucki@icloud.com');
      expect(email.queryParameters['subject'], 'Zgłoszenie błędu w aplikacji Śpiewnik (1.2.1)');
      expect(email.queryParameters['body'], contains('Nie udało się przenieść danych z poprzedniej wersji aplikacji.'));
      expect(email.queryParameters['body'], contains(migrationError));
    });
  });

  group('SettingsViewModel', () {
    test('reports no migration error when the failure flag is not set', () async {
      SharedPreferences.setMockInitialValues({CoreDataMigration.errorKey: 'stary błąd'});

      expect(await SettingsViewModel().getDataMigrationError(), isNull);
    });

    test('reports a placeholder when the failure flag is set without an error message', () async {
      SharedPreferences.setMockInitialValues({CoreDataMigration.failedKey: true});

      expect(await SettingsViewModel().getDataMigrationError(), 'Brak szczegółów błędu.');
    });

    test('keeps the bug report email without a body when there are no details', () async {
      await SettingsViewModel().sendEmail('1.2.1');

      final email = Uri.parse(urlLauncher.launchedUrls.single);
      expect(email.queryParameters['subject'], 'Zgłoszenie błędu w aplikacji Śpiewnik (1.2.1)');
      expect(email.queryParameters.containsKey('body'), isFalse);
    });
  });
}
