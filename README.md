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

**Symulator podawaj wyłącznie przez UDID**, nie przez nazwę. Nazwy się powtarzają — „iPhone 17" to dziś trzy różne
urządzenia (iOS 26.0, 26.3, 27.0). `xcodebuild` zbuduje przy niejednoznacznej nazwie bez słowa skargi, a `simctl`
trafi w przypadkowe z nich (`Unable to lookup in current state: Shutdown`). Stara aplikacja wyląduje wtedy na innym
symulatorze niż build Fluttera i test „nie przejdzie" z powodu procedury, nie kodu.

```sh
xcrun simctl list devices available   # skopiuj UDID właściwego urządzenia
SIM="EEE75C35-E60A-47AA-9739-659B160776DE"
OLD=$(mktemp -d)
git -C /ścieżka/do/repo-ios archive 37f0a8e | tar -x -C "$OLD"
mkdir -p "$OLD/Spiewnik/Preview Content"
xcrun simctl uninstall "$SIM" com.natanielmarmucki.Spiewnik   # tylko jeśli na symulatorze jest nowsza wersja
xcodebuild -project "$OLD/Spiewnik.xcodeproj" -scheme Spiewnik -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$OLD/dd" build
xcrun simctl install "$SIM" "$OLD/dd/Build/Products/Debug-iphonesimulator/Spiewnik.app"
```

Stara aplikacja ma w `Info.plist` manifest scen (`UIApplicationSupportsMultipleScenes`), więc uruchamia się także
na iOS 27 — test można przejść na tej samej wersji systemu, na której sprawdzasz nowy build.

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
- przy pierwszym uruchomieniu ekran powitalny „Śpiewnik w nowej odsłonie”, `flutter.postMigrationWelcomeShown` = `true`
  i w logu „Welcome screen: showing it once”; przy drugim od razu lista pieśni. Ekran nie wraca także wtedy, gdy
  aplikację zamknięto bez dotknięcia „Zaczynajmy” — flaga zapisuje się, zanim ekran się pokaże;
- po odinstalowaniu i czystej instalacji tego samego buildu ekranu powitalnego **nie ma** (log: „no database of the
  old iOS app”, brak `flutter.postMigrationWelcomeShown`);
- `Model.sqlite`, `-wal` i `-shm` identyczne z kopią.

## Testy golden (wygląd ekranów)

`test/golden/` trzyma obrazy wszystkich ekranów w motywie jasnym i ciemnym. Rasteryzacja czcionek różni się
między systemami, więc **obrazy powstają wyłącznie na Linuksie**, w kontenerze z przypiętym Flutterem
(`tools/golden.Dockerfile`, wersja 3.47.4 — ta sama co na CI).

```sh
tools/golden.sh            # sprawdza, czy wygląd zgadza się z obrazami w repozytorium
tools/golden.sh --update   # zapisuje nowe obrazy po zamierzonej zmianie wyglądu
```

Pierwsze uruchomienie buduje obraz Dockera (kilka minut), kolejne korzystają z gotowego.

Lokalne `flutter test` na macOS **pomija** te testy (są oznaczone tagiem `golden` i pominięte poza Linuksem),
żeby pętla pracy została szybka. Na CI uruchamiają się normalnie i to one pilnują, żeby wygląd nie zmienił się
przypadkiem. Gdy test golden obleje na CI, w artefaktach przebiegu (`golden-failures`) leżą trzy obrazy dla
każdej różnicy: oczekiwany, otrzymany i mapa różnic.

## CI

GitHub Actions, `.github/workflows/`:

| Workflow | Kiedy | Co robi |
|---|---|---|
| `ci.yml`, zadanie „Analyze and test” | każdy pull request i push do `main` | `flutter analyze --no-fatal-infos` i `flutter test` na Ubuntu, razem z testami golden |
| `ci.yml`, zadanie „Build the Android app” | jw., równolegle | `flutter build apk --debug --target-platform android-arm64` |
| `ios-build.yml` | każdy pull request oraz ręcznie (Actions → „iOS build” → „Run workflow”) | `flutter build ios --simulator --no-codesign` na macOS |

Oba zadania `ci.yml` idą równolegle, więc wynik testów jest po około dwóch minutach, niezależnie od dłuższego buildu
Androida. Build debug powstaje tylko dla `android-arm64`: to wystarczy, żeby wykryć błędy kompilacji i linkowania,
a pełny build robi to samo trzy razy.

Flutter jest przypięty do wersji 3.47.4, tej samej co w projekcie. Przed testami CI instaluje `libsqlite3-dev`
i pobiera bibliotekę ObjectBoksa skryptem `tools/fetch_objectbox_lib.sh`. Każdy nieudany krok przerywa przebieg,
więc czerwone testy blokują scalenie.

CI uruchamia `flutter analyze --no-fatal-infos`: bez tej flagi analiza kończy się błędem przy każdej uwadze,
także poziomu „info”. Uwagi „info” (m.in. `print` i przestarzałe `canLaunch`) są znane i znikną przy porządkach
w widokach; błędy i ostrzeżenia przerywają przebieg.

Workflow iOS chodzi na pull requestach. Minuty na runnerze macOS liczą się razy dziesięć, ale repozytorium jest
publiczne, więc są darmowe. Zostaje też ręczne uruchamianie, przydatne przed wydaniem.

To samo lokalnie:

```sh
tools/fetch_objectbox_lib.sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
flutter build ios --simulator --no-codesign   # tylko na macOS
```

## Znane pułapki

### W Xcode 27 okno symulatora to DeviceHub

`Simulator.app` już nie istnieje — `open -a Simulator` kończy się „no such file", co wygląda na zepsutą
instalację, a nie jest. Okno symulatora otwiera:

```sh
open "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"
```

Bez okna i tak działa całe `xcrun simctl` (`boot`, `install`, `launch`, `io <udid> screenshot`,
`ui <udid> appearance dark|light`), więc zrzuty i instalacje robi się bez GUI. Czego `simctl` **nie**
potrafi, to stuknąć w ekran — do klikania potrzebne jest okno DeviceHuba.

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

### Manifest prywatności iOS nie pokrywa bibliotek bez własnego manifestu

App Store Connect odrzuca build, w którym kod używa API z wymaganym powodem (UserDefaults, daty plików,
wolne miejsce na dysku i inne), a żaden manifest go nie deklaruje. Wtyczki przez Swift Package Manager wnoszą
własne `PrivacyInfo.xcprivacy`, ale nie wszystkie deklarują to, czego używają: `package_info_plus` czyta daty
bundla aplikacji, a ObjectBox (CocoaPods) nie ma manifestu wcale. Te powody deklaruje
`ios/Runner/PrivacyInfo.xcprivacy`.

Po dodaniu lub podbiciu wtyczki iOS zbuduj aplikację i sprawdź, czego używają binaria bez manifestu:

```sh
flutter build ios --release --no-codesign
find build/ios/iphoneos/Runner.app -name PrivacyInfo.xcprivacy   # które biblioteki mają manifest
xcrun nm -u -j build/ios/iphoneos/Runner.app/Frameworks/ObjectBox.framework/ObjectBox \
  | grep -E '^_(f?stat|fstatat|lstat|statv?fs|getattrlist|mach_absolute_time)'
strings -a build/ios/iphoneos/Runner.app/Runner \
  | grep -xE 'fileModificationDate|fileCreationDate|creationDate|systemUptime|standardUserDefaults'
```

Wtyczki przez SPM są linkowane statycznie do `Runner`, więc ich wywołania widać w jego binarium.
