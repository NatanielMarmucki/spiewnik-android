import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiewnik/model/font_size_model.dart';

/// Ustawienia tekstu istniejących użytkowników: nowe domyślne obowiązują tylko przy pierwszej
/// instalacji, a zapisane wartości spoza nowego zakresu są przycinane, nie resetowane.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FontSizeModel> load(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final model = FontSizeModel();
    await model.loaded;
    return model;
  }

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  test('pierwsza instalacja dostaje nowe domyślne 19 i 1,62', () async {
    final model = await load({});

    expect(model.fontSize, 19.0);
    expect(model.lineHeight, 1.62);
    // Brakujący klucz zostaje brakujący: nic nie zapisujemy przy samym odczycie.
    expect((await prefs()).containsKey(FontSizeModel.fontSizeKey), isFalse);
    expect((await prefs()).containsKey(FontSizeModel.lineHeightKey), isFalse);
  });

  test('dotychczasowe ustawienia 16 i 1,5 zostają bez zmian', () async {
    final model = await load({'fontSize': 16.0, 'lineHeight': 1.5});

    expect(model.fontSize, 16.0);
    expect(model.lineHeight, 1.5);
  });

  test('wartości poniżej zakresu są przycinane do minimum', () async {
    final model = await load({'fontSize': 8.0, 'lineHeight': 1.0});

    expect(model.fontSize, 10.0);
    expect(model.lineHeight, 1.4);
    expect((await prefs()).getDouble(FontSizeModel.fontSizeKey), 10.0);
    expect((await prefs()).getDouble(FontSizeModel.lineHeightKey), 1.4);
  });

  test('wartości powyżej zakresu są przycinane do maksimum', () async {
    final model = await load({'fontSize': 44.0, 'lineHeight': 3.0});

    expect(model.fontSize, 30.0);
    expect(model.lineHeight, 1.8);
    expect((await prefs()).getDouble(FontSizeModel.fontSizeKey), 30.0);
    expect((await prefs()).getDouble(FontSizeModel.lineHeightKey), 1.8);
  });

  test('ułamkowa wartość z migracji iOS zostaje bez zaokrąglania', () async {
    // isSize ze starej aplikacji potrafi być ułamkiem, np. po przeciągnięciu suwaka.
    final model = await load({'fontSize': 25.5549418926239});

    expect(model.fontSize, 25.5549418926239);
    expect(model.lineHeight, 1.62); // interlinii stara aplikacja nie migruje
  });

  test('ułamkowa wartość z migracji iOS powyżej zakresu jest przycinana', () async {
    final model = await load({'fontSize': 33.75});

    expect(model.fontSize, 30.0);
  });

  test('suwak nie potrafi wyjść poza zakres', () async {
    final model = await load({});

    model.setFontSize(99.0);
    model.setLineHeight(0.5);

    expect(model.fontSize, 30.0);
    expect(model.lineHeight, 1.4);
    expect((await prefs()).getDouble(FontSizeModel.fontSizeKey), 30.0);
  });

  test('przywrócenie domyślnych ustawia 19 i 1,62', () async {
    final model = await load({'fontSize': 12.0, 'lineHeight': 1.75});

    model.resetToDefaults();

    expect(model.fontSize, 19.0);
    expect(model.lineHeight, 1.62);
    expect((await prefs()).getDouble(FontSizeModel.fontSizeKey), 19.0);
    expect((await prefs()).getDouble(FontSizeModel.lineHeightKey), 1.62);
  });

  test('skala pieśni bierze wartości z ustawień', () async {
    final model = await load({'fontSize': 19.0, 'lineHeight': 1.62});

    expect(model.songTextScale.lineHeight, closeTo(30.78, 0.001));
  });
}
