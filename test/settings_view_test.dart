import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/json_manager.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/settings_view.dart';
import 'package:spiewnik/view/widgets/settings_section.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

import 'support/platform_fakes.dart';

void main() {
  late FakeUrlLauncher urlLauncher;
  late FakeWakelock wakelock;
  late AppSettingsModel appSettings;
  late FontSizeModel fontSizeModel;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Śpiewnik',
      packageName: 'com.nm.spiewnik',
      version: '12.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({JsonManager.dataVersionKey: 7});
    urlLauncher = FakeUrlLauncher()..install();
    wakelock = FakeWakelock()..install();
  });

  tearDown(() {
    urlLauncher.uninstall();
    wakelock.uninstall();
    ScreenWakeLock.resetEnabledForTesting();
  });

  Future<void> pumpSettings(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    fontSizeModel = FontSizeModel();
    appSettings = AppSettingsModel();
    await fontSizeModel.loaded;
    await appSettings.loaded;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: fontSizeModel),
          ChangeNotifierProvider.value(value: appSettings),
          Provider(create: (_) => SettingsViewModel()),
        ],
        child: MaterialApp(theme: lightTheme, home: const SettingsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ustawienia są dłuższe niż ekran testowy, więc przed dotknięciem trzeba dojechać do celu.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('pokazuje sekcje ustawień', (tester) async {
    await pumpSettings(tester);

    expect(find.text('CZYTANIE'), findsOneWidget);
    expect(find.text('WYGLĄD'), findsOneWidget);
    expect(find.text('Rozmiar tekstu'), findsOneWidget);
    expect(find.text('Interlinia'), findsOneWidget);
  });

  testWidgets('wypisuje wersję aplikacji i wersję bazy pieśni', (tester) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(find.text('Wersja bazy pieśni'), 200.0);

    expect(find.text('12.0.0'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  group('nie gaś ekranu', () {
    testWidgets('domyślnie włączone, a wyłączenie zdejmuje blokadę od razu', (tester) async {
      await pumpSettings(tester);
      // Otwarta pieśń w tle: ustawienia są osiągalne z ekranu pieśni.
      ScreenWakeLock.acquire();
      addTearDown(ScreenWakeLock.release);
      await tester.pump();
      expect(wakelock.enabled, isTrue);

      await tapVisible(tester, find.byType(Switch));

      expect(appSettings.keepScreenOn, isFalse);
      expect(wakelock.enabled, isFalse, reason: 'blokada schodzi, choć pieśń jest otwarta');
    });

    testWidgets('wyłączona nie zapala blokady przy otwarciu pieśni', (tester) async {
      SharedPreferences.setMockInitialValues({AppSettingsModel.keepScreenOnKey: false});
      await pumpSettings(tester);

      ScreenWakeLock.acquire();
      addTearDown(ScreenWakeLock.release);
      await tester.pump();

      expect(wakelock.enabled, isFalse);
    });

    testWidgets('zapisuje się w ustawieniach', (tester) async {
      await pumpSettings(tester);

      await tapVisible(tester, find.byType(Switch));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppSettingsModel.keepScreenOnKey), isFalse);
    });
  });

  group('motyw', () {
    testWidgets('domyślnie idzie za systemem i daje trzy wybory', (tester) async {
      await pumpSettings(tester);

      expect(appSettings.themeMode, ThemeMode.system);
      expect(find.text('Jak w systemie'), findsOneWidget);
      expect(find.text('Jasny'), findsOneWidget);
      expect(find.text('Ciemny'), findsOneWidget);
    });

    testWidgets('wybór ciemnego zapisuje się i zaznacza wiersz', (tester) async {
      await pumpSettings(tester);

      await tapVisible(tester, find.text('Ciemny'));

      expect(appSettings.themeMode, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppSettingsModel.themeModeKey), 'dark');
      final row = tester.widget<SettingsRow>(
        find.ancestor(of: find.text('Ciemny'), matching: find.byType(SettingsRow)),
      );
      expect(row.selected, isTrue);
    });

    testWidgets('zapisany motyw wraca po ponownym wczytaniu', (tester) async {
      SharedPreferences.setMockInitialValues({AppSettingsModel.themeModeKey: 'light'});

      await pumpSettings(tester);

      expect(appSettings.themeMode, ThemeMode.light);
    });
  });

  testWidgets('reset nie rusza motywu ani blokady ekranu', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppSettingsModel.themeModeKey: 'dark',
      AppSettingsModel.keepScreenOnKey: false,
    });
    await pumpSettings(tester);
    fontSizeModel.setFontSize(FontSizeModel.maxFontSize);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Przywróć domyślny rozmiar i interlinię'));

    expect(fontSizeModel.fontSize, FontSizeModel.defaultFontSize);
    expect(appSettings.themeMode, ThemeMode.dark);
    expect(appSettings.keepScreenOn, isFalse);
  });

  testWidgets('próbka pieśni rośnie z rozmiarem tekstu i nic nie ucina', (tester) async {
    await pumpSettings(tester, size: const Size(400, 900));
    final sample = find.byType(SongContent);
    final smallest = tester.getSize(sample).height;

    fontSizeModel.setFontSize(FontSizeModel.maxFontSize);
    await tester.pumpAndSettle();

    final largest = tester.getSize(sample).height;
    expect(largest, greaterThan(smallest), reason: 'brak stałej wysokości: próbka rośnie');
    expect(tester.takeException(), isNull, reason: 'nic nie przepełnia się przy największej czcionce');
  });
}
