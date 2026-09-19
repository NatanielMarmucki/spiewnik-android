import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// A failure to open a link or email must be visible to the user (B3 in docs/PARITY.md).
void main() {
  late SettingsViewModel viewModel;
  late List<Uri> attempts;

  /// A view model that always reports that the system failed to open the address.
  SettingsViewModel failing() {
    attempts = [];
    return SettingsViewModel(
      logger: Logger(level: Level.off),
      openUrl: (url) async {
        attempts.add(url);
        return false;
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Śpiewnik',
      packageName: 'com.nm.spiewnik',
      version: '12.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    viewModel = failing();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FontSizeModel()),
          ChangeNotifierProvider(create: (_) => AppSettingsModel()),
          Provider<SettingsViewModel>.value(value: viewModel),
        ],
        child: MaterialApp(theme: lightTheme, home: const SettingsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String label) async {
    // The row may be off screen, and the list builds only what is visible.
    await tester.scrollUntilVisible(find.text(label), 200.0);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed bug report says so and shows the address', (tester) async {
    await pumpSettings(tester);

    await tapRow(tester, 'Zgłoś błąd');

    expect(attempts.single.scheme, 'mailto');
    expect(find.text('Nie udało się otworzyć'), findsOneWidget);
    expect(find.textContaining(SettingsViewModel.contactEmail), findsOneWidget);
  });

  testWidgets('the address can be copied from the dialog', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpSettings(tester);
    await tapRow(tester, 'Zgłoś błąd');

    await tester.tap(find.text('Kopiuj adres'));
    await tester.pumpAndSettle();

    expect(copied, SettingsViewModel.contactEmail);
    expect(find.text('Adres skopiowany do schowka'), findsOneWidget);
    expect(find.text('Nie udało się otworzyć'), findsNothing, reason: 'dialog się zamyka');
  });

  testWidgets('a failure to open a web page shows the page address', (tester) async {
    await pumpSettings(tester);

    await tapRow(tester, 'Wesprzyj');

    expect(find.textContaining('https://suppi.pl/spiewnik'), findsOneWidget);
  });

  testWidgets('a successful open shows nothing', (tester) async {
    viewModel = SettingsViewModel(logger: Logger(level: Level.off), openUrl: (url) async => true);
    await pumpSettings(tester);

    await tapRow(tester, 'Kontakt');

    expect(find.text('Nie udało się otworzyć'), findsNothing);
  });

  test('the contact address is defined in one place', () {
    expect(SettingsViewModel.contactEmail, contains('@'));
  });
}
