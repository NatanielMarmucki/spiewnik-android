# Spiewnik

## Testy

Testy korzystające z bazy ObjectBox potrzebują natywnej biblioteki ObjectBox w katalogu `lib/`
(`libobjectbox.dylib` na macOS, `libobjectbox.so` na Linuksie). Biblioteka nie jest w repozytorium,
więc po sklonowaniu i na CI trzeba ją najpierw pobrać:

```sh
tools/fetch_objectbox_lib.sh
flutter test
```

Skrypt pobiera `objectbox-c` w wersji zgodnej z pakietem `objectbox` z `pubspec.lock` i sprawdza sumę
kontrolną archiwum. Obsługuje macOS oraz Linux x64 i aarch64. Po aktualizacji pakietu `objectbox` skrypt
przerwie działanie i trzeba w nim podbić wersję biblioteki oraz sumy kontrolne.

Testy czytnika starej bazy iOS (`test/core_data_reader_test.dart`, `test/core_data_migration_test.dart`) używają
SQLite przez `sqflite_common_ffi`. Pakiet `sqlite3` (od wersji 3) przy pierwszym uruchomieniu testów pobiera przez
build hook prekompilowaną bibliotekę z wydań `sqlite3.dart` na GitHubie (sprawdzaną sumą kontrolną) do
`.dart_tool/hooks_runner/`, więc pierwsze uruchomienie, także na CI, wymaga dostępu do sieci. Na Linuksie README
`sqflite_common_ffi` nadal zaleca pakiet `libsqlite3-dev`.

`sqflite_common_ffi` jest zależnością deweloperską: biblioteka SQLite z hooka trafia do buildów debug (APK debug,
aplikacja na symulator iOS), ale nie do APK release ani archiwum IPA. Aplikacja na urządzeniu czyta starą bazę iOS
przez `sqflite`, czyli systemowe SQLite.

## Znane pułapki

### `flutter_native_splash` nadpisuje `UIStatusBarHidden` i zasoby Androida

`dart run flutter_native_splash:create` poza ekranem startowym zmienia pliki, których nie powinien ruszać:

- w `ios/Runner/Info.plist` ustawia **`UIStatusBarHidden` na `false`** (opcja `fullscreen` domyślnie `false`)
  i przeformatowuje cały plik. Aplikacja ma mieć `true`, tak jak poprzednia wersja w App Store. Ustawienie
  `fullscreen: true` w `pubspec.yaml` nie jest rozwiązaniem, bo zmienia też ekran startowy na Androidzie;
- przegenerowuje obrazy splasha Androida w `android/app/src/main/res/drawable*/` (ta sama grafika, inne bajty)
  i tworzy `android/app/src/main/res/values/styles.xml`, którego w projekcie nie ma.

Po każdym uruchomieniu generatora:

```sh
git checkout -- ios/Runner/Info.plist     # przywraca UIStatusBarHidden = true
plutil -p ios/Runner/Info.plist | grep UIStatusBarHidden   # musi pokazać: true
git status android                        # zmiany w Androidzie przywróć, jeśli nie były zamierzone:
git checkout -- android && rm -f android/app/src/main/res/values/styles.xml
```

Jeśli zmiana w `Info.plist` była zamierzona w tym samym commicie, nie przywracaj całego pliku, tylko ustaw
`UIStatusBarHidden` z powrotem na `true`.
