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

### Test migracji E2E ze starej aplikacji iOS

Testy jednostkowe migracji (`test/core_data_*`, `test/legacy_settings_migration_test.dart`) działają na fixtures. Przy
każdej zmianie dotykającej migracji (`lib/migration/`, `ios/Runner/AppDelegate.swift`, ObjectBox, `shared_preferences`)
trzeba też przejść pełną ścieżkę na symulatorze: stara aplikacja Swift 11.2024 z danymi, na nią build Fluttera bez
odinstalowywania. Stanu nie da się trzymać na stałe, więc przed testem odtwarza się go według tej procedury.

> **Uwaga:** `flutter test integration_test -d <symulator>` odinstalowuje aplikację i usuwa jej dane. Nie uruchamiaj
> testów integracyjnych na symulatorze przygotowanym do tego testu.

**1. Stary projekt Swift.** Repo iOS, commit `37f0a8e` („update 11.2024”, wersja ze sklepu). Projekt nie używa
CocoaPods. W repozytorium brakuje katalogu `Preview Content`, bez którego build się nie uda:

```sh
SIM="iPhone 17"   # nazwa albo UDID symulatora
OLD=$(mktemp -d)
git -C /ścieżka/do/repo-ios archive 37f0a8e | tar -x -C "$OLD"
mkdir -p "$OLD/Spiewnik/Preview Content"
xcrun simctl uninstall "$SIM" com.natanielmarmucki.Spiewnik   # tylko jeśli na symulatorze jest nowsza wersja
xcodebuild -project "$OLD/Spiewnik.xcodeproj" -scheme Spiewnik -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath "$OLD/dd" build
xcrun simctl install "$SIM" "$OLD/dd/Build/Products/Debug-iphonesimulator/Spiewnik.app"
```

**2. Dane w starej aplikacji** (ręcznie w symulatorze):

- 3 ulubione, np. pieśni 3, 5 i 8;
- 2 własne pieśni: jedna z kilkoma akapitami (pusta linia między zwrotkami), druga z polskimi znakami w tytule
  i treści (np. „Pieśń na drogę”, „Żółta gęś, ćma i źdźbło.”);
- w ustawieniach rozmiar czcionki inny niż domyślny.

Potem wyjdź z aplikacji do ekranu głównego (zapis Core Data) i zamknij ją:
`xcrun simctl terminate "$SIM" com.natanielmarmucki.Spiewnik`.

**3. Kopia stanu przed testem.** Nowe dane zwykle są tylko w `Model.sqlite-wal`, więc kopiuj wszystkie trzy pliki
i **nie otwieraj bazy w kontenerze** narzędziem `sqlite3` (zrobi checkpoint i zmieni pliki):

```sh
C=$(xcrun simctl get_app_container "$SIM" com.natanielmarmucki.Spiewnik data)
BEFORE=$(mktemp -d)
cp "$C"/Documents/Model.sqlite* "$BEFORE"/
cp "$C/Library/Preferences/com.natanielmarmucki.Spiewnik.plist" "$BEFORE"/
(cd "$C/Documents" && shasum -a 256 Model.sqlite*) > "$BEFORE/sha256.txt"
plutil -p "$BEFORE/com.natanielmarmucki.Spiewnik.plist" | grep isSize
```

Zawartość sprawdzaj na kopii: `sqlite3 "$BEFORE/Model.sqlite" "SELECT ZNUMBER FROM ZSONG WHERE ZFAVORITE = 1; SELECT ZTITLE FROM ZMYSONG;"`.

**4. Build Fluttera na wierzch, bez odinstalowywania:**

```sh
flutter build ios --simulator
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$SIM" com.natanielmarmucki.Spiewnik
```

Po instalacji kontener dostaje nowy katalog, dlatego ścieżkę `C` pobierz ponownie. Dane zostają.

**5. Sprawdzenie** (po zamknięciu aplikacji, pierwsze i drugie uruchomienie):

```sh
C=$(xcrun simctl get_app_container "$SIM" com.natanielmarmucki.Spiewnik data)
plutil -p "$C/Library/Preferences/com.natanielmarmucki.Spiewnik.plist" | grep -E 'flutter\.|isSize'
(cd "$C/Documents" && shasum -a 256 Model.sqlite*) | diff "$BEFORE/sha256.txt" - && echo "Model.sqlite nietknięty"
xcrun simctl spawn "$SIM" log show --last 5m --style compact --predicate 'process == "Runner"' | grep -F migration
```

- `flutter.coreDataMigrationDone` i `flutter.legacySettingsMigrationDone` = `true`, brak `flutter.coreDataMigrationFailed`;
- `flutter.fontSize` równe `isSize` (przycięte do 10–30);
- log: „marked 3 favorites, added 2 user songs”, a przy drugim uruchomieniu „already done, skipping”;
- w aplikacji: te same ulubione, własne pieśni z pełną treścią, po drugim uruchomieniu bez duplikatów;
- `Model.sqlite`, `-wal` i `-shm` identyczne z kopią.

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
