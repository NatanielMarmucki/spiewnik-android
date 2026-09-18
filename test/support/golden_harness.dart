import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/app_settings_model.dart';
import 'package:spiewnik/model/font_size_model.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/model/song_model.dart';
import 'package:spiewnik/theme/theme.dart';
import 'package:spiewnik/viewmodel/settings_viewmodel.dart';

/// Narzędzia do zrzutów golden: prawdziwe kroje, rozmiar telefonu, oba motywy.
///
/// Zrzuty powstają offscreen, bez urządzenia, więc są powtarzalne i nadają się do CI.
/// Aktualizacja obrazów: `flutter test --update-goldens test/golden`.

/// Rozmiar ekranu zrzutów: telefon 411 x 915 dp (jak Pixel) przy gęstości 3.
const Size _screenSize = Size(411, 915);

/// Ładuje kroje z assets oraz czcionkę ikon Material, inaczej test rysuje prostokąty
/// zamiast liter i ikon.
Future<void> loadAppFonts() async {
  final iconsFont = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/Users/natanielmarmucki/development/flutter'}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconsFont.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(iconsFont.readAsBytesSync().buffer)));
    await loader.load();
  }

  final fonts = {
    'Newsreader': [
      'assets/fonts/Newsreader-ExtraLight.ttf',
      'assets/fonts/Newsreader-Light.ttf',
      'assets/fonts/Newsreader-Regular.ttf',
    ],
    'SchibstedGrotesk': [
      'assets/fonts/SchibstedGrotesk-Regular.ttf',
      'assets/fonts/SchibstedGrotesk-Medium.ttf',
      'assets/fonts/SchibstedGrotesk-SemiBold.ttf',
    ],
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(Future.value(ByteData.view(File(path).readAsBytesSync().buffer)));
    }
    await loader.load();
  }
}

/// Buduje ekran w obu motywach i zapisuje zrzuty do test/golden/goldens/.
///
/// [name] trafia do nazwy pliku: `<name>-light.png` i `<name>-dark.png`.
Future<void> goldenScreen(
  WidgetTester tester,
  String name,
  Widget Function(BuildContext context) build, {
  Future<void> Function(WidgetTester tester)? afterPump,
  Map<String, Object> preferences = const {'fontSize': 19.0, 'lineHeight': 1.62},
  /// Systemowe powiększenie czcionki, osobne od rozmiaru tekstu pieśni.
  double textScale = 1.0,
}) async {
  for (final theme in [('light', lightTheme), ('dark', darkTheme)]) {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(preferences));
    final fontSizeModel = FontSizeModel();
    await fontSizeModel.loaded;
    final appSettings = AppSettingsModel();
    await appSettings.loaded;

    tester.view.physicalSize = Size(_screenSize.width * 3, _screenSize.height * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FontSizeModel>.value(value: fontSizeModel),
          ChangeNotifierProvider<AppSettingsModel>.value(value: appSettings),
          Provider<SettingsViewModel>(create: (_) => SettingsViewModel()),
        ],
        child: MaterialApp(
          // Klucz na motyw: bez niego drugi przebieg trafia w to samo drzewo elementów,
          // Navigator zachowuje stos tras i dialog otwarty w pierwszym motywie zostaje na ekranie.
          key: ValueKey(theme.$1),
          theme: theme.$2,
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Builder(builder: build),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (afterPump != null) {
      await afterPump(tester);
      await tester.pumpAndSettle();
    }

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name-${theme.$1}.png'));
  }
}

/// Pieśni ze śpiewnika do zrzutów: numery, tytuły i jedna ulubiona.
List<Song> sampleSongs() {
  const titles = [
    'Alleluja, chwalcie Pana',
    'Barankowi chwałę',
    'Bądź Panu cześć',
    'Boże wielki',
    'Chcę o Jezusie',
    'Barankowi cześć',
    'Chciejmy Zbawcę',
    'Chwalże ma duszo',
    'Chwałę daj Panu',
    'Czego chcesz od nas Panie',
  ];
  return [
    for (var i = 0; i < titles.length; i++)
      Song(
        number: i + 1,
        title: titles[i],
        content: i == 0
            ? '1. Alleluja, chwalcie Pana, Nućcie Jemu chwałę, cześć! Chwalcie, wszyscy aniołowie, '
                  'Głosząc Jego łaski wieść! Chwal Go, słońce i księżycu, Chwal Go, mnóstwo jasnych gwiazd, '
                  'Chwalcie, góry, chwalcie, drzewa, Chwalcie, ptaki, z swoich gniazd!\n\n'
                  'Refren: Wysławiajcie imię Pańskie, Uwielbiajcie Jego moc! [:Niech są pełne Jego chwały,:] '
                  'Niech są pełne Jego chwały Niebo, ziemia w dzień i w noc!'
            : 'treść ${i + 1}',
        favorite: i == 2 || i == 4,
      ),
  ];
}

/// Dłuższa lista do zrzutu szybkiego przewijania: uchwyt pokazuje się dopiero, gdy jest co
/// przewijać. Tytuły powtarzają się cyklicznie, numery rosną tak jak w śpiewniku.
List<Song> manySongs({int count = 200}) {
  final titles = sampleSongs().map((song) => song.title).toList();
  return [
    for (var i = 0; i < count; i++)
      Song(
        number: i + 1,
        title: titles[i % titles.length],
        content: 'treść ${i + 1}',
        favorite: i % 37 == 0,
      ),
  ];
}

/// Własna pieśń do zrzutów.
MySong sampleMySong() {
  final now = DateTime(2026, 9, 18, 12);
  return MySong(
    title: 'Wieczorna modlitwa',
    content: '1. Zmierzch zapada, Panie, zostań z nami.\n\nRefren: Ciebie wielbimy.',
    createdAt: now,
    updatedAt: now,
  );
}
